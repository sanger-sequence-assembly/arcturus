#!/bin/csh

# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = gap4 project (database) name
  
set basedir=`dirname $0`
set arcturus_home = ${basedir}/..

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

set caf2gap_dir = /nfs/pathsoft/prod/WGSassembly/bin/64bit

# ok, here we go : request memory for the big action

limit datasize 16000000

if ( ! -f ${projectname}.0 ) then
  echo \!\! -- Project $projectname version 0 does not exist --
#  exit 1
endif

${basedir}/calculateconsensus -instance $instance -organism $organism -project $projectname -quiet -lowmem

endif

# delete the version A of the specified project

if ( -f $projectname.A ) then
  rmdb $projectname A
endif

set padded=/tmp/${projectname}.$$.padded.caf
set depadded=/tmp/${projectname}.$$.depadded.caf

echo Processing $projectname

echo Exporting from Arcturus to caffile $depadded

${arcturus_home}/utils/project-export -instance $instance -organism $organism -project $projectname -caf $depadded

echo Padding CAF file

caf_pad < $depadded > $padded

echo Converting CAF file to Gap4 database

$caf2gap_dir/caf2gap -project $projectname -version A -ace $padded

echo Changing access privileges on Gap4 database

chmod g-w ${projectname}.A

chmod g-w ${projectname}.A.aux

echo Cleaning up

rm -f $padded $depadded


if ( ! (-e ${projectname}.B) ) then

    echo \!\! -- version ${projectname}.0 kept because no back-up B version found --

endif


if ( -z ${projectname}.B ) then

    echo \!\! -- version ${projectname}.0 kept because corrupted B version found --

endif


if ( { ${arcturus_home}/utils/isolderthan ${projectname}.B ${projectname}.0 } ) then

    echo -- version ${projectname}.0 is deleted --

    rmdb ${projectname} 0

else

    echo \!\! -- version ${projectname}.0 kept because no valid B version found --

endif

exit 0
