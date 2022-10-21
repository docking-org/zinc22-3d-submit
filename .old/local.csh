#!/bin/csh -f

if ( $#argv != 0 ) then
    echo
    echo "Run DOCK locally"
    echo
    echo "usage: local.csh"
    echo
    exit 1
endif

$DOCKBASE/docking/submit/rundock.csh $DOCKBASE/docking/DOCK/bin/dock.csh
exit $status
