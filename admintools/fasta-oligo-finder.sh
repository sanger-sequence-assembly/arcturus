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

 if [ $# -lt 2 ]
 then
   echo Usage: $0 oligo file-to-search
	 echo Both the oligo and its complement will be searched for
   exit 1
 fi

PATTERN=$1
FILE=$2

if [ -f ${FILE} ]
then
  echo Looking for oligo ${PATTERN} in ${FILE}...
  echo Found the following matching lines in ${FILE}
  cat ${FILE} | tr -d "\n" | grep -c ${PATTERN}
  echo
  REVPATTERN=`echo ${PATTERN} | rev`
  echo Looking for reversed oligo ${REVPATTERN} in ${FILE}...
  echo Found the following matching lines in ${FILE}
  cat ${FILE} | tr -d "\n" | grep -c ${REVPATTERN} 
else
  echo $0: cannot find file ${FILE}
fi
