#!/bin/csh 
# project_stats.csh

if ( $# > 0 ) then
  set INSTANCE=$1
else
  echo Please provide the instance name to run this script against
	exit(-1)
endif

echo
echo ------------------------------------------------------------
echo
echo Creating project statistics for the Arcturus databases

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set PERL_SCRIPT_NAME=${SCRIPT_HOME}/${SCRIPT_NAME}.pl

set PROJECTSTATSFOLDER=${HOME}/project-stats
set LOGFILE=${HOME}/project-stats.log

set UTILSFOLDER=${SCRIPT_HOME}/../utils
set STATS_SCRIPT = ${UTILSFOLDER}/populate-project-contig-history
set READS_SCRIPT = ${UTILSFOLDER}/populate-organism-history
 
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
		echo Submitting a batch job for ${STATS_SCRIPT} to calculate project statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/${ORG}/${ORG}.log -J ${ORG}ps -N ${STATS_SCRIPT} -instance $INSTANCE -organism $ORG

		echo Submitting a batch job for ${READS_SCRIPT} to calculate free read statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/${ORG}/${ORG}.log -J ${ORG}ps -N ${READS_SCRIPT} -instance $INSTANCE -organism $ORG -threshold 100
  popd
end

echo All done at `date`

exit 0
