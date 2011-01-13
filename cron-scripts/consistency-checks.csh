#!/bin/csh 
# consistency-checks.sh

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

if ( $# > 0 ) then
  set INSTANCE=$1
else
  set INSTANCE=pathogen
endif

echo
echo ------------------------------------------------------------
echo
echo Checking the consistency of the Arcturus databases

set CONSISTENCYFOLDER=${SCRIPT_HOME}/../consistency-checker
set JARFILE=${SCRIPT_HOME}/java/consistency-checker.jar
set LOGFILE=consistency_checker.log

cd ${CONSISTENCYFOLDER}

foreach ORG (`cat ~/test_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking the consistency of the $ORG database using ${SCRIPT_HOME}/${SCRIPT_NAME}

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Submitting a batch job to check the consistency of the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${CONSISTENCYFOLDER}/$ORG.log -J ${ORG}cc -N ${SCRIPT_HOME}/submit-consistency-checks.csh test $ORG
  popd
end

echo All done at `date`

exit 0
