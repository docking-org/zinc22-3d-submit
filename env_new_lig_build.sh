#!/bin/bash

# debugging stage
export DOCKBASE=/mnt/nfs/home/jklyu/zzz.github/DOCK3/DOCK
export AMSOLEXE=/nfs/soft/amsol/in-house/amsol7.1-colinear-fix/amsol7.1

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
# set the flag if omega uses hard-coded torsion patterns
#export OMEGA_HARD_CODED_TOR_PATTERN=True

# Dependencies
source /nfs/soft/corina/current/env.sh
source /nfs/soft/openbabel/openbabel-2.3.2/env.sh
# activate the openeye license
export OE_LICENSE=/nfs/soft/openeye/oe_license.txt
source /nfs/soft/jchem/jchem-19.15/env.sh

LIMIT_JAVA="${DOCKBASE}/common/java-thread-limiter/mock-num-cpus 2"
export CXCALCEXE="${LIMIT_JAVA} `which cxcalc `"
export MOLCONVERTEXE="${LIMIT_JAVA} `which molconvert`"
export PATH="${PATH}:${DOCKBASE}/bin"

# activate the conda env
source /mnt/nfs/home/jklyu/anaconda3/etc/profile.d/conda.sh
conda activate lig_build_py3-3.7