#!/bin/bash

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

cd java

ant jar

exit
