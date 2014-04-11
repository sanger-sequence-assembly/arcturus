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
# read-repeat-tag-loader.pl
#
# This script loads read repeat tags which have been found using cross_match

use DBI;
use FileHandle;
use DataSource;

use strict;

my $verbose = 0;
my $instance;
my $organism;
my $tagtable = 'READTAG';

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $tagtable = shift @ARGV if ($nextword eq '-tagtable');

    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
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

my $query = "select tag_seq_id from TAGSEQUENCE where tagseqname = ?";

my $sth_find_tagseq = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into TAGSEQUENCE(tagseqname) VALUES (?)";

my $sth_store_tagseq = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into $tagtable(seq_id,tagtype,tag_seq_id,pstart,pfinal,strand,comment) VALUES(?,?,?,?,?,?,?)";

my $sth_store_readtag = $dbh->prepare($query);
&db_die("prepare($query) failed");

my %tagseqs;
my $rc;

while (my $line = <STDIN>) {
    chop($line);

    my ($score,$frac,$enda,$seqname,$seqlen,$seqstart,$seqend,$endb,$repname,$replen,$repstart,$repend) =
	$line =~ /\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/;

    my $clipping;

    ($seqname, $clipping) = split(/:/, $seqname);

    my ($seqid) = $seqname =~ /[^\d]+(\d+)/;

    my $offset = 0;

    if (defined($clipping)) {
	my $junk;
	($offset,$junk) = split(/\-/, $clipping);
	$offset -= 1;
    }

    $seqstart += $offset;
    $seqend += $offset;

    my $strand = ($repstart < $repend) ? 'F' : 'R';

    my $tagseqid = $tagseqs{$repname};

    if (!defined($tagseqid)) {
	print STDERR "Looking up \"$repname\" in TAGSEQUENCE table" if $verbose;

	$sth_find_tagseq->execute($repname);
	($tagseqid) = $sth_find_tagseq->fetchrow_array();

	if (defined($tagseqid)) {
	    print STDERR " --> $tagseqid\n" if $verbose;
	} else {
	    print STDERR "\n    Not found, inserting ..." if $verbose;
	    $rc = $sth_store_tagseq->execute($repname);
	    &db_carp("Inserting $repname");

	    $tagseqid = $dbh->{'mysql_insertid'} if ($rc == 1);

	    print STDERR ($rc == 1) ? " $tagseqid\n" : " failed\n";
	}

	$tagseqs{$repname} = $tagseqid if defined($tagseqid);

	$tagseqid = 0 unless defined($tagseqid);
    }

    my $comment = "$repname from $repstart to $repend";

    $rc = $sth_store_readtag->execute($seqid, 'REPT', $tagseqid, $seqstart, $seqend, $strand, $comment);
    &db_carp("Inserting $seqid, 'REPT', $tagseqid, $seqstart, $seqend, $strand, $comment");
}

$sth_find_tagseq->finish();
$sth_store_tagseq->finish();
$sth_store_readtag->finish();

$dbh->disconnect();

exit(0);


sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub db_carp {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\tVerbose output\n";
}
