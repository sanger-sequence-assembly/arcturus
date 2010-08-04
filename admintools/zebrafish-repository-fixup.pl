#!/usr/local/bin/perl

use strict;

use DBI;
use OORepository;

my $host;
my $port;
my $username;
my $password;
my $verbose = 0;
my $fixit = 0;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
    } elsif ($nextword eq '-verbose') {
	$verbose = 1;
    } elsif ($nextword eq '-fixit') {
	$fixit = 1;
    } elsif ($nextword eq '-help') {
	&showHelp();
	exit(0);
    } else {
	die "Unknown option: $nextword";
    }
}

$username = $ENV{'MYSQL_USERNAME'} unless defined($username);
$password = $ENV{'MYSQL_PASSWORD'} unless defined($password);

unless (defined($host) && defined($port) && 
	defined($username) && defined($password)) {
    &showHelp("One or more mandatory options were missing");
    exit(1);
}

my $url = "DBI:mysql:arcturus;host=$host;port=$port";

eval {
    my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 1});

    my $repos = new OORepository;

    print STDERR "Enumerating zebrafish databases...";

    my $sth = $dbh->prepare("show databases like 'ZGTC%'");

    $sth->execute();

    my @dblist;

    while (my ($dbname) = $sth->fetchrow_array()) {
	push @dblist, $dbname;
    }

    $sth->finish();

    my $sth_set_directory = $dbh->prepare("update PROJECT set directory = ? where project_id = ?");

    print STDERR " done.\n";

    foreach my $dbname (@dblist) {
	print STDERR "\nFixing database $dbname\n";

	$dbh->do("use $dbname");

	$sth = $dbh->prepare("select project_id,name,directory from PROJECT where name like 'z%'");

	$sth->execute();

	while (my ($projid, $pname, $pdir) =  $sth->fetchrow_array()) {
	    $repos->get_online_path_from_project($pname);

	    my $rdir = $repos->{online_path};

	    if (defined($rdir) && $rdir ne $pdir) {
		print STDERR "\tDirectory for $pname (ID=$projid) is\n\t\t$pdir in Arcturus\n\t\t$rdir in Tracking DB\n";

		if ($fixit) {
		    my $rc = $sth_set_directory->execute($rdir, $projid);

		    print STDERR "\tSet directory to $rdir in Arcturus.\n";
		} else {
		    print STDERR "\tRe-run this script with the -fixit option to repair this problem.\n";
		}

		print STDERR "\n";
	    }
	}

	$sth->finish();
    }

    $sth_set_directory->finish();

    $dbh->disconnect();
};
if ($@) {
    # Handle error
}

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-username\tUsername to connect to server [or set MYSQL_USERNAME]\n";
    print STDERR "\t-password\tPassword to connect to server [or set MYSQL_PASSWORD]\n";

    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\t-fixit\tFix all incorrect directory locations\n";
    print STDERR "\t-verbose\tRun in verbose mode\n";
}
