#!/bin/bash
echo "copying dock env"
time cp $HOME/soft/DOCK.1.tar.gz $WORK_DIR/DOCK.1.tar.gz
echo "untarring python env"
pushd $WORK_DIR 2>&1 > /dev/null
time tar -xzf DOCK.1.tar.gz
echo "done!" > DOCK.1/.done
popd 2>&1 > /dev/null
