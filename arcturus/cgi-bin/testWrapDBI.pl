#!/usr/local/bin/perl

use WrapMySQL;

@dbs = ('babel.prod', 'babel.dev', 'babel.test', 'pcs3.prod', 'pcs3.dev', 'pcs3.test');

@modes = ('admin', 'read', 'write');

print "Content-Type: text/plain\n\n";

foreach $db (@dbs) {
    print "TESTING $db:\n";
    foreach $mode (@modes) {
	printf "    %-5s", $mode;

	my $dbh = WrapMySQL->connect($db, $mode);

	if (!defined($dbh)) {
	    print " FAILED: $DBI::errstr\n";
	} else {
	    print " OK\n";
	    $dbh->disconnect();
	}
    }
    print "\n";
}

exit(0);
