#!/bin/csh -f

if ( $#argv != 0 ) then
    echo
    echo "Submit jobs to SGE as array jobs."
    echo
    echo "usage: submit.csh"
    echo
    exit 1
endif

$DOCKBASE/docking/submit/subdock.csh $DOCKBASE/docking/DOCK/bin/dock.csh
exit $status
