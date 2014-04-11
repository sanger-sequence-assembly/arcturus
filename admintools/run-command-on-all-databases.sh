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


set MYDIR=`dirname $0`
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

echo MySQL username:
set MYSQL_USER=$<

echo MySQL password:
setty -echo
set MYSQL_PASSWORD=$<:q
setty +echo

echo Command to run:
set MYSQL_COMMAND=$<:q

echo Command is "$MYSQL_COMMAND"

set MYSQL="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER --batch --skip-column-name --password=$MYSQL_PASSWORD"

set query="select table_schema from tables where table_name = 'READINFO'"

if ( $?MYSQL_DB_NAME_LIKE ) then
  echo "Limiting command to databases whose name matches ${MYSQL_DB_NAME_LIKE}"
  set query="$query and table_schema like '${MYSQL_DB_NAME_LIKE}'"
endif

foreach DB (`$MYSQL --batch --skip-column-name -e "$query" information_schema`)
  echo Executing command on $DB
  $MYSQL -e "$MYSQL_COMMAND" $DB
end
