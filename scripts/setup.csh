# Shared csh code for Arcturus wrapper scripts

# Parse out the program name and base directory
set PROGNAME=`basename $0`
set ARCTURUS_HOME=`dirname $0`

# Specify the location of site-wide preferences and other files
set ARCTURUS_SITE_HOME=/nfs/pathsoft/arcturus

# This is the Arcturus JAR file
set ARCTURUS_JAR=${ARCTURUS_HOME}/../arcturus.jar

# This is the Arcturus root package name
set ARCTURUS_PACKAGE=uk.ac.sanger.arcturus

# This is the test package
set ARCTURUS_TEST_PACKAGE=${ARCTURUS_PACKAGE}.test

# Add the JAR files to the CLASSPATH environment variable
if ( $?CLASSPATH ) then
    setenv CLASSPATH ${CLASSPATH}:${ARCTURUS_JAR}
else
    setenv CLASSPATH ${ARCTURUS_JAR}
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

# Specify the additional run-time options for Java
set EXTRA_OPTS="${JAVA_HEAP_SIZE}"

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
