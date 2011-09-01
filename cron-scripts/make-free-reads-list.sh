#!/bin/bash

if [ $# != 1 ]
then
  echo "Usage: $0 dbname"
  exit 1
fi

DB=$1

SERVER="-h mcs8 -P 15001"

CREDENTIALS="-u arcturus -p***REMOVED***"

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

FREEREADS=${KEEPDIR}/free-reads.out

echo "`date` : making list of free reads"

comm -23 ${ALLREADSSORTED} ${USEDREADSSORTED} > ${FREEREADS}

echo "The list of free reads is in the file ${FREEREADS}"

