#!/bin/bash

# req: INPUT_FILE
# req: SLURM_PARTITION
# req: OUTPUT_DEST

# opt: MAX_PARALLEL
# opt: LOG_DIR
# opt: NICE

LOG_DIR=${LOG_DIR-$PWD/logs}
MAX_PARALLEL=${MAX_PARALLEL-2500}
NICE=${NICE-19}

N_SMILES=`cat $INPUT_FILE | wc -l`
user=`whoami`

if ! [ -d $LOG_DIR ]; then
    echo "failed to specify existing LOG_DIR. Current value: LOG_DIR=$LOG_DIR"
    exit
fi

export INPUT_FILENAME=$(basename $INPUT_FILE)
export OUTPUT_DEST

p=1
for i in `seq 100 100 $N_SMILES`; do

    export SMILES=`cat $INPUT_FILE | sed -n '$p,$i p'`
    export START_ID=$i

    srun -o $LOG_DIR/build_3d_%j.out -J build_3d --nice=$NICE -p $SLURM_PARTITION build-3d.bash

    jobs=`squeue -p $SLURM_PARTITION -u $whoami | grep build_3d`
    n_jobs=`echo "$jobs" | wc -l`

    while [ $n_jobs -eq $MAX_PARALLEL ]; then
        sleep 5
        jobs=`squeue -p $SLURM_PARTITION -u $whoami | grep build_3d`
        n_jobs=`echo "$jobs" | wc -l`
    done

    p=$((i+1))

done