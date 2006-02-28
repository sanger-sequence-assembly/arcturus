#!/bin/csh -f

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

${admintool} -host ${dbhost} -port 14641 -dumpdir ${dumpdir}/prod -auto \
    -gzip -safedumpdir ${safedumpdir}/prod -binlogdir ${binlogdir}/prod \
    -cp $copycmd -rsh $rshcmd $cleanup

${admintool} -host ${dbhost} -port 14642 -dumpdir ${dumpdir}/dev  -auto \
    -gzip -safedumpdir ${safedumpdir}/dev -binlogdir ${binlogdir}/dev \
    -cp $copycmd -rsh $rshcmd $cleanup

${admintool} -host ${dbhost} -port 14643 -flushlogs

${admintool} -host ${dbhost} -port 14644 -flushlogs
