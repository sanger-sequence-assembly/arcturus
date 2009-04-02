#!/bin/csh -f

if ( $# < 3) then
    echo One or more arguments missing:
    echo project_name contigs_caf_file reads_caf_file new_assembly_caf_file
    exit 1
endif

set wgshome=/software/pathogen/WGSassembly

set wgslib=${wgshome}/lib
set wgsbin=${wgshome}/bin

if ( $?PERL5LIB ) then
    setenv PERL5LIB ${wgslib}:${PERL5LIB}
else
    setenv PERL5LIB ${wgslib}
endif

set dlimit=10000000

set phrapexe=phrap.manylong

perl ${wgsbin}/reassembler -project $1 -minscore 70 -minmatch 30 -phrapexe ${phrapexe} \
    -qual_clip phrap -dlimit ${dlimit} -nocons99 -notrace_edit $2 $3 > $4
