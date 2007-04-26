# Shared csh code for Arcturus wrapper scripts

# Parse out the program name and base directory
set PROGNAME=`basename $0`
set ARCTURUS_HOME=`dirname $0`

# Specify the location of site-wide preferences and other files
set ARCTURUS_SITE_HOME=/nfs/pathsoft/arcturus

# This is the Arcturus root package name
set ARCTURUS_PACKAGE=uk.ac.sanger.arcturus

# This is the test package
set ARCTURUS_TEST_PACKAGE=${ARCTURUS_PACKAGE}.test

# Specify minimum heap size
if ( ! $?JAVA_HEAP_SIZE) then
    setenv JAVA_HEAP_SIZE -Xmx512M
endif

# Determine our operating system, and set JAVA_HOME accordingly.

if ( `uname -s` == 'OSF1' ) then
    setenv JAVA_HOME /nfs/pathsoft/external/bio-soft/java/usr/opt/java142
    setenv JAVA_HEAP_SIZE "-fast64 -Xmx4096M"
    set ARCTURUS_JAR=${ARCTURUS_HOME}/../arcturus-for-java1.4.jar
    echo Using the legacy \(Java 1.4\) version of arcturus.jar
else
    setenv JAVA_HOME /software/jdk1.6.0_01
    set ARCTURUS_JAR=${ARCTURUS_HOME}/../arcturus.jar
endif

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

set EXTRA_OPTS="${EXTRA_OPTS} -Darcturus.home=${ARCTURUS_HOME} -Darcturus.site.home=${ARCTURUS_SITE_HOME}"

# Add the JDBC and JNDI options to the run-time options
if ( $?JAVA_OPTS ) then
    # Append to user-specified options
    setenv JAVA_OPTS "${JAVA_OPTS} ${EXTRA_OPTS}"
else
    # No user-defined options, so set explicitly
    setenv JAVA_OPTS "${EXTRA_OPTS}"
endif
