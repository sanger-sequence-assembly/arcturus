#!/bin/csh -f

set ALL = $#argv

set MYSQL="mysql -h mcs2a -P 15001 -u arcturus --password=***REMOVED*** --batch --skip-column-names"
set LISTDBS="select table_schema from information_schema.tables where table_name = 'PROJECT'"
set LISTDIRS="select distinct(substring_index(directory,'/',5)) from PROJECT where directory like '/nfs/repository/%'"

foreach db (`$MYSQL -e "$LISTDBS"`)
  set CHECKDIR = (`pfind -q -u $db |& grep -v exist`)
  if ($#CHECKDIR == 0) then 
# repeat pfiond with lowercase name and keep error message to flag problems
      set lcdb = `echo $db | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`
      set CHECKDIR = (`pfind -q -u $lcdb`)
  endif

  if ($#CHECKDIR > 0) then
     if ($ALL > 0) then
# list all entries
         $MYSQL -e "$LISTDIRS" $db | awk -v db=$db '{printf "%s\t%s\n",db,$1}'
     else
# list only those entries which differ
         $MYSQL -e "$LISTDIRS" $db | awk -v db=$db -v dir=$CHECKDIR '(dir != $1) {printf "%s\t%s\t%s\n",db,$1,dir}'
     endif
  endif
end
