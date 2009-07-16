#!/bin/csh

set MYSQL_HOST=mcs3a
set MYSQL_PORT=15001
set MYSQL_USER=arcturus
set MYSQL_PASSWORD=***REMOVED***

set MYSQL="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER --password=$MYSQL_PASSWORD"

foreach DB (`$MYSQL --batch --skip-column-name \
    -e "select table_schema from tables where table_name = 'TRACEARCHIVE'" \
    information_schema`)
  echo Checking $DB
  $MYSQL \
    -e 'select count(*) as badrefs from TRACEARCHIVE where traceref not regexp "^[[:digit:]]+$"' $DB
  $MYSQL \
    -e 'select count(*) as nullrefs from READINFO left join TRACEARCHIVE using(read_id) where traceref is null' $DB
end
