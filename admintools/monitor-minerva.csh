#!/bin/csh

setenv ARCTURUS_HOME /software/arcturus/java

set cp=${JAVA_HOME}/lib/jconsole.jar:${JAVA_HOME}/lib/tools.jar:${ARCTURUS_HOME}/lib/jmxremote_optional.jar

${JAVA_HOME}/bin/jconsole -J-Djava.class.path=${cp} $*
