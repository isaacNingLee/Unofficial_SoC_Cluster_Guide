# NUS SoC compute-cluster helpers.
# Source this file from ~/.bashrc; do not execute it as a standalone script.

# Print free and total GPU counts by GPU type, excluding unavailable nodes.
gpufree() {
  sinfo -N -h -O NodeList:100,StateComplete:30,Gres:200,GresUsed:200 |
  gawk '
  !seen[$1]++ {
      state = tolower($2)
      if (state ~ /(down|drain|fail|maint|power|future|unknown|reserved)/)
          next

      for (column = 3; column <= 4; column++) {
          count = split($column, entries, ",")
          for (i = 1; i <= count; i++) {
              entry = entries[i]
              sub(/\(.*/, "", entry)

              fields = split(entry, part, ":")
              if (part[1] != "gpu")
                  continue

              type = (fields == 3 ? part[2] : "untyped")

              if (column == 3)
                  total[type] += part[fields]
              else
                  used[type] += part[fields]
          }
      }
  }
  END {
      PROCINFO["sorted_in"] = "@ind_str_asc"
      printf "%-20s %s\n", "GPU_TYPE", "FREE / TOTAL"
      for (type in total)
          printf "%-20s %d / %d\n", type, total[type] - used[type], total[type]
  }'
}

# Display current jobs and terminal-state jobs from the past 24 hours.
show_job() {
    {
        printf '%s\n' \
          'ID|JOBNAME|PARTITION|QOS|STATE|RUNNING TIME|WALLTIME|NODES|DETAILS|ExitCode|AllocCPUs'

        # Current jobs.
        squeue \
          --noheader \
          --me \
          --Format='JobID:32|,Name:1000|,Partition:32|,QOS:24|,State:48|,TimeUsed:24|,TimeLimit:24|,NumNodes:12|,ReasonList:256|,exit_code:16|,NumCPUs:16'

        # Finished jobs from the past 24 hours.
        sacct \
          --noheader \
          --parsable2 \
          --allocations \
          --user="$USER" \
          --starttime=now-1day \
          --endtime=now \
          --format='JobIDRaw,JobName%1000,Partition,QOS,State,Elapsed,Timelimit,NNodes,NodeList%256,ExitCode,AllocCPUS' |
        awk -F'|' '
            $5 ~ /(COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|PREEMPTED|BOOT_FAIL|DEADLINE|REVOKED)/
        '
    } |
    awk -F'|' '
        BEGIN {
            OFS = "|"
        }

        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        # Convert 00:42:19 to 42m, 05:27:41 to 5h27m, and so on.
        function compact_time(value, dayparts, timeparts,
                              count, days, hours, minutes, seconds, result) {
            value = trim(value)

            if (value == "" ||
                value == "UNLIMITED" ||
                value == "Partition_Limit" ||
                value == "Unknown" ||
                value == "N/A") {
                return value
            }

            days = 0

            if (index(value, "-")) {
                split(value, dayparts, "-")
                days = dayparts[1] + 0
                value = dayparts[2]
            }

            count = split(value, timeparts, ":")

            if (count == 3) {
                hours   = timeparts[1] + 0
                minutes = timeparts[2] + 0
                seconds = timeparts[3] + 0
            } else if (count == 2) {
                hours   = 0
                minutes = timeparts[1] + 0
                seconds = timeparts[2] + 0
            } else {
                return value
            }

            result = ""

            if (days)
                result = result days "d"

            if (hours || days)
                result = result hours "h"

            if (minutes || hours || days)
                result = result minutes "m"
            else if (seconds > 0)
                result = "<1m"
            else
                result = "0m"

            return result
        }

        function truncate(value, maximum) {
            value = trim(value)

            if (length(value) > maximum)
                return substr(value, 1, maximum - 3) "..."

            return value
        }

        NR == 1 {
            print
            next
        }

        NF >= 11 {
            for (i = 1; i <= 11; i++)
                $i = trim($i)

            $6 = compact_time($6)
            $7 = compact_time($7)

            # Prevent long node lists or reasons from stretching the table.
            # The complete job name in $2 is not truncated.
            $9 = truncate($9, 45)

            print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
        }
    ' |
    column -t -s '|'
}
