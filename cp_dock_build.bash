#!/bin/bash
echo "copying dock env"
time cp $HOME/soft/${DOCK_VERSION}.tar.gz $WORK_DIR/${DOCK_VERSION}.tar.gz
echo "untarring dock env"
cd $WORK_DIR
time tar -xzf ${DOCK_VERSION}.tar.gz
echo "done!" > ${DOCK_VERSION}/.done
