#!/bin/csh -f

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


set ALL = $#argv

set MYSQL="mysql -h mcs9 -P 15001 -u arcturus --password=*** REMOVED *** --batch --skip-column-names"
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
