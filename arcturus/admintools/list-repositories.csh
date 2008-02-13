#!/bin/csh -f

set MYSQL="mysql -h mcs1a -P 15001 -u arcturus --password=***REMOVED*** --batch --skip-column-names"
set LISTDBS="select table_schema from information_schema.tables where table_name = 'PROJECT'"
set LISTDIRS="select distinct(substring_index(directory,'/',4)) from PROJECT where directory like '/nfs/repository/%'"

foreach db (`$MYSQL -e "$LISTDBS"`)
  #echo $db
  $MYSQL -e "$LISTDIRS" $db | awk -v db=$db '{printf "%s\t%s\n",db,$1}'
end
