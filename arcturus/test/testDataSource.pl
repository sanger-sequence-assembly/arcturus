#!/usr/local/bin/perl

use DataSource;
use DBI;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');
}

die "You must specify the instance" unless defined($instance);
die "You must specify the organism" unless defined($organism);

$ds = new DataSource(-instance => $instance,
		     -organism => $organism);

$url = $ds->getURL();
print "The URL is $url\n";

$dbh = $ds->getConnection();

if (defined($dbh)) {
    print "        CONNECT OK\n";
} else {
    print "        CONNECT FAILED: : $DBI::errstr\n";
}

$dbh->disconnect if defined($dbh);

exit(0);
