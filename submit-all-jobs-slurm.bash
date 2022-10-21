#!/bin/bash

# req: INPUT_FILE
# req: OUTPUT_DEST

# opt: MAX_PARALLEL
# opt: MAX_BATCHES
# opt: LINES_PER_BATCH
# opt: LINES_PER_JOB
# opt: QSUB_ARGS

BINDIR=$(dirname $0)
BINDIR=${BINDIR-.}

if ! [[ "$BINDIR" == /* ]]; then
	BINDIR=$PWD/$BINDIR
fi

function log {
    echo "[submit-all $(date +%X)]: " $@
}

function mkd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
}

function exists {
	env_name=$1
	desc=$2
	if [ -z "${!env_name}" ]; then
		echo "expected env arg: $env_name"
		echo "arg description: $desc" 
		failed=1
	fi
}

function exists_warning {
	env_name=$1
	desc=$2
	default=$3
	if [ -z "${!env_name}" ]; then
		echo "optional env arg missing: $env_name"
		echo "arg description: $desc"
		echo "defaulting to $default"
		export $env_name="$default"
	fi
}

failed=0
exists INPUT_FILE "input SMILES for 3d building"
exists OUTPUT_DEST "nfs destination for db2, logs, split input files"
exists_warning SHRTCACHE "short term storage for working files" /dev/shm
exists_warning LONGCACHE "long term storage for program files" /tmp
exists_warning MAX_BATCHES "max no. of job arrays submitted at one time" 25
exists_warning LINES_PER_BATCH "number of SMILES per job array batch" 50000
exists_warning LINES_PER_JOB "number of SMILES per job array element" 50
exists_warning BATCH_RESUBMIT_THRESHOLD "minimum percentage of entries in an array batch that are complete before batch is considered complete" 80
exists_warning SOFT_HOME "nfs directory where software is stored" $HOME/soft
exists_warning LICENSE_HOME "nfs directory where licenses are stored" $HOME
exists_warning BUILD_MOL2 "build from mol2 files instead of smiles. input entries should be paths to mol2 files instead of smiles"
JOBS_PER_BATCH=$((LINES_PER_BATCH/LINES_PER_JOB))

[ $failed -eq 1 ] && exit

export INPUT_FILENAME=$(basename $INPUT_FILE)
export OUTPUT_DEST=$OUTPUT_DEST/$INPUT_FILENAME.batch-3d.d

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

    # it tends to be faster (if supported) to use du -s --inodes to count entries, as ls | wc -l can be slow
    n_submit=$(du -s --inodes $INPUT | awk '{print $1}')
    if [ -d $INPUT/resubmit ]; then
	n_resubmit=$(du -s --inodes $INPUT/resubmit | awk '{print $1}')
	n_submit=$((n_submit-n_resubmit-1)) # -1 because du counts the directory iteslf for no. of inodes
    fi

    if [ -d $OUTPUT ]; then
        #n_present=$(ls $OUTPUT | wc -l)
	n_present=$(du -s --inodes $OUTPUT | awk '{print $1}')
	if [ -d $OUTPUT/save ]; then
		n_save=$(du -s --inodes $OUTPUT/save | awk '{print $1}')
		n_present=$((n_present-n_save-1)) # -1 -1 because du counts the directory iteslf for no. of inodes
	fi
	if [ $((n_submit-n_present)) -lt $(((BATCH_RESUBMIT_THRESHOLD * n_submit)/100)) ]; then
		log "this batch looks mostly done: ($((n_submit-n_present))) missing... moving on!"
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

    # dont need to do this for slurm
    #for var in RESUBMIT OUTPUT INPUT LOGGING SHRTCACHE LONGCACHE SOFT_HOME LICENSE_HOME BUILD_MOL2; do
    #    [ -z "$var_args" ] && var_args="-v $var=${!var}" || var_args="$var_args -v $var=${!var}"
    #done

    SBATCH_ARGS=${SBATCH_ARGS-"--time=02:00:00"}
    if [ -z $BUILD_MOL2 ]; then
	    BUILD_SCRIPT="build-3d.bash"
    else
	    BUILD_SCRIPT="build-3d-mol2.bash"
    fi
    job_id=$(sbatch $SBATCH_ARGS --parsable --signal=USR1@120 -o $LOGGING/%a.out -e $LOGGING/%a.err --array=1-$n_submit%20 -J batch_3d $BINDIR/$BUILD_SCRIPT)
    log "submitted batch with job_id=$job_id"

    n_uniq=0
    once=true
    while [ "$n_uniq" -ge $MAX_BATCHES ] || ! [ -z $once ]; do
        [ -z $once ] && sleep 120
	    n_uniq=`squeue -u $(whoami) | tail -n+2 | grep batch_3d | awk '{print $1}' | cut -d'_' -f1 | sort -u | wc -l`
	    n_jobs=`squeue -u $(whoami) | tail -n+2 | grep batch_3d | wc -l`
        n_jobs=$((n_jobs-n_uniq))
        log "$n_uniq batches submitted, $n_jobs jobs running"
	once=
    done 

    log n_jobs=$n_jobs

done
