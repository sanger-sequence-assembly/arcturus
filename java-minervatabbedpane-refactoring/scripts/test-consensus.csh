#!/bin/csh

set ARCTURUS=/nfs/team81/adh/workspace/arcturus

set JARS=${ARCTURUS}/lib/activation.jar:${ARCTURUS}/lib/javamail.jar:${ARCTURUS}/lib/jlfgr-1_0.jar:${ARCTURUS}/lib/jmxremote_optional.jar:${ARCTURUS}/lib/mysql-connector-java-5.1.6-bin.jar:${ARCTURUS}/lib/oracle-jdbc.jar:${ARCTURUS}/lib/postgresql-8.3-603.jdbc3.jar:${ARCTURUS}/lib/trilead-ssh2-build213.jar

java -Xmx2048M -classpath ${ARCTURUS}/classes:${JARS} \
  uk.ac.sanger.arcturus.test.CalculateConsensus $*
