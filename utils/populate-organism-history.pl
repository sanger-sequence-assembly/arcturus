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
my $since="";
my $until="";
my $threshold;

my $debug;
 
my $validKeys  = "organism|o|instance|i|since|s|until|u|help|hi|threshold|t";

while (my $nextword = shift @ARGV) {

	if ($nextword !~ /\-($validKeys)\b/) {
		&showUsage("Invalid keyword '$nextword'");
	}

	$instance = shift @ARGV if ($nextword eq '-instance');
	$organism = shift @ARGV if ($nextword eq '-organism');
	$since = shift @ARGV if ($nextword eq '-since');
	$until = shift @ARGV if ($nextword eq '-until');
	$threshold = shift @ARGV if ($nextword eq '-threshold');
	  
	if ($nextword eq '-help') {
		&showUsage();
		exit(0);
	}
}

unless (defined($threshold)) {
	&showUsage();
	exit(0);
}

unless (($since ne "") && ($until ne "")) {
	if (($since ne "") || ($until ne "")) {
		print STDERR "/n/tOnly one date defined\n";
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
my @datelist;

if (($since eq "") || ($until eq "")) {
	# generate just yesterday
	my $yesterday_query ="select date_sub(date(now()),interval 1 day)";

	my $yqh = $dbh->prepare($yesterday_query);
	$yqh->execute() or &queryFailed("Cannot find yesterday's date");
	my $yesterday = $yqh->fetchrow_array();

	push @datelist, $yesterday;
	print STDERR "Populating data for $yesterday only\n";
}
elsif (($since eq "") && ($until ne "")) {
	# a range of dates need to be generated from creation of database to $until inclusive
	# to be implemented
}
elsif (($since ne "") && ($until eq "")) {
	# a range of dates need to be generated from $since to yesterday inclusive
	# to be implemented
}
elsif (($since ne "") && ($until ne "")) {
	if ($since eq $until) {
		print STDERR "Populating data for $since only\n";
		push @datelist, $since;
	}
	else {
	
		my $date_create = "create temporary table time_intervals( statsdate DATE NOT NULL, until_date DATE NOT NULL)";
		my $dch = $dbh->do($date_create) or &queryFailed("Cannot create the time_intervals table");

		my $date_insert = "insert into time_intervals values(date(?), date(?))";
		my $dih = $dbh->prepare($date_insert);
		$dih->execute($since, $until) or &queryFailed("Cannot set up the time_intervals table");

		my $date_update = "update time_intervals set statsdate = timestampadd(DAY, 1, statsdate)";
		my $duh = $dbh->prepare($date_update);

		my $date_query = "select max(statsdate), until_date from time_intervals group by statsdate;";
		my $dqh = $dbh->prepare($date_query);

		my $date_drop = "drop temporary table time_intervals";
		my $statsdate;
		my $tempdate;
  
		$statsdate = $since;

		print STDERR "Finding data from $statsdate until $until:\n";
		#print STDERR "Adding $statsdate to list of dates\n";
		push @datelist, $statsdate;

		while ($statsdate ne $until) { 
			$duh->execute() or &queryFailed("Cannot update the time_intervals table");
			$dqh->execute() or &queryFailed("Cannot find the maximum date");
			($statsdate, $tempdate) = $dqh->fetchrow_array();
			#	print STDERR "Adding $statsdate to list of dates\n";
  		push @datelist, $statsdate;
		}
		$dih->finish();
		$duh->finish();
		$dqh->finish();
	}
}

my $insert_query = "insert into ORGANISM_HISTORY (
	organism,
	statsdate, 
	total_reads,
	reads_in_contigs,
	free_reads,
	asped_reads,
	next_gen_reads)
	select 
	?,
	?,
	9999,
	sum(C.nreads),
	9999,
	9999,
	9999
	from CONTIG as C,PROJECT as P  
	where C.contig_id in 
     (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)
     on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)
     where CA.created < ? and CA.nreads > 1 and CA.length >= 0 
		 and (C2CMAPPING.parent_id is null  or CB.created > ?))
    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
    and P.project_id = C.project_id";
my $isth = $dbh->prepare_cached($insert_query);

my $total_read_update = "update ORGANISM_HISTORY 
set total_reads = (select count(*) from READINFO) 
where statsdate = ?";
my $usth = $dbh->prepare_cached($total_read_update);

my $free_read_update = "update ORGANISM_HISTORY 
set free_reads =  total_reads - reads_in_contigs
where statsdate = ?";
my $uusth = $dbh->prepare_cached($free_read_update);

my $asped_read_update = "update ORGANISM_HISTORY
set asped_reads =  (select count(*) from READINFO where asped is not null )
where statsdate = ?";
my $asth = $dbh->prepare_cached($asped_read_update);

my $next_gen_read_update = "update ORGANISM_HISTORY
set next_gen_reads = total_reads - asped_reads
where statsdate = ?";
my $nsth = $dbh->prepare_cached($next_gen_read_update);

foreach my $date (@datelist) {
	#print STDERR "Inserting line for $date\n";
	my $insert_count = $isth->execute($organism, $date, $date, $date) || &queryFailed($insert_query);
	my $total_read_update_count = $usth->execute($date) || &queryFailed($total_read_update);
	my $free_read_update_count = $uusth->execute($date) || &queryFailed($free_read_update);
	my $asped_read_update_count = $asth->execute($date) || &queryFailed($asped_read_update);
	my $next_gen_read_update_count = $nsth->execute($date) || &queryFailed($next_gen_read_update);

	#print STDERR "Checking for free read variation over the allowed threshold of $threshold reads\n";
	&checkFreeReadChange( $dbh, $date, $threshold);
} # end foreach date to populate

$isth->finish();
$usth->finish();
$uusth->finish();
$asth->finish();
$nsth->finish();

print STDERR "Successfully created organism read statistics for organism $organism in instance $instance \n";

$dbh->disconnect();

exit 0;

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub checkFreeReadChange {
  my $dbh = shift;
  my $date = shift;
  my $threshold = shift;

	#print STDERR "\tChecking for free read variation over the allowed threshold of $threshold or more reads on $date and previous date\n";

	# get the free_reads for stats_day
	my $stasday_free_reads = 0;
	my $statsday_query = "select statsdate, total_reads, free_reads, asped_reads 
		from ORGANISM_HISTORY 
 		where statsdate = ?";
	my $dsth = $dbh->prepare_cached($statsday_query);

 	my $previous_query = "select statsdate, total_reads, free_reads, asped_reads 
 		from ORGANISM_HISTORY 
 		where statsdate = date_sub(?,interval 1 day)";
	my $psth = $dbh->prepare_cached($previous_query);

	my $statsday_count = $dsth->execute($date) || &queryFailed($statsday_query);
	my $statsday_values = $dsth->fetchall_arrayref();
#
	my $user = "";
  if ($instance eq 'test') {
		$user = "kt6";
  }
	else {
		#$user = "kt6";
		$user = "freeread";
	}

	foreach my $statsday_value (@$statsday_values) {
		my $statsdate = @$statsday_value[0];
		my $total_reads_stats_day = @$statsday_value[1];
		my $free_reads_stats_day = @$statsday_value[2];
		my $asped_reads_stats_day = @$statsday_value[3];

		print STDERR "\tChecking for free read variation over the allowed threshold of $threshold reads on $statsdate ";

		my $previous_count = $psth->execute($date) || &queryFailed($previous_query);

		my $previous_values = $psth->fetchall_arrayref();

		foreach my $previous_value (@$previous_values) {
			my $previous_date = @$previous_value[0];
			my $total_reads_previous_day = @$previous_value[1];
			my $free_reads_previous_day = @$previous_value[2];
			my $asped_reads_previous_day = @$previous_value[3];

			print STDERR "and $previous_date\n";
 			my $free_read_difference =  $free_reads_stats_day - $free_reads_previous_day;
 			#my $free_read_difference =  abs($free_reads_previous_day - $free_reads_stats_day);

 			if ($free_read_difference >= $threshold) {
	 			my $message = "This is to let you know that the difference between the free reads for the $organism database ";
				$message .= "on $statsdate and $previous_date is $free_read_difference.\n\n";
 				$message .= "This is over the threshold of $threshold or more reads difference that has been set.\n\n";

 				$message .= "\n $previous_date\n";
				$message .= "\t total reads = $total_reads_previous_day\n";
				$message .= "\t asped reads  = $asped_reads_previous_day\n";
				$message .= "\t free reads = $free_reads_previous_day\n";
				$message .= "\n";
 				$message .= "\n $statsdate\n";
				$message .= "\t total reads = $total_reads_stats_day\n";
				$message .= "\t asped reads = $asped_reads_stats_day\n";
				$message .= "\t free reads = $free_reads_stats_day\n\n\n" ;

				&sendMessage($user, $message, $instance, $organism) if $message;
				print STDERR $message;
			}
		}# end foreach previous_values
	}# end foreach statsday_values
	$dsth->finish();
	$psth->finish();
}

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

		print STDOUT "\n Please supply two dates for an inclusive period to populate the organism statistics,";
		print STDOUT "\n or no dates to populate yesterday's data, with a threshold of read variation to ignore\n";
    print STDOUT "\n Parameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";
    unless ($organism && $instance) {
        print STDOUT "MANDATORY PARAMETERS:\n";
        print STDOUT "\n";
        print STDOUT "-organism\tArcturus organism database\n" unless $organism;
        print STDOUT "-instance\tArcturus database instance\n" unless $instance;
        print STDOUT "-since\tArcturus database since\n";
        print STDOUT "-until\tArcturus database until\n";
        print STDOUT "-threshold\tThreshold of change in reads before an email is sent\n";
        print STDOUT "\n";
    }

    $code ? exit(1) : exit(0);
}

sub sendMessage {
    my ($user,$message,$instance, $organism) = @_;

		my $to = "";

    if ($instance eq 'test') {
			$to = $user;
    }
		else {
			$to = "arcturus-help\@sanger.ac.uk";
			$to .= ',' . $user if defined($user);
		}

		print STDOUT "Sending message to $to\n";

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("Unexpected change in the number of free reads for $organism");
    #$mail->add("X-Arcturus", "contig-transfer-manager");
    my $handle = $mail->open;
    print $handle "$message\n";
    $handle->close;
    
}

