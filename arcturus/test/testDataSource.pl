#!/usr/local/bin/perl

use DataSource;
use DBI;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $username = shift @ARGV if ($nextword eq '-username');

    $password = shift @ARGV if ($nextword eq '-password');
}

die "You must specify the instance" unless defined($instance);
die "You must specify the organism" unless defined($organism);

$ds = new DataSource(-instance => $instance,
		     -organism => $organism);

$url = $ds->getURL();
print "The URL is $url\n";

if (defined($username) && defined($password)) {
    $dbh = $ds->getConnection(username => $username, password => $password);
} else {
    $dbh = $ds->getConnection();
}

if (defined($dbh)) {
    print "        CONNECT OK\n";
} else {
    print "        CONNECT FAILED:";
    print " (with username=\"$username\" and password=\"$password\")"
	if (defined($username) && defined($password));
    print " : $DBI::errstr\n";
}

$dbh->disconnect if defined($dbh);

exit(0);
