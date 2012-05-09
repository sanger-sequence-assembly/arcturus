#!/bin/csh -f

set arcturushome=/software/arcturus

set arcturuslib=${arcturushome}/lib
set arcturusbin=${arcturushome}/utils
set arcturusjava=${arcturushome}/java/scripts

set wgshome=/software/pathogen/WGSassembly

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

if ($#argv < 3) then
echo Usage: $0 instance organism project [allunassembledflag]
# allunassembledflag true  results in using all unassembled reads
#                    false results in using only reads of the project  
    exit 1
endif

set instance=$1
set organism=$2
set project=$3
set allunassembled = 0
if ($#argv > 3) then
    set allunassembled = $4
endif

set newreads = /tmp/newreads.${project}.caf

set oldcontigs = /tmp/oldcontigs.${project}.caf

set unassembled = /tmp/unassembled.${project}.caf

set export=0
if ( ! -f ${newreads} ) then
#    echo new reads to be exported
    set export=1
endif

if ( ! -f ${oldcontigs} ) then
#    echo contigss to be exported
    set export=1
endif

if ($allunassembled > 0) then
    if ( ! -f ${unassembled} ) then
#    echo contigss to be exported
        set export=1
    endif
endif

if ($export == 1) then

    echo exporting contigs and project reads for ${project}

    ${arcturusbin}/project-export  -instance    ${instance} \
        	                   -organism    ${organism} \
	        	           -project     ${project} \
				   -caf         ${oldcontigs} \
                                   -singletons  ${newreads} \
                                   -mask x

# if all unassembled reads are used append them to ${newreads}; we use
# all unassembled reads except the ones in single reads contigs which
# can belong to other projects

    if ($allunassembled > 0) then

        echo exporting unassembled reads for ${project}

        ${arcturusbin}/getunassembledreads -instance    ${instance} \
              	                           -organism    ${organism} \
                                           -caf         ${unassembled} \
                                           -nostatus     \
                                           -mqr 40       \
                                           -mask x
        if ( !(-z ${unassembled}) ) then
            cat ${newreads} ${unassembled} > /tmp/cat.caf
            mv /tmp/cat.caf ${newreads} 
            rm ${unassembled}
        endif

    endif

endif

if ( -z ${newreads} ) then
    echo there are no new reads for project ${project}
    exit 1
endif

if ( -z ${oldcontigs} ) then
    set phrapexe=phrap.manyreads
else
    set phrapexe=phrap.longreads
endif

set newassembly = /tmp/newassembly.${project}.caf

if ( ! -f ${newassembly} ) then

   echo starting reassembly

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
                  ${oldcontigs} ${newreads} > ${newassembly}

    if ( -z ${newassembly}) then
        echo empty new assembly returned
        exit 1
    endif

else 

    echo existing new assembly ${newassembly} detected

endif



set depaddedassembly = /tmp/newassembly.${project}.depad.caf

if ( ! -f ${depaddedassembly} ) then

     echo depadding new assembly

    caf_depad < ${newassembly} > ${depaddedassembly}

else

    echo exiting depadded assembly ${depaddedassembly} detected

endif

exit 1 # test

${arcturusbin}/new-contig-loader -instance ${instance} \
                                 -organism ${organism} \
                                 -project  ${project} \
                                 -caf ${depaddedassembly}
# ? tag options ...

${arcturusjava}/calculateconsensus -instance ${instance} \
                                   -organism ${organism}

