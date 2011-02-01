#!/bin/csh 
# consistency-checks.csh

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

if ( $# > 0 ) then
  set INSTANCE=$1
else
	echo Consistency-check.sh expects the instance name to check (in lower case).
  exit -1
endif

set ABSOLUTE_SCRIPT_HOME=`pwd`
set LSF_SCRIPT_NAME=${ABSOLUTE_SCRIPT_HOME}/submit-consistency-checks.csh

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
		bsub -q phrap -o ${CONSISTENCYFOLDER}/$ORG.log -J ${ORG}cc -N ${LSF_SCRIPT_NAME} test $ORG
	popd
end

echo All done at `date`

exit 0
