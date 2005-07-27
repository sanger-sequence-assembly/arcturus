#!/bin/csh

set arcturus=`dirname $0`

set hostname=`hostname`

set instance=undef
set organism=undef
set contigs=undef
set cleanup=0

while ( $#argv > 0 )
  if ( "$1" == "-instance" ) then
      set instance=$2
      shift
      shift
  else if ( "$1" == "-organism" ) then
      set organism=$2
      shift
      shift
  else if ( "$1" == "-contigs" ) then
      set contigs=$2
      shift
      shift
  else if ( "$1" == "-cleanup" ) then
      set cleanup=1
      shift
  endif
end

if ( "$instance" == "undef" ) then
    echo Instance was not specified
    exit 1
endif

if ( "$organism" == "undef" ) then
    echo Organism was not specified
    exit 1
endif

if ( "$contigs" == "undef" ) then
    echo Contig list was not specified
    exit 1
endif

set project=${organism}$$
set tmpdir=/tmp/${project}

mkdir ${tmpdir}

pushd ${tmpdir}

${arcturus}/contig-export -instance ${instance} -organism ${organism} -caf export.unpadded.caf -contigs ${contigs}

caf_pad < export.unpadded.caf > export.padded.caf

caf2gap -ace export.padded.caf -project ${project}

lsrun -m ${hostname} gap4 ${project}.0.aux

gap2caf -project ${project} -ace import.padded.caf

caf_depad < import.padded.caf > import.unpadded.caf

${arcturus}/contig-loader -instance ${instance} -organism ${organism} -caf import.unpadded.caf

${arcturus}/calculateconsensus -instance ${instance} -organism ${organism} -quiet

popd

if ( "$cleanup" != "0" ) then
    rm -r -f ${tmpdir}
endif

exit 0
