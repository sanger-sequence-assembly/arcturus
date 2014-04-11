#!/bin/sh

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


if [ $# -lt 1 ]
then
    echo Usage: $0 filename [version]
    exit 1
fi

DIR=`dirname $1`
FILE=`basename $1`

VERSION=0

if [ $# -gt 1 ]
then
    VERSION=$2
fi

if [ ! -d $DIR ]
then
    echo Directory $DIR does not exist
    exit 1
fi

cd $DIR

DBFILE=${FILE}.${VERSION}

if [ ! -e ${DBFILE} ]
then
    echo File $DBFILE does not exist in $DIR
    exit 2
fi

###
### Ensure we have our environment set up
###
export STADENROOT=$BADGER/opt/staden_production
STADEN_PREPEND=1 . $STADENROOT/share/staden/staden.profile

###
### Now run the script
###
tclsh <<EOF
source \$env(STADTABL)/shlib.conf
load \$env(STADLIB)/\${lib_prefix}tk_utils\${lib_suffix}
load_package tk_utils
tk_utils_init
load_package gap
set io [open_db -name $FILE -version $VERSION -access r]
set db [io_read_database \$io]
set nc [keylget db num_contigs]
for {set i 1} {\$i <= \$nc} {incr i} { puts "[contig_order_to_number -io \$io -order \$i]" }
close_db -io \$io
exit
EOF
