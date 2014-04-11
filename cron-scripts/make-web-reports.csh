#!/bin/csh -f

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


echo
echo ------------------------------------------------------------
echo
echo Making Arcturus web reports at `date` on `hostname`

if ( ! $?ARCTURUS_HOME ) then
    set ARCTURUS_HOME=/software/arcturus
endif

if ( ! $?WEBREPORTSCRIPT ) then
    set WEBREPORTSCRIPT=${ARCTURUS_HOME}/utils/make-web-report
endif

if ( ! $?WEBFOLDER ) then
    set WEBFOLDER=/nfs/WWWdev/INTWEB_docs/htdocs/Software/Arcturus/reports
endif

if ( ! $?WEBPUBLISH ) then
    set WEBPUBLISH=/software/bin/webpublish
endif

if ( ! $?ACTIVE_ORGANISMS_LIST ) then
    set ACTIVE_ORGANISMS_LIST=${HOME}/active-organisms.list
endif

if ( ! -f $ACTIVE_ORGANISMS_LIST ) then
    echo Cannot find active organisms list file $ACTIVE_ORGANISMS_LIST
    exit 1
endif

set LOGFILE=reports.log

cd ${WEBFOLDER}

foreach ORG (`cat ${ACTIVE_ORGANISMS_LIST}`)
  echo Making report for $ORG

  if  ( ! -d $ORG ) then
    mkdir $ORG
  endif

  pushd $ORG

  ${WEBREPORTSCRIPT} -instance pathogen -organism $ORG > index.html

  popd
end

cd ..

echo Running webpublish at `date`

${WEBPUBLISH} -r reports

# And again, as suggested by Jody Clements (RT ticket #114188)

echo Re-running webpublsh at `date`

${WEBPUBLISH} -r reports

echo All done at `date`

exit 0
