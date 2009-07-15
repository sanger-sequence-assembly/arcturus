#!/bin/ksh
#
##########################################################################################
#
# Control script for Arcturus servers
#
# Author: David Harper <adh@sanger.ac.uk>
#
# Usage:
#
#    arcturus.sh <action>
#
# <action> is one of start or stop
#
##########################################################################################

ARCTURUSUSER=pathdb

CAA_SCRIPT_DEBUG=1
export CAA_SCRIPT_DEBUG

if [ "$USER" != "$ARCTURUSUSER" ]; then
    echo You must run this script as $ARCTURUSUSER
    exit -1
fi

ACTION=${1-blarglefarble}

CLUSTER=`/nfs/pathsoft/arcturus/utils/clu_get_name`
if [ $? -ne 0 ]; then
    echo Unable to determine cluster alias
    exit -1
fi

case $CLUSTER in
  'babel')
    ARCTURUSHOME=/nfs/pathdb/arcturus
    OTHERCLUSTER=pcs3
    ;;

  'pcs3')
    ARCTURUSHOME=/nfs/pathdb2/arcturus
    OTHERCLUSTER=babel
    ;;

  *)
    echo ERROR -- UNKNOWN CLUSTER
    exit -1;
    ;;
esac

echo Cluster is $CLUSTER
echo Other cluster is $OTHERCLUSTER

MYSQLSCRIPT=${ARCTURUSHOME}/caa/arcturus-mysql.sh
APACHESCRIPT=${ARCTURUSHOME}/init.d/apachectl

case $ACTION in
  'start')
    echo Attempting to start servers
    ;;

  'stop')
    echo Attempting to stop servers
    ;;

  *)
    echo Unknown command option: $ACTION
    echo Argument must be either start or stop
    exit -1
    ;;
esac

echo Production MySQL server ...
${MYSQLSCRIPT} $CLUSTER prod                 $ACTION
echo Development MySQL server ...
${MYSQLSCRIPT} $CLUSTER dev                  $ACTION
echo Production mirror MySQL server ...
${MYSQLSCRIPT} $CLUSTER ${OTHERCLUSTER}-prod $ACTION
echo Development mirror MySQL server ...
${MYSQLSCRIPT} $CLUSTER ${OTHERCLUSTER}-dev  $ACTION

echo Apache web server ...
${APACHESCRIPT} $ACTION

exit 0

