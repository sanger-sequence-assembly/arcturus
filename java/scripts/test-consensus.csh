#!/bin/csh

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


set ARCTURUS=/nfs/team81/adh/workspace/arcturus

set JARS=${ARCTURUS}/lib/activation.jar:${ARCTURUS}/lib/javamail.jar:${ARCTURUS}/lib/jlfgr-1_0.jar:${ARCTURUS}/lib/jmxremote_optional.jar:${ARCTURUS}/lib/mysql-connector-java-5.1.6-bin.jar:${ARCTURUS}/lib/oracle-jdbc.jar:${ARCTURUS}/lib/postgresql-8.3-603.jdbc3.jar:${ARCTURUS}/lib/trilead-ssh2-build213.jar

java -Xmx2048M -classpath ${ARCTURUS}/classes:${JARS} \
  uk.ac.sanger.arcturus.test.CalculateConsensus $*
