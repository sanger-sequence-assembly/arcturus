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


use OracleReadFactory;

print STDERR "Creating OracleReadFactory ...\n";

$orf = new OracleReadFactory(@ARGV);

#$orf = new OracleReadFactory(schema => 'SHISTO',
#			     readnamelike => 'shisto8407%',
#			     aspedafter => '15-mar-04');

print STDERR "Done\n";

$nreads = 0;

while ($readname = $orf->getNextReadName()) {
    $read = $orf->getNextRead();
    $read->setReadName($readname);
    print STDERR "$readname\n";
    $read->dump();
    print STDERR "\n";
    $nreads++;
}

$orf->close();

print STDERR "Processed $nreads reads.\n";

exit(0);
