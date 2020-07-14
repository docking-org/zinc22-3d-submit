#!/bin/bash

# req: INPUT_FILENAME (can contain path)
# req: SLURM_PARTITION

nodes=`sinfo -N -p $SLURM_PARTITION | awk '{print $1}'`

for node in nodes; do

    srun -w $node collect-3d.bash