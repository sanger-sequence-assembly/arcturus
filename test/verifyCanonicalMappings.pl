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

use DBI;
use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex);

use DataSource;

my $instance;
my $organism;
my $limit;
my $verbose = 0;

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $limit         = shift @ARGV if ($nextword eq '-limit');

    $verbose       = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => { RaiseError => 1, PrintError => 1});

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select contig_id,seq_id,mapping_id,direction from MAPPING order by contig_id asc,seq_id asc";

$query .= " limit $limit" if defined($limit);

my $sth_get_old_mappings = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by rstart asc";

my $sth_get_old_segments = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select coffset,roffset,mapping_id,direction from SEQ2CONTIG where contig_id = ? and seq_id = ?";

my $sth_get_new_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select cstart,rstart,length from CANONICALSEGMENT where mapping_id = ? order by rstart asc";

my $sth_get_new_segments = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth_get_old_mappings->execute();

my $format = "%8d %8d %s\n";
my $format2 = "%8s %8d %8d\n";

while (my ($contig_id,$seq_id,$old_mapping_id,$old_direction) = $sth_get_old_mappings->fetchrow_array()) {
    $sth_get_new_mapping->execute($contig_id, $seq_id);

    my ($coffset,$roffset,$new_mapping_id,$new_direction) = $sth_get_new_mapping->fetchrow_array();

    unless (defined($new_mapping_id)) {
	printf $format, $contig_id, $seq_id, "NO_NEW_MAPPING";
	next;
    }

    my $forward = $old_direction eq 'Forward';

    if ($old_direction ne $new_direction) {
	printf $format, $contig_id, $seq_id, "DIRECTION_MISMATCH old=$old_direction new=$new_direction";
    }

    $sth_get_old_segments->execute($old_mapping_id);

    my @old_segments;

    while (my ($cstart,$rstart,$seglen) = $sth_get_old_segments->fetchrow_array()) {
	push @old_segments, [$cstart,$rstart,$seglen];
    }

    my @new_segments;

    $sth_get_new_segments->execute($new_mapping_id);

     while (my ($cstart,$rstart,$seglen) = $sth_get_new_segments->fetchrow_array()) {
	push @new_segments, [$cstart,$rstart,$seglen];
    }

    my $old_segment_count = scalar(@old_segments);
    my $new_segment_count = scalar(@new_segments);

    if ($old_segment_count != $new_segment_count) {
	printf $format, $contig_id, $seq_id, "SEGMENT_COUNT_MISMATCH old=$old_segment_count new=$new_segment_count";
	next;
    }

    if ($verbose) {
	printf $format, $contig_id, $seq_id, $old_direction;
    }

    my $bad_segments = 0;

    foreach my $old_segment (@old_segments) {
	my $new_segment = shift @new_segments;

	my ($old_cstart,$old_rstart,$old_length) = @{$old_segment};

	my ($old_cfinish,$old_rfinish);

	if ($forward) {
	    $old_rfinish = $old_rstart + $old_length - 1;
	    $old_cfinish = $old_cstart + $old_length - 1;
	} else {
	    $old_rfinish = $old_rstart;
	    $old_cfinish = $old_cstart;
	    $old_rstart = $old_rstart - $old_length + 1;
	    $old_cstart = $old_cstart + $old_length - 1;
	}

	my ($new_cstart,$new_rstart,$new_length) = @{$new_segment};

	my ($new_cfinish,$new_rfinish);

	if ($forward) {
	    $new_cstart += $coffset;
	    $new_rstart += $roffset;

	    $new_cfinish = $new_cstart + $new_length - 1;
	    $new_rfinish = $new_rstart + $new_length - 1;
	} else {
	    $new_cstart = $coffset - $new_cstart;
	    $new_rstart += $roffset;

	    $new_cfinish = $new_cstart - $new_length + 1;
	    $new_rfinish = $new_rstart + $new_length - 1;
	}

	my $bad_segment = ($old_rstart != $new_rstart) || ($old_rfinish != $new_rfinish) ||
	    ($old_cstart != $new_cstart) || ($old_cfinish != $new_cfinish) || ($old_length != $new_length);

	$bad_segments += 1 if $bad_segment;

	if ($verbose || $bad_segment) {
	    print $verbose ? "---------- SEGMENT ----------\n" : "BAD SEGMENT IN CONTIG $contig_id SEQUENCE $seq_id\n";
	    printf $format2, "rstart", $old_rstart, $new_rstart;
	    printf $format2, "rfinish", $old_rfinish, $new_rfinish;

	    printf $format2, "cstart", $old_cstart, $new_cstart;
	    printf $format2, "cfinish", $old_cfinish, $new_cfinish;
	    
	    printf $format2, "length", $old_length, $new_length;

	    print "\n";
	}
    }

    printf $format, $contig_id, $seq_id, ($bad_segments ? "BAD_SEGMENTS $bad_segments" : "OK");
}

$sth_get_old_mappings->finish();
$sth_get_old_segments->finish();

$sth_get_new_mapping->finish();
$sth_get_new_segments->finish();

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
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-limit\t\tShow only the first N contigs\n";
    print STDERR "-verbose\tProduce verbose output\n";
}
