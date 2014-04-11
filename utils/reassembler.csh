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


<<<<<<< .mine
set arcturushome=$HOME/arcturus
set arcturushome=/software/arcturus
=======
if ( $# < 3) then
    echo One or more arguments missing:
    echo project_name contigs_caf_file reads_caf_file new_assembly_caf_file
    exit 1
endif
>>>>>>> .r3321

set wgshome=/software/pathogen/WGSassembly

<<<<<<< .mine
set minervahome=/software/arcturus/java

set minervabin=${minervahome}/scripts

set wgshome=/nfs/pathsoft/prod/WGSassembly

=======
>>>>>>> .r3321
set wgslib=${wgshome}/lib
set wgsbin=${wgshome}/bin

if ( $?PERL5LIB ) then
    setenv PERL5LIB ${wgslib}:${PERL5LIB}
else
    setenv PERL5LIB ${wgslib}
endif

set dlimit=10000000

set phrapexe=phrap.manylong

<<<<<<< .mine
set dlimit=2000000
set instance=pathogen
set organism=$1

shift

if ( ! -d $organism ) then
    mkdir $organism
endif

cd $organism

foreach cutoff ($*)
    if ( -d $cutoff ) then
	rm -r -f $cutoff
    endif

    mkdir $cutoff

    pushd $cutoff

    ${arcturusbin}/getunassembledreads.pl -instance ${instance} \
                                          -organism ${organism} \
                                          -aspedbefore ${cutoff} > newreads.caf

    ${arcturusbin}/export-assembly.pl -instance ${instance} \
                                      -organism ${organism} \
                                      -caf oldcontigs.caf

    if ( -z oldcontigs.caf ) then
        set phrapexe=phrap.manyreads
    else
        set phrapexe=phrap.longreads
    endif

    ${wgsbin}/reassembler -project ${organism} \
                          -minscore 70 \
                          -minmatch 30 \
                          -phrapexe ${phrapexe} \
                          -qual_clip phrap \
                          -dlimit ${dlimit} \
                          -nocons99 \
                          -notrace_edit \
			  oldcontigs.caf newreads.caf > newassembly.caf

    caf_depad < newassembly.caf > newassembly.depad.caf

    ${arcturusbin}/new-contig-loader.pl -instance ${instance} \
                                        -organism ${organism} \
                                        -caf newassembly.depad.caf

    ${minervabin}/calculateconsensus -instance cn=${instance},cn=jdbc \
                                     -organism cn=${organism}

    rm -f [a-z]*
    popd
end
=======
perl ${wgsbin}/reassembler -project $1 -minscore 70 -minmatch 30 -phrapexe ${phrapexe} \
    -qual_clip phrap -dlimit ${dlimit} -nocons99 -notrace_edit $2 $3 > $4
>>>>>>> .r3321
