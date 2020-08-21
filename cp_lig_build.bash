#!/bin/bash
echo "copying python env"
time cp $HOME/soft/${PYENV_VERSION}.tar.gz /tmp
echo "untarring python env"
pushd /tmp 2>&1 > /dev/null
time tar -xzf ${PYENV_VERSION}.tar.gz
echo "done!" > ${PYENV_VERSION}/.done
popd 2>&1 > /dev/null
