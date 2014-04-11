#!/bin/sh

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


if [ $# -lt 1 ]
then
  echo Usage: $0 DATABASENAME
  exit 1
fi

DB=$1

if [ $# -lt 2 ]
then
  PREFIX=TEST
else
  PREFIX=$2
fi

TESTDB=${PREFIX}${DB}

MASTER_INSTANCE='-h mcs3a -P 15001'
TEST_INSTANCE='-h mcs4a -P 3311'

DEFAULTS_FILE=${HOME}/mysql/arcturus_dba.cnf

DUMPFILE=/tmp/${USER}.${DB}.$$.sql

RM='/bin/rm -f'

date
echo Dumping database $DB on master instance.

mysqldump --defaults-extra-file=${DEFAULTS_FILE} \
	$MASTER_INSTANCE $DB > $DUMPFILE

RC=$?

if [ $RC != 0 ]
then
    echo Failed to dump database $DB on master instance.  Return code was $RC.
    exit 1
fi

date
echo Creating database $TESTDB on test instance.

mysql --defaults-extra-file=${DEFAULTS_FILE} \
	$TEST_INSTANCE -e "drop database if exists $TESTDB ; create database $TESTDB"

RC=$?

if [ $RC != 0 ]
then
    echo Failed to create new database $TESTDB on test instance.  Return code was $RC.
    ${RM} $DUMPFILE
    exit 1
fi

date
echo Loading  data for database $TESTDB on test instance.

mysql --defaults-extra-file=${DEFAULTS_FILE} \
	$TEST_INSTANCE $TESTDB < $DUMPFILE

RC=$?

if [ $RC != 0 ]
then
    echo Failed to load data for database $TESTDB on test instance.  Return code was $RC.
    echo Data is in file $DUMPFILE on `hostname`
    exit 1
fi

date
echo Cleaning up.

${RM} $DUMPFILE

exit 0
