#!/bin/bash

if [ $# != 1 ]
then
  echo "Usage: $0 dbname"
  exit 1
fi

DB=$1
KEEPDIR=${HOME}/free-reads/${DB}
#YESTERDAY=${KEEPDIR}/${DB}-free-reads.out
YESTERDAY=/tmp/A.out
#TODAY=/tmp/${DB}-free-reads.out
TODAY=/tmp/B.out

echo "`date` : yesterday's reads are "
cat ${YESTERDAY}

echo "`date` : today's reads are "
cat ${TODAY}

FREEREADS=${KEEPDIR}/`date +%s --date='yesterday'`-${DB}-free-reads.out
NEWFREEREADS=${KEEPDIR}/${DB}-new-free-reads.out

echo "`date` : comparing yesterday's and today's free reads with the new reads stored in ${NEWFREEREADS}"

diff /tmp/A.out /tmp/B.out | awk '{print $2}' > ${NEWFREEREADS}

echo "`date` : new free reads added today "

cat ${NEWFREEREADS}

mv ${YESTERDAY} ${FREEREADS}

echo "`date` : yesterday's free reads saved in ${FREEREADS} for any future checks"

mv ${TODAY} ${YESTERDAY}

echo "`date` : today's free reads saved in ${YESTERDAY} for tomorrow's checks"

ls -l ${KEEPDIR}

exit 0
