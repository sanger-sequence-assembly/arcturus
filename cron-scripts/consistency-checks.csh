#!/bin/csh 
# consistency-checks.sh

if ( $# > 0 ) then
  set INSTANCE=$1
else
  set INSTANCE=pathogen
endif

echo
echo ------------------------------------------------------------
echo
echo Checking the consistency of the Arcturus databases

switch($INSTANCE)
case test:
	set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/4595239_consistency_checks
	breaksw
default:
	set ARCTURUS=/software/arcturus
	breaksw
endsw

set ARCTURUSHOME=`dirname ~/whoami`
set CONSISTENCYFOLDER=${ARCTURUSHOME}/consistency-checker
set JARFILE=${ARCTURUS}/java/consistency-checker.jar
set LOGFILE=consistency_checker.log

cd ${CONSISTENCYFOLDER}

foreach ORG (`cat ~/test_active_organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking the consistency of the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG
		echo Submitting a batch job to  check the consistency of the $ORG organism in the $INSTANCE database instance...
		bsub -q phrap -o ${CONSISTENCYFOLDER}/$ORG.log -J ${ORG}cc -N ${ARCTURUS}/cron-scripts/submit-consistency-checks.csh test $ORG
  popd
end

echo All done at `date`

exit 0
