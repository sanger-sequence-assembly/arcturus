#!/bin/csh
# build-active-organism-list.sh

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set LISTDIR=`dirname ~/whoami`
set PERL_SCRIPT=build-active-organism-list.pl
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=***REMOVED***

if ( $# > 0 ) then
	set MYSQL_HOST=$1
  set TIME_IN_DAYS=$2
else
	echo "Build-active-organism-list requires host name and number of days to check back for"
	exit -1
endif

echo
echo -----------------------------------------------------------------------------------------
echo
echo Building the list of modified Arcturus databases ready for the consistency checker

switch($MYSQL_HOST)
case mcs6:
# check for a LIVE database used in the last $TIME_IN_DAYS days
	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15001  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/hlm_active_organisms.list

	echo
	echo Helminth list built in $LISTDIR/hlm_active_organisms.list

	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15003  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/arc_active_organisms.list

	echo
	echo Arcturus list built in $LISTDIR/arc_active_organisms.list

	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15005  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/zeb_active_organisms.list

	echo
	echo Zebrafish list built in $LISTDIR/zeb_active_organisms.list

	breaksw
case mcs4a:
# check for a TEST database used in the last $TIME_IN_DAYS days
	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 3311 -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/test_active_organisms.list

	echo
	echo Test databases list built in $LISTDIR/test_active_organisms.list

	breaksw
default:
	echo "Build-active-organism-list does not recognise host $MYSQL_HOST - list has NOT been built"
	echo
	echo -----------------------------------------------------------------------------------------
	exit -1
	breaksw
endsw

echo
echo Built the list of modified Arcturus databases ready for the consistency checker at `date`
echo
echo -----------------------------------------------------------------------------------------
echo

exit 0
