#!/usr/bin/csh

if ($?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH /usr/local/badger/distrib-1999.0/lib/alpha-binaries:${LD_LIBRARY_PATH}
else
    setenv LD_LIBRARY_PATH /usr/local/badger/distrib-1999.0/lib/alpha-binaries
endif

set task = $1

set data = $2

$task $data | grep -E '(dye|DYE)'

#set yuk = `$task $data | grep -E '(dye|DYE)'`
#echo "$yuk[1]"

exit 0
