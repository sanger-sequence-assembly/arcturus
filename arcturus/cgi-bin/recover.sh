#!/usr/bin/csh

#echo "load bla bla disabled"

if ($?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH /usr/local/badger/distrib-1999.0/lib/alpha-binaries:${LD_LIBRARY_PATH}
else
    setenv LD_LIBRARY_PATH /usr/local/badger/distrib-1999.0/lib/alpha-binaries
endif

set task = $1

set data = $2

#/usr/local/badger/distrib-1999.0/alpha-bin/get_scf_field  /nfs/disk222/malaria/MAL4/0004/mal4Zh7.p1tSCF | grep -E '(dye|DYE)'

$task $data | grep -E '(dye|DYE)'

exit 0
