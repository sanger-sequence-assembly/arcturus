#!/bin/sh

FILE=/lustre/scratch101/sanger/sn5/CELERA.sam.rebuilt
echo Looking for the following strings in ${FILE}
cat /lustre/scratch101/sanger/kt6/oligo-finder-strings.txt
grep -F -f /lustre/scratch101/sanger/kt6/oligo-finder-strings.txt ${FILE} | awk '{print $1,$10}' 
