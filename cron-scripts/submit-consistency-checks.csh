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

# submit-consistency-checks.sh
# uses just one organism to test bsub parameters

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

if ( $# > 0 ) then
  set INSTANCE=$1
  set ORG=$2
	set JAR=$3
else
  echo "submit-consistency-check is expecting INSTANCE, ORGANISM and JAR as parameters e.g. test TRICHURIS arcturus2 or test TESTRATTI arcturus"
	die 1
endif

echo
echo ------------------------------------------------------------
echo
echo Checking the consistency of the Arcturus databases

set JARFILE=${SCRIPT_HOME}/../java/${JAR}.jar
set CONSISTENCYFOLDER=${HOME}/consistency-checker

if  ( ! -d $CONSISTENCYFOLDER ) then
  mkdir $CONSISTENCYFOLDER
endif

cd ${CONSISTENCYFOLDER}

  echo Checking the consistency of the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG

	echo Starting to check the consistency of the $ORG organism in the $INSTANCE Arcturus using the JAR ${JARFILE}...
  	/software/jdk/bin/java -classpath ${JARFILE} uk.ac.sanger.arcturus.consistencychecker.CheckConsistency -instance $INSTANCE -organism $ORG -log_full_path ${CONSISTENCYFOLDER}/$ORG/ -critical

  popd

echo All done at `date`

exit 0
