#!/usr/local/bin/perl

use WrapMySQL;

@dbs = ('pcs3.prod', 'pcs3.dev', 'pcs3.test', 'babel.prod', 'babel.dev', 'babel.test');

@modes = ('admin', 'read', 'write', 'root');

print "Content-Type: text/plain\n\n";

foreach $db (@dbs) {
    print "TESTING $db:\n";
    foreach $mode (@modes) {
	printf "    %-5s", $mode;

	my $dbh = WrapMySQL->connect($db, $mode);

	if (!defined($dbh)) {
	    print " FAILED: ", WrapMySQL->getErrorString, "\n";
	} else {
	    print " OK\n";
	    $dbh->disconnect();
	}
    }
    print "\n";
}

exit(0);
