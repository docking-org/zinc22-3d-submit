#!/bin/bash

# req: INPUT_FILE
# req: OUTPUT_DEST

# opt: MAX_PARALLEL
# opt: MAX_BATCHES
# opt: LINES_PER_BATCH
# opt: LINES_PER_JOB
# opt: QSUB_ARGS
# opt: TEMPDIR

function log {
    echo "[submit-all $(date +%X)]: " $@
}

function mkd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
}

TEMPDIR=${TEMPDIR-/tmp}
MAX_BATCHES=${MAX_BATCHES-20}
MAX_PARALLEL=${MAX_PARALLEL-5000}
LINES_PER_BATCH=${LINES_PER_BATCH-20000}
LINES_PER_JOB=${LINES_PER_JOB-50}
JOBS_PER_BATCH=$((LINES_PER_BATCH/LINES_PER_JOB))

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

log "splitting file into sub-batches of $LINES_PER_BATCH..."

if [ `ls $OUTPUT_DEST/in | wc -l` -eq 0 ]; then
split --suffix-length=3 --lines=$LINES_PER_BATCH $INPUT_FILE $OUTPUT_DEST/in/
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

    if ! [ -d $INPUT ]; then
        mkdir $INPUT
        split --suffix-length=3 --lines=$LINES_PER_JOB $batch_50K $INPUT/
    fi

    n_submit=$(ls -l $INPUT | tail -n+2 | grep -v "^d" | wc -l)

    if [ -d $OUTPUT ]; then
        n_present=$(ls $OUTPUT | wc -l)
	    if [ $((n_submit-n_present)) -lt $(((5 * n_submit)/100)) ]; then
		log "this batch looks mostly done, ($((n_submit-n_present)))moving on..."
                continue
        fi

        export RESUBMIT=TRUE
        log "checking existing output..."
        all_input=$(ls -l $INPUT | tail -n+2 | grep -v "^d" | awk '{print $9}')
        present=$(ls $OUTPUT | cut -d'.' -f1 | sort -n)
        all=$(seq 1 $n_submit)
        missing=$(printf "$present\n$all\n" | sort -n | uniq -u)

        if [ -d $INPUT/resubmit ]; then rm -r $INPUT/resubmit; fi
        mkdir $INPUT/resubmit
        for m in $missing; do
            infile=$(printf "$all_input" | tr '\n' ' ' | cut -d' ' -f$m)
            ln -s $INPUT/$infile $INPUT/resubmit/$m
        done
        n_submit=$(printf "$missing" | wc -l)
        log "resubmitting $n_submit failed items of $batch_50K"
    else
	log "submitting $n_submit items of $batch_50K"
        export RESUBMIT=
    fi

    mkdir -p $OUTPUT
    mkdir -p $LOGGING

    QSUB_ARGS=${QSUB_ARGS-"-l s_rt=01:58:00 -l h_rt=02:00:00"}
    # very annoying having to export environment variables like this
    qsub $QSUB_ARGS -o $TEMPDIR -e $TEMPDIR -v TEMPDIR=$TEMPDIR -v WORK_DIR=$WORK_DIR -v RESUBMIT=$RESUBMIT -v OUTPUT=$OUTPUT -v LOGGING=$LOGGING -v INPUT=$INPUT -N batch_3d -t 1-$n_submit 'build-3d.bash'
    log "submitted batch"

    once=true
    while [ "$n_jobs" -ge $MAX_PARALLEL ] || [ "$n_uniq" -ge $((MAX_PARALLEL/500)) ] || ! [ -z $once ]; do
        [ -z $once ] && sleep 120
        n_uniq=`qstat | tail -n+3 | grep batch_3d | awk '{print $1}' | sort -u | wc -l`
        n_jobs=`qstat | tail -n+3 | grep batch_3d | wc -l`
        n_jobs=$((n_jobs-n_uniq))
        log "$n_uniq batches submitted, $n_jobs jobs running"
        once=
    done

    log n_jobs=$n_jobs

done
