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

use Linux::Monitor;

my $pid = shift;

my $monitor = new Linux::Monitor($pid);

my $stathash = $monitor->getStat();

die "getStat returned null" unless defined($stathash);

print "STAT\n\n";

foreach my $key (sort keys %{$stathash}) {
    my $val = $stathash->{$key};
    printf "%-20s %s\n", $key, $val;
}

$stathash = $monitor->getStatm();

die "getStatm returned null" unless defined($stathash);

print "\nSTATM\n\n";

foreach my $key (sort keys %{$stathash}) {
    my $val = $stathash->{$key};
    printf "%-20s %s\n", $key, $val;
}

exit(0);
