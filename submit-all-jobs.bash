#!/bin/bash

# req: INPUT_FILE
# req: OUTPUT_DEST

# opt: MAX_PARALLEL

function log {
    echo "[submit-all $(date +%X)]: " $@
}

function mkd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
}

MAX_PARALLEL=${MAX_PARALLEL-5000}

export INPUT_FILENAME=$(basename $INPUT_FILE)
export OUTPUT_DEST=$OUTPUT_DEST/$INPUT_FILENAME.batch-3d.d

if ! [ -z $WIPE_ALL ]; then
    log "wiping all previous files before running..."
    rm -r $OUTPUT_DEST/*
fi

mkd $OUTPUT_DEST/in
mkd $OUTPUT_DEST/out
mkd $OUTPUT_DEST/log

log "splitting file into sub-batches of 50,000..."

if [ `ls $OUTPUT_DEST/in | wc -l` -gt 0 ]; then rm -r $OUTPUT_DEST/in/*; fi
split --suffix-length=3 --lines=50000 $INPUT_FILE $OUTPUT_DEST/in/

for batch_50K in $OUTPUT_DEST/in/*; do
    
    log "processing batch: $batch_50K"
    batch_name=$(basename $batch_50K)

    export OUTPUT=$OUTPUT_DEST/out/$batch_name.d
    export LOGGING=$OUTPUT_DEST/log/$batch_name.d
    export INPUT=$batch_50K.d

    mkd $OUTPUT
    mkd $LOGGING
    mkd $INPUT

    split --suffix-length=3 --lines=50 $batch_50K $INPUT/
    qsub -v OUTPUT=$OUTPUT -v LOGGING=$LOGGING -v INPUT=$INPUT -N batch_3d 'build-3d.bash'
    log "submitted batch"

    jobs=`qstat | tail -n+3 | grep batch_3d`
    n_jobs=`echo "$jobs" | wc -l`
    while [ "$n_jobs" -ge $((MAX_PARALLEL/1000)) ]; do
        sleep 5
        jobs=`qstat | tail -n+3 | grep batch_3d`
        n_jobs=`echo "$jobs" | wc -l`
    done

    log n_jobs=$n_jobs

done
