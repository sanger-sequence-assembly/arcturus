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
# contigs2fas
#
# This script extracts one or more contigs and generates a FASTA file

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

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

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select sequence from CONSENSUS where contig_id = ?";
print STDERR $query,"\n";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

while(my $line = <STDIN>) {
    chop($line);

    my ($contigid, $cstart, $cfinish) = $line =~ /\s*(\d+)\s+(\d+)\s+(\d+)/;

    $sth_sequence->execute($contigid);

    my ($compressedsequence) = $sth_sequence->fetchrow_array();

    $sth_sequence->finish();

    next unless defined($compressedsequence);

    my $sequence = uncompress($compressedsequence);

    my $seqlen = length($sequence);

    print STDERR "Got sequence for contig $contigid, length $seqlen\n";

    my $contigname = sprintf("contig%06d", $contigid);
    my $range;

    if (defined($cstart) && defined($cfinish)) {
	$range = "$cstart..$cfinish";

	print STDERR "\tRange: $range\n";

	my $revcomp = ($cstart > $cfinish) ? 1 : 0;

	($cstart, $cfinish) = ($cfinish, $cstart) if $revcomp;

	$cstart = 1 if ($cstart < 1);
	$cfinish = $seqlen if ($cfinish > $seqlen);
	    
	$sequence = substr($sequence, $cstart - 1, 1 + $cfinish - $cstart);

	if ($revcomp) {
	    $sequence = reverse($sequence);

	    $sequence =~ tr/ACGTacgt/TGCAtgca/;
	}

	print STDERR "\tSubsequence has length " . length($sequence) . "\n";
    }

    print ">$contigname";
    print " $range" if defined($range);
    print "\n";

    while (length($sequence) > 0) {
	print substr($sequence, 0, 50), "\n";
	$sequence = substr($sequence, 50);
    }
}

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "This script reads contig ID and optional start/end positions\n";
    print STDERR "from standard input, and writes FASTA-style sequences to standard\n";
    print STDERR "output.  If start/end are omitted, the entire contig is written.\n";
    print STDERR "If end < start, then the contig is reverse complemented before the\n";
    print STDERR "sub-sequence is written.\n";
}
