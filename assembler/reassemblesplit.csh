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
    echo Reassembles from scratch all reads occurring in the split
    echo Usage: $0 instance organism split,project unassembled
# if unassembled flag set, add all unassembled reads as well
    exit 1
endif

set instance=$1
set organism=$2
set project=$3

set allunassembled = 0
if ($#argv > 3) then
    set allunassembled = $4
endif

set allreads = /tmp/allreads.${project}.caf

set unassembled = /tmp/unassembled.${project}.caf

set export=0
if ( ! -f ${allreads} ) then
#    echo new reads to be exported
    set export=1
endif

if (${allunassembled} > 0) then
    if ( ! -f ${unassembled} ) then
        set export=1
    endif
endif

# echo export $export $allreads

set mqr = 24

if ($export == 1) then

    echo exporting assembled reads of project ${project}

    ${arcturusbin}/project-export  -instance    ${instance} \
        	                   -organism    ${organism} \
	        	           -project     ${project}  \
				   -caf         ${allreads} \
                                   -readsonly   \
                                   -mask x
# add name filter? or asped select? problem with consensus reads being skipped?
#                                   -ef standard \ # weed out mangled capillary read names

# if all unassembled reads are used append them to ${allreads}; we use
# all unassembled reads except the ones in single reads contigs which
# can belong to other projects

    if (${allunassembled} > 0) then

        echo exporting unassembled reads

        ${arcturusbin}/getunassembledreads -instance    ${instance} \
              	                           -organism    ${organism} \
                                           -caf         ${unassembled} \
                                           -nostatus    \
                                           -mqr ${mqr}  \
                                           -mask x
#                                           -ef standard \ # weed out mangled capillary read names
# problem with consensus reads being ignored
        if ( !(-z ${unassembled}) ) then
            cat ${allreads} ${unassembled} > /tmp/cat.caf
            mv /tmp/cat.caf ${allreads} 
#            rm ${unassembled}
        endif

    endif

endif

if ( -z ${allreads} ) then
    echo there are no reads for project ${project}
    exit 1
endif

# exit 0 # TEST REMOVE !
# create a dummy empty contig file

set oldcontigs = /tmp/oldcontigs.${project}.caf
touch ${oldcontigs}

set phrapexe=phrap.manylong

set newassembly = /tmp/newassembly.${project}.caf

if ( $export == 1 ) then
    rm -f ${newassembly}
endif

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
                  ${oldcontigs} ${allreads} > ${newassembly}

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

exit 1

${arcturusbin}/new-contig-loader -instance ${instance} \
                                 -organism ${organism} \
                                 -project  ${project} \
                                 -caf ${depaddedassembly}
# tag options ...

${arcturusjava}/calculateconsensus -instance ${instance} \
                                   -organism ${organism}

