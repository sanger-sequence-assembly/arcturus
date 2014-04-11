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

use RepositoryManager;

my $rm = new RepositoryManager();

print STDERR "TESTING CONVERSION FROM META DIRECTORY TO ABSOLUTE PATH\n";

my $tmpxxx = "/tmp/XXXXXXXX";

my @testsets = ([":PROJECT:/subdir", 'project' => 'EMU'],
		[":ASSEMBLY:/subdir", 'assembly' => 'EMU'],
		[":PROJECT:/subdir", 'assembly' => 'EMU'],
		[":ASSEMBLY:/subdir", 'project' => 'EMU'],
		["$tmpxxx/subdir", 'assembly' => 'EMU'],
		["$tmpxxx/subdir", 'project' => 'EMU'],
		[":EMU:/subdir"]
		);

my $newdir;

foreach my $args (@testsets) {
    print "\nTEST: ",join(", ", @{$args}),"\n";
    eval {
	$newdir = $rm->convertMetaDirectoryToAbsolutePath(@{$args});
	print $newdir,"\n";
    };

    if ($@) {
	print STDERR "\nERROR: " . $@ . "\n";
    }
}

print STDERR "\n\nTESTING CONVERSION FROM ABSOLUTE PATH TO META DIRECTORY\n\n";

my $emuhome = $rm->convertMetaDirectoryToAbsolutePath(':ASSEMBLY:', 'assembly' => 'EMU');

print STDERR "EMU home is $emuhome\n";

@testsets = (["$emuhome/subdir", 'project' => 'EMU'],
	     ["$emuhome/subdir", 'assembly' => 'EMU'],
	     ["$emuhome/subdir", 'assembly' => 'XXX'],
	     ["$emuhome/subdir", 'project' => 'XXX'],
	     ["$emuhome/subdir"],

	     ["$tmpxxx/subdir", 'project' => 'EMU'],
	     ["$tmpxxx/subdir", 'assembly' => 'EMU'],
	     ["$tmpxxx/subdir", 'assembly' => 'XXX'],
	     ["$tmpxxx/subdir", 'project' => 'XXX'],
	     ["$tmpxxx/subdir"],
	     );


foreach my $args (@testsets) {
    print "\nTEST: ",join(", ", @{$args}),"\n";
    eval {
	$newdir = $rm->convertAbsolutePathToMetaDirectory(@{$args});
	print $newdir,"\n";
    };

    if ($@) {
	print STDERR "\nERROR: " . $@ . "\n";
    }
}

exit 0;
