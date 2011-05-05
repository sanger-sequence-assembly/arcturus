#!/bin/csh

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

echo Script to run:
set MYSQL_SCRIPT=$<:q

if ( ! -f $MYSQL_SCRIPT ) then
  echo Script $MYSQL_SCRIPT does not exist
  exit 1
endif

set MYSQL="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER --password=$MYSQL_PASSWORD"

set query="select table_schema from tables where table_name = 'READINFO'"

if ( $?MYSQL_DB_NAME_LIKE ) then
  echo "Limiting command to databases whose name matches ${MYSQL_DB_NAME_LIKE}"
  set query="$query and table_schema like '${MYSQL_DB_NAME_LIKE}'"
endif

foreach DB (`$MYSQL --batch --skip-column-name -e "$query" information_schema`)
  echo Executing script on $DB
  $MYSQL $DB < $MYSQL_SCRIPT
end
