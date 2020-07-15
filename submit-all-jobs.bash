#!/bin/bash

# req: INPUT_FILE
# req: OUTPUT_DEST

# opt: MAX_PARALLEL
# opt: LOG_BASE_DIR
# opt: NICE

function log {
    echo "[submit-all $(date +%X)]: $@"
}

function mkd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
}

LOG_BASE_DIR=${LOG_BASE_DIR-$PWD/logs}
MAX_PARALLEL=${MAX_PARALLEL-2500}
NICE=${NICE-19}

N_SMILES=`cat $INPUT_FILE | wc -l`
user=`whoami`

export INPUT_FILENAME=$(basename $INPUT_FILE)
export OUTPUT_DEST

p=1
for i in `seq 100 100 $N_SMILES`; do

    export SMILES=`cat $INPUT_FILE | sed -n '$p,$i p'`
    export START_ID=$i
    export BATCH_ID=$((i/1000))

    LOG_DIR=$LOG_BASE_DIR/$INPUT_FILENAME/$BATCH_ID
    mkd $LOG_DIR

    qsub -o $LOG_DIR/build_3d_$i.out -N build_3d build-3d.bash
    #srun -o $LOG_BASE_DIR/build_3d_%j.out -J build_3d --nice=$NICE -p $SLURM_PARTITION build-3d.bash

    jobs=`qstat | tail -n+2 | grep -v "\-\-\-\-\-"`
    #jobs=`squeue -p $SLURM_PARTITION -u $whoami | grep build_3d`
    n_jobs=`echo "$jobs" | wc -l`

    while [ "$n_jobs" -ge "$MAX_PARALLEL" ]; then
        sleep 5
        jobs=`squeue -p $SLURM_PARTITION -u $whoami | grep build_3d`
        n_jobs=`echo "$jobs" | wc -l`
    done

    p=$((i+1))

done