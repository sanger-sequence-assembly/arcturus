#!/usr/local/bin/perl

use WrapMySQL;

WrapMySQL->initFromFile('wrapmysql.ini');

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

print "Now enumerating instances and roles ...\n\n";

@dbs = WrapMySQL->listInstances();

foreach $db (@dbs) {
    printf "%-15s", $db;
    @modes = WrapMySQL->listRolesForInstance($db);
    foreach $mode (@modes) {
	printf " %-8s", $mode;
    }
    print "\n";
}

exit(0);
