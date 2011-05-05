#!/bin/csh

set NORUNFILE=${HOME}/readloader.norun

if ( -e ${NORUNFILE} ) then
  echo The file ${NORUNFILE} exists at `date` ... the run will be abandoned.
  exit 0
endif

set ARCTURUS=/software/arcturus
set READLOADER=${ARCTURUS}/utils/read-loader
set LOGFOLDER=${HOME}/readloader/logs
set OPTIONS="-instance pathogen -source TraceServer -minreadid auto -info"

set TODAY=`date '+%Y%m%d'`
set LOGFOLDER=${LOGFOLDER}/${TODAY}

if ( ! $?ACTIVE_ORGANISMS_LIST ) then
    set ACTIVE_ORGANISMS_LIST=${HOME}/active-organisms.list
endif

if ( ! -f $ACTIVE_ORGANISMS_LIST ) then
    echo Cannot find active organisms list file $ACTIVE_ORGANISMS_LIST
    exit 1
endif

if ( ! -e ${LOGFOLDER} ) then
  mkdir ${LOGFOLDER}
endif

foreach ORG (`cat ${ACTIVE_ORGANISMS_LIST}`)
  set LOGNAME=`date +'%H%M'`
  set LOGFILE=${LOGFOLDER}/${LOGNAME}-${ORG}.out
  set PARAMS="-organism $ORG"
  ${READLOADER} ${OPTIONS} ${PARAMS} >& ${LOGFILE}
end
