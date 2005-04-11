# Shared csh code for Arcturus wrapper scripts

# Parse out the program name and base directory
set PROGNAME=`basename $0`
set ARCTURUS_HOME=`dirname $0`

# Specify the directory in which JAR files can be found
set JAR_DIRECTORY=/nfs/pathsoft/minerva/jars

# This is the Arcturus JAR file
set ARCTURUS_JAR=${ARCTURUS_HOME}/../build/lib/arcturus.jar

# This is the test class directory
set ARCTURUS_TEST_CLASSES=${ARCTURUS_HOME}/../build/test

# JAR file and driver name for MySQL Connector/J
set CONNECTORJ_VER=3.0.14-stable
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
set DEFAULT_JNDI_URL="ldap://ldap.internal.sanger.ac.uk/ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"

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

# Set up the Apache Project's Java logging framework
set LOG4J_VERSION=1.2.9
set LOG4J_JARS=${JAR_DIRECTORY}/log4j-${LOG4J_VERSION}.jar

#set LOG4J_CONFIGURATION=${ARCTURUS_HOME}/log4j.properties

# Append any non-Arcturus JAR files to this list
set EXTRAJARS=${CONNECTORJ_JARS}:${ORACLE_JDBC_JARS}:${JNDI_JARS}:${JLFGR_JARS}:${LOG4J_JARS}

# Add the JAR files to the CLASSPATH environment variable
if ( $?CLASSPATH ) then
    setenv CLASSPATH ${CLASSPATH}:${EXTRAJARS}:${ARCTURUS_TEST_CLASSES}:${ARCTURUS_JAR}
else
    setenv CLASSPATH ${EXTRAJARS}:${ARCTURUS_TEST_CLASSES}:${ARCTURUS_JAR}
endif

# Specify minimum heap size
if ( ! $?JAVA_HEAP_SIZE) then
    setenv JAVA_HEAP_SIZE -Xmx256M
endif

# Specify Arcturus default parameters
set ARCTURUS_DEFAULTS="-Darcturus.default.instance=cn=dev,cn=jdbc -Darcturus.default.algorithm=arcturus.test.Gap4BayesianConsensus"

# Specify the additional run-time options for Java
set EXTRA_OPTS="-Djdbc.drivers=${CONNECTORJ_DRIVER}:${ORACLE_JDBC_DRIVER} ${JNDI_OPTS} ${ARCTURUS_DEFAULTS} ${JAVA_HEAP_SIZE}"

if ( $?LOG4J_CONFIGURATION ) then
    echo Configuring log4j from ${LOG4J_CONFIGURATION}
    set EXTRA_OPTS="${EXTRA_OPTS} -Dlog4j.configuration=${LOG4J_CONFIGURATION}"
endif

# Add the JDBC and JNDI options to the run-time options
if ( $?JAVA_OPTS ) then
    # Append to user-specified options
    setenv JAVA_OPTS "${JAVA_OPTS} ${EXTRA_OPTS}"
else
    # No user-defined options, so set explicitly
    setenv JAVA_OPTS "${EXTRA_OPTS}"
endif
