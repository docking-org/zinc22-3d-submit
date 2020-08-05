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
WORK_DIR=${WORK_DIR-/dev/shm}

if ! [ -d $WORK_DIR/strainfilter_noH ]; then
        echo "copying strainfilter files"
        cp -r $HOME/soft/strainfilter_noH $WORK_DIR
fi

if ! [ -d $WORK_DIR/DOCK ]; then
        echo "copying DOCK files"
        time cp $HOME/soft/DOCK.tar.gz $WORK_DIR/DOCK.tar.gz
        echo "untarring DOCK files"
        cd $WORK_DIR
        time tar -xzf DOCK.tar.gz
fi

if ! [ -f /tmp/lig_build_py3-3.7/.done ]; then
        function build_py_env {
        mkdir /tmp/lig_build_py3-3.7
        echo "copying python env"
        time cp $HOME/soft/lig_build_py3-3.7.tar.gz /tmp/lig_build_py3-3.7
        echo "untarring python env"
        cd /tmp/lig_build_py3-3.7
        time tar -xzf lig_build_py3-3.7.tar.gz
        echo "done!" > .done
        }
        flock -w 0 /tmp/lig_build.lock $cwd/cp_lig_build.bash
fi

while ! [ -f /tmp/lig_build_py3-3.7/.done ]; do
        echo "waiting for python environment..."
        sleep 2
done

export DOCKBASE=$WORK_DIR/DOCK

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
    mv /scratch/batch_3d*$SLURM_ARRAY_JOB_ID*$SLURM_ARRAY_TASK_ID* $LOGGING
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
export DOCKBASE=$WORK_DIR/DOCK
export DEBUG=TRUE
${DOCKBASE}/common/on-one-core-py3 - ${DOCKBASE}/ligand/generate/build_database_ligand_strain_noH.sh -H 7.4 --no-db ${SLURM_ARRAY_TASK_ID}

log "finished build job on $WORK_BASE/$SLURM_ARRAY_TASK_ID"

tar -czf $SLURM_ARRAY_TASK_ID.tar.gz finished/*
mv $SLURM_ARRAY_TASK_ID.tar.gz $OUTPUT
mv /tmp/slurm*$SLURM_ARRAY_JOB_ID*$SLURM_ARRAY_TASK_ID* $LOGGING

cd $cwd

rm -r $WORK_BASE
