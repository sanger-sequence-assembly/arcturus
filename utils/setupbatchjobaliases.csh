#!/bin/csh

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


set mydate = `date +%Y%m%d`

set organism = $1  # first parameter, organism

shift

set importdelay = ""

set exportdelay = ""

if ($1) then

    set importdelay = "-b 18:00"  # second parameter 0 for at once, 1 for after 6 PM

    set exportdelay = "-b 23:59" 

endif

shift

set number = 0

if ($1) then

    set number = $1 # third parameter, the number of enumerated projects

endif

shift

set projectdir = `pfind -q $organism`

# create the alias for the bin

set prt = `echo $organism | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`

alias import${prt}all "bsub -q pcs3q1 -N ${importdelay} -o ${projectdir}/arcturus/import-export/import-$mydate-all ${projectdir}/arcturus/import-export/importintoarcturus.csh"

alias export${prt}all "bsub -q pcs3q1 -N ${exportdelay} -o ${projectdir}/arcturus/import-export/export-$mydate-all ${projectdir}/arcturus/import-export/exportfromarcturus.csh"

alias import${prt}bin "bsub -q pcs3q1 -N ${importdelay} -o ${projectdir}/arcturus/import-export/import-$mydate-bin ${projectdir}/arcturus/import-export/importintoarcturus.csh BIN"

alias export${prt}bin "bsub -q pcs3q1 -N ${exportdelay} -o ${projectdir}/arcturus/import-export/export-$mydate-bin ${projectdir}/arcturus/import-export/exportfromarcturus.csh BIN"

set j = $number

while ($j > 0)

    @ i = $number - $j

    @ i = $i + 1

    @ j = $j - 1

    alias import${prt}${i} "bsub -q pcs3q1 -N ${importdelay} -o ${projectdir}/arcturus/import-export/import-$mydate-${prt}${i} ${projectdir}/arcturus/import-export/importintoarcturus.csh ${organism}${i}"

    alias export${prt}${i} "bsub -q pcs3q1 -N ${exportdelay} -o ${projectdir}/arcturus/import-export/export-$mydate-${prt}${i} ${projectdir}/arcturus/import-export/exportfromarcturus.csh ${organism}${i}"

end

while ($#argv != 0)

    set rawname = $1

    set name = `echo $rawname | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`

    alias import${prt}${name} "bsub -q pcs3q1 -N ${importdelay} -o ${projectdir}/arcturus/import-export/import-$mydate-${prt}${name} ${projectdir}/arcturus/import-export/importintoarcturus.csh $1"

    alias export${prt}${name} "bsub -q pcs3q1 -N ${exportdelay} -o ${projectdir}/arcturus/import-export/export-$mydate-${prt}${name} ${projectdir}/arcturus/import-export/exportfromarcturus.csh $1"

    shift

end
