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

# project_stats.csh
set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set PROJECTSTATSFOLDER=${HOME}/project-stats
set LOGFILE=${HOME}/project-stats.log

set PROJECTSTATSFOLDER=${HOME}/project-stats

set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/6163487_warehouse
#set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/trunk.clean
#set ARCTURUS=/software/arcturus
set UTILSFOLDER=${ARCTURUS}/utils

echo SCRIPT_HOME is ${SCRIPT_HOME} and UTILSFOLDER is ${UTILSFOLDER}
set STATS_SCRIPT = ${UTILSFOLDER}/populate-project-contig-history
set READS_SCRIPT = ${UTILSFOLDER}/populate-organism-history

if ( $# > 0 ) then
  set INSTANCE = $1
	set THRESHOLD = $2
else
  echo Please provide the instance name to run this script against: illumna, mysql, pathogen or test, and an integer threshold for free read variation
	exit(-1)
endif

set VERSION='-gap4'

switch(${INSTANCE})
	case mysql:
	breaksw
	case pathogen:
	breaksw
	case test:
	breaksw
	case illumina:
		set VERSION='-gap5'
	breaksw
	default:
		echo populate-project-stats.csh does not recogonise instance ${INSTANCE} 
  	exit -1
	breaksw
endsw

echo
echo ------------------------------------------------------------
echo
echo Creating project statistics for the ${INSTANCE} Arcturus 

if  ( ! -d $PROJECTSTATSFOLDER ) then
  mkdir $PROJECTSTATSFOLDER
endif

cd ${PROJECTSTATSFOLDER}

foreach ORG (`cat ${HOME}/${INSTANCE}_project_stats_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Creating project statistics for the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Running ${STATS_SCRIPT} to calculate project statistics for the $ORG organism in the $INSTANCE database instance...
		${STATS_SCRIPT} -instance $INSTANCE -organism $ORG

		echo Running ${READS_SCRIPT} to calculate free read statistics for the $ORG organism in the $INSTANCE database instance...
		echo Any read variation over ${THRESHOLD} will be notified to email freereads and cc to arcturus-help
		${READS_SCRIPT} -instance $INSTANCE -organism $ORG -threshold ${THRESHOLD} ${VERSION} 
  popd
end

echo All done at `date`

exit 0
