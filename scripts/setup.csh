# Shared csh code for Arcturus wrapper scripts

# Parse out the program name and base directory
set PROGNAME=`basename $0`
set ARCTURUS_HOME=`dirname $0`

# Specify the location of site-wide preferences and other files
set ARCTURUS_SITE_HOME=/nfs/pathsoft/arcturus

# Specify the directory in which JAR files can be found
set JAR_DIRECTORY=/nfs/pathsoft/minerva/jars

# This is the Arcturus JAR file
set ARCTURUS_JAR=${ARCTURUS_HOME}/../build/lib/arcturus.jar

# This is the Arcturus root package name
set ARCTURUS_PACKAGE=uk.ac.sanger.arcturus

# This is the test package
set ARCTURUS_TEST_PACKAGE=${ARCTURUS_PACKAGE}.test

# JAR file and driver name for MySQL Connector/J
#set CONNECTORJ_VER=3.0.14-stable
set CONNECTORJ_VER=3.1.8
set CONNECTORJ_JARS=${JAR_DIRECTORY}/mysql-connector-java-${CONNECTORJ_VER}-bin.jar
set CONNECTORJ_DRIVER=com.mysql.jdbc.Driver

# JAR file and driver name for the Oracle Type 4 (pure Java) JDBC driver
set ORACLE_JDBC_JARS=${JAR_DIRECTORY}/oracle-jdbc.jar
set ORACLE_JDBC_DRIVER=oracle.jdbc.driver.OracleDriver

# JAR files and factory name for JNDI
set JNDI_FS_JARS=${JAR_DIRECTORY}/fscontext.jar:${JAR_DIRECTORY}/fsproviderutil.jar
set JNDI_LDAP_JARS=${JAR_DIRECTORY}/jaas.jar:${JAR_DIRECTORY}/ldap.jar:${JAR_DIRECTORY}/ldapbp.jar:${JAR_DIRECTORY}/ldapsec.jar:${JAR_DIRECTORY}/providerutil.jar

set JNDI_JARS=${JNDI_FS_JARS}:${JNDI_LDAP_JARS}

#set DEFAULT_JNDI_FACTORY=com.sun.jndi.fscontext.RefFSContextFactory
#set DEFAULT_JNDI_URL=file:/nfs/pathsoft/minerva/jndi
set DEFAULT_JNDI_FACTORY=com.sun.jndi.ldap.LdapCtxFactory
#set DEFAULT_JNDI_URL="ldap://hoyle:1389/ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"
# Use the official Sanger Institute LDAP server
set DEFAULT_JNDI_URL="ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"

# Use the JNDI factory specified via ARCTURUS_JNDI_FACTORY, if it exists
# otherwise use a fallback
if ( $?ARCTURUS_JNDI_FACTORY ) then
    set JNDI_FACTORY=${ARCTURUS_JNDI_FACTORY}
else
    set JNDI_FACTORY=${DEFAULT_JNDI_FACTORY}
endif

# Use the JNDI URL specified via ARCTURUS_JNDI_URL, if one exists,
# otherwise use a fallback
if ( $?ARCTURUS_JNDI_URL ) then
    if ( -d ${ARCTURUS_JNDI_URL} ) then
      set JNDI_URL=file:${ARCTURUS_JNDI_URL}
    else
      set JNDI_URL=${ARCTURUS_JNDI_URL}
    endif
else
    set JNDI_URL=${DEFAULT_JNDI_URL}
endif

set JNDI_OPTS="-Djava.naming.factory.initial=$JNDI_FACTORY -Djava.naming.provider.url=$JNDI_URL"

# JAR file for Java look and feel graphics repository
set JLFGR_JARS=${JAR_DIRECTORY}/jlfgr-1_0.jar

# Append any non-Arcturus JAR files to this list
set EXTRAJARS=${CONNECTORJ_JARS}:${ORACLE_JDBC_JARS}:${JNDI_JARS}:${JLFGR_JARS}

# Add the JAR files to the CLASSPATH environment variable
if ( $?CLASSPATH ) then
    setenv CLASSPATH ${CLASSPATH}:${EXTRAJARS}:${ARCTURUS_JAR}
else
    setenv CLASSPATH ${EXTRAJARS}:${ARCTURUS_JAR}
endif

# Specify minimum heap size
if ( ! $?JAVA_HEAP_SIZE) then
    setenv JAVA_HEAP_SIZE -Xmx256M
endif

# Determine our operating system, and alter the path to Java if we're running
# on an Alpha system.

if ( `uname -s` == 'OSF1' ) then
    setenv PATH /nfs/pathsoft/external/bio-soft/java/usr/opt/java142/bin:${PATH}
    setenv JAVA_HEAP_SIZE "-fast64 -Xmx4096M"
endif

# Specify Arcturus default parameters
set ARCTURUS_DEFAULTS="-Darcturus.default.instance=cn=dev,cn=jdbc -Darcturus.default.algorithm=uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus"

set ARCTURUS_JNDI_PEOPLE_URL="ldap://ldap.internal.sanger.ac.uk/ou=people,dc=sanger,dc=ac,dc=uk"

set ARCTURUS_DEFAULTS="${ARCTURUS_DEFAULTS} -Darcturus.naming.people.url=${ARCTURUS_JNDI_PEOPLE_URL}"

# Specify the additional run-time options for Java
set EXTRA_OPTS="-Djdbc.drivers=${CONNECTORJ_DRIVER}:${ORACLE_JDBC_DRIVER} ${JNDI_OPTS} ${ARCTURUS_DEFAULTS} ${JAVA_HEAP_SIZE}"

# Specify local host name parameter
set HOSTNAME=`hostname -s`
set EXTRA_OPTS="${EXTRA_OPTS} -Dhost.name=${HOSTNAME}"

# Create .arcturus directory if it does not exist
if (! -d ${HOME}/.arcturus ) then
    mkdir ${HOME}/.arcturus
endif

# Create logging directory if ti does not exist
if (! -d ${HOME}/.arcturus/logging ) then
    mkdir ${HOME}/.arcturus/logging
endif

if ( $?LOGGING_PROPERTIES ) then
    echo Configuring logging from ${LOGGING_PROPERTIES}
    set EXTRA_OPTS="${EXTRA_OPTS} -Djava.util.logging.config.file=${LOGGING_PROPERTIES}"
else
    if ( -f ${ARCTURUS_HOME}/logging.properties ) then
	echo Configuring logging from ${ARCTURUS_HOME}/logging.properties
	set EXTRA_OPTS="${EXTRA_OPTS} -Djava.util.logging.config.file=${ARCTURUS_HOME}/logging.properties"
    else
	echo No logging configuration file specified
    endif
endif

set EXTRA_OPTS="${EXTRA_OPTS} -Darcturus.home=${ARCTURUS_HOME} -Darcturus.site.home=${ARCTURUS_SITE_HOME}"

# Add the JDBC and JNDI options to the run-time options
if ( $?JAVA_OPTS ) then
    # Append to user-specified options
    setenv JAVA_OPTS "${JAVA_OPTS} ${EXTRA_OPTS}"
else
    # No user-defined options, so set explicitly
    setenv JAVA_OPTS "${EXTRA_OPTS}"
endif
