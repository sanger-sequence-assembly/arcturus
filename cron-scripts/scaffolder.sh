#!/bin/sh

if [ "x${ARCTURUS_HOME}" == "x" ]
then
    ARCTURUS_HOME=/software/arcturus
fi

if [ "x${SCAFFOLDER}" == "x" ]
then
    SCAFFOLDER=${ARCTURUS_HOME}/test/scaffolder
fi

OPTIONS='-instance pathogen -out /dev/null -xml DATABASE -puclimit 15000 -shownames'

if [ "x${NOTIFY_TO}" == "x" ]
then
    NOTIFY_TO=arcturus-help@sanger.ac.uk
fi

if [ "x$ACTIVE_ORGANISMS_LIST" == "x" ]
then
    ACTIVE_ORGANISMS_LIST=${HOME}/active-organisms.list
fi

if [ ! -f $ACTIVE_ORGANISMS_LIST ]
then
    echo Cannot find active organisms list file $ACTIVE_ORGANISMS_LIST
    exit 1
fi

let failed=0

for ORG in `cat ${ACTIVE_ORGANISMS_LIST}`
do
  PARAMS="-organism $ORG"

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
