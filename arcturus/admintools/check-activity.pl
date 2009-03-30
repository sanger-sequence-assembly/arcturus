#!/usr/local/bin/perl

use strict;

use DBI;

my $host;
my $port;
my $username;
my $password;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
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

my $dbname = 'arcturus';

my $url = "DBI:mysql:$dbname;host=$host;port=$port";

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 0});

my $query = 'select table_schema,engine from information_schema.tables where table_name = ?'
    . ' order by table_schema asc';

my $sth = $dbh->prepare($query);

$sth->execute('CONTIG');

my @dblist;

while (my ($schema, $engine) = $sth->fetchrow_array()) {
    push @dblist, [$schema, $engine];
}

$sth->finish();

foreach my $db (@dblist) {
    my ($schema, $engine) = @{$db};

    $query = "select max(created) from " . $schema . ".CONTIG";

    $sth = $dbh->prepare($query);
    $sth->execute();
    my ($created) = $sth->fetchrow_array();
    $sth->finish();

    printf "%-20s %6s %s\n", $schema, $engine, $created;
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
