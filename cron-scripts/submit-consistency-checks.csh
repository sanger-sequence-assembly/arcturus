#!/bin/csh 
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
