#!/bin/csh
# build-active-organism-list.sh

set SCRIPTDIR=`dirname .`
set LISTDIR=`dirname ~/whoami`
set MYPERL_SCRIPT=build-active-organism-list.pl
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=***REMOVED***

set MYSQLHOST=mcs6
# check for a LIVE database used in the last 28 days
	perl $MYPERL_SCRIPT -host $MYSQLHOST -port 15001  -username $MYSQL_USER -password $MYSQL_PASSWORD -since 28 > $LISTDIR/hlm_active_organisms.list
	perl $MYPERL_SCRIPT -host $MYSQLHOST -port 15003  -username $MYSQL_USER -password $MYSQL_PASSWORD -since 28 > $LISTDIR/arc_active_organisms.list
	perl $MYPERL_SCRIPT -host $MYSQLHOST -port 15005  -username $MYSQL_USER -password $MYSQL_PASSWORD -since 28 > $LISTDIR/zeb_active_organisms.list

set MYSQLHOST=mcs4a
# check for a TEST database used in the last 365 days
	perl $MYPERL_SCRIPT -host $MYSQLHOST -port 3311 -username $MYSQL_USER -password $MYSQL_PASSWORD -since 365 > $LISTDIR/test_active_organisms.list

exit 0
