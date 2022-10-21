#!/bin/csh -f

if ( $#argv != 0 ) then
    echo
    echo "Submit jobs to PBS."
    echo
    echo "usage: submit_pbs.csh"
    echo
    exit 1
endif

$DOCKBASE/docking/submit/subdock_pbs.csh $DOCKBASE/docking/DOCK/bin/dock.csh
exit $status
