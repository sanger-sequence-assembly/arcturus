#!/bin/csh

set arcturus_home = /software/arcturus/utils
#set arcturus_home = $HOME/arcturus/dev/utils

if ( $#argv == 0 ) then
  echo \!\! -- No database instance specified --
  echo "usage: $0 instance_name organism-name assembly_caf_file [project]"
  exit 1
endif

set instance = $1

if ( $#argv == 1 ) then
  echo \!\! -- No arcturus database specified --
  echo "usage: $0 instance_name organism-name assembly_caf_file [project]"
  exit 1
endif

set organism = $2

if ( $#argv == 2 ) then
  echo \!\! -- No phusion assembly CAF file name specified --
  echo "usage: $0 instance_name organism-name assembly_caf_file [project]"
  exit 1
endif

set assemblycaffile = $3

set project = BIN

if ( $#argv == 4 ) then
    set project = $4
endif

set tempdir = /tmp
set padded = $tempdir/$organism.pad.caf
set depadded = $tempdir/$organism.depad.caf

if ( !(-f $depadded) ) then
    echo \!\! -- creating depadded assembly : $depadded
    if (  !(-f $padded) ) then
        set extension = $assemblycaffile:e
        if ( $extension == "gz" ) then
             echo \!\! -- unzipping file $assemblycaffile
             gunzip -c $assemblycaffile > $padded
        else
            set padded = $assemblycaffile
        endif
    endif
    echo \!\! -- padded assembly : $padded

    set isunpadded = `grep -l Unpadded $padded || echo 0`

    if ( $isunpadded != 0 ) then
        echo \!\! -- assembly is already unpadded
#        mv $padded $depadded
        set depadded = $padded
    else
        echo \!\! -- creating depadded assembly
        caf_depad < $padded > $depadded
    endif

endif


if ( !(-f $depadded) ) then
    echo  \!\! -- FAILED to create depadded assembly $depadded
    exit 1
endif

echo \!\! -- depadded assembly found : $depadded

# echo \!\! -- test abort
#exit 

set missingreadsfile = missing${organism}reads.lis

set arcturus_home = $HOME/arcturus/dev/utils
$arcturus_home/new-contig-loader -instance $instance -organism $organism -caf $depadded  -out $missingreadsfile -ap $project -nsrt -dp $project



#$arcturus_home/new-contig-loader.pl -instance $instance -organism $organism -caf $depadded -nlrt -ctt REPT -avz -out $missingreadsfile -ap $project

exit 










