#!/bin/sh
 if [ $# -lt 1 ]
 then
   echo Usage: $0 pattern-file file-to-search
	 echo file-to-search can be a FASTA or a SAM file
   exit 1
 fi

PATTERNFILE=$1
FILE=$2

if [ -f ${FILE} ]
then
  echo Looking for the following strings in ${FILE}
  cat ${PATTERNFILE}
  echo
  echo Found the following matching lines in ${FILE}
  grep -n --colour=auto -F -f ${PATTERNFILE} ${FILE} 
else
  echo $0: cannot find ${FILE}
fi
