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


use strict;

use FileHandle;
use ReadFactory::TraceServerReadFactory;

print STDERR "Creating TraceServerReadFactory ...\n";

my $factory = new TraceServerReadFactory(@ARGV);

print STDERR "Done\n";

my $nreads = 0;

while (my $readname = $factory->getNextReadName()) {
    my $read = $factory->getNextRead();
    print STDERR "$readname\n";
    $read->writeToCaf(*STDOUT);
    print STDERR "\n";
    $nreads++;
}

print STDERR "Processed $nreads reads.\n";

exit(0);
