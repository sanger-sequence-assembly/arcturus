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

my $instance = 'dev';
my $organism = 'EIMER';
my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

my $dbh = $adb->getConnection();

my $query = "select readname from SEQ2READ left join READINFO using(read_id) where seq_id = ?";

my $sth_readname = $dbh->prepare($query);

&db_die("prepare($query) failed");

while (my $line = <STDIN>) {
    chop($line);

    my ($fosmidname, $rlength, $rstart, $rfinish, $ctgid, $clength, $cstart, $cfinish) = split(/\s+/, $line);

    $ctgid =~ s/CONTIG//;

    my ($filename, $junk) = glob("????/$fosmidname");

    print STDERR "Unable to find experiment file for $fosmidname" unless $filename;

    next unless $filename;

    $query = "select seq_id,cstart,cfinish,abs(cstart-$cstart)+abs(cfinish-$cfinish) as delta " .
	" from MAPPING where contig_id = $ctgid and ((cfinish <= $cfinish and cfinish >= $cstart) " .
	    " or (cstart <= $cfinish and cstart >= $cstart)) order by delta asc limit 1";

    my $sth = $dbh->prepare($query);

    &db_die("prepare($query) failed");

    $sth->execute();

    &db_die("execute($query) failed");

    my ($seqid, $pstart, $pfinish, $delta) = $sth->fetchrow_array();

    $sth->finish();

    next unless defined($seqid);

    $sth_readname->execute($seqid);

    my ($readname) = $sth_readname->fetchrow_array();

    my $sense = ($rstart < $rfinish) ? '+' : '-';

    printf "%-20s %-20s %1s %8d %8d %8d %8d %4d\n", $fosmidname, $readname, $sense, $cstart, $cfinish, $pstart, $pfinish, $delta;

    open(INPUT, "< $filename");

    open(OUTPUT, "> fosmidends/$fosmidname");

    while (my $expline = <INPUT>) {
	if ($expline =~ /^SI\s+/) {
	    $expline = "SI   30000..40000\n";
	}

	print OUTPUT $expline;
    }

    close(INPUT);

    print OUTPUT "AP $readname $sense ", $cstart-$pstart, " ", 3*$delta, "\n";

    close(OUTPUT);
}

$sth_readname->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    return unless $DBI::err;

    my $msg = shift;

    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}
