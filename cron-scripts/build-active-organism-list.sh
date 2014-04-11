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

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set PERL_SCRIPT=build-active-organism-list.pl
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=*** REMOVED ***

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
case mcs8:
# check for a LIVE database used in the last $TIME_IN_DAYS days
	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15001  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $HOME/pathogen_active_organisms.list

	echo
	echo Helminth list built in $HOME/pathogen_active_organisms.list

	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15003  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $HOME/tmp_pathogen_active_organisms.list

	echo
	echo Renaming TASMANIAN_DEVIL to TASMANIAN for LDAP lookup
	sed '/^ZGTC_[0-9]*/d' $HOME/tmp_pathogen_active_organisms.list | sed 's/_DEVIL//' >> pathogen_active_organisms.list
	echo Extracting ZGTC_nn and ZFISH2_POOLnn to vertebrates list for LDAP lookup
	grep ZGTC $HOME/tmp_pathogen_active_organisms.list > vertebrates_active_organisms.list
	echo
	echo Renaming ZFISH2_POOLn to POOL2 for LDAP lookup
	grep POOL2 $HOME/tmp_pathogen_active_organisms.list | sed 's/^ZFISH2_POOL[0-9]*/POOL2/' >> vertebrates_active_organisms.list
	sed '/^ZFISH2_[0-9]*/d' $HOME/tmp_pathogen_active_organisms.list 
	echo
	echo Pathogen list built in $HOME/pathogen_active_organisms.list:
	cat $HOME/pathogen_active_organisms.list
	echo
	echo Vertebrate list built in $HOME/vertebrates_active_organisms.list:
	cat $HOME/vertebrates_active_organisms.list
	rm $HOME/tmp_pathogen_active_organisms.list

	echo
	echo Zebrafish list built in $HOME/illumina_active_organisms.list

	breaksw
case mcs7:
# check for a LIVE MINERVA 2 database used in the last $TIME_IN_DAYS days
	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 15005  -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $HOME/illumina_active_organisms.list

	echo
	echo Minerva2 databases list built in $HOME/illumina_active_organisms.list

	breaksw
case mcs4a:
# check for a TEST database used in the last $TIME_IN_DAYS days
	perl ${SCRIPT_HOME}/$PERL_SCRIPT -host $MYSQL_HOST -port 3311 -username $MYSQL_USER -password $MYSQL_PASSWORD -since $TIME_IN_DAYS > $HOME/test_active_organisms.list

	echo
	echo Test databases list built in $HOME/test_active_organisms.list

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
