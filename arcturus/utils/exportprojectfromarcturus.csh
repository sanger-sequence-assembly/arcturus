#!/bin/csh

# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = gap4 project (database) name
#             no 4 = indicates 64 bit version or 32 bit
#             no 5 = flag for skipping consensus update (skipped if == true)
  
set arcturus_home = /nfs/pathsoft/arcturus

if ( $#argv == 0 ) then
  echo \!\! -- No database instance specified --
  echo usage: $0 instance_name organism-name project_name bit_version \[1\]
  exit 1
endif

set instance = $1

if ( $#argv == 1 ) then
  echo \!\! -- No arcturus database specified --
  echo usage: $0 instance_name organism-name project_name bit_version \[1\]
  exit 1
endif

set organism = $2 

if ( $#argv == 2 ) then
  echo \!\! -- No project name specified --
  echo usage: $0 instance_name organism-name project_name bit_version \[1\]
  exit 1
endif

set projectname = $3

if ( $#argv == 3 ) then
  echo \!\! -- No bit version specified --
  echo usage: $0 instance_name organism-name project_name bit_version \[1\]
  exit 1
else if ( $4 == 64 ) then

  set caf2gap_dir = /nfs/pathsoft/prod/WGSassembly/bin/64bit

else if ( $4 == 32 ) then

  set caf2gap_dir = /usr/local/badger/bin

else
  echo \!\! -- Invalid bit version \($4\) specified specified \(should be 32 or 64\) --
  exit 1 
endif


# ok, here we go : go to the work directory and request memory for the big action

limit datasize 16000000

cd `pfind -q $organism`/arcturus

if ( ! -f ${projectname}.0 ) then
  echo \!\! -- Project $projectname version 0 does not exist --
#  exit 1
endif

# unless the 5-th parameter is defined and true, do consensus update 

if  ( ! $5 ) then
  set arcturus_java = ${arcturus_home}/java/scripts

  setenv PATH /nfs/pathsoft/external/bio-soft/java/usr/opt/java142/bin:${PATH}

  ${arcturus_java}/calculateconsensus -instance $instance -organism $organism -quiet -lowmem
endif

#echo test abort $projectname $caf2gap_dir
#exit 0

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

chmod g+w ${projectname}.A

chmod g+w ${projectname}.A.aux

echo Cleaning up

rm -f $padded $depadded

exit 0
