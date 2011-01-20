#!/bin/bash

TARGET=.retired

if [ ! -d ${TARGET} ]
then
  echo There is no directory named ${TARGET} ... bailing out\!
  exit 1
fi

for item in admintools assembler cron-scripts .gitignore java lib project shared sql .svn test userguide utils
do
  if [ -e ${TARGET}/${item} ]
  then
    if [ -e ${item} ]
    then
      rm -r -f ${item}
    fi

    mv -f ${TARGET}/${item} ./
  fi
done

exit
