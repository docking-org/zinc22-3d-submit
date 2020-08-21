#!/bin/bash
echo "copying dock env"
time cp $HOME/soft/${DOCK_VERSION}.tar.gz $WORK_DIR/${DOCK_VERSION}.tar.gz
echo "untarring dock env"
pushd $WORK_DIR 2>&1 > /dev/null
time tar -xzf ${DOCK_VERSION}.tar.gz
echo "done!" > ${DOCK_VERSION}/.done
popd 2>&1 > /dev/null
