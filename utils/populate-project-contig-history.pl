#!/usr/local/bin/perl -w
# populate-project-contig-history.pl
# runs each night to add a row for today
# generates a csv of year so far to project directory/csv


use strict; # Constraint variables declaration before using them
use ArcturusDatabase;
use ArcturusDatabase::ADBRoot qw(queryFailed);

use FileHandle;
use Logging;
use PathogenRepository;

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

my $validKeys  = "organism|o|instance|i|"
               . "test|info|verbose|debug|log|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }

# selection on name or date

    $loglevel         = 1            if ($nextword eq '-verbose'); 
    $loglevel         = 2            if ($nextword eq '-info'); 
    $loglevel         = 1            if ($nextword eq '-debug');

    $debug            = 1            if ($nextword eq '-debug'); 

    $test             = 2            if ($nextword eq '-test'); 

    $number           = shift @ARGV  if ($nextword eq '-all');

    $logfile          = shift @ARGV  if ($nextword eq '-log');


    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardFilter($loglevel) if defined $loglevel; # reporting level

$logger->stderr2stdout() if defined $loglevel;

$logger->setBlock('debug',unblock=>1) if $debug;

$logger->setSpecialStream($logfile,list=>1) if $logfile;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism && $organism eq 'default' || $instance && $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
                                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message

    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Organism '$organism' not found on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection

my $URL = $adb->getURL;
my $dbh = $adb->getConnection;

$logger->info("Database $URL opened succesfully");

$adb->setLogger($logger);

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# add all rows to the history table for today
# for each project
# 	calculate the free reads
# 	calculate the median value
#

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
	median_contig_length)
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
	      where CA.created < now()  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or CB.created > now()-1))
	     and P.name not in ('BIN','FREEASSEMBLY','TRASH')
	     and P.project_id = C.project_id; ";

my $sth = $dbh->prepare_cached($query);
my $project_contig_insert_count = $sth->execute() || &queryFailed($query);
$sth->finish();

if ($test) {
	$logger->warning("Data for $project_contig_insert_count projects collected");
}

my $project_query = "select project_id, name from PROJECT";

my $sth = $dbh->prepare($query);
$sth->execute() || &queryFailed($query);
 
my $projectids = $sth->fetchall_arrayref();

foreach my $project (@$projectids) {

	my $project_id = @$project[0];
	my $project_name = @$project[1];

	# update the median read

  my $median_read = 9999;

	my $median_read_update = "update PROJECT_CONTIG_HISTORY"
	. " set median_read = $median_read"
	. " where project_id = $project_id";

	my $sth = $dbh->prepare_cached($query);
	my $median_read_count = $sth->execute() || &queryFailed($query);
	$sth->finish();

 	if ($test) {
    $logger->warning("Median read for project $project_id is $medianread");
 	}

	# create the CSV file

	if ($test) {
		my $project_directory = '/tmp';
	}

	my $csv_query = "select * "
		. " from PROJECT_CONTIG_HISTORY"
		. " where project_id = $project_id"
		. " into OUTFILE '$project_directory/$project_name.csv'"
		. " fields terminated by ','"
		. "lines terminated by '\n'";

	my $sth = $dbh->prepare_cached($query);
	my $csv_file_count = $sth->execute() || &queryFailed($query);
	$sth->finish();

 	if ($test) {
    $logger->warning("Data for project $project_name for the year so far has been exported to $project_directory/$project_name.csv");
 	}

} # end foreach project 

$adb->disconnect();

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

		print STDOUT "\n populate-project-contig-history.pl runs each night to add a row for today.";
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
