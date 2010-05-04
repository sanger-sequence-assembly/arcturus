#!/bin/csh

set NORUNFILE=${HOME}/readloader.norun

if ( -e ${NORUNFILE} ) then
  echo The file ${NORUNFILE} exists at `date` ... the run will be abandoned.
  exit 0
endif

set ARCTURUS=/software/arcturus
set READLOADER=${ARCTURUS}/utils/read-loader
set LOGFOLDER=`dirname $0`/logs
set OPTIONS="-instance pathogen -source TraceServer -minreadid auto -info"

set TODAY=`date '+%Y%m%d'`
set LOGFOLDER=${LOGFOLDER}/${TODAY}

if ( ! -e ${LOGFOLDER} ) then
  mkdir ${LOGFOLDER}
endif

foreach ORG (`cat ~/active-organisms.list`)
  set LOGNAME=`date +'%H%M'`
  set LOGFILE=${LOGFOLDER}/${LOGNAME}-${ORG}.out
  set PARAMS=`echo $ORG | awk -F : '{org=$1; group= (NF>1) ? $2 : $1; printf "-organism %s -group %s",org,group}'`
  ${READLOADER} ${OPTIONS} ${PARAMS} >& ${LOGFILE}
end
