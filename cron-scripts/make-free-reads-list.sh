#!/bin/bash

if [ $# != 1 ]
then
  echo "Usage: $0 dbname"
  exit 1
fi

DB=$1

SERVER="-h mcs8 -P 15001"

CREDENTIALS="-u arcturus -p*** REMOVED ***"

OPTIONS="--batch --skip-column-names"

TMPDIR=/tmp/${USER}-${DB}-freereads-$$
mkdir -p ${TMPDIR}

KEEPDIR=${HOME}/free-reads/${DB}
mkdir -p ${KEEPDIR}

ALLREADS=${TMPDIR}/all-reads.out

echo "`date` : making list of all reads"

mysql ${SERVER} ${CREDENTIALS} ${OPTIONS} \
		    -e "select readname from READINFO" ${DB} > ${ALLREADS}

READFINDERREADS=${TMPDIR}/read-finder-reads.out
USEDREADS=${TMPDIR}/used-reads.out

echo "`date` : making list of assembled reads"

mysql ${SERVER} ${CREDENTIALS} ${OPTIONS} \
				     -e "select readname  from ((CURRENTCONTIGS left join MAPPING using (contig_id)) left join SEQ2READ using (seq_id)) left join READINFO using (read_id)"  ${DB} > ${USEDREADS}
						      
ALLREADSSORTED=${TMPDIR}/all-reads.sorted.out

echo "`date` : sorting list of all reads"

sort -S 500M -b -k1 ${ALLREADS} > ${ALLREADSSORTED}

USEDREADSSORTED=${TMPDIR}/used-reads.sorted.out

echo "`date` : sorting list of assembled reads"

sort -S 500M -b -k1 ${USEDREADS} > ${USEDREADSSORTED}

TODAY=/tmp/${DB}-free-reads.out

echo "`date` : making list of free reads"

comm -23 ${ALLREADSSORTED} ${USEDREADSSORTED} > ${TODAY}

echo "`date` : the list of free reads is stored in the file ${FREEREADS}"

YESTERDAY=${KEEPDIR}/${DB}-free-reads.out

FREEREADS=${KEEPDIR}/`date +%s --date='yesterday'`-${DB}-free-reads.out
NEWFREEREADS=${KEEPDIR}/${DB}-new-free-reads.out

echo "`date` : comparing yesterday's and today's free reads with the new reads stored in ${NEWFREEREADS}"

diff ${YESTERDAY} ${TODAY} | awk '{print $2}' > ${NEWFREEREADS}

echo "`date` : new free reads added today "

cat ${NEWFREEREADS}

mv ${YESTERDAY} ${FREEREADS}

echo "`date` : yesterday's free reads saved in ${FREEREADS} for any future checks"

mv ${TODAY} ${YESTERDAY}

echo "`date` : today's free reads saved in ${YESTERDAY} for tomorrow's checks"

exit 0
