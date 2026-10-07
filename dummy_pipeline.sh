#!/bin/bash

# Dummy pipeline used to test a Slurm submission end to end.
#
# It deliberately runs for a couple of minutes so you can confirm the job
# while it is still PENDING/RUNNING in squeue, not only after it finishes.
#
# Called by job_template.sbatch as:
#   bash dummy_pipeline.sh "$@"

set -euo pipefail

echo "Dummy pipeline started on $(hostname) at $(date)"
echo "Arguments received: $*"

echo "---- nvidia-smi ----"
nvidia-smi || echo "nvidia-smi not available (no GPU allocated?)"

TOTAL_STEPS=12
for step in $(seq 1 "$TOTAL_STEPS"); do
    echo "Step $step/$TOTAL_STEPS at $(date +%T)"
    sleep 10
done

echo "Dummy pipeline finished at $(date)"
