#!/bin/csh -f
if ( $# > 0 ) then
  set CONTIG=$1
else
  echo hunt-for-duplicate-in-SAM is expecting a contig 
	die 1
endif

set FILE = /lustre/scratch101/sanger/sn5/CELERA.sam.rebuilt
echo Looking for contig $1 in SAM file $FILE
grep $1 $FILE
echo Search complete

