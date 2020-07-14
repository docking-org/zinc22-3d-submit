#!/bin/bash

# req: INPUT_FILENAME
# req: SMILES
# req: OUTPUT_DEST
# req: START_ID

# opt: WORK_DIR

WORK_DIR=${WORK_DIR-/dev/shm}

function log {
    echo "[build-3d $(date +%X)]: $@"
}

function mkcd {
    if ! [ -d $1 ]; then
        mkdir $1
    fi
    cd $1
}

cwd=$PWD

DOCKBASE=${DOCKBASE-/mnt/nfs/home/jklyu/zzz.github/DOCK3/DOCK}
OUTPUT_BASE=$OUTPUT_DEST/$INPUT_FILENAME.build-3d.d
WORK_BASE=$WORK_DIR/$INPUT_FILENAME.build-3d.d

mkcd $OUTPUT_BASE

if [ -f $START_ID.tar.gz ]; then
    log "results already present in $OUTPUT_BASE for this job, exiting..."
    exit
fi

mkcd $WORK_BASE
mkcd $START_ID

rm -r *

echo "$SMILES" > $START_ID.src

log "starting build job on $INPUT_FILENAME/$START_ID"

# this will contain all the necessary exports, software, etc.
source $cwd/env_new_lig_build.sh
${DOCKBASE}/common/on-one-core-py3 - ${DOCKBASE}/ligand/generate/build_database_ligand_strain_noH.sh -H 7.4 --no-db $START_ID.src 2>&1 > $START_ID.log

log "finished build job on $INPUT_FILENAME/$START_ID"

tar -czf ../$START_ID.tar.gz finished/*
mv $START_ID.log ..
cd ..

rm -r $START_ID