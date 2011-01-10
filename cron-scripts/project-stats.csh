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

switch($INSTANCE)
case test:
	set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/6163487_warehouse
	breaksw
default:
	set ARCTURUS=/software/arcturus
	breaksw
endsw

set ARCTURUSHOME=`dirname ~/whoami`
set PROJECTSTATSFOLDER=${ARCTURUSHOME}/project-stats
set LOGFILE=project-stats.log

cd ${PROJECTSTATSFOLDER}

foreach ORG (`cat ~/test_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking project statistics for the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Submitting a batch job to calculate project statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/$ORG.log -J ${ORG}ps -N ${ARCTURUS}/populate-project-contig-history -instance $INSTANCE -organism $ORG
		echo Submitting a batch job to calculate free read statistics for the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${PROJECTSTATSFOLDER}/$ORG.log -J ${ORG}ps -N ${ARCTURUS}/populate-organism-history -instance $INSTANCE -organism $ORG
  popd
end

echo All done at `date`

exit 0
