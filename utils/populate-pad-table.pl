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

use DataSource;

my $nextword;
my $instance;
my $organism;
my $verbose = 0;

while ($nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

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

unless (defined($organism) && defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => { RaiseError => 1, PrintError => 1 });

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "set autocommit = 0";

$dbh->do($query);

$query = "select CS.contig_id,CP.pad_list_id,CS.sequence from" .
    " CONSENSUS CS left join CONTIGPADDING CP using(contig_id)" .
    " where CP.updated is null or CP.updated < CS.updated";

my $sth = $dbh->prepare($query);

$query = "delete from CONTIGPADDING where contig_id = ? and pad_list_id = ?";

my $sth_delete = $dbh->prepare($query);

$query = "insert into CONTIGPADDING(contig_id) values(?)";

my $sth_new_padding = $dbh->prepare($query);

$query = "insert into PAD(pad_list_id,position) values (?,?)";

my $sth_new_pad = $dbh->prepare($query);

$sth->execute();

my $all_pads = 0;
my $all_contigs = 0;
my $all_seqlen = 0;

while (my ($contig_id, $pad_list_id, $sequence) = $sth->fetchrow_array()) {
    $sequence = uncompress($sequence);

    $all_contigs++;
    $all_seqlen += length($sequence);

    my @pads = ();

    my $position = 0;

    while (1) {
	$position = index($sequence, '-', $position);

	last if $position < 0;

	$position++;

	push @pads, $position;
    }

    my $npads = scalar(@pads);

    $dbh->begin_work();

    if (defined($pad_list_id)) {
	$sth_delete->execute($contig_id, $pad_list_id);
    }

    $sth_new_padding->execute($contig_id);

    $pad_list_id = $dbh->{'mysql_insertid'};

    foreach $position (@pads) {
	$sth_new_pad->execute($pad_list_id, $position);
    }

    $dbh->commit();

    print STDERR "Found $npads pads in contig $contig_id\n" if ($verbose && $npads > 0);

    $all_pads += $npads;
}

$dbh->disconnect();

$sth->finish();
$sth_delete->finish();
$sth_new_padding->finish();
$sth_new_pad->finish();

print "Found $all_pads pads in $all_contigs contigs from $all_seqlen bp of consensus\n";

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
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
}
