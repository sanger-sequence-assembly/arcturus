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

# print-fake-reads-WashU.pl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;
my $single = 0;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-db') {
	$dbname = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
    } elsif ($nextword eq '-single') {
	$single = shift @ARGV;
    } elsif ($nextword eq '-help') {
	&showHelp();
	exit(0);
    } else {
	die "Unknown option: $nextword";
    }
}

$username = $ENV{'MYSQL_USERNAME'} unless defined($username);
$password = $ENV{'MYSQL_PASSWORD'} unless defined($password);

unless (defined($host) && defined($port) && defined($dbname) &&
	defined($username) && defined($password)) {
    &showHelp("One or more mandatory options were missing");
    exit(1);
}

my $url = "DBI:mysql:$dbname;host=$host;port=$port";

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 0});

my $query = "";
if ($single > 0) {
# single contig query useful to check data
	$query = "select r.readname, min(t.rstart), sum(t.length),  r.strand, c.contig_id, min(t.cstart) from SEQUENCE s, SEQ2READ  q, MAPPING m, SEGMENT t, READINFO r, CURRENTCONTIGS c where  m.mapping_id = t.mapping_id and m.seq_id = q.seq_id and s.seq_id = q.seq_id and q.read_id = r.read_id and m.contig_id = c.contig_id  and c.contig_id = $single group by t.mapping_id order by c.contig_id, m.cstart";
}
else {
	$query = "select r.readname, min(t.rstart), sum(t.length),  r.strand, c.contig_id, min(t.cstart) from SEQUENCE s, SEQ2READ  q, MAPPING m, SEGMENT t, READINFO r, CURRENTCONTIGS c where  m.mapping_id = t.mapping_id and m.seq_id = q.seq_id and s.seq_id = q.seq_id and q.read_id = r.read_id and m.contig_id = c.contig_id group by t.mapping_id order by c.contig_id, m.cstart";
    }
my $contigreads = $dbh->selectall_arrayref($query) || die "Cannot run query $query: $DBI::errstr";
    
# contigread holds (readname, rstart, seqlen, strand, contig name, cstart)
# | WTSI_1060_1p06.p1k           |     40 |   1605 | Forward | WTSI_1060_1p06.p1k           |      1 | 
# +------------------------------+--------+--------+---------+------------------------------+--------+
# need to print out:
# * 454.genome1_scaffold00001_1 1 7541 0 merged_contig1 * 1 *
# * ILLUM.genome2_NODE_150591_length_16322_cov_6.316321_19 1 2385 1 
# merged_contig1 * 296 *
# * ILLUM.genome2_NODE_150591_length_16322_cov_6.316321_18 1 207 1 
# merged_contig1 * 2683 *
# * ILLUM.genome2_NODE_150591_length_16322_cov_6.316321_17 1 468 1 
# merged_contig1 * 2992 *
#
# column 1: a star symbol
# column 2: read name																						r.readname
# column 3: the first trimmed position of the read							g.rstart
# column 4: the length of the trimmed read											s.seqlen
# column 5: orientation of the read (0 = forward, 1=reverse)  	r.strand translated to 0 and 1
# column 6: name of the contig 																	pathogen_RATTI_contig_<c.contig_id>
# column 7: a star symbol
# column 8: position of the read in the contig									g.cstart
# column 9: a star symbol
#
# All separated by 1 space 
#
# That is the nth base in the contig where the first base of the aligned 
# read is:
#
# ---------> Contig1 (10 bases)
#       --->         Read1 (3 bases) starting at the 6th position of the 
# contig
#
# * Read1 1 3 0 Contig1 * 6 *
#

my $current_contig_id = "";

foreach my $contigread (@{$contigreads}) { 
	print "* @$contigread[0] @$contigread[1] @$contigread[2]";
	if (@$contigread[3] eq "Forward") {
		print " 0 ";
	}
	else {
		print " 1 ";
	}
	print "pathogen_RATTI_contig_@$contigread[4] * @$contigread[5] *\n";
}

$dbh->disconnect();

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-db\t\tDatabase\n";
    print STDERR "\t-username\tUsername to connect to server\n";
    print STDERR "\t-password\tPassword to connect to server\n";
    print STDERR "\t-single\tRun the report just for this contig\n";
}
