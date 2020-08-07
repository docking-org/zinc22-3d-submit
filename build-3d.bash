#!/bin/bash
#
#SBATCH -o /tmp/slurm_%A_%a.out
#SBATCH -e /tmp/slurm_%A_%a.err
#SBATCH -a 1-1000

# req: SLURM_ARRAY_JOB_ID
# req: SLURM_ARRAY_TASK_ID
# req: INPUT
# req: OUTPUT
# req: LOGGING

# opt: WORK_DIR

cwd=$PWD
export WORK_DIR=${WORK_DIR-/dev/shm}

if ! [ -f $WORK_DIR/DOCK.1/.done ]; then
	# use flock to copy software over in a thread-safe way
	flock -w 0 /tmp/dock_build.lock $cwd/cp_dock_build.bash
fi
while ! [ -f $WORK_DIR/DOCK.1/.done ]; do
	echo "waiting for DOCK..."
	sleep 2
done

if ! [ -f /tmp/lig_build_py3-3.7/.done ]; then
	# only one thread at a time should be performing a copy/untar operation
        flock -w 0 /tmp/lig_build.lock $cwd/cp_lig_build.bash
fi
while ! [ -f /tmp/lig_build_py3-3.7/.done ]; do
        echo "waiting for python environment..."
        sleep 2
done

export DOCKBASE=$WORK_DIR/DOCK.1

function log {
    echo "[build-3d $(date +%X)]: $@"
}

function mkcd {
    if ! [ -d $1 ]; then
        mkdir -p $1
    fi
    cd $1
}

if [ -f $OUTPUT/$SLURM_ARRAY_TASK_ID.tar.gz ]; then
    log "results already present in $OUTPUT_BASE for this job, exiting..."
    mv /tmp/slurm*$SLURM_ARRAY_JOB_ID*$SLURM_ARRAY_TASK_ID* $LOGGING
    exit
fi

WORK_BASE=$WORK_DIR/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.build-3d.d
mkcd $WORK_BASE

# cd $INPUT
SPLIT_FILE=`ls $INPUT | tr '\n' ' ' | cut -d' ' -f$SLURM_ARRAY_TASK_ID`
cp $INPUT/$SPLIT_FILE $WORK_BASE/$SLURM_ARRAY_TASK_ID

log SPLIT_FILE=$INPUT/$SPLIT_FILE

cd $WORK_BASE

log "starting build job on $WORK_BASE/$SLURM_ARRAY_TASK_ID"
log `head $SLURM_ARRAY_TASK_ID`
log `wc -l $SLURM_ARRAY_TASK_ID`

# this will contain all the necessary exports, software, etc.
source $cwd/env_new_lig_build.sh
export DEBUG=TRUE

${DOCKBASE}/common/on-one-core-py3 - ${DOCKBASE}/ligand/generate/build_database_ligand_strain_noH.sh -H 7.4 --no-db ${SLURM_ARRAY_TASK_ID}

log "finished build job on $WORK_BASE/$SLURM_ARRAY_TASK_ID"

echo "1" > finished/.dock_version
tar -czf $SLURM_ARRAY_TASK_ID.tar.gz finished/*
mv $SLURM_ARRAY_TASK_ID.tar.gz $OUTPUT
mv /tmp/slurm*$SLURM_ARRAY_JOB_ID*$SLURM_ARRAY_TASK_ID* $LOGGING

cd $cwd

if [ -z $SKIP_DELETE ]; then
rm -r $WORK_BASE
fi
