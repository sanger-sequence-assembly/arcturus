#!/bin/csh -f

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
