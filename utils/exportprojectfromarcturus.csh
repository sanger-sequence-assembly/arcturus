#!/bin/tcsh

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


# parameters: no 1 = database instance
#             no 2 = organism name
#             no 3 = gap4 project (database) name
#             no 4 = nolock [OPTIONAL]
  
set basedir=`dirname $0`
set arcturus_home = ${basedir}/..

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

set nolock=0

if ( $#argv > 3 && $4 == 'nolock' ) then
    set nolock=1
endif

# ok, here we go : request memory for the big action

limit datasize 16000000

if ( ! -f ${projectname}.0 ) then
  echo \!\! -- Project $projectname version 0 does not exist --
endif

${basedir}/calculateconsensus -instance $instance -organism $organism -project $projectname

endif

# delete the version A of the specified project

if ( -f $projectname.A ) then
  rmdb $projectname A
endif

set caffile=/tmp/${projectname}.$$.caf

echo Processing $projectname

# should the project lock not better be in the export script itself?

if ( "$nolock" == "0" ) then
    ${arcturus_home}/utils/project-lock -instance $instance -organism $organism -project $projectname -confirm

    set rc=$?

    if ( $rc > 0 ) then
	echo  \!\! -- FAILED to lock project $projectname : export aborted --
	exit 1
    else
	echo  -- project $projectname is now locked --
    endif
endif

echo Exporting from Arcturus to caffile $caffile

${arcturus_home}/utils/project-export -instance $instance -organism $organism -project $projectname -caf $caffile  # ? -unlocked

set rc=$?

if ( $rc >  ) then
    echo \!\! -- FAILED to export project $projectname to a CAF file : export aborted --
    exit 1
endif

echo Converting CAF file to Gap4 database

${badgerbin}/caf2gap -project $projectname -version A -ace $caffile

set rc=$?

if ( $rc > 0 ) then
    echo  \!\! -- FAILED to create a Gap4 database from $caffile --
    exit 1
endif

echo Changing access privileges on Gap4 database

chmod g-w ${projectname}.A

chmod g-w ${projectname}.A.aux

echo Marking the project as exported

set gap4dirname=`pwd`;

${arcturus_home}/utils/project-export-marker -instance $instance -organism $organism -project $projectname -file ${gap4dirname}/${projectname}.A 

if ( "$nolock" == "0" ) then
    echo Transfering lock to project owner

    ${arcturus_home}/utils/project-lock -instance $instance -organism $organism -project $projectname -transfer owner -confirm
endif

echo Cleaning up

rm -f $caffile

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



