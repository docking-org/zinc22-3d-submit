#!/bin/bash
mkdir /tmp/lig_build_py3-3.7
echo "copying python env"
time cp $HOME/soft/lig_build_py3-3.7.tar.gz /tmp/lig_build_py3-3.7
echo "untarring python env"
pushd /tmp/lig_build_py3-3.7
time tar -xzf lig_build_py3-3.7.tar.gz
echo "done!" > .done
popd
