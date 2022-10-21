#!/bin/csh
#PBS -l walltime=24:00:00
#PBS -o /dev/null
#PBS -e /dev/null
#PBS -V


if ( $#argv != 0 ) then
    echo
    echo "Run a dock job inside PBS."
    echo
    echo "usage: rundock.csh" 
    echo
    exit 1
endif

# go to the dir were script was run, this is where the dir file was located 
cd $PBS_O_WORKDIR

set dock = "$DOCK"

#echo "Copying DOCK to directory: $PWD"
$DOCKBASE/docking/DOCK/bin/get_dock_files.csh

# switch to subdirectory
echo "Starting dock in directory: $PWD" >> stderr
set dirarray=`cat dirlist`

if ! $?PBS_ARRAYID then
    set PBS_ARRAYID=1
endif

set pth=$dirarray[$PBS_ARRAYID]

cd $pth

echo "HOST: "`hostname` > stderr

# get the real path with this pwd madness (i.e. dock68 instead of dockenv) 
pushd "$dock:h" > /dev/null
set real_dir = `pwd`
popd > /dev/null

echo "DOCK: $real_dir/$dock:t" >> stderr
if ( $?PBS_JOBID ) then 
    echo "JOB ID: $PBS_JOBID" >> stderr
endif
if ( $?PBS_ARRAYID) then
    echo "TASK ID: $PBS_ARRAYID" >> stderr
endif
# now run dock

$dock INDOCK >>& stderr
exit $status
