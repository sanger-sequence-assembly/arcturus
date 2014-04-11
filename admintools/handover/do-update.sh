#!/bin/bash

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


ME=`whoami`

if [ ${ME} != arcturus ]
then
  echo You must be logged in as arcturus to run this script
  exit 1
fi

TARGET=.retired

OLDJARS=.oldjars

REPOS=svn+ssh://svn.internal.sanger.ac.uk/repos/svn/arcturus/trunk

if [ ! -d ${TARGET} ]
then
  mkdir ${TARGET}
fi

if [ ! -d ${OLDJARS} ]
then
  mkdir ${OLDJARS}
fi

cp -f java/arcturus-*.jar ${OLDJARS}/

COPY_RC=$?

for item in admintools assembler cron-scripts .gitignore java lib project shared sql .svn test userguide utils
do
  mv -f ${item} ${TARGET}/
done

svn checkout ${REPOS} .

if [ $? -ne 0 ]
then
  echo Failed to checkout ${REPOS}
  echo You should run the undo script
  exit 1
fi

if [ ${COPY_RC} -eq 0 ]
then
  cp -f ${OLDJARS}/arcturus-*.jar java/
fi

cd utils
./makePerlWrappers
./makeLSFWrappers
cd ..

cd test
./makePerlWrappers
cd ..

cd java
ant jar
cd ..

exit
