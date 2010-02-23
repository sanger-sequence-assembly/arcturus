#!/bin/bash

#########################################################################
###             These settings are Sanger-specific                    ###
#########################################################################
LDAP_URL="ldap://ldap.internal.sanger.ac.uk/"
LDAP_ROOT_DN="cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"
LDAP_USER="uid=${USER},ou=people,dc=sanger,dc=ac,dc=uk"

ARCTURUS_INSTANCE=test
MYSQL_INSTANCE=arct

#########################################################################
###             These settings are specific to ZGTC                   ###
#########################################################################
CLONE_LIST_FILE=CloneListWithDirectories.txt
CONTIG_TO_CLONE_MAP=Contigs_To_Clones

#########################################################################
###             Start of main script                                  ###
#########################################################################

if [ ! -e ${CLONE_LIST_FILE} ]
then
    echo There is no clone list file named ${CLONE_LIST_FILE} in this directory.
    exit 1
fi

projects=${CLONE_LIST_FILE}

if [ ! -e ${CONTIG_TO_CLONE_MAP} ]
then
    echo There is no contig-to-clone map file named ${CONTIG_TO_CLONE_MAP} in this directory.
    exit 1
fi

SCRIPT_HOME=`dirname $0`

PERL_LIB_DIR=${SCRIPT_HOME}/../lib

export PERL5LIB=${PERL_LIB_DIR}:${PERL5LIB}

instance=${ARCTURUS_INSTANCE}

echo -n "Enter pool name > "
read poolname

reposdir=`pwd`

if [ "x$reposdir" = "x" ]
then
    echo "Inferring repository location using pfind ..."
    reposdir=`pfind -q -u $organism`

    if [ "x$reposdir" = "x" ]
    then
	echo "Unable to proceed because $organism is not in the repository"
	exit 1
    fi
fi

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
echo "Projects file         $projects"
echo "----------------------------------------------------------"

echo -n "Is this correct? [yes/no] > "
read yorn

if [ "x$yorn" != "xyes" ]
then
    echo "Exiting without creating the new database"
    exit 1
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
