#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;
use DBI;
use FileHandle;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $readid = shift @ARGV if ($nextword eq '-readid');
}

$instance = 'prod' unless defined($instance);

$readid = 1 unless defined($readid);

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

$read = $adb->getReadByID($readid);

$fh = new FileHandle("/tmp/testadb.$$", "w");

$read->writeReadToCaf($fh);

$fh->close();

exit(0);
