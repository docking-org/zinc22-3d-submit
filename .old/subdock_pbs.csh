#!/bin/csh -f

if ( $#argv != 1 ) then
    echo
    echo "Submit jobs to PBS as a colection jobs using specified DOCK version."
    echo
    echo "usage: subdock.csh path/to/dock_executable"
    echo
    exit 1
endif

set dock = "$1"

if ( ! -e dirlist ) then
    echo "Error: Cannot find dirlist, the list of subdirectories!"
    echo "Exiting!"
    exit 1
endif

set dirnum=`cat dirlist | wc -l`

set dirarray=`cat dirlist`
set i = 1

setenv DOCK $dock

set mount = `pwd`

while ($i <= $dirnum)
   set pth = $dirarray[$i]
   cd $mount/$pth
   echo "In dir:  $mount/$pth"
   ls -l 
   #qsub $DOCKBASE/docking/submit/rundock_pbs.csh "$dock"
   qsub $DOCKBASE/docking/submit/rundock_pbs.csh 
   @ i = $i + 1 
end


