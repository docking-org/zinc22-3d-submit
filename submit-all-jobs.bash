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

MAX_BATCHES=40
MAX_PARALLEL=${MAX_PARALLEL-15000}

log MAX_PARALLEL=$MAX_PARALLEL
log MAX_BATCHES=$MAX_BATCHES

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

if [ `ls $OUTPUT_DEST/in | wc -l` -eq 0 ]; then
split --suffix-length=3 --lines=50000 $INPUT_FILE $OUTPUT_DEST/in/
fi

for batch_50K in $OUTPUT_DEST/in/*; do
    if [ -d $batch_50K ]; then
        continue
    fi    

    log "processing batch: $batch_50K"
    batch_name=$(basename $batch_50K)

    export OUTPUT=$OUTPUT_DEST/out/$batch_name.d
    export LOGGING=$OUTPUT_DEST/log/$batch_name.d
    export INPUT=$batch_50K.d

    mkd $OUTPUT
    mkd $LOGGING
    mkd $INPUT

    split --suffix-length=3 --lines=50 $batch_50K $INPUT/
    n_submit=$(ls $INPUT | wc -l)

    if [ -d $OUTPUT ]; then
        log "checking existing output..."
        all_input=$(ls -l $INPUT | grep -v "^d" | awk '{print $9}')
        present=$(ls $OUTPUT | cut -d'.' -f1 | sort -n)
        all=$(seq 1 $n_submit)
        missing=$(printf "$present\n$all\n" | sort -n | uniq -u)
        if [ $(printf "$missing" | wc -l) -gt 0 ]; then
            if [ -d $INPUT/resubmit ]; then rm -r $INPUT/resubmit; fi
	    mkdir $INPUT/resubmit
            for m in $missing; do
                infile=$(printf "$all_input" | tr '\n' ' ' | cut -d' ' -f$m)
		ln -s $INPUT/$infile $INPUT/resubmit/$m
            done
	    export RESUBMIT=TRUE
            n_submit=$(ls $INPUT/resubmit | wc -l)
            log "resubmitting $n_submit failed items of $batch_50K"
        fi
    else
        export RESUBMIT=
    fi

    job_id=$(sbatch --parsable --array=1-$n_submit -J batch_3d 'build-3d.bash')
    log "submitted batch with job_id=$job_id"

    n_uniq=`squeue | tail -n+2 | grep batch_3d | awk '{print $1}' | cut -d'_' -f1 | sort -u | wc -l`
    n_jobs=`squeue | tail -n+2 | grep batch_3d | wc -l`
    n_jobs=$((n_jobs-n_uniq))
    log "$n_uniq batches submitted, $n_jobs jobs running"
    while [ "$n_jobs" -ge $MAX_PARALLEL ] || [ "$n_uniq" -ge $MAX_BATCHES ]; do
        sleep 120
        n_uniq=`squeue | tail -n+2 | grep batch_3d | awk '{print $1}' | cut -d'_' -f1 | sort -u | wc -l`
        n_jobs=`squeue | tail -n+2 | grep batch_3d | wc -l`
        n_jobs=$((n_jobs-n_uniq))
        log "$n_uniq batches submitted, $n_jobs jobs running"
    done

    log n_jobs=$n_jobs

done
