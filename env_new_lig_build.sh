#!/bin/bash

export PYTHONBASE=${PYTHONBASE-$WORK_DIR/$PYENV_VERSION}
export DOCKBASE=${DOCKBASE-$WORK_DIR/$DOCK_VERSION}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$WORK_DIR/lib

# amsol needs libg2c to work, which I've installed locally to wynton
#export AMSOLEXE=$SOFTBASE/amsol/in-house/amsol7.1-colinear-fix/amsol7.1

# Experimental changes to DOCK ligand pipeline
export EMBED_PROTOMERS_3D_EXE=$DOCKBASE/ligand/3D/embed3d_corina.sh
# parameters related to omega
# set omega energy window, if it equals 0, rotatable-bond-dependent window method.
export OMEGA_ENERGY_WINDOW=12
# set omega max number of confs, if it equals 0, rotatable-bond-dependent window method.
export OMEGA_MAX_CONFS=600
# set the omega torsion library: 1) Original; 2) GubaV21
export OMEGA_TORLIB=Original
# set the omega force field. Options are in the link below
# https://docs.eyesopen.com/toolkits/cpp/oefftk/OEFFConstants/OEMMFFSheffieldFFType.html#OEFF::OEMMFFSheffieldFFType::MMFF94Smod
export OMEGA_FF=MMFF94Smod
# set the omega rmsd for clustering and filtering conformations, if it equals 0, rotatable-bond-dependent window method.
export OMEGA_RMSD=0.5

# Dependencies

# CORINA env.sh on wynton has an incorrect path specified
export PATH="$WORK_DIR/corina:${PATH}"

# so does openbabel
export OBABELBASE=$WORK_DIR/openbabel-install
export BABEL_LIBDIR=$WORK_DIR/lib/openbabel/2.3.1
export BABEL_DATADIR=$WORK_DIR/openbabel-install/share/openbabel/2.3.1
export PATH="${PATH}:${OBABELBASE}/bin"

# aaand jchem too. all the software
# activate the openeye license
export OE_LICENSE=$HOME/.oe-license.txt
export CHEMAXON_PATH=$WORK_DIR/jchem-19.15
export CHEMAXON_LICENSE_URL=$HOME/.jchem-license.cxl
export PATH="$PATH:$CHEMAXON_PATH/bin"

LIMIT_JAVA="${DOCKBASE}/common/java-thread-limiter/mock-num-cpus 2"
export CXCALCEXE="`which cxcalc `"
export MOLCONVERTEXE="`which molconvert`"
export PATH="${PATH}:${DOCKBASE}/bin"

# activate python environment
source $PYTHONBASE/bin/activate
