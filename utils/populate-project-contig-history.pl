#!/usr/local/bin/perl -w

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

# populate-project-contig-history.pl
# runs each night to add a row for today
# generates a csv of year so far to project directory/csv
# called from make-web-report for the LIVE system whilst tested in this script

use strict; # Constraint variables declaration before using them

use FileHandle;
use DataSource;

use DBI;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;
my $date; 
my $outputFileName;
my $selectmethod;
my $status;

my $logfile;            # default STDERR
my $loglevel;           # default log warnings and errors only
my $debug;
my $test;

my $validKeys  = "organism|o|instance|i|";

while (my $nextword = shift @ARGV) {

	if ($nextword !~ /\-($validKeys)\b/) {
		&showUsage("Invalid keyword '$nextword'");
	}

	$instance = shift @ARGV if ($nextword eq '-instance');
	$organism = shift @ARGV if ($nextword eq '-organism');
	  
	if ($nextword eq '-help') {
		&showUsage();
		exit(0);
	}
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

&populateProjectContigHistory($dbh);

$dbh->disconnect();

exit 0;

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------
sub queryFailed {
   my $query = shift;
 
   $query =~ s/\s+/ /g; # remove redundent white space
 
   print STDERR "FAILED query:\n$query\n\n";
	 print STDERR "MySQL error: $DBI::err ($DBI::errstr)\n\n" if ($DBI::err);
	 return 0;
}

sub populateProjectContigHistory {
   my $dbh = shift;

	 my $test = 1;

# add all rows to the history table for today
# for each project
# 	calculate the N50 value
#

	my $minlen = 0;

	my $insert_query = " insert into PROJECT_CONTIG_HISTORY (
		project_id,
		statsdate,
		name,
		total_contigs,
	 	total_reads,
		total_contig_length,
		mean_contig_length,
		stddev_contig_length,
		max_contig_length,
		N50_contig_length)
			select
	 		P.project_id,
	 		now(),
	 		P.name,
	 		count(*) as contigs,
	 		sum(C.nreads),
			sum(C.length),
	 		round(avg(C.length)),
	 		round(std(C.length)),
	 		max(C.length),
	 		'0'
	 		from CONTIG as C,PROJECT as P
	 		where C.contig_id in
	      (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
	      on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
	      where CA.created < now()  and CA.nreads > 1 and CA.length >= ? and (C2CMAPPING.parent_id is null  or CB.created > now()))
	     and P.name not in ('BIN','FREEASSEMBLY','TRASH')
	     and P.project_id = C.project_id group by project_id; ";

	my $isth = $dbh->prepare_cached($insert_query);
	my $project_contig_insert_count = $isth->execute($minlen) || &queryFailed($insert_query);
	$isth->finish();

	if ($test) {
		print STDERR"Data for $project_contig_insert_count projects collected\n";
	}

	my $project_query = "select project_id, name, statsdate from PROJECT_CONTIG_HISTORY where statsdate = now()";

	my $ssth = $dbh->prepare($project_query);
	$ssth->execute() || &queryFailed($project_query);
 
	my $projectids = $ssth->fetchall_arrayref();

	foreach my $project (@$projectids) {

		my $project_id = @$project[0];
		my $project_name = @$project[1];
		my $date = @$project[2];

if ($test) {
   print STDERR "Creating N50 contig length for project $project_name\n";
}

		# update the N50 read length

  	my $N50_contig_length = &get_N50_for_date($date, $minlen, $project_id);

		my $N50_contig_length_update = "update PROJECT_CONTIG_HISTORY"
		. " set N50_contig_length = ?"
		. " where project_id = ? and statsdate = ?";

		my $nsth = $dbh->prepare_cached($N50_contig_length_update);
		my $N50_contig_length_count = $nsth->execute($N50_contig_length, $project_id, $date) || &queryFailed($N50_contig_length_update);
		$nsth->finish();

 		if ($test) {
    	print STDERR"Median read for project $project_id is $N50_contig_length\n\n";
 		}

	} # end foreach project 
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

		print STDOUT "\n populate-project-contig-history.pl runs each night to add a row for today.";
    print STDOUT "\n\nParameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";
    unless ($organism && $instance) {
        print STDOUT "MANDATORY PARAMETERS:\n";
        print STDOUT "\n";
        print STDOUT "-organism\tArcturus organism database\n" unless $organism;
        print STDOUT "-instance\tArcturus database instance\n" unless $instance;
        print STDOUT "\n";
    }

    $code ? exit(1) : exit(0);
}

sub get_N50_for_date {
    my $date = shift;
    my $minlen = shift;
		my $project_id = shift;

    my $from_where_clause =
	" from CONTIG as C where C.project_id = ? and C.contig_id in " .
	" (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)" .
	" on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)" .
	" where CA.created < ?  and CA.nreads > 1 and CA.length >= ? and (C2CMAPPING.parent_id is null or CB.created > ?))";

    my $sql = "select C.length " . $from_where_clause . " order by C.length desc";

    my $sth_contig_lengths = $dbh->prepare($sql);

    $sth_contig_lengths->execute($project_id, $date, $minlen, $date);

    my $n50 = &get_N50_from_resultset($sth_contig_lengths);

    $sth_contig_lengths->finish();

    return $n50;
}

sub get_N50_from_resultset {
    my $sth = shift;

    my $lengths = [];

    while (my ($ctglen) = $sth->fetchrow_array()) {
	push @{$lengths}, $ctglen;
    }

    return &get_N50_from_lengths($lengths);
}

sub get_N50_from_lengths {
    my $lengths = shift;

    my $sum_length = 0;

    foreach my $ctglen (@{$lengths}) {
	$sum_length += $ctglen;
    }

    my $target_length = int($sum_length/2);

    #print STDERR "get_N50_from_lengths: list of length ", scalar(@{$lengths}), ", sum_length=$sum_length",
    #", target_length=$target_length\n";

    $sum_length = 0;

     foreach my $ctglen (@{$lengths}) {
	$sum_length += $ctglen;
	#printf STDERR "%10d %8d\n",$sum_length,$ctglen;
	return $ctglen if ($sum_length > $target_length);
    }   

    return 0;
}

sub printCSV {
	my ($csvfile, $csvlines) = @_;

	my $csvlinesref = ref($csvlines);
	my $ret;

	unless ($csvlinesref eq 'ARRAY') {
		$ret = -1;
	}

	open(my $csvhandle, "> $csvfile") or die "Cannot open filehandle to $csvfile : $!";

	my $i = 0;

	foreach my $csvline (@{$csvlines}){
		foreach my $csvitem (@{$csvline}){
			print $csvhandle "$csvitem,";
		}
		$i++;
		print $csvhandle "@$csvline[$i]\n";
	}

	$ret = close $csvhandle;
	return $ret;
	}

	# end
