#!/bin/bash

# MIGRATE_HOST
# MIGRATE_USER
# MIGRATE_DEST
# OUT_SRC

MIGRATE_HOST=gimel
MIGRATE_USER=btingle
MIGRATE_DEST=/nfs/exb/zinc22
OUT_SRC=/wynton/group/bks/zinc22
PW_FILE=~/.ssh/.pw

function _rsync {
    in=$1
    out=$2
    sshpass -f $PW_FILE rsync $in $MIGRATE_USER@$MIGRATE_HOST:$out
}

function _ssh_cmd {
    sshpass -f $PW_FILE ssh $MIGRATE_USER@$MIGRATE_HOST $@
}

function relative_dir {
    base=$1
    path=$2
    relative=""
    depth_b=$(echo $base | awk -F'/' '{print NF-1}')
    depth_p=$(echo $path | awk -F'/' '{print NF-1}')
    for i in $(seq $((depth_b+1)) $depth_p); do
        relative="$relative/$(echo $path | cut -d'/' -f$i)"
    done
    echo $relative
}

function exists_on_host {
    in=$1
}

function mkdir_host {

}

for partition in $OUT_SRC/*.build-3d.d; do

    for batch in $partition/out/*.d; do

        for result in $batch/*.tar.gz; do

            relative=$(relative_dir $OUT_SRC $result)
            dest=$MIGRATE_DEST/$relative
            echo $relative
        
        done
    done
done