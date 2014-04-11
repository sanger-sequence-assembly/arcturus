#!/bin/csh -f

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


set SCRIPT_HOME=`dirname $0`
set UTILS_DIR=${SCRIPT_HOME}/../utils

set bsub="bsub"
set queue="-q pcs3q2"
set script=${UTILS_DIR}/readloader
set params="-instance test -organism SCHISTO -source Oracle -schema SHISTO -projid 1"

${bsub} ${queue} ${script} ${params} -minreadid       1 -maxreadid  200000

${bsub} ${queue} ${script} ${params} -minreadid  200001 -maxreadid  400000

${bsub} ${queue} ${script} ${params} -minreadid  400001 -maxreadid  600000

${bsub} ${queue} ${script} ${params} -minreadid  600001 -maxreadid  800000

${bsub} ${queue} ${script} ${params} -minreadid  800001 -maxreadid 1000000

${bsub} ${queue} ${script} ${params} -minreadid 1000001 -maxreadid 1200000

${bsub} ${queue} ${script} ${params} -minreadid 1200001 -maxreadid 1400000

${bsub} ${queue} ${script} ${params} -minreadid 1400001 -maxreadid 1600000

${bsub} ${queue} ${script} ${params} -minreadid 1600001 -maxreadid 1800000

${bsub} ${queue} ${script} ${params} -minreadid 1800001 -maxreadid 2000000

${bsub} ${queue} ${script} ${params} -minreadid 2000001
