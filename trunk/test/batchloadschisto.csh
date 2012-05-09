#!/bin/csh -f

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
