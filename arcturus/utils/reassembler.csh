#!/bin/csh -f

set arcturushome=/nfs/team81/adh/arcturus

set arcturuslib=${arcturushome}/lib
set arcturusbin=${arcturushome}/utils

set minervahome=/nfs/team81/adh/minerva

set minervabin=${minervahome}/scripts

set wgshome=/nfs/pathsoft/prod/WGSassembly

set wgslib=${wgshome}/lib
set wgsbin=${wgshome}/bin

if ( $?PERL5LIB ) then
    setenv PERL5LIB ${wgslib}:${arcturuslib}:${PERL5LIB}
else
    setenv PERL5LIB ${wgslib}:${arcturuslib}
endif

set workingdir=`dirname $0`

cd ${workingdir}

set dlimit=2000000
set instance=dev
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

    ${arcturusbin}/contig-loader.pl -instance ${instance} \
                                    -organism ${organism} \
                                    -caf newassembly.depad.caf

    ${minervabin}/calculateconsensus -instance cn=${instance},cn=jdbc \
                                     -organism cn=${organism}

    rm -f [a-z]*
    popd
end
