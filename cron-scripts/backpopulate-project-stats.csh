#!/bin/csh 
# backpopulate-project-stats.csh

set SCRIPT_HOME=`dirname $0`
set SCRIPT_NAME=`basename $0`
set ABSOLUTE_SCRIPT_HOME = `pwd`
set UTILSFOLDER=${ABSOLUTE_SCRIPT_HOME}/../utils
set PROJECTSTATSFOLDER=${HOME}/project-stats

#set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/6163487_warehouse
#set ARCTURUS=/software/arcturus

set STATS_SCRIPT = ${UTILSFOLDER}/backpopulate-project-contig-history
set READS_SCRIPT = ${UTILSFOLDER}/populate-organism-history

if ( $# > 0 ) then
	set INSTANCE=$1
else
	echo backpopulate-project-stats.csh expects the instance name to check (in lower case).
  exit -1
endif

set LOGFILE=${HOME}/${INSTANCE}-backpopulate-project-stats.log
set SINCE = '2010-01-01'
set UNTIL = '2011-01-31'
set THRESHOLD = 1000

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
		echo Submitting a batch job to backpopulate PROJECT_CONTIG_HISTORY for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/${ORG}bps.log -J ${ORG}bps -N ${STATS_SCRIPT} -instance $INSTANCE -organism $ORG -since ${SINCE} -until ${UNTIL}
et LOGFILE=${HOME}/${INSTANCE}-backpopulate-project-stats.log

		echo Submitting a batch job to backpopulate ORGANISM_HISTORY for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/${ORG}bfr.log -J ${ORG}bfr -N ${READS_SCRIPT} -instance $INSTANCE -organism $ORG -threshold ${THRESHOLD} -since ${SINCE} -until ${UNTIL}
  popd
end

echo All done at `date`
exit 0
