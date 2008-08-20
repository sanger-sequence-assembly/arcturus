#!/bin/csh

set MYDIR=`dirname $0`
set SQLDIR=${MYDIR}/../sql

set MYSQL_HOST=mcs3a
set MYSQL_PORT=15001

echo MySQL username:
set MYSQL_USER=$<

echo MySQL password:
setty -echo
set MYSQL_PASSWORD=$<:q
setty +echo

echo Command to run:
set MYSQL_COMMAND=$<:q

echo Command is "$MYSQL_COMMAND"

set MYSQL="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER --password=$MYSQL_PASSWORD"

foreach DB (`$MYSQL --batch --skip-column-name \
    -e "select table_schema from tables where table_name = 'READINFO'" \
    information_schema`)
  echo Executing command on $DB
  $MYSQL -e "$MYSQL_COMMAND" $DB
end
