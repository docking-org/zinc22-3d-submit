#!/bin/csh
#PBS -l walltime=24:00:00
#PBS -o stdout
#PBS -e stderr
#PBS -V

cd $PBS_O_WORKDIR   #The working directory from where you ran qsub

if ( $#argv != 0 ) then
    echo
    echo "Run a dock job inside PBS."
    echo
    echo "usage: rundock_pbs.csh "
    echo
    exit 1
endif

set dock = "$DOCK"
#set localdock = `basename $dock`

#echo "Copying DOCK to directory: $PWD"
$DOCKBASE/docking/DOCK/bin/get_dock_files.csh

# switch to subdirectory
echo "Starting dock in directory: $PWD"

echo "HOST: "`hostname`
set real_dir = `pwd`

echo "DOCK: $real_dir/$dock:t"

echo "PBS JOB ID: $PBS_JOBID"
# now run dock

$dock INDOCK 
exit $status
