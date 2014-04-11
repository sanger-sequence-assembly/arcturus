#!/bin/csh

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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
