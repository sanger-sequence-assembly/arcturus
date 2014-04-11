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
use DataSource;
use Compress::Zlib;
use Digest::MD5 qw(md5);

my $instance;
my $organism;
my $project;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $project  = shift @ARGV if ($nextword eq '-project');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) && defined($project)) {
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

my $query = "select project_id from PROJECT where name = ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($project);

my ($project_id) = $sth->fetchrow_array();

$sth->finish();

unless (defined($project_id)) {
    $dbh->disconnect();
    print STDERR "Unknown project name: \"$project\"\n";
    exit(1);
}

$query = "select distinct RI.template_id" .
    " from ((CURRENTCONTIGS CC left join MAPPING M using(contig_id))" .
    " left join SEQ2READ using (seq_id)) left join READINFO RI using (read_id)" .
    " where CC.project_id = ? and RI.asped is not null and RI.template_id > 0";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($project_id);

my @subclones;

while (my ($template_id) = $sth->fetchrow_array()) {
    push @subclones, $template_id;
}

$sth->finish();

print STDERR "Found ", scalar(@subclones), " subclones\n";

$query = "select read_id,readname from READINFO where template_id = ?";

my $sth_reads_for_template = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select CC.contig_id from READINFO RI left join" .
    " (SEQ2READ SR, MAPPING M, CURRENTCONTIGS CC) using (read_id)" .
    " where RI.read_id = ? and SR.seq_id=M.seq_id and M.contig_id=CC.contig_id";

my $sth_contig_for_read_id = $dbh->prepare($query);
&db_die("prepare($query) failed");

foreach my $template_id (@subclones) {
    $sth_reads_for_template->execute($template_id);

    #print "Template $template_id\n";

    while (my ($read_id, $readname) = $sth_reads_for_template->fetchrow_array()) {
	$sth_contig_for_read_id->execute($read_id);

	my ($contig_id) = $sth_contig_for_read_id->fetchrow_array();

	#print "\t", $readname, "\t", (defined($contig_id) ? $contig_id : "FREE"), "\n"

	print $readname,"\n" unless defined($contig_id);
    }
}

$sth_reads_for_template->finish();
$sth_contig_for_read_id->finish();

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
    print STDERR "    -project\t\tName of project\n";
}
