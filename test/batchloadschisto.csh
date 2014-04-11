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
set script=${UTILS_DIR}/readloader
set params="-instance test -organism SCHISTO -source Oracle -schema SHISTO -projid 1"
set queue="-q pcs3q2"

${bsub} ${queue} ${script} ${params} -minreadid       1 -maxreadid  500000

${bsub} ${queue} ${script} ${params} -minreadid  500001 -maxreadid 1000000

${bsub} ${queue} ${script} ${params} -minreadid 1000001 -maxreadid 1500000

${bsub} ${queue} ${script} ${params} -minreadid 1500001
