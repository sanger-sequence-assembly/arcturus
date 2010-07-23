# Shared csh code for Arcturus wrapper scripts

# Parse out the program name and base directory
set PROGNAME=`basename $0`
set ARCTURUS_HOME=`dirname $0`

# This is the Arcturus root package name
set ARCTURUS_PACKAGE=uk.ac.sanger.arcturus

# This is the utils package
set ARCTURUS_UTILS_PACKAGE=${ARCTURUS_PACKAGE}.utils

# This is the apps package
set ARCTURUS_APPS_PACKAGE=${ARCTURUS_PACKAGE}.apps

# This is the test package
set ARCTURUS_TEST_PACKAGE=${ARCTURUS_PACKAGE}.test

# Set default heap size

if ( `uname -m` == 'x86_64' && $PROGNAME != 'minerva' && $PROGNAME != 'minerva2' ) then
    set DEFAULT_JAVA_HEAP_SIZE=-Xmx4096M
else
    set DEFAULT_JAVA_HEAP_SIZE=-Xmx512M
endif

# Specify minimum heap size
if ( ! $?JAVA_HEAP_SIZE) then
    setenv JAVA_HEAP_SIZE $DEFAULT_JAVA_HEAP_SIZE
endif

# Set JAVA_HOME and location of Arcturus JAR file

setenv JAVA_HOME /software/jdk1.6.0_13
set ARCTURUS_JAR=${ARCTURUS_HOME}/../arcturus.jar

echo Using Java in $JAVA_HOME 
echo Arcturus JAR file is $ARCTURUS_JAR

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

set EXTRA_OPTS="${EXTRA_OPTS} -Darcturus.jar=${ARCTURUS_JAR}"

# Add the JDBC and JNDI options to the run-time options
if ( $?JAVA_OPTS ) then
    # Append to user-specified options
    setenv JAVA_OPTS "${JAVA_OPTS} ${EXTRA_OPTS}"
else
    # No user-defined options, so set explicitly
    setenv JAVA_OPTS "${EXTRA_OPTS}"
endif
