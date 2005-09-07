#!/bin/csh

# parameters: database instance, organism name, Gap4 project name

if ( $#argv == 0 ) then
  echo \!\! -- No database instance specified --
  echo usage: $0 instance_name organism-name project_name
  exit 1
endif

set instance = $1

if ( $#argv == 1 ) then
  echo \!\! -- No arcturus database specified --
  echo usage: $0 instance_name organism-name project_name
  exit 1
endif

set organism = $2 

if ( $#argv == 2 ) then
  echo \!\! -- No project name specified --
  echo usage: $0 instance_name organism-name project_name
  exit 1
endif

set projectname = $3

set organism_dir = `pfind -q $organism`

cd $organism_dir/arcturus

if ( ! -f ${projectname}.0 ) then
  echo \!\! -- Project $projectname version 0 does not exist --
  exit 1
endif

# get trash project name, if any

set trashproject = TRASH

if ( $#argv > 3 ) then
    set trashproject = $4
endif

set arcturus_home=/nfs/pathsoft/arcturus

# limit datasize 16000000

set padded=/tmp/${projectname}.padded.caf

set depadded=/tmp/${projectname}.depadded.caf

echo Processing $projectname

if ( -f ${projectname}.0.BUSY ) then
  echo \!\! -- Import of project $projectname aborted: Gap4 version 0 is BUSY --
  exit 0
endif

if ( -f ${projectname}.A.BUSY ) then
  echo \!\! -- Import of project $projectname aborted: Gap4 version A is BUSY --
  exit 0
endif

echo Test abort
set pwd = `pwd`
echo d:$pwd i:$instance o:$organism p:$projectname tp:$trashproject
exit 0

echo Backing up version 0 to version B

if ( -f ${projectname}.B ) then
  rmdb $projectname B
endif

cpdb $projectname 0 $projectname B

echo Converting Gap4 database to CAF format

/nfs/pathsoft/prod/WGSassembly/bin/64bit/gap2caf -project $projectname -version 0 -ace $padded

echo Depadding CAF file

caf_depad < $padded > $depadded

echo Importing to Arcturus

# added 06/09/2005 default project name

${arcturus_home}/utils/contig-loader -instance $instance -organism $organism -caf $depadded -project $projectname

# added 06/09/2005 read allocation test with assignment to TRASH project

echo Testing read-allocation for posible duplicates

${arcturus_home}/utils/read-allocation-test -instance $instance -organism $organism -trash -project $trashproject

echo Calculating consensus sequence

setenv PATH /nfs/pathsoft/external/bio-soft/java/usr/opt/java142/bin:${PATH}

/nfs/pathsoft/arcturus/java/scripts/calculateconsensus -instance $instance -organism $organism -quiet -lowmem

echo Cleaning up

rm -f $padded $depadded
