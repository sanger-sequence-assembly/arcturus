#!/usr/local/bin/perl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;
my $fix = 0;

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
    } elsif ($nextword eq '-fix') {
	$fix = 1;
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

my $query = "select m.contig_id, r.readname from SEQ2READ s, MAPPING m, READINFO r where m.seq_id = s.seq_id and s.read_id = r.read_id order by m.contig_id, r.readname";
    
my $contigreads = $dbh->selectall_arrayref($query) || die "Cannot run query $query: $DBI::errstr";
    
# contigread holds (contig_id, readname)
# keep track of the current contig_id to print it only once at the top of the list of its reads
# pathogen_RATTI_contig 39478
# ratti-350a05.q1k 
# :
# <read 449>
#
# pathogen_RATTI_contig 39482
#
# ratti-310j11.p1k
# :
# <read 288>

my $current_contig_id = "";

foreach my $contigread (@{$contigreads}) { 
  if ($current_contig_id ne @$contigread[0])  {
		print "\npathogen_RATTI_contig_@$contigread[0]\n";
		$current_contig_id = @$contigread[0];
		}
	print "@$contigread[1]\n";
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
}
