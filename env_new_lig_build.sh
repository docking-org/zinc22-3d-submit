#!/bin/bash

export SOFTBASE=/bks/soft
export SOFTBASE2=~/soft
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
export PATH="$SOFTBASE/corina/current:${PATH}"

# so does openbabel
export OBABELBASE=$WORK_DIR/openbabel-install
export PATH="${PATH}:${OBABELBASE}/bin"

# aaand jchem too. all the software
# activate the openeye license
export OE_LICENSE=$SOFTBASE/openeye/oe_license.txt
export CHEMAXON_PATH=$SOFTBASE/jchem/jchem-19.15
export CHEMAXON_LICENSE_URL=$SOFTBASE/jchem/license.cxl
export PATH="$PATH:$CHEMAXON_PATH/bin"

LIMIT_JAVA="${DOCKBASE}/common/java-thread-limiter/mock-num-cpus 2"
export CXCALCEXE="${LIMIT_JAVA} `which cxcalc `"
export MOLCONVERTEXE="${LIMIT_JAVA} `which molconvert`"
export PATH="${PATH}:${DOCKBASE}/bin"

# activate python environment
source $PYTHONBASE/bin/activate
