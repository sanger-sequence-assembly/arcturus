#!/bin/csh
# build-active-organism-list.sh

set MYDIR=`dirname .`
set SQLDIR=${MYDIR}/../sql

if ( $# > 0 ) then
  set MYSQL_HOST=$1
else
  set MYSQL_HOST=mcs6
endif

if ( $# > 1 ) then
  set MYSQL_PORT=$2
else
  set MYSQL_PORT=15003
endif

set MYPERL_SCRIPT=build-active-organism-list.pl
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=***REMOVED***

perl $MYPERL_SCRIPT -host $MYSQL_HOST -port $MYSQL_PORT -username $MYSQL_USER -password $MYSQL_PASSWORD
exit 0
