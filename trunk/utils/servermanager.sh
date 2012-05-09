#!/usr/bin/ksh -p
#
##########################################################################################
#
# CAA control script for Arcturus mysql servers
#
# Author: David Harper <adh@sanger.ac.uk>
#
# Usage:
#
#    arcturus-mysql.sh <cluster-name> <instance-name> <action>
#
# <cluster-name> must be either babel or pcs3
#
# <instance-name> must be one of prod, dev, test, babel-prod, babel-dev, babel-test,
#                                                 pcs3-prod,  pcs3-dev or pcs3-test
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
    SERVICE_NAME="mysqld-babel-prod"
    ;;

  'babel-dev')
    MYSQLPORT=14644
    SERVICE_NAME="mysqld-babel-dev"
    ;;

  'pcs3-prod')
    MYSQLPORT=14643
    SERVICE_NAME="mysqld-pcs3-prod"
    ;;

  'pcs3-dev')
    MYSQLPORT=14644
    SERVICE_NAME="mysqld-pcs3-dev"
    ;;

  'prod')
    MYSQLPORT=14641
    SERVICE_NAME="mysqld-prod"
    ;;

  'dev')
    MYSQLPORT=14642
    SERVICE_NAME="mysqld-dev"
    ;;


  'test')
    MYSQLPORT=14651
    SERVICE_NAME="mysqld-test"
    ;;

  'babel-test')
    MYSQLPORT=14653
    SERVICE_NAME="mysqld-babel-test"
    ;;

  'pcs3-test')
    MYSQLPORT=14653
    SERVICE_NAME="mysqld-pcs3-test"
    ;;

  'minerva')
    MYSQLPORT=19638
    SERVICE_NAME="mysqld-minerva"
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

if [ "x$CAA_SCRIPT_DEBUG" = "x" ]; then
    SU="/bin/su - pathdb -c"
else
    SU=""
fi

####################################################################
#
# The following section contains variables that can be set to best
# suit your application. 
#
# Please review each variable and set as needed.
#
# Set CAA_SCRIPT_DEBUG when invoking the script from command line 
# for testing. This will cause all output events to go to the terminal,
# rather than being sent to EVM.
#
####################################################################
#
# Application name - set this variable to a name that describes this
# (mandatory)        application.  Enclose the name in double quotes.
#                    Examples: "apache", "netscape"

#SERVICE_NAME="mysqld-babel-prod"

# Associated Processes - the application configured may consist of 
# (mandatory         single or multiple processes.  Specifying the names
#                    of the processes here allows CAA to monitor that they
#                    are running and allows CAA to completely clean up when
#                    stopping the application.
#                    Ex:  "proc1 proc2"
   

PROBE_PROCS=${MYSQLHOME}/bin/safe_mysqld

# Application Startup Command - CAA will invoke this command when starting
# (mandatory)        the application.  Include the command to execute along
#                    with any flags and arguments needed.  Use this
#                    variable along with START_APPCMD2 (see below) when
#                    dealing with a simple application start procedure.
#
#                    If the start procedure is complicated and/or involves
#                    many commands, you may find it easier to disregard
#                    this variable and manually code the commands needed
#                    in the "Start" section of this script (see below).
#                   
#                    Another alternative for a complicated start procedure
#                    is to create a separate script containing those
#                    commands and specifying that script in this variable.
#
#                    Ex: "/cludemo/avs/avsetup -s"
#
#                    NOTE: if not set, you must manually code the commands
#                    to start the application in the "Start" section of
#                    this script.

START_APPCMD="${MYSQLHOME}/bin/safe_mysqld --defaults-file=${STARTCONFIG} --err-log=${ERRORLOGFILE}"

# Secondary Application Startup Command - used in conjunction with the 
# (optional)         Application Startup Command just described above.  Use
#                    if desired to implement a two-step startup process for
#                    your application, if needed.

START_APPCMD2=""

# Application Stop Command - CAA will invoke this command when stopping
# (optional)         the application.  Include the command to execute along
#                    with any flags and arguments needed.  Use this
#                    variable along with STOP_APPCMD2 (see below) when
#                    dealing with a simple application stop procedure.
#
#                    If the stop procedure is complicated and/or involves
#                    many commands, you may find it easier to disregard
#                    this variable and manually code the commands needed
#                    in the "Stop" section of this script (see below).
#                   
#                    Another alternative for a complicated stop procedure
#                    is to create a separate script containing those
#                    commands and specifying that script in this variable.
#
#                    Ex: "/cludemo/avs/avsetup -k"
#
#                    NOTE: if not set, you should manually code the commands
#                    to stop the application in the "Stop" section of
#                    this script.  Otherwise, this script will not stop the
#                    application in a graceful manner.

STOP_APPCMD="${MYSQLHOME}/bin/mysqladmin --defaults-file=${STOPCONFIG} -h $MYSQLHOST -P $MYSQLPORT shutdown"

# Secondary Application Stop Command - used in conjunction with the 
# (optional)         Application Stop Command just described above.  Use
#                    if desired to implement a two-step stop process for
#                    your application, if needed.

STOP_APPCMD2=""

# Check Application Command - this must return zero if the application is OK
# (mandatory)       and non-zero otherwise.

CHECK_APPCMD="${MYSQLHOME}/bin/mysqladmin -h $MYSQLHOST -P $MYSQLPORT -u ping ping"

# Application Directory - If set, this script will change to this directory
# (optional)         prior to executing the start process.  This may allow 
#                    you to not have to specify full path names for 
#                    commands or files in this directory. 
#
#                    Ex:  "/var/opt/product1"

APPDIR=""

export SERVICE_NAME START_APPCMD START_APPCMD2
export APPDIR PROBE_PROCS STOP_APPCMD STOP_APPCMD2

#################################################################
#
# The following section contains variables used by CAA.  We recommend
# leaving them defined as is.
#
#################################################################

DEBUG_PRIORITY=100
INFO_PRIORITY=200
ERROR_PRIORITY=500

SCRIPT=$0
#ACTION=$1                     # Action (start, stop or check)

EVMPOST="/usr/bin/evmpost"    # EVM command to post events
DEBUG=0

if [[ "$CAA_SCRIPT_DEBUG" != "" ]]; then
    DEBUG=1
    EVMPOST="/usr/bin/evmpost -r | /usr/bin/evmshow -d"
fi      

export EVMPOST ACTION SCRIPT

###################################################################
#
# The following section contains procedures that are available to
# be used from the start, stop, and check portions of this script.
#
###################################################################

#
# postevent - Posts EVM event with specified parameters
#
# Argument:  $1 - priority (optional)
#            $2 - message  (optional)
#            
#

postevent () {
    typeset pri=$1
    typeset msg=${2:-failed}

    typeset evt='event { name sys.unix.clu.caa.action_script '

    if [ ! -z "$pri" ]; then
        evt="$evt priority $pri "
    fi

    evt="$evt var {name name value \\\"$SERVICE_NAME\\\" } "
    evt="$evt var {name script value \\\"$SCRIPT\\\" } "
    evt="$evt var {name action value \\\"$ACTION\\\" } "
    evt="$evt var {name message value \\\"$msg\\\" }"

    evt="$evt }"

    evt="echo $evt | $EVMPOST"

    eval $evt
}

#########################################################################
#
# Main section of Action Script - starts, stops, or checks an application
#        
# This script is invoked by CAA when managing the application associated
# with this script.
#
# Argument:  $1 - start | stop | check
#
# Returns:   0 - successful start, stop, or check
#            1 - error
#
#########################################################################

#
# Start section - start the process and report results
#
# If the Application Startup Commands (see description above) were used,
# little, if any modifications are needed in this section.  If not used,
# you may replace most of the contents in this section with your own
# start procedure code.
#
# For improved serviceability, preserve the commands below that log
# messages or posts events.
#

case $ACTION in
'userstart'|'start')
    if [ "$ACTION" = "userstart" ]; then
        if [ -f $LOCKFILE ]; then
          /bin/rm -f $LOCKFILE
        fi
        if [ -f $LOCKFILE ]; then
          postevent $ERROR_PRIORITY "userstart: failed to remove lockfile $LOCKFILE"
          exit 1
        fi
    fi

    if [ -f $LOCKFILE ]; then
      exit 0
    fi

    postevent $DEBUG_PRIORITY "trying to start"
    cd $APPDIR
    if [ "$START_APPCMD" != "" ]; then
        $SU $START_APPCMD &
        if [ $? -ne 0 ]; then
            postevent $ERROR_PRIORITY "start: $out"
            exit 1
        fi
    fi

    if [ "$START_APPCMD2" != "" ]; then
        out=$($SU\ $START_APPCMD2\ &)
        if [ $? -ne 0 ]; then
            postevent $ERROR_PRIORITY "start 2: $out"
            exit 1
        fi
    fi
    ;;

#
# Stop section - stop the process and report results
#
# If the Application Stop Commands or Associated Processes (see descriptions
# above) were used,little, if any modifications are needed in this section.
# If not used, you may replace most of the contents in this section with 
# your own stop procedure code.
#
# For improved serviceability, preserve the commands below that log
# messages or posts events.
#

'userstop'|'stop')
    if [ "$ACTION" = "userstop" ]; then
	/bin/touch $LOCKFILE
    fi
    postevent $DEBUG_PRIORITY "trying to stop"
    cd $APPDIR
    if [ "$STOP_APPCMD" != "" ]; then
        out=`$SU $STOP_APPCMD`
        if [ $? -ne 0 -a $? -ne 4 ]; then
            postevent $ERROR_PRIORITY "stop: $out"
            exit 1
        fi
    fi

    if [ "$STOP_APPCMD2" != "" ]; then
        out=`$SU $STOP_APPCMD2`
        if [ $? -ne 0 ]; then
            postevent $ERROR_PRIORITY "stop 2: $out"
            exit 1
        fi
    fi

#
# Run once more to make certain
#
    if [ "$STOP_APPCMD" != "" ]; then
        out=`$SU $STOP_APPCMD`
        if [ $? -ne 0 -a $? -ne 4 ]; then
	    postevent $ERROR_PRIORITY "stop 3: $out"
            exit 1
        fi
    fi

    ;;

#
# Check section - check the process and report results
#
# If you specified $PROBE_PROCS (see earlier description), very little,
# if any, changes are needed to have simple process checking.
#
# Your application might allow you to implement more accurate process
# checking.  If so, you may choose to implement that code here.  See the 
# description for the probeapp function earlier in this script.
#
'check')
    if [ -f $LOCKFILE ]; then
    postevent "" success
        exit 0
    fi

    out=`$SU $CHECK_APPCMD`
    if [ $? -ne 0 ]; then
        postevent "" "check failed: $out"
        exit 1
    fi

    ;;

*)
    echo Unrecognised action: $ACTION
    exit 1
    ;;

*)
    postevent $ERROR_PRIORITY "usage: $0 cluster-name instance-name {start|stop|check}"
    exit 1

    ;;

esac

postevent "" success
exit 0
