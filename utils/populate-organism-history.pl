#!/usr/local/bin/perl -w
# populate-organism-history.pl
# runs each night to add a row for today
# generates a csv of year so far to project directory/csv

use strict; # Constraint variables declaration before using them

use FileHandle;
use PathogenRepository;

use DBI;
use DataSource;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

my $debug;
my $test;
 
my $validKeys  = "organism|o|instance|i|";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
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

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $insert_query = "insert into ORGANISM_HISTORY (
organism,
statsdate, 
total_reads,
reads_in_contigs,
free_reads)
select 
'TESTRATTI',
now(),
9999,
sum(C.nreads),
9999
from CONTIG as C,PROJECT as P  
where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < now()  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or CB.created > now()-1))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id";

my $sth = $dbh->prepare_cached($insert_query);
my $insert_count = $sth->execute() || &queryFailed($insert_query);
$sth->finish();

-- update the total reads

my $total_read_update = "update ORGANISM_HISTORY 
set total_reads = (select count(*) from READINFO) 
where free_reads = 9999";

my $sth = $dbh->prepare_cached($total_read_update);
my $total_read_update_count = $sth->execute() || &queryFailed($total_read_update);
$sth->finish();

-- update the free reads

my $free_read_update = "update ORGANISM_HISTORY 
set free_reads =  total_reads - reads_in_contigs
where free_reads = 9999";

my $sth = $dbh->prepare_cached($free_read_update);
my $free_read_update_count = $sth->execute() || &queryFailed($free_read_update);
$sth->finish();

if ($test) {
   $logger->warning("Successfully created organism read statistics");
}

# create the CSV file

if ($test) {
	my $project_directory = '/tmp';
}

my $csv_query = "select * "
		. " from ORGANISM_HISTORY"
		. " into OUTFILE '$project_directory/$organism.csv'"
		. " fields terminated by ','"
		. "lines terminated by '\n'";

my $sth = $dbh->prepare_cached($query);
my $csv_file_count = $sth->execute() || &queryFailed($query);
$sth->finish();

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

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

		print STDOUT "\n populate-organism-history.pl runs each night to add a row for today.";
		print STDOUT "\n It generates a csv file for data for the year so far to project directory/csv\n";
    print STDOUT "\nParameter input ERROR: $code \n" if $code; 
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
