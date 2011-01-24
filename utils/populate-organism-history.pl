#!/usr/local/bin/perl -w
# populate-organism-history.pl
# runs each night to add a row for today
# generates a csv of year so far to project directory/csv

use strict; # Constraint variables declaration before using them

use FileHandle;
use PathogenRepository;

use DBI;
use DataSource;

require Mail::Send;
#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

my $debug;
 
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

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $insert_query = "insert into ORGANISM_HISTORY (
organism,
statsdate, 
total_reads,
reads_in_contigs,
free_reads,
asped_reads,
next_gen_reads)
select 
'TESTRATTI',
date(now())-1,
9999,
sum(C.nreads),
9999,
9999,
9999
from CONTIG as C,PROJECT as P  
where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where date(CA.created) < date(now())-1 and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or date(CB.created) > date(now())-2))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id";

my $isth = $dbh->prepare_cached($insert_query);
my $insert_count = $isth->execute() || &queryFailed($insert_query);
$isth->finish();

# update the total reads

my $total_read_update = "update ORGANISM_HISTORY 
set total_reads = (select count(*) from READINFO) 
where statsdate = date(now())-1";

my $usth = $dbh->prepare_cached($total_read_update);
my $total_read_update_count = $usth->execute() || &queryFailed($total_read_update);
$usth->finish();

# update the free reads

my $free_read_update = "update ORGANISM_HISTORY 
set free_reads =  total_reads - reads_in_contigs
where statsdate = date(now())-1";

my $uusth = $dbh->prepare_cached($free_read_update);
my $free_read_update_count = $uusth->execute() || &queryFailed($free_read_update);
$uusth->finish();

# update the asped and next_gen_reads

my $asped_read_update = "update ORGANISM_HISTORY
set asped_reads =  (select count(*) from READINFO where asped is not null )
where statsdate = date(now())-1";

my $asth = $dbh->prepare_cached($asped_read_update);
my $asped_read_update_count = $asth->execute() || &queryFailed($asped_read_update);
$asth->finish();

my $next_gen_read_update = "update ORGANISM_HISTORY
set next_gen_reads = total_reads - asped_reads
where statsdate = date(now())-1";

my $nsth = $dbh->prepare_cached($next_gen_read_update);
my $next_gen_read_update_count = $nsth->execute() || &queryFailed($next_gen_read_update);
$nsth->finish();

print STDERR "Successfully created organism read statistics for organism $organism in instance $instance \n";

# COMMENTED OUT UNTIL BACK POPULATION ENSURES DATA IS THERE

#$threshold = 100;

# get the free_reads for stats_day
# my $stasday_free_reads = 0;
# my $statsday_query = "select total_reads from ORGANISM_HISTORY where statsdate = date(now())-1";

#my $dsth = $dbh->prepare_cached($previous_query);
#my $statsday_count = $dsth->execute() || &queryFailed($statsday_query);
#$dsth->finish();
#my $statsday_values = $dsth->fetchall_arrayref();
#
#foreach my $statsday_value (@$statsday_values) {
		#$statsday_free_reads = @$statsday_value[0];

#my $previous_values = $psth->fetchall_arrayref();
# get the free_reads and asped reads for previous_day
# my $previous_query = "select total_reads, asped_reads from ORGANISM_HISTORY where statsdate = date(now())-2";

#my $psth = $dbh->prepare_cached($previous_query);
#my $previous_count = $psth->execute() || &queryFailed($previous_query);
#$psth->finish();

#my $previous_values = $psth->fetchall_arrayref();
#
#foreach my $previous_value (@$previous_values) {
		#$free_reads_previous_day = @$previous_value[0];
		#my $asped_reads_previous_day = @$previous_value[0];
		#
# 	$read_difference =  $free_reads_previous_day - $free_reads_stats_day - $asped_reads_previous_day;
#
# if ($read_difference > $threshold) {
#
# my $msg = "This is to let you know that the difference between the free reads   
# for the TESTSCHISTO database stats_day and previous_day is $free_read_difference, which is over  
# the threshold of $threshold.
#
# Previous day  (yyyy/mm/dd)
# total reads = a
# asped reads  = b
# free reads = c
#
# Stats day (yyyy/mm/dd)
#
# total reads = d
# asped reads  = e
# free reads = f"
#
# ******************
#  send the email 
#	&sendMessage($user, $message, $instance) if $message;
#	}	
#}
#
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

sub sendMessage {
    my ($user,$message,$instance) = @_;

		my $to = "kt6";
		$to .= ',' . $user if defined($user);

    if ($instance eq 'test') {
				$to = $user;
    }

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("Arcturus project import FAILED");
    #$mail->add("X-Arcturus", "contig-transfer-manager");
    my $handle = $mail->open;
    print $handle "$message\n";
    $handle->close;
    
}

