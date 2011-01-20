#!/usr/local/bin/perl
# populate-project-contig-history.pl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;
my $since;
my $until;

while (my $nextword = shift @ARGV) {
  if ($nextword eq '-host') {
		$host = shift @ARGV;
  } 
	elsif ($nextword eq '-port') {
		$port = shift @ARGV;
  } 
	elsif ($nextword eq '-dbname') {
		$dbname = shift @ARGV;
	} 
	elsif ($nextword eq '-username') {
		$username = shift @ARGV;
  } 
	elsif ($nextword eq '-password') {
		$password = shift @ARGV;
  } 
	elsif ($nextword eq '-since') {
		$since = shift @ARGV;
  } 
	elsif ($nextword eq '-until') {
		$until = shift @ARGV;
  } 
	elsif ($nextword eq '-help') {
		&showHelp();
		exit(0);
  } 
	else {
    &showHelp("Unknown option: $nextword");
    }
}

$username = $ENV{'MYSQL_USERNAME'} unless defined($username);
$password = $ENV{'MYSQL_PASSWORD'} unless defined($password);

unless (defined($host) && defined($port) && defined($dbname) &&
	defined($username) && defined($password) &&
	defined($since) && defined ($until)){
    &showHelp("One or more mandatory options were missing");
    exit(1);
}

my $url = "DBI:mysql:$dbname;host=$host;port=$port";

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 0});

my $query = "select distinct date(created) from CONTIG where created >= '$since' and created <= '$until'";

print STDERR "Looking for dates when contigs were created using query\n $query\n\n";

my $sth = $dbh->prepare($query);

$sth->execute();

my @datelist;

while (my ($qdate) = $sth->fetchrow_array()) {
	print STDERR "Adding $qdate to list of dates\n";
  push @datelist, $qdate;
}

$sth->finish();

foreach my $date (@datelist) {

# this query must match the one in weeklyStats in make-web-report
# use of ? rather than direct $date substitution imperative

  $query = "insert into PROJECT_CONTIG_HISTORY (
		 project_id,
		 statsdate,
		 name,
		 total_contigs,
		 total_reads,
		 total_contig_length,
		 mean_contig_length,
		 stddev_contig_length,
		 max_contig_length,
		 n50_contig_length)
		 select
		 P.project_id,
		 ?,
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
		    where CA.created <= ?  and CA.nreads > 1 and CA.length >= 0 and (C2CMAPPING.parent_id is null  or CB.created > ?))
		    and P.name not in ('BIN','FREEASSEMBLY','TRASH')
		    and P.project_id = C.project_id group by project_id";

	print STDERR "Inserting data for $date into PROJECT_CONTIG_HISTORY using query\n $query\n\n";

  $sth = $dbh->prepare($query);
  $sth->execute($date, $date, $date);
  $sth->finish();
}

$dbh->disconnect();

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-username\tUsername to connect to server (overrides ENV\{MYSQL_USERNAME\})\n";
    print STDERR "\t-password\tPassword to connect to server (overrides ENV\{MYSQL_PASSWORD\})\n";
    print STDERR "\t-dbname\t\tDatabase name\n";
    print STDERR "\n";
    print STDERR "\t-since\t\tInclusive date to start from\n";
    print STDERR "\t-until\t\tInclusive date to finish at\n";
}
