#!/bin/csh -f

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


if ( $#argv < 2 ) then
  echo usage: $0 database readnamepattern
  exit 1
endif

set mysql_home=/nfs/pathsoft/external/linux/mysql5.0/bin

set db=$1
set proj=$2

${mysql_home}/mysql -h mcs1a -P 15001 -u arcturus --password=*** REMOVED *** \
  --skip-column-names --batch -e "call procfreereadsbynamelike('${proj}%')" $db
