#!/usr/local/bin/perl

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


use WrapMySQL;

$inifile = shift;

WrapMySQL->initFromFile($inifile);

print "Enumerating instances and roles ...\n\n";

@dbs = WrapMySQL->listInstances();

foreach $db (@dbs) {
    printf "%-15s", $db;
    @modes = WrapMySQL->listRolesForInstance($db);
    foreach $mode (@modes) {
	printf " %-8s", $mode;
    }
    print "\n";
}

$savefile = shift || "$inifile.new";

WrapMySQL->addInstance('TABBYCAT', {'host' => 'pcs3',
				    'port' => 14641,
				    'database' => 'dinah'});

WrapMySQL->addRoleToInstance('TABBYCAT', 'read', 'dinah', 'miaow');
WrapMySQL->addRoleToInstance('TABBYCAT', 'write', 'molly', 'yowl');

WrapMySQL->setDatabase('TABBYCAT', 'dinahmatic');

$tabbyport = WrapMySQL->getPort('TABBYCAT');

print "Port for TABBYCAT is $tabbyport\n";

($u, $p) = WrapMySQL->getRole('TABBYCAT', 'read');

print "Read role for TABBYCAT is $u,$p\n";

WrapMySQL->saveToFile($savefile);

exit(0);
