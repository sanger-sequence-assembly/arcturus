#!/bin/bash

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

The user can specify the Arcturus alias which is to be given to the new
database as a command line argument.  If no argument is present, the script
will prompt the user to enter one.

It then carries out four steps:

1. Find the repository directories corresponding to the clones listed in 
   CloneList.txt using pfind

2. Create the Arcturus MySQL database and LDAP entry for the new database

3. Import the assembly from the CAF file

4. Re-assign the contigs listed in Contigs_To_Clones to their respective
   projects

The following environment variables may be set before running the script:

ARCTURUS_INSTANCE

ARCTURUS_MYSQL_INSTANCE

ARCTURUS_LDAP_USERNAME

ARCTURUS_LDAP_PASSWORD

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

INSTANCE=${ARCTURUS_INSTANCE-pathogen}
MYSQL_INSTANCE=${ARCTURUS_MYSQL_INSTANCE-arcp}

#########################################################################
###             These settings are specific to ZGTC                   ###
#########################################################################
CLONE_LIST_FILE=CloneList.txt
CONTIG_TO_CLONE_MAP=Contigs_To_Clones

#########################################################################
###             Start of main script                                  ###
#########################################################################

if [ $# -lt 1 ]
then
    echo -n "Enter pool name > "
    read poolname
else
    if [ $1 == "-help" ]
    then
	showHelp
	exit 0
    else
	poolname=$1
	echo Got pool name $poolname from command-line arguments
    fi
fi

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
echo STAGE 1 : FINDING DIRECTORIES FOR PROJECTS

CLONE_LIST_WITH_DIRS=${TMP}/CloneListWithDirectories.txt

for clone in `cat ${CLONE_LIST_FILE}`
do
  echo $clone,`pfind -q -u $clone` >> ${CLONE_LIST_WITH_DIRS}
done

for clone in BIN POOL
do
  echo $clone,`pwd` >> ${CLONE_LIST_WITH_DIRS}
done

projects=${CLONE_LIST_WITH_DIRS}

###
### Define the Arcturus instance other parameters that are required by the database
### creation script
###

echo ''
echo STAGE 2 : CREATING THE ARCTURUS DATABASE

instance=${INSTANCE}

reposdir=`pwd`

node=${MYSQL_INSTANCE}

dbname=$poolname

subdir=Zebrafish/Pools

description="Zebrafish pooled BAC assembly ${poolname}"

echo "----- Summary of input -----------------------------------"
echo "Arcturus instance     $instance"
echo "Pool name             $poolname"
echo "Repository location   $reposdir"
echo "MySQL instance        $node"
echo "MySQL database        $dbname"
echo "LDAP sub-directory    $subdir"
echo "Description           $description"
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
    fi
fi

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

###
### Import the CAF file
###

echo ''
echo STAGE 3 : IMPORTING THE ASSEMBLY CAF FILE

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
echo STAGE 4 : ASSIGNING CONTIGS TO CLONES

${UTILS_DIR}/assign-contigs-to-projects \
    -instance $instance \
    -organism $poolname \
    -mapfile ${CONTIG_ID_TO_CLONE_MAP}

echo ''
echo ALL DONE

exit 0
