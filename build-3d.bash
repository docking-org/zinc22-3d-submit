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
export OLD_DOCK_VERSION=${OLD_DOCK_VERSION-DOCK.2.4.1}
export DOCK_VERSION=${DOCK_VERSION-DOCK.2.4.2}
export OLD_PYENV_VERSION=${OLD_PYENV_VERSION-lig_build_py3-3.7}
export PYENV_VERSION=${PYENV_VERSION-lig_build_py3-3.7.1}

function synchronize_all_but_first {
	if [ -f /tmp/${1}.done ]; then return; fi # in the case of a particularly short running command, it might be done by the time another job even enters this function
	flock -w 0 /tmp/${1}.lock -c "printf ${1} && ${@:2} && echo > /tmp/${1}.done" && FIRST=TRUE
	if [ -z $FIRST ]; then
		printf "waiting ${1}"
		while ! [ -f /tmp/${1}.done ]; do sleep 1; printf "."; done
	else
		sleep 5 && rm /tmp/${1}.done
	fi
}

# any jobs that were cancelled previously should be cleaned up
old_work=$(find $WORK_DIR -mindepth 1 -maxdepth 1 -mmin +120 -name '*.build-3d.d')
old_jobs=$(find /tmp -mindepth 1 -maxdepth 1 -mmin +120 -name 'slurm*.???')

# to properly synchronize work done by multiple threads we need to do a couple things
# 1. we need a long-term flag to mark the work as completed/not completed
#    a. In the case of removing old files, this "flag" might be as simple as there no longer being old files present
#    b. In the case of an install/extract operation, this would be a ".done" file in the install directory
# 2. local synchronization
#    a. It doesn't serve us well to have multiple threads trying to extract/remove the same file at the same time
#       To prevent this it helps to use a flock lock to ensure that only one process can work on the task at a time
#    b. In the case of an install operation, we might not want other threads to continue until the first thread is done
#       with it's work. In this case, we need to have a temporary "done" flag for the first thread to signal the 
#       other waiting threads that it's okay to move on, which is what I do in the synchronize_all_but_first function

if [ $(echo "$old_work" | wc -l) -gt 1 ]; then
	synchronize_all_but_first "removing_old_work" "find $WORK_DIR -mindepth 1 -maxdepth 1 -mmin +120 -name '*.build-3d.d' | xargs rm -r"
fi
if [ $(echo "$old_jobs" | wc -l) -gt 1 ]; then
	synchronize_all_but_first "removing_old_logs" "find /tmp -mindepth 1 -maxdepth 1 -mmin +120 -name 'slurm*.???' | xargs rm"
fi
if [ -d /tmp/$OLD_PYENV_VERSION ]; then
	synchronize_all_but_first "removing_old_pyenv" "rm -r /tmp/$OLD_PYENV_VERSION"
fi
if [ -d $WORK_DIR/$OLD_DOCK_VERSION ]; then
	synchronize_all_but_first "removing_old_dock" "rm -r $WORK_DIR/$OLD_DOCK_VERSION"
fi
if ! [ -f $WORK_DIR/$DOCK_VERSION/.done ]; then
	synchronize_all_but_first "extracting_dock" "cp $HOME/soft/$DOCK_VERSION.tar.gz $WORK_DIR && pushd $WORK_DIR && time tar -xzf $DOCK_VERSION.tar.gz && echo > $DOCK_VERSION/.done && popd"
fi
if ! [ -f /tmp/$PYENV_VERSION/.done ]; then
        synchronize_all_but_first "extracting_pyenv" "cp $HOME/soft/$PYENV_VERSION.tar.gz /tmp && pushd /tmp && time tar -xzf $PYENV_VERSION.tar.gz && echo > $PYENV_VERSION/.done && popd"
fi

export DOCKBASE=$WORK_DIR/$DOCK_VERSION

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

SPLIT_FILE=`ls $INPUT | tr '\n' ' ' | cut -d' ' -f$SLURM_ARRAY_TASK_ID`
cp $INPUT/$SPLIT_FILE $WORK_BASE/$SLURM_ARRAY_TASK_ID
log SPLIT_FILE=$INPUT/$SPLIT_FILE
cd $WORK_BASE

log $(hostname)
log "starting build job on $WORK_BASE/$SLURM_ARRAY_TASK_ID"
log `head $SLURM_ARRAY_TASK_ID`
log `wc -l $SLURM_ARRAY_TASK_ID`

source $cwd/env_new_lig_build.sh
export DEBUG=TRUE
${DOCKBASE}/ligand/generate/build_database_ligand_strain_noH_btingle.sh -H 7.4 --no-db ${SLURM_ARRAY_TASK_ID}

log "finished build job on $WORK_BASE/$SLURM_ARRAY_TASK_ID"

mv working/output.tar.gz $OUTPUT/$SLURM_ARRAY_TASK_ID.tar.gz
if ! [ -z $LOGGING ]; then mv /tmp/slurm*$SLURM_ARRAY_JOB_ID*$SLURM_ARRAY_TASK_ID* $LOGGING; fi
if [ -z $SKIP_DELETE ]; then rm -r $WORK_BASE; fi
