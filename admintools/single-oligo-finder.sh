#!/bin/sh
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
  grep -c ${PATTERN} ${FILE} 
  echo
  REVPATTERN=`echo ${PATTERN} | rev`
  echo Looking for reversed oligo ${REVPATTERN} in ${FILE}...
  echo Found the following matching lines in ${FILE}
  grep -c ${REVPATTERN} ${FILE}
else
  echo $0: cannot find file ${FILE}
fi
