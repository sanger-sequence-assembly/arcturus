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

# consistency-checks.csh

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

if ( $# > 0 ) then
  set INSTANCE=$1
else
	echo Consistency-check.sh expects the instance name to check (in lower case).
  exit -1
endif

set LSF_SCRIPT_NAME=${SCRIPT_HOME}/submit-consistency-checks.csh

echo
echo ------------------------------------------------------------
echo
echo Checking the consistency of the Arcturus databases

set CONSISTENCYFOLDER=${HOME}/consistency-checker

if  ( ! -d $CONSISTENCYFOLDER ) then
  mkdir $CONSISTENCYFOLDER
endif

cd ${CONSISTENCYFOLDER}

foreach ORG (`cat ~/${INSTANCE}_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking the consistency of the $ORG database using ${SCRIPT_HOME}/${SCRIPT_NAME}

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif
	pushd $ORG
		echo Submitting a batch job to check the consistency of the $ORG organism in the $INSTANCE database instance using ${LSF_SCRIPT_NAME}...
		bsub -q phrap -o ${CONSISTENCYFOLDER}/$ORG/$ORG.log -J ${ORG}cc -N ${LSF_SCRIPT_NAME} ${INSTANCE} $ORG
	popd
end

echo All done at `date`

exit 0
