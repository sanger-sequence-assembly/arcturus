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

# backpopulate-project-stats.csh


set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/6163487_warehouse
#set ARCTURUS=/software/arcturus

#set UTILSFOLDER=${SCRIPT_HOME}/../utils
set UTILSFOLDER=${ARCTURUS}/utils
set PROJECTSTATSFOLDER=${HOME}/project-stats
set STATS_SCRIPT = ${UTILSFOLDER}/backpopulate-project-contig-history
set READS_SCRIPT = ${UTILSFOLDER}/populate-organism-history

if ( $# > 0 ) then
	set INSTANCE=$1
	set SINCE = $2
	set UNTIL = $3
	set THRESHOLD = $4
else
  echo Please provide the instance name to run this script against: illumna, mysql, pathogen or test, the since and until dates (inclusive) and the threshold of reads for an alert to be sent
  exit -1
endif

set LOGFILE=${HOME}/${INSTANCE}-backpopulate-project-stats.log

echo
echo ------------------------------------------------------------
echo
echo Calculating project stats for the ${INSTANCE} Arcturus from ${SINCE} to ${UNTIL} with a free read variation threshold of ${THRESHOLD}


switch(${INSTANCE})
	case mysql:
	breaksw
	case pathogen:
	breaksw
	case test:
	breaksw
	case illumina:
	breaksw
	default:
		echo backpopulate-project-stats.csh does not recogonise instance ${INSTANCE} 
  	exit -1
	breaksw
endsw

if  ( ! -d $PROJECTSTATSFOLDER ) then
  mkdir $PROJECTSTATSFOLDER
endif

cd ${PROJECTSTATSFOLDER}

foreach ORG (`cat ${HOME}/${INSTANCE}_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Creating project statistics for the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Backpopulating PROJECT_CONTIG_HISTORY for the $ORG organism in the $INSTANCE database instance...
		${STATS_SCRIPT} -instance $INSTANCE -organism $ORG -since ${SINCE} -until ${UNTIL}

		echo Backpopulating ORGANISM_HISTORY for the $ORG organism in the $INSTANCE database instance with a threshold of ${THRESHOLD}...
		${READS_SCRIPT} -instance $INSTANCE -organism $ORG -threshold ${THRESHOLD} -since ${SINCE} -until ${UNTIL}
  popd
end

echo All done at `date`
exit 0
