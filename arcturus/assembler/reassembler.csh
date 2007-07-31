#!/bin/csh -f

set arcturushome=/software/arcturus

set arcturuslib=${arcturushome}/lib
set arcturusbin=${arcturushome}/utils
set arcturusjava=${arcturushome}/java/scripts

set wgshome=/nfs/pathsoft/prod/WGSassembly

set wgslib=${wgshome}/lib
set wgsbin=${wgshome}/bin

if ( $?PERL5LIB ) then
    setenv PERL5LIB ${wgslib}:${PERL5LIB}
else
    setenv PERL5LIB ${wgslib}
endif

set scriptdir=`dirname $0`

set reassembler="/usr/local/bin/perl ${wgshome}/bin/reassembler"

set dlimit=24000000
set instance=$1
set organism=$2
set cutoff=$3

shift

if ( ! -d $organism ) then
    mkdir $organism
endif

cd $organism

if ( ! -d $cutoff ) then
    mkdir $cutoff
endif

cd $cutoff

if ( ! -f newreads.caf ) then
	${arcturusbin}/getunassembledreads -instance ${instance} \
        	                           -organism ${organism} \
			                   -aspedbefore ${cutoff} \
					   -caf newreads.caf
endif

if ( ! -f oldcontigs.caf ) then
	${arcturusbin}/export-assembly -instance ${instance} \
        	                       -organism ${organism} \
				       -caf oldcontigs.caf
endif

if ( -z oldcontigs.caf ) then
    set phrapexe=phrap.manyreads
else
    set phrapexe=phrap.longreads
endif

${reassembler} -project ${organism} \
               -minscore 70 \
               -minmatch 30 \
               -phrapexe ${phrapexe} \
               -qual_clip phrap \
               -dlimit ${dlimit} \
               -nocons99 \
               -notrace_edit \
	       -cvclip \
	       -noclean \
               oldcontigs.caf newreads.caf > newassembly.caf

caf_depad < newassembly.caf > newassembly.depad.caf

${arcturusbin}/contig-loader -instance ${instance} \
                             -organism ${organism} \
                             -caf newassembly.depad.caf

${arcturusjava}/calculateconsensus -instance ${instance} \
                                   -organism ${organism} \
                                   -quiet -lowmem

#rm -f oldcontigs.caf newreads.caf newassembly.caf assembly
#gzip newassembly.depad.caf
