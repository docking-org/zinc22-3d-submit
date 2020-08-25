#!/bin/bash
mkdir /scratch/lig_build_py3-3.7
echo "copying python env"
time cp $HOME/soft/lig_build_py3-3.7.tar.gz /scratch/lig_build_py3-3.7
echo "untarring python env"
cd /scratch/lig_build_py3-3.7
time tar -xzf lig_build_py3-3.7.tar.gz
echo "done!" > .done
