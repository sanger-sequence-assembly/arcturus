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
# tracefetch.pl
#
# This script fetches traces at random from a MySQL database

use strict;

use DBI;
use DataSource;
use FileHandle;
use Compress::Zlib;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $store;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $store = 1 if ($nextword eq '-store');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance)) {
    print STDERR "*** ERROR *** One or more mandatory parameters are missing.\n\n";
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

my $query = "select readname,trace from READINFO left join TRACE using(read_id) where READINFO.read_id = ?";

my $sth_trace_by_id = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $query = "select READINFO.read_id,trace from READINFO left join TRACE using(read_id) where readname = ?";

my $sth_trace_by_name = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $readname;
my $readid;
my $trace;

while (my $line = <STDIN>) {
    my ($name) = $line =~ /\s*(\S+)/;

    undef $trace;

    if ($name =~ /^\d+$/) {
	$readid = $name;

	$sth_trace_by_id->execute($readid);
	&db_carp("executing trace query for read_id $readid");

	($readname, $trace) = $sth_trace_by_id->fetchrow_array();
	&db_carp("fetching trace for read_id $readid");
    } else {
	$readname = $name;

	$sth_trace_by_name->execute($readname);
	&db_carp("executing trace query for readname $readname");

	($readid, $trace) = $sth_trace_by_name->fetchrow_array();
	&db_carp("fetching trace for readname $readname");
    }

    if (defined($trace)) {
	$trace = uncompress($trace);
	my $tracelen = length($trace);
	printf "%-30s %8d %6d\n", $readname, $readid, $tracelen;

	if ($store && open(FILE, ">$readname" . ".scf")) {
	    binmode FILE;
	    print FILE $trace;
	    close FILE;
	}
    }
}

$sth_trace_by_id->finish();
$sth_trace_by_name->finish();

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
}
