#!/bin/csh -f

echo
echo ------------------------------------------------------------
echo
echo Checking the consistency of the Arcturus databases

#set ARCTURUS=/software/arcturus
set ARCTURUS=/nfs/users/nfs_k/kt6/ARCTURUS/arcturus/branches/4595239_consistency_checks
set ARCTURUSHOME=/nfs/users/nfs_k/kt6
set JARFILE=${ARCTURUS}/java/consistency-checker.jar
set LOGFILE=consistency_checker.log
set CONSISTENCYFOLDER=${ARCTURUSHOME}/consistency-checker

cd ${CONSISTENCYFOLDER}

foreach ORG (`cat ~/active-organisms.list`)
  set ORG=`echo $ORG | awk -F : '{print $1}'`

  echo Checking the consistency of the $ORG database

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG

  /software/jdk/bin/java -jar ${JARFILE} -instance pathogen -organism $ORG -log_full_path ${CONSISTENCYFOLDER}/$ORG/

  popd
end

echo All done at `date`

exit 0
