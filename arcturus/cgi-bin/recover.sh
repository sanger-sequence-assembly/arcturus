#!/usr/bin/csh

# echo $LD_LIBRARY_PATH

set task = $1

set data = $2

$task $data

exit 0
