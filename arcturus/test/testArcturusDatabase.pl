#!/usr/local/bin/perl

use ArcturusDatabase;
use DBI;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');
}

die "You must specify the instance" unless defined($instance);
die "You must specify the organism" unless defined($organism);

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);


$url = $adb->getURL();
print "The URL is $url\n";

$dbh = $adb->getConnection();

if (defined($dbh)) {
    print "        CONNECT OK\n";
} else {
    print "        CONNECT FAILED: : $DBI::errstr\n";
}

$dbh->disconnect if defined($dbh);

exit(0);
