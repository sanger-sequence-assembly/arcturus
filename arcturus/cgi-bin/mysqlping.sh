#!/bin/sh

host=${1:-localhost}
port=${2:-3306}

/nfs/pathsoft/external/mysql-3.23.49/bin/mysqladmin -h $host -P $port -u ping ping >/dev/null 2>&1

exit $?
