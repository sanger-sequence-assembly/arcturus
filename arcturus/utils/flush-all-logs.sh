#!/bin/csh -f

admintool=/nfs/pathsoft/external/mysql-3.23.51/bin/mysqladmin

${admintool} --defaults-file=/nfs/pathdb/arcturus/init.d/flushlogs.
cnf -h babel -P 14643 flush-logs
