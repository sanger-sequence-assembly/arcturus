#!/bin/csh

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

# build-active-organism-list.sh

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

set SCRIPTDIR=`dirname .`
set LISTDIR=`dirname ~/whoami`
set MYPERL_SCRIPT=build-active-organism-list.pl
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=*** REMOVED ***

switch($MYSQL_HOST)
case mcs10:
# check for a LIVE database used in the last $TIME_IN_DAYS days
	perl $MYPERL_SCRIPT -host $MYSQL_HOST -port 15001  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/hlm_active_organisms.list
	perl $MYPERL_SCRIPT -host $MYSQL_HOST -port 15003  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/arc_active_organisms.list
	breaksw
case mcs7:
	perl $MYPERL_SCRIPT -host $MYSQL_HOST -port 15005  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/zeb_active_organisms.list
	breaksw
case mcs4a:
# check for a TEST database used in the last $TIME_IN_DAYS days
	perl $MYPERL_SCRIPT -host $MYSQL_HOST -port 3311 -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $LISTDIR/test_active_organisms.list
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
