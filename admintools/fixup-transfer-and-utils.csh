#!/bin/csh

if (! -d transfer ) then
    echo There is no transfer directory
    exit 1
endif

if (! -d utils ) then
    echo There is no utils directory
    exit 1
endif

echo "Fixing up the transfer directory"

echo "    Re-naming transfer to transfer.ejz"

mv transfer transfer.ejz

echo "    Creating a new transfer directory"

mkdir transfer

echo "    Copying the contents of the old directory to the new one"

cp transfer.ejz/* transfer/

echo "    Changing the access permissions on the new directory"

chmod -R 0775 transfer

echo "    Changing the group owner to pathdev"

chgrp -R pathdev transfer

echo "Fixing up the utils directory"

echo "    Re-naming utils to utils.ejz"

mv utils utils.ejz

echo "    Creating a new utils directory"

mkdir utils

echo "    Copying the contents of the old directory to the new one"

cd utils.ejz

foreach file (*)
    sed -e 's#team81/ejz/arcturus/dev#pathsoft/arcturus#g' $file > ../utils/$file
end

cd ..

echo "    Changing the access permissions on the new directory"

chmod -R 0775 utils

echo "    Changing the group owner to pathdev"

chgrp -R pathdev utils
