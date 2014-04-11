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
