#!/bin/tcsh
#SBATCH -t 24:00:00
#SBATCH --job-name=array_job_test
#SBATCH --output=/dev/null

if ( $#argv != 0 ) then
    echo
    echo "Run a dock job with SLURM queue."
    echo
    echo "usage: rundock.csh" 
    echo
    exit 1
endif

# go to the dir were script was run, this is where the dir file was located 
cd ${SLURM_SUBMIT_DIR} 

set dock = "$DOCK"

#echo "Copying DOCK to directory: $PWD"
$DOCKBASE/docking/DOCK/bin/get_dock_files.csh

# switch to subdirectory
echo "Starting dock in directory: $PWD" >> stderr
set dirarray=`cat dirlist`

if ! $?SLURM_ARRAY_TASK_ID then
    set SLURM_ARRAY_TASK_ID=1
endif

set pth=$dirarray[${SLURM_ARRAY_TASK_ID}]

cd $pth

echo "HOST: "`hostname` > stderr

# get the real path with this pwd madness (i.e. dock68 instead of dockenv) 
pushd "$dock:h" > /dev/null
set real_dir = `pwd`
popd > /dev/null

echo "DOCK: $real_dir/$dock:t" >> stderr
if ( $?PBS_JOBID ) then 
    echo "JOB ID: $SLURM_JOBID" >> stderr
endif
if ( $?PBS_ARRAYID) then
    echo "TASK ID: $SLURM_JOBID" >> stderr
endif
# now run dock

$dock INDOCK >>& stderr
exit $status
