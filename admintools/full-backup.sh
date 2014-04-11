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


set dbhost=pcs3
set arcturushome=/nfs/arcturus2
set otherarcturushome=babel:/nfs/arcturus1

set admintool=${arcturushome}/init.d/backup-and-flush-logs.pl
set dumpdir=${arcturushome}/mysql/backup/${dbhost}

set binlogdir=${arcturushome}/mysql/binlog

set safedumpdir=${otherarcturushome}/mysql/backup/${dbhost}

set copycmd=/usr/bin/rcp
set rshcmd=/usr/bin/rsh

set cleanup="-cleanup"

${admintool} -host ${dbhost} -port 14641 -dumpdir ${dumpdir}/prod \
    -dumpfiles -flushlogs \
    -gzip -safedumpdir ${safedumpdir}/prod -binlogdir ${binlogdir}/prod \
    -cp $copycmd -rsh $rshcmd $cleanup

${admintool} -host ${dbhost} -port 14642 -dumpdir ${dumpdir}/dev  -auto \
    -gzip -safedumpdir ${safedumpdir}/dev -binlogdir ${binlogdir}/dev \
    -cp $copycmd -rsh $rshcmd $cleanup

${admintool} -host ${dbhost} -port 14643 -flushlogs

${admintool} -host ${dbhost} -port 14644 -flushlogs
