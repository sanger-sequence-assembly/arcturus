#!/bin/sh

ARCTURUS=/software/arcturus
SCAFFOLDER=${ARCTURUS}/test/scaffolder
OPTIONS='-instance pathogen -out /dev/null -xml DATABASE -puclimit 15000 -shownames'
#NOTIFY_TO=arcturus-help@sanger.ac.uk
NOTIFY_TO=adh@sanger.ac.uk

let failed=0

for ORG in `cat ~/active-organisms.list`
do
  PARAMS=`echo $ORG | awk -F : '{org=$1; group= (NF>1) ? $2 : $1; printf "-organism %s -group %s",org,group}'`

  ${SCAFFOLDER} ${OPTIONS} ${PARAMS}

  if [ $? != 0 ]
  then
      if [ $failed -eq 0 ]
      then
	  failures=${ORG}
      else
	  failures=${failures},${ORG}
      fi

      let failed+=1
  fi
done

if [ $failed -gt 0 ]
then
    mail -s "Arcturus scaffolder failures" ${NOTIFY_TO} <<EOF
Errors occurred during the latest run of the Arcturus scaffolder.

The following organisms had problems:

${failures}
EOF
fi

exit 0
