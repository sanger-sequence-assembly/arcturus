#!/bin/csh -f

set SCRIPT_HOME=`dirname $0`

${SCRIPT_HOME}/random 398477 $1 | /bin/time ${SCRIPT_HOME}/tracefetch -instance linuxtest -organism TESTPKN > /dev/null
