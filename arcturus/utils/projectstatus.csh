#!/bin/csh

# run script from your work directory

# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = must be keyword '-project'
#             no 4 = gap4 project (database) name

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
  echo usage: utils/diagnose -project project_name
  exit 1
endif

if ( !($3 == '-project')) then
  echo \!\! -- '-project' keyword specified --
  echo usage: utils/diagnose -project project_name
endif

if ( $#argv == 3 ) then
  echo \!\! -- No project name specified --
  echo usage: utils/diagnose -project project_name
  exit 1
endif

set project = $4

set arcturus_home = /software/arcturus

# part I : test which versions exist

set exists0 = 1
set existsA = 1
set existsB = 1

if ( ! -f ${project}.0 ) then
  set pwd = `pwd`
  echo \!\! -- version ${pwd}/${project}.0 not found --
  set exists0 = 0
else
# here a test on the size?
endif

if ( ! -f ${project}.A ) then
  set pwd = `pwd`
  echo \!\! -- version ${pwd}/${project}.A not found --
  set existsA = 0
else
# here a test on the size?
endif

if ( ! -f ${project}.B ) then
  set pwd = `pwd`
  echo \!\! -- version ${pwd}/${project}.B not found --
  set existsB = 0
else
# here a test on the size?
endif

# part I : diagnose

if ( $exists0 == 0 ) then

  if ( $existsA && $existsB ) then

     if ( { ${arcturus_home}/utils/isolderthan ${project}.A ${project}.B } ) then
# B version younger than A version
       echo \!\! -- status ANOMALOUS: data base ${project}.0 has been lost --
       echo \!\! -- project ${project} may need to be re-exported before copying --
     else
# B version older than A version
       echo \!\! -- data base ${project}.A needs to be copied to ${project}.0 --

     endif

  else if ( $existsA ) then
# both 0 and B do not exist
    echo \!\! -- data base ${project}.A needs to be copied to ${project}.0 --

  else 
# none of the data bases exists
    echo \!\! -- status ABSENT : check that you are in the correct directory --

  endif
  exit 0
endif

if ( !($existsA) ) then
# version 0 exists

  if ( !($existsB) ) then
    echo \!\! -- project ${project} may be imported into Arcturus --

  else if ( { ${arcturus_home}/utils/isolderthan ${project}.B ${project}.0 } ) then
# only versions 0 and B exist but B is younger
    echo \!\! -- ${project} appears to have been imported into Arcturus --
    echo \!\! -- check that you did not forget to export a new A version --

  else 
# only versions 0 and B exist but B is older
    echo \!\! -- ${project} status NOMINAL : project can be imported into Arcturus --
    echo \!\! --                UNEXPECTED : version A \(the last export\) has been lost --   
  endif
  exit 0
endif

if ( !($existsB) ) then
# only versions 0 and A exist
  if ( { ${arcturus_home}/utils/isolderthan ${project}.A ${project}.0 } ) then
    echo \!\! -- ${project} status NEW : version A can be copied to version 0 --
    echo \!\! --            UNEXPECTED : version B \(the back-up\) has been lost --
  else 
    echo \!\! -- ${project} status NOMINAL : project can be imported into Arcturus --
  endif
  exit 0
endif

# part II : all project versions exist; get timestamp order

set Aolderthan0 = 0
set Bolderthan0 = 0
set AolderthanB = 0

if ( { ${arcturus_home}/utils/isolderthan ${project}.0 ${project}.A } ) then
  set Aolderthan0 = 1
endif

if ( { ${arcturus_home}/utils/isolderthan ${project}.0 ${project}.B } ) then
  set Bolderthan0 = 1
endif

if ( { ${arcturus_home}/utils/isolderthan ${project}.B ${project}.A } ) then
  set AolderthanB = 1
endif

# part III : test if the project is busy

set isBusy = ''
if ( -f ${project}.0.BUSY ) then
  set isBusy = "(BUSY)"
endif

if ( -f ${project}.A.BUSY ) then
  set isBusy = "(BUSY)"
endif

# part IV : diagnose
#echo A-0 = $Aolderthan0   B-0 = $Bolderthan0   A-B = $AolderthanB

if ( $Aolderthan0 == 1 && $AolderthanB == 0 ) then
# 0AB
  echo \!\! -- ${project} status NOMINAL $isBusy : project can be imported into Arcturus --
  exit 0
endif
  
if ( $Aolderthan0 == 1 && $Bolderthan0 == 0 )  then
# B0A
  echo \!\! -- ${project} status PENDING : export of new A version from Arcturus may be required --
  exit 0
endif

if ( $Bolderthan0 == 1 && $AolderthanB == 1 ) then
# 0BA
  echo \!\! -- ${project} status FRAGILE : no export from Arcturus done after last import --
  exit 0
endif

if ( $Aolderthan0 == 0 && $Bolderthan0 == 1 ) then
# A0B
  echo \!\! -- ${project} status INCONSISTENT : no import into Arcturus was made before the last export, ask help --
  exit 0
endif

if ( $AolderthanB == 0 && $Bolderthan0 == 0 ) then
# AB0
  echo \!\! -- ${project} status NEW : version A can be copied to version 0 --
  exit 0
endif

if ( $AolderthanB == 1 && $Aolderthan0 == 0 ) then
# BA0
  echo \!\! -- ${project} status ANOMALOUS : this situation should not occur, get help --
  exit 0
endif
  
echo Invalid termination of $0
