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

use ArcturusDatabase;

my $nextword;
my $instance;
my $organism;
my $name;
my $value;

while ($nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $name          = shift @ARGV if ($nextword eq '-name');
    $value         = shift @ARGV if ($nextword eq '-value');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

if (defined($value) && !defined($name)) {
    &showUsage("-value parameter cannot be used without -name");
    exit(2);
}

my $adb = new ArcturusDatabase(-instance => $instance, -organism => $organism);

die "Failed to create an ArcturusDatabase object" unless defined($adb);

if (defined($name)) {
    if (defined($value)) {
	my $rc = $adb->putMetadata($name, $value);

	print "Updated $rc rows of metadata\n";
    } else {
	$value = $adb->getMetadata($name);
	
	print "metadata($name) is ", (defined($value) ? $value : "UNDEFINED"), "\n";
    }
} else {
    $value = $adb->getMetadata();

    foreach my $key (sort keys(%{$value})) {
	print $key," --> ",$value->{$key},"\n";
    }
}

$adb->disconnect();

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-name\t\tName of metadata to get/set\n";
    print STDERR "-value\t\tValue of metadata to set\n";
}
