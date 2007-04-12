#!/bin/csh -f

if ( $#argv < 2 ) then
  echo usage: $0 database readnamepattern
  exit 1
endif

set db=$1
set proj=$2

mysql -h mcs1a -P 15001 -u arcturus --password=***REMOVED*** \
  --skip-column-names --batch -e "call procfreereadsbynamelike('${proj}%')" $db
