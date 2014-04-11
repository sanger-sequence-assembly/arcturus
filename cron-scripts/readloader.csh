#!/bin/csh

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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
