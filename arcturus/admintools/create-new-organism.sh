#!/bin/bash

LDAP_URL="ldap://ldap.internal.sanger.ac.uk/"
LDAP_ROOT_DN="cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"
LDAP_USER="uid=${USER},ou=people,dc=sanger,dc=ac,dc=uk"

SCRIPT_HOME=`dirname $0`

PERL_LIB_DIR=${SCRIPT_HOME}/../lib

export PERL5LIB=${PERL_LIB_DIR}:${PERL5LIB}

echo -n "Enter Arcturus instance [pathogen,test] > "
read instance

echo -n "Enter organism name > "
read organism

echo -n "Enter repository location (hit RETURN to infer from pfind) > "
read reposdir

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

echo -n "Enter MySQL instance [arcp,hlmp,arct] > "
read node

echo -n "Enter template database name > "
read template

echo -n "Enter Group/Genus (e.g. Bacteria/Clostridium) > "
read subdir

echo -n "Enter description (e.g. Clostridium difficile strain CDSM) > "
read description

echo "----- Summary of input -----------------------------------"
echo "Arcturus instance     $instance"
echo "Organism name         $organism"
echo "Repository location   $reposdir"
echo "MySQL instance        $node"
echo "Template database     $template"
echo "LDAP sub-directory    $subdir"
echo "Description           $description"
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
    -organism $organism \
    -node $node \
    -template $template \
    -ldapurl ${LDAP_URL} \
    -rootdn ${LDAP_ROOT_DN} \
    -ldapuser ${LDAP_USER} \
    -subdir $subdir \
    -description "$description" \
    -repository $reposdir
