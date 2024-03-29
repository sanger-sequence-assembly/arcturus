#!/bin/bash

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


function showHelp () {
    cat <<EOF
This script creates a new Arcturus database for a zebrafish pooled clone
assembly.

It must be run in the directory which contains the assembly files, otherwise it
will not work correctly.

To check that it is in a directory containing a zebrafish pooled clone assembly,
the script tests for the existence of the following files:

CloneList.txt
Contigs_To_Clones

and a file named assembly_contig.caf or assembly_contig.caf.gz

MANDATORY PARAMETERS

    -instance         Arcturus instance name [pathogen,vertebrates,test,...]
    -pool             Name of pooled assembly
    -mysql-instance   Arcturus MySQL instance [arcp,hlmp,zebp,arct,...]
EOF
}

SCRIPT_HOME=`dirname $0`

PERL_LIB_DIR=${SCRIPT_HOME}/../lib

UTILS_DIR=${SCRIPT_HOME}/../utils

export PERL5LIB=${PERL_LIB_DIR}:${PERL5LIB}

#########################################################################
###             These settings are Sanger-specific                    ###
#########################################################################
LDAP_URL="ldap://ldap.internal.sanger.ac.uk/"
LDAP_ROOT_DN="cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"
LDAP_USER=${ARCTURUS_LDAP_USERNAME-"uid=${USER},ou=people,dc=sanger,dc=ac,dc=uk"}

#########################################################################
###             These settings are specific to ZGTC                   ###
#########################################################################
CLONE_LIST_FILE=CloneList.txt
CONTIG_TO_CLONE_MAP=Contigs_To_Clones

#########################################################################
###             Start of main script                                  ###
#########################################################################

createdb=1

until [ -z "$1" ]
do
  keyword=$1
  shift

  case "$keyword" in
      "-instance" )
	  instance=$1
	  shift
	  ;;

      "-pool" )
	  poolname=$1
	  shift
	  ;;

      "-mysql-instance" | "-mysql_instance" )
	  node=$1
	  shift
	  ;;

      "-subdir" )
	  subdir=$1
	  shift
	  ;;

      "-nocreatedb" )
	  createdb=0;
	  ;;

      "-help" | "--help" | "-h" )
	  showHelp
	  exit 0
	  ;;

      * )
	  echo Unknown option : $keyword
	  exit 1
	  ;;
  esac
done

if [ "x" == "x$poolname" ]
then
    echo -n "Enter pool name > "
    read poolname
fi

if [ "x" == "x$instance" ]
then
    echo -n "Enter Arcturus instance [pathogen,vertebrates,test,illumina...] > "
    read instance
fi

if [ "$createdb" -ne "0" ]
then
    if [ "x" == "x$node" ]
	then
	echo -n "Enter MySQL instance [arcp,hlmp,zebp,arct,illp...] > "
	read node
    fi

    if [ "x" == "x$subdir" ]
	then
	subdir=Zebrafish/Pools
    fi

    reposdir=`pwd`

    dbname=$poolname

    description="Zebrafish pooled BAC assembly ${poolname}"
fi

echo "----- Summary of input -----------------------------------"
echo "Arcturus instance     $instance"
echo "Pool name             $poolname"

if [ "$createdb" -ne "0" ]
then
    echo "Repository location   $reposdir"
    echo "MySQL instance        $node"
    echo "MySQL database        $dbname"
    echo "LDAP sub-directory    $subdir"
    echo "Description           $description"
fi
echo "----------------------------------------------------------"

###
### If the script is not running in batch mode, then ask the user
### to confirm the input
###

if [ "x$LSB_JOBID" == "x" ]
then
    echo -n "Is this correct? [yes/no] > "
    read yorn

    if [ "x$yorn" != "xyes" ]
	then
	echo "Exiting without creating the new database"
	exit 1
    else
	echo ''
    fi
fi

echo ''
echo STAGE 1 : CHECKING FOR INPUT FILES

###
### Test for existence of key input files
###

if [ ! -e ${CLONE_LIST_FILE} ]
then
    echo There is no clone list file named ${CLONE_LIST_FILE} in this directory.
    exit 1
fi

if [ ! -e ${CONTIG_TO_CLONE_MAP} ]
then
    echo There is no contig-to-clone map file named ${CONTIG_TO_CLONE_MAP} in this directory.
    exit 1
fi

###
### Create the temporary directory
###

TMP=tmp.$$

mkdir $TMP

caffile=

###
### Look for a plain CAF file containing the assembly
###

for fn in `find . -name assembly_contig.caf`
do
  echo Found a CAF file : $fn
  caffile=$fn
  break
done

###
### If there was no plain CAF file, look for a compressed CAF file
### and uncompress it into the temporary directory
###

if [ "x$caffile" == "x" ]
then
  for fn in `find . -name assembly_contig.caf.gz`
  do
    caffile=${TMP}/uncompressed_assembly_contig.caf
    echo Found a compressed CAF file : $fn
    gunzip -c $fn > $caffile
    break
  done
fi

###
### If there is still no CAF file, report the error and bail out
###

if [ "x$caffile" == "x" ]
then
    rmdir $TMP
    echo 'Failed to find a CAF file (plain or compressed) in this directory'
    exit 1
fi

###
### Create the file containing project names and directories
###

echo ''
echo STAGE 2 : FINDING DIRECTORIES FOR PROJECTS

CLONE_LIST_WITH_DIRS=${TMP}/CloneListWithDirectories.txt

for clone in `cat ${CLONE_LIST_FILE}`
do
  echo $clone,:PROJECT: >> ${CLONE_LIST_WITH_DIRS}
done

for clone in BIN POOL
do
  echo $clone,:ASSEMBLY: >> ${CLONE_LIST_WITH_DIRS}
done

projects=${CLONE_LIST_WITH_DIRS}

###
### Define the Arcturus instance other parameters that are required by the database
### creation script
###

echo ''

if [ "$createdb" -eq "0" ]
then
    echo '*** SKIPPING STAGE 3 BECAUSE YOU SPECIFIED -nocreatedb ***'
else
    echo STAGE 3 : CREATING THE ARCTURUS DATABASE

    ${SCRIPT_HOME}/create-new-organism.pl \
	-instance $instance \
	-organism $poolname \
	-node $node \
	-db $dbname \
	-ldapurl ${LDAP_URL} \
	-rootdn ${LDAP_ROOT_DN} \
	-ldapuser ${LDAP_USER} \
	-subdir $subdir \
	-description "$description" \
	-repository $reposdir \
	-projectsfile $projects

    RC=$?

    if [ $RC != 0 ]
	then
	echo Database creation script exited with return code $RC
	exit $RC
    fi
fi

###
### Import the CAF file
###

echo ''
echo STAGE 4 : IMPORTING THE ASSEMBLY CAF FILE

MAPFILE=${TMP}/contigs.map

${UTILS_DIR}/new-contig-loader \
    -instance $instance \
    -organism $poolname \
    -caf $caffile \
    -crn all \
    -project POOL \
    -mapfile $MAPFILE

${UTILS_DIR}/calculateconsensus \
    -instance $instance \
    -organism $poolname

###
### Sort the contig name to clone and contig name to ID files and join them
###

CONTIG_TO_CLONE_MAP_SORTED=${TMP}/${CONTIG_TO_CLONE_MAP}.sorted
MAPFILE_SORTED=${MAPFILE}.sorted
CONTIG_ID_TO_CLONE_MAP=${TMP}/Contigs_To_Clones.ByArcturusID

sort -b -k1 ${CONTIG_TO_CLONE_MAP} > ${CONTIG_TO_CLONE_MAP_SORTED}

sort -b -k1 ${MAPFILE} > ${MAPFILE_SORTED}

join -j 1 -o 1.2,2.2 ${MAPFILE_SORTED} ${CONTIG_TO_CLONE_MAP_SORTED} > ${CONTIG_ID_TO_CLONE_MAP}

echo ''
echo STAGE 5 : ASSIGNING CONTIGS TO CLONES

${UTILS_DIR}/assign-contigs-to-projects \
    -instance $instance \
    -organism $poolname \
    -mapfile ${CONTIG_ID_TO_CLONE_MAP}

echo ''
echo ALL DONE

exit 0
