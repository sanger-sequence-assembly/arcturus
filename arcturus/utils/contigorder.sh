#!/bin/sh

if [ $# -lt 1 ]
then
    echo Usage: $0 filename [version]
    exit 1
fi

FILE=$1

VERSION=0

if [ $# -gt 1 ]
then
    VERSION=$2
fi

DBFILE=${FILE}.${VERSION}

if [ ! -e ${DBFILE} ]
then
    echo File $DBFILE does not exist
    exit 2
fi

export STADENROOT=$BADGER/opt/staden_production

###
### The next few lines are borrowed from the Staden gap4 wrapper script
###

STADEN_PREPEND=1 . $STADENROOT/staden.profile
export TCL_LIBRARY=$STADLIB/tcl
export TK_LIBRARY=$STADLIB/tk

STASH=${STADENROOT}/linux-x86_64-bin/stash
#STASH=cat

###
### Now run the script
###

${STASH} <<EOF
load_package gap
set io [open_db -name $FILE -version $VERSION -access r]
set db [io_read_database \$io]
set nc [keylget db num_contigs]
for {set i 1} {\$i <= \$nc} {incr i} { puts "[contig_order_to_number -io \$io -order \$i]" }
close_db -io \$io
exit
EOF
