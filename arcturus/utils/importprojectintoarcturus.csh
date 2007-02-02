#!/bin/csh

# run script from your work directory

# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = gap4 project (database) name
#             no 4 = indicates 64 bit version or 32 bit
#             no 5 = problems project name (optional, default PROBLEMS)

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

if ( $#argv == 3 ) then
  echo \!\! -- No bit version specified --
  echo usage: $0 instance_name organism-name project_name bit_version \[1\]
  exit 1
else if ( $4 == 64 ) then

  set gap2caf_dir = /nfs/pathsoft/prod/WGSassembly/bin/64bit

else if ( $4 == 32 ) then

  set gap2caf_dir = /usr/local/badger/bin

else
  echo \!\! -- Invalid bit version \($4\) specified specified \(should be 32 or 64\) --
  exit 1 
endif

# ok, here we go : go to the work directory and request memory for the big action

limit datasize 16000000

# cd `pfind -q $organism`/arcturus # removed: run script from work directory

if ( ! -f ${projectname}.0 ) then
  set pwd = `pwd`
  echo \!\! -- Project $projectname version 0 does not exist in ${pwd} --
  exit 1
endif

# get problems project name, if any

set repair = movetoproblems

set problemsproject = PROBLEMS

if ( $#argv > 4 ) then
    set problemsproject = $5
    set repair = mtp
endif

set basedir=`dirname $0`

set arcturus_home=${basedir}/..

set padded=/tmp/${projectname}.$$.padded.caf

set depadded=/tmp/${projectname}.$$.depadded.caf

echo Processing $projectname

if ( -f ${projectname}.0.BUSY ) then
  echo \!\! -- Import of project $projectname aborted: Gap4 version 0 is BUSY --
  exit 1
endif

if ( -f ${projectname}.A.BUSY ) then
  echo \!\! -- Import of project $projectname WARNING: Gap4 version A is BUSY --
#  exit 1
endif

if ( -e ${projectname}.0 ) then
# test age of version 0 against version A
    if ( -e ${projectname}.A ) then
        if ( { ${arcturus_home}/utils/isolderthan ${projectname}.A ${projectname}.0 } ) then
            echo \!\! -- Import of project $projectname skipped: Gap4 version 0 older than version A --
            exit 0
        endif
    endif
else
  echo \!\! -- Import of project $projectname aborted: Gap4 version 0 not found --
  exit 1
endif

#echo Test abort
#set pwd = `pwd`
#echo d:$pwd i:$instance o:$organism p:$projectname tp:$problemsproject
#exit 0


echo Backing up version 0 to version B

if ( -f ${projectname}.B ) then
  rmdb $projectname B
endif

cpdb $projectname 0 $projectname B

echo Converting Gap4 database to CAF format

$gap2caf_dir/gap2caf -project $projectname -version 0 -ace $padded

echo Depadding CAF file

caf_depad < $padded > $depadded

echo Importing to Arcturus

# added 06/09/2005 default project name

${arcturus_home}/utils/contig-loader -instance $instance -organism $organism -caf $depadded -defaultproject $projectname

# added 06/09/2005 read allocation test with assignment to PROBLEMS project

echo Testing read-allocation for possible duplicates

${arcturus_home}/utils/read-allocation-test -instance $instance -organism $organism -$repair -project $problemsproject

# calculating consensus sequence (for this project only)

setenv PATH /nfs/pathsoft/external/bio-soft/java/usr/opt/java142/bin:${PATH}

${arcturus_home}/java/scripts/calculateconsensus -instance $instance -organism $organism -project $projectname -quiet -lowmem

echo Cleaning up

rm -f $padded $depadded

exit 0












