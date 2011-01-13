#!/bin/csh 
# project_stats.csh

if ( $# > 0 ) then
  set INSTANCE=$1
else
  set INSTANCE=pathogen
endif

echo
echo ------------------------------------------------------------
echo
echo Creating project statistics for the Arcturus databases

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`

set PERL_SCRIPT_NAME=${SCRIPT_HOME}/${SCRIPT_NAME}.pl

set PROJECTSTATSFOLDER=${SCRIPT_HOME}/../project-stats
set LOGFILE=project-stats.log
 
if  ( ! -d $PROJECTSTATSFOLDER ) then
  mkdir $PROJECTSTATSFOLDER
endif

cd ${PROJECTSTATSFOLDER}

foreach ORG (`cat ~/test_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking project statistics for the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Submitting a batch job for ${SCRIPT_HOME}/${SCRIPT_NAME} to calculate project statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/$ORG.log -J ${ORG}ps -N ${SCRIPT_HOME}/../populate-project-contig-history -instance $INSTANCE -organism $ORG
		echo Submitting a batch job to calculate free read statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/$ORG.log -J ${ORG}ps -N ${SCRIPT_HOME}/../populate-organism-history -instance $INSTANCE -organism $ORG
  popd
end

echo All done at `date`

exit 0
