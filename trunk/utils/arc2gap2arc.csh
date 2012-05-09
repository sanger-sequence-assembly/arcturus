#!/bin/csh

set arcturus=`dirname $0`

set hostname=`hostname`

set instance=undef
set organism=undef
set contigs=undef
set cleanup=0
set use64bit=0
set display=undef

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
  else if ( "$1" == "-display" ) then
      set display=$2
      shift
      shift
  else if ( "$1" == "-cleanup" ) then
      set cleanup=1
      shift
  else if ( "$1" == "-64bit" ) then
      set use64bit=1
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

if ( "$display" != "undef" ) then
    echo ### Setting DISPLAY to $display
    setenv DISPLAY $display
endif

if ( "$use64bit" == "1") then
    set CAF2GAP=/nfs/pathsoft/prod/WGSassembly/bin/64bit/caf2gap
    set GAP2CAF=/nfs/pathsoft/prod/WGSassembly/bin/64bit/gap2caf
    set GAP4="gap4 -root=/usr/local/badger/STADEN_PKGS/unix-rel-1-6-0b1"
    echo Using 64-bit Gap4
else
    set CAF2GAP=caf2gap
    set GAP2CAF=gap2caf
    set GAP4=gap4
endif

echo Running on ${hostname}

set project=${organism}$$
set tmpdir=/tmp/${project}

mkdir ${tmpdir}

pushd ${tmpdir}

echo Exporting contigs from Arcturus

${arcturus}/contig-export -instance ${instance} -organism ${organism} -caf export.unpadded.caf -contig ${contigs}

echo Padding CAF file

caf_pad < export.unpadded.caf > export.padded.caf

echo Converting CAF to Gap

${CAF2GAP} -ace export.padded.caf -project ${project}

echo Running Gap4

lsrun -m ${hostname} ${GAP4} ${project}.0.aux

echo Converting Gap to CAF

${GAP2CAF} -project ${project} -ace import.padded.caf

echo Depadding CAF file

caf_depad < import.padded.caf > import.unpadded.caf

echo Importing contigs to Arcturus

${arcturus}/contig-loader -instance ${instance} -organism ${organism} -caf import.unpadded.caf -minimum 1

echo Calculating contig consensus

${arcturus}/calculateconsensus -instance ${instance} -organism ${organism} -quiet

popd

if ( "$cleanup" != "0" ) then
    rm -r -f ${tmpdir}
endif

exit 0
