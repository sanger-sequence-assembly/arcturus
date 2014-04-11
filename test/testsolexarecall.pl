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

#
# testsolexarecall.pl
#
# This script extracts one or more Solexa reads

use strict;

use DBI;
use DataSource;

my $instance;
my $organism;
my $fetchall = 0;
my $lowmem = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $fetchall = 1 if ($nextword eq '-fetchall');
    $lowmem = 1 if ($nextword eq '-lowmem');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

die "Failed to create database object" unless defined($dbh);

if ($fetchall) {
    &fetchAll($dbh, $lowmem);
} else {
    &fetchNamedReads($dbh);
}

$dbh->disconnect();

exit(0);

sub fetchAll {
    my $dbh = shift;
    my $lowmem = shift;

    my $ndone = 0;

    printf STDERR "%8d", $ndone;
    my $format = "\010\010\010\010\010\010\010\010%8d";

    my $sth = $dbh->prepare("select id,name,sequence,quality from SOLEXA");

    $sth->{mysql_use_result} = 1 if $lowmem;

    $sth->execute();

    while (my ($readid,$name,$sequence,$quality) = $sth->fetchrow_array()) {
	$ndone++;
	printf STDERR $format, $ndone if (($ndone % 5) == 0);
    }

    print STDERR "\n";

    $sth->finish();
}

sub fetchNamedReads {
    my $dbh = shift;

    my $ndone = 0;

    printf STDERR "%8d", $ndone;
    my $format = "\010\010\010\010\010\010\010\010%8d";

    my $sth = $dbh->prepare("select id,sequence,quality from SOLEXA where name = ?");

    while (my $line = <STDIN>) {
	my ($readname) = $line =~ /^\s*(\S+)\s*/;

	next unless defined($readname);

	$sth->execute($readname);

	while (my ($readid,$sequence,$quality) = $sth->fetchrow_array()) {
	    $ndone++;
	    printf STDERR $format, $ndone if (($ndone % 5) == 0);
	}
    }

    print STDERR "\n";

    $sth->finish();
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -fetchall\t\tFetch all reads\n";
    print STDERR "    -lowmem\t\tUse techniques to reduce memory usage\n";
}
