#!/bin/csh -f

if ( $#argv != 0 ) then
    echo
    echo "Submit jobs to PBS as array jobs."
    echo
    echo "usage: submit.csh"
    echo
    exit 1
endif

$DOCKBASE/docking/submit/subdock_pbs_array.csh $DOCKBASE/docking/DOCK/bin/dock.csh
exit $status
