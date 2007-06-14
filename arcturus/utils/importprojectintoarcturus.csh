#!/bin/tcsh

# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = gap4 project (database) name
#             no 4 = (optional) name of problems project

set basedir=`dirname $0`
set arcturus_home = ${basedir}/..
set loader_script = ${arcturus_home}/utils/contig-loader

set badgerbin=${BADGER}/bin

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

# ok, here we go : request memory for the big action

limit datasize 16000000

if ( ! -f ${projectname}.0 ) then
  set pwd = `pwd`
  echo \!\! -- Project $projectname version 0 does not exist in ${pwd} --
  exit 1
endif

# get problems project name, if any

set repair = -movetoproblems

set problemsproject = PROBLEMS

if ( $#argv > 3 ) then
    set problemsproject = $4
    set repair = -mtp
endif

if ( $#argv > 4 ) then
    echo  \!\! -- contig loader $5 to be used --
    set loader_script = $5
else
    echo  \!\! -- default contig loader used --
endif


set padded=/tmp/${projectname}.$$.padded.caf

set depadded=/tmp/${projectname}.$$.depadded.caf

set loading_log=/tmp/${projectname}.$$.loading.log

set allocation_log=/tmp/${projectname}.$$.allocation.log

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

echo Backing up version 0 to version B

if ( -f ${projectname}.B ) then
  rmdb $projectname B
endif

cpdb $projectname 0 $projectname B

echo Converting Gap4 database to CAF format

${badgerbin}/gap2caf -project $projectname -version 0 -ace $padded

set rc=$?

if ( $rc > 0 ) then
    echo \!\! -- FAILED to create a CAF file from Gap4 database $projectname :  import aborted --
    exit 1
endif

echo Depadding CAF file

${badgerbin}/caf_depad < $padded > $depadded

if ( $rc > 0 ) then
    echo \!\! -- FAILED to depad CAF file $padded :  import aborted --
    exit 1
endif

echo Importing into Arcturus # ${arcturus_home}/utils

# added 06/09/2005 default project name

${loader_script} -instance $instance -organism $organism -caf $depadded -defaultproject $projectname

# added 06/09/2005 read allocation test with assignment to PROBLEMS project

# added 13/02/2007 test split between inside project and between projects

# use repair mode for inconsistencies inside the project

echo Testing read-allocation for possible duplicates inside projects

${arcturus_home}/utils/read-allocation-test -instance $instance -organism $organism $repair -problemproject $problemsproject -workproject $projectname -inside -log $allocation_log -mail ejz

# no repair mode for inconsistencies between projects

echo Testing read-allocation for possible duplicates between projects

${arcturus_home}/utils/read-allocation-test -instance $instance -organism $organism -nr -problemproject $problemsproject -workproject $projectname -between -log $allocation_log -mail ejz

# calculating consensus sequence (for this project only)

${basedir}/calculateconsensus -instance $instance -organism $organism -project $projectname -quiet -lowmem

echo Cleaning up

set allocationlog = readallocation.log

if ( ! -f $allocationlog) then
     touch $allocationlog
endif

cat $allocation_log >> $allocationlog

rm -f $padded $depadded

exit 0
