#!/usr/bin/ksh -p
#
##########################################################################################
#
# Control script for Arcturus mysql servers
#
# Author: David Harper <adh@sanger.ac.uk>
#
# Usage:
#
#    arcturus-mysql.sh <cluster-name> <instance-name> <action>
#
# <cluster-name> must be either babel or pcs3
#
# <instance-name> must be one of prod, dev, babel-prod, babel-dev, pcs3-prod, pcs3-dev
#
# <action> is interpreted as follows:
#
#     The 'start', 'stop' and 'check' actions are for use by the CAA daemon.
#
#     To bring down a server manually so that CAA will not restart it, use the
#     'userstop' action. In addition to stopping the server, this creates a lockfile.
#
#     The 'check' action will always return zero (i.e. telling CAA that the application
#     is still running) if it detects the existence of the lockfile.
#
#     The 'start' action will do nothing if it detects the existence of the lockfile.
#
#     Thus, if the lockfile is present, CAA will be unaware that the application
#     is unavailable, and even if it tries to restart the application, nothing will
#     happen.
#
#     Use the 'userstart' action to remove the lockfile. When CAA next checks the
#     application, this script will then perform a real check and inform CAA that
#     the application is not running. CAA should then successfully restart the
#     application.
#
##########################################################################################

CLUSTER=${1-unknown}
INSTANCE=${2-unknown}
ACTION=${3-check}

case $CLUSTER in
  'babel')
    MYSQLHOME=/nfs/pathsoft/external/mysql-3.23.51
    ARCTURUSHOME=/nfs/pathdb/arcturus
    MYSQLHOST=babel
    ;;

  'pcs3')
    MYSQLHOME=/nfs/pathdb2/external/mysql-3.23.51
    ARCTURUSHOME=/nfs/pathdb2/arcturus
    MYSQLHOST=pcs3
    ;;

  *)
    echo ERROR -- UNKNOWN CLUSTER NAME: $CLUSTER
    exit -1;
    ;;
esac

STARTCONFIG=${ARCTURUSHOME}/init.d/mysqld-${INSTANCE}.cnf
STOPCONFIG=${ARCTURUSHOME}/init.d/shutdown.cnf
MYSQLDATADIR=${ARCTURUSHOME}/mysql/data
LOCKFILEDIR=${ARCTURUSHOME}/caa
ERRORLOGFILE=${ARCTURUSHOME}/mysql/logs/${INSTANCE}.log

case $INSTANCE in
  'babel-prod')
    MYSQLPORT=14643
    SERVER_ID=3
    SERVICE_NAME="mysqld-babel-prod"
    ;;

  'babel-dev')
    MYSQLPORT=14644
    SERVER_ID=4
    SERVICE_NAME="mysqld-babel-dev"
    ;;

  'pcs3-prod')
    MYSQLPORT=14643
    SERVER_ID=3
    SERVICE_NAME="mysqld-pcs3-prod"
    ;;

  'pcs3-dev')
    MYSQLPORT=14644
    SERVER_ID=4
    SERVICE_NAME="mysqld-pcs3-dev"
    ;;

  'prod')
    MYSQLPORT=14641
    SERVER_ID=1
    SERVICE_NAME="mysqld-prod"
    ;;

  'dev')
    MYSQLPORT=14642
    SERVER_ID=2
    SERVICE_NAME="mysqld-dev"
    ;;

  *)
    echo ERROR -- UNKNOWN INSTANCE NAME: $INSTANCE
    exit -1
    ;;
esac

if [ ! -d ${MYSQLDATADIR}/${INSTANCE} ]; then
    echo ERROR -- CANNOT FIND DATA DIRECTORY ${MYSQLDATADIR}/${INSTANCE}
    exit -1
fi

if [ ! -f ${STARTCONFIG} ]; then
    echo ERROR -- CANNOT FIND CONFIG FILE ${STARTCONFIG}
    exit -1
fi

if [ ! -f ${STOPCONFIG} ]; then
    echo ERROR -- CANNOT FIND STOP-CONFIG FILE ${STOPCONFIG}
    exit -1
fi

LOCKFILE=${LOCKFILEDIR}/${INSTANCE}.nostart

PATH=/sbin:/usr/sbin:/usr/bin:${MYSQLHOME}/bin
export PATH

ARCTURUSUSER=pathdb

NOHUP=nohup

PROBE_PROCS=${MYSQLHOME}/bin/safe_mysqld

START_APPCMD="${MYSQLHOME}/bin/safe_mysqld --defaults-file=${STARTCONFIG} --err-log=${ERRORLOGFILE}"

STOP_APPCMD="${MYSQLHOME}/bin/mysqladmin --defaults-file=${STOPCONFIG} -h $MYSQLHOST -P $MYSQLPORT shutdown"

CHECK_APPCMD="${MYSQLHOME}/bin/mysqladmin -h $MYSQLHOST -P $MYSQLPORT -u ping ping"

export SERVICE_NAME START_APPCMD START_APPCMD2
export APPDIR PROBE_PROCS STOP_APPCMD STOP_APPCMD2

#########################################################################
#
# Main section of Action Script - starts, stops, or checks an application
#
# Argument:  $1 - start | stop | check
#
# Returns:   0 - successful start, stop, or check
#            1 - error
#
#########################################################################

case $ACTION in
'userstart'|'start')
    if [ "$ACTION" = "userstart" ]; then
        if [ -f $LOCKFILE ]; then
          /bin/rm -f $LOCKFILE
        fi
    fi

    if [ -f $LOCKFILE ]; then
      exit 0
    fi

    cd $APPDIR
    if [ "$START_APPCMD" != "" ]; then
        $NOHUP $START_APPCMD &
        if [ $? -ne 0 ]; then
	    echo "start failed"
            exit 1
        fi
    fi
    ;;

#
# Stop section - stop the process and report results
#

'userstop'|'stop')
    if [ "$ACTION" = "userstop" ]; then
	/bin/touch $LOCKFILE
    fi
    cd $APPDIR
    if [ "$STOP_APPCMD" != "" ]; then
        out=`$SU $STOP_APPCMD`
        if [ $? -ne 0 -a $? -ne 4 ]; then
	    echo "stop failed: $out"
            exit 1
        fi
    fi
   ;;

#
# Check section - check the process and report results
#

'check')
    if [ -f $LOCKFILE ]; then
        exit 0
    fi

    out=`$SU $CHECK_APPCMD`
    if [ $? -ne 0 ]; then
        echo "check failed: $out"
        exit 1
    fi

    ;;

*)
    echo Unrecognised action: $ACTION
    exit 1
    ;;

*)
    echo "usage: $0 cluster-name instance-name {start|stop|check}"
    exit 1

    ;;

esac

echo Exiting ...
exit 0
