#!/bin/sh

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
