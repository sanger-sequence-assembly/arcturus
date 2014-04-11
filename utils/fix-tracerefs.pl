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
# fix-tracerefs.pl
#
# This script fixes the trace archive reference for one or more
# reads in an Arcturus database.
#
# It can insert a missing trace archive reference or update an
# existing reference to a repository file.

use strict;

use DBI;
use DataSource;
use TraceServer;

my $verbose = 0;
my $instance;
my $organism;
my $fixwhat;
my $silent;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $fixwhat  = shift @ARGV if ($nextword eq '-fix');

    $verbose = 1 if ($nextword eq '-verbose');
    $silent  = 1 if ($nextword eq '-silent');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$fixwhat = 'missing' unless defined($fixwhat);

unless ($fixwhat eq 'missing' || $fixwhat eq 'filerefs') {
    print STDERR "\"$fixwhat\" is not a valid argument for -fix.\n\n";
    &showUsage();
    exit(1);
}

my $ts;
eval {
    $ts = TraceServer->new(TS_DIRECT, TS_READ_ONLY, "");
};
die if ($@);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless ($dbh) {
    print STDERR "Failed to open data source : $DBI::err ($DBI::errstr)\n\n";
}

my $condition;

if ($fixwhat eq 'missing') {
    $condition = "traceref is null";
} elsif ($fixwhat eq 'filerefs') {
    $condition = "traceref not regexp '^[[:digit:]]+\$'";
} else {
    $condition = "0==1";
}

my $query = "select READINFO.read_id,readname" .
    " from READINFO left join TRACEARCHIVE using(read_id)" .
    " where $condition";

print STDERR "query is $query\n" if $verbose;

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$query = "insert into TRACEARCHIVE(read_id,traceref) VALUES(?,?) " .
    "on duplicate key update traceref = values(traceref)";

my $sth_insert_or_update = $dbh->prepare($query);
&db_die("prepare($query) failed");

while (my ($readid,$readname) = $sth->fetchrow_array()) {
    printf STDERR "%8d %s\n", $readid, $readname if $verbose;

     my $read = $ts->get_read_by_name($readname);

    if (defined($read)) {
	my $seq = $read->get_sequence();

	if (defined($seq)) {
	    my $seqid = $seq->get_id();

	    if (defined($seqid)) {
		print STDERR "\tSequence ID is $seqid\n" if $verbose;

		if ($seqid =~ /^\d+$/) {
		    my $rc = $sth_insert_or_update->execute($readid, $seqid);
		    if ($rc == 1) {
			print STDERR "INSERTED $readname ($readid) --> $seqid\n";
		    } elsif ($rc == 2) {
			print STDERR "UPDATED  $readname ($readid) --> $seqid\n";
		    } else {
			print STDERR "RC=$rc   $readname ($readid) --> $seqid\n";
		    }
		}
	    }
	} else {
	    print STDERR "\t" if $verbose;
	    print STDERR "*** No sequence for $readname ***\n";
	}
    } else {
        next if $silent;
	print STDERR "\t" if $verbose;
	print STDERR "*** $readname is not in the Internal Trace Server ***\n";
    }

    print STDERR "\n" if $verbose;
}

$sth->finish();

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
    print STDERR "    -instance\t\t\tName of instance\n";
    print STDERR "    -organism\t\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -fix [missing | filerefs]\tWhat to fix (default: missing)\n";
}
