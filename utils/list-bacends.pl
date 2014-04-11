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


use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigid;
my $clonename;
my $minlen;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $contigid = shift @ARGV if ($nextword eq '-contig');

    $clonename = shift @ARGV if ($nextword eq '-clone');

    $minlen = shift @ARGV if ($nextword eq '-minlen');
}

unless (defined($instance) &&
	defined($organism) &&
	defined($clonename)) {
    &showUsage();
    exit(0);
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my ($query, $stmt);

my @contigs;

if (defined($contigid)) {
    push @contigs, $contigid;
} else {
    $query =  "select contig_id from CURRENTCONTIGS";

    $query .= " and length > $minlen" if defined($minlen);

    $query .= " order by length desc";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $stmt->execute();
    &db_die("Failed to execute query \"$query\"");

    while (($contigid) = $stmt->fetchrow_array()) {
	push @contigs, $contigid;
    }

    $stmt->finish();
}

my @conditions = ("MAPPING.seq_id = SEQ2READ.seq_id",
		  "SEQ2READ.read_id = READINFO.read_id",
		  "READINFO.template_id = TEMPLATE.template_id",
		  "TEMPLATE.ligation_id = LIGATION.ligation_id",
		  "LIGATION.clone_id = CLONE.clone_id");

my $conditions = join(' and ', @conditions);

$query = "select TEMPLATE.template_id,READINFO.read_id,readname,cstart,cfinish,direction,LIGATION.sihigh" .
    " from MAPPING,SEQ2READ,READINFO,TEMPLATE,LIGATION,CLONE" .
    " where contig_id = ?" .
    " and $conditions and CLONE.name=? order by template_id asc,cstart asc";

my $stmt_readinfo = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select name from CONTIG left join PROJECT using(project_id) where contig_id = ?";

my $stmt_projectname = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

foreach $contigid (@contigs) {
    $stmt_projectname->execute($contigid);

    my ($project) = $stmt_projectname->fetchrow_array() || "UNKNOWN";

    $stmt_readinfo->execute($contigid, $clonename);
    &db_die("Failed to execute query \"$query\" for contig $contigid");
    
    my $last_templateid = -1;
    my ($last_readname, $last_cstart, $last_cfinish, $last_direction);

    while (my ($templateid, $readid, $readname, $cstart, $cfinish, $direction, $sihigh) =
	   $stmt_readinfo->fetchrow_array()) {
	if ($templateid == $last_templateid) {
	    if ($last_direction eq 'Forward' && $direction eq 'Reverse') {
		printf "%8d %8d  %8d  %8d  %-30s  %-30s  %-20s\n",$contigid,
		$last_cstart, $cfinish, ($cfinish-$last_cstart-$sihigh),
		$last_readname, $readname, $project;
	    } else {
		print STDERR "Inconsistent: $contigid $last_readname $last_direction $last_cstart to $last_cfinish <-->" .
		    " $readname $direction $cstart $cfinish\n";
	    }
	}
	
	($last_templateid, $last_readname, $last_cstart, $last_cfinish, $last_direction) =
	    ($templateid, $readname, $cstart, $cfinish, $direction);
    }
}

$stmt_readinfo->finish();
$stmt_projectname->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "  -instance\t\tName of instance\n";
    print STDERR "  -organism\t\tName of organism\n";
    print STDERR "  -clone\t\tName of clone for BAC/fosmid ends\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "  -contig\t\tID of contig to analyse\n";
    print STDERR "  -minlen\t\tMinimum length for contigs scan\n";
}
