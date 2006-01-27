#!/bin/csh

set mydate = `date +%Y%m%d`

set organism = $1

shift

set number = 0

if ($1) then

    set number = $1

    shift
endif

set projectdir = `pfind -q $organism`

# create the alias for the bin

set prt = `echo $organism | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`

alias import${prt}all "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/import-$mydate-all ${projectdir}/arcturus/import-export/importintoarcturus.csh"

alias export${prt}all "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/export-$mydate-all ${projectdir}/arcturus/import-export/exportfromarcturus.csh"

alias import${prt}bin "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/import-$mydate-bin ${projectdir}/arcturus/import-export/importintoarcturus.csh BIN"

alias export${prt}bin "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/export-$mydate-bin ${projectdir}/arcturus/import-export/exportfromarcturus.csh BIN"

set j = $number

while ($j > 0)

    @ i = $number - $j

    @ i = $i + 1

    @ j = $j - 1

    alias import${prt}${i} "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/import-$mydate-${prt}${i} ${projectdir}/arcturus/import-export/importintoarcturus.csh ${organism}${i}"

    alias export${prt}${i} "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/export-$mydate-${prt}${i} ${projectdir}/arcturus/import-export/exportfromarcturus.csh ${organism}${i}"

end

while ($#argv != 0)

    set rawname = $1

    set name = `echo $rawname | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`

    alias import${prt}${name} "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/import-$mydate-${prt}${name} ${projectdir}/arcturus/import-export/importintoarcturus.csh $1"

    alias export${prt}${name} "bsub -q pcs3q1 -N -o ${projectdir}/arcturus/import-export/export-$mydate-${prt}${name} ${projectdir}/arcturus/import-export/exportfromarcturus.csh $1"

    shift

end
