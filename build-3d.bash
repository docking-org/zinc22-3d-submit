#!/bin/bash
#
#$ -o /scratch 
#$ -e /scratch
#$ -cwd
#$ -t 1-1000

# req: JOB_ID
# req: SGE_TASK_ID
# req: INPUT
# req: OUTPUT
# req: LOGGING

# opt: WORK_DIR

WORK_DIR=${WORK_DIR-/dev/shm}

function log {
    echo "[build-3d $(date +%X)]: $@"
}

function mkcd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
    cd $1
}

cwd=$PWD

if [ -f $OUTPUT/$SGE_TASK_ID.tar.gz ]; then
    log "results already present in $OUTPUT_BASE for this job, exiting..."
    exit
fi

WORK_BASE=$WORK_DIR/${JOB_ID}_${SGE_TASK_ID}.build-3d.d
mkcd $WORK_BASE

# cd $INPUT
SPLIT_FILE=`ls $INPUT | tr '\n' ' ' | cut -d' ' -f$SGE_TASK_ID`
cp $INPUT/$SPLIT_FILE $WORK_BASE/$SGE_TASK_ID

log SPLIT_FILE=$INPUT/$SPLIT_FILE

cd $WORK_BASE

log "starting build job on $WORK_BASE/$SGE_TASK_ID"
log `head $SGE_TASK_ID`
log `wc -l $SGE_TASK_ID`

# this will contain all the necessary exports, software, etc.
source $cwd/env_new_lig_build.sh
export DEBUG=TRUE
${DOCKBASE}/common/on-one-core-py3 - ${DOCKBASE}/ligand/generate/build_database_ligand_strain_noH.sh -H 7.4 --no-db ${SGE_TASK_ID}

log "finished build job on $WORK_BASE/$SGE_TASK_ID"

tar -czf $SGE_TASK_ID.tar.gz finished/*
mv $SGE_TASK_ID.tar.gz $OUTPUT
mv /scratch/batch_3d*$JOB_ID*$SGE_TASK_ID* $LOGGING

cd $cwd

rm -r $WORK_BASE
