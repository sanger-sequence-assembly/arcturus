#!/bin/csh -f

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

