#!/usr/local/bin/perl

use CGI;
use DBI;

$mysqladmin = '/nfs/pathsoft/external/mysql-3.23.49/bin/mysqladmin';

$cgi = new CGI;

$script = $ENV{'SCRIPT_FILENAME'};

print $cgi->header();

print $cgi->start_html('MySQL Server Status');

$servers = $cgi->param('servers');

unless (defined($servers)) {
    print $cgi->strong("No servers were specified"),"\n";
    print $cgi->end_html();
    exit(0);
}

@servers = split(/,/, $servers);

foreach $servport (@servers) {
    ($host, $port) = split(/:/, $servport);

    $port = 3306 unless defined($port);

    $dsn = "DBI:mysql;host=$host;port=$port";

    print "<H2>$host:$port</H2>\n";

    `$mysqladmin -h $host -P $port -u ping ping >/dev/null 2>&1`;

    if ($? == 0) {
	$dbh = DBI->connect($dsn, 'ping', undef,
			    {RaiseError => 0, PrintError => 0});

	if ($dbh) {
	    print "<CODE>\n";
	    $sth = $dbh->prepare("SHOW PROCESSLIST");
	    $sth->execute();
	    while (@ary = $sth->fetchrow_array()) {
		print join('<BR>', @ary);
		print "<BR>\n";
	    }
	    print "</CODE><BR>\n";
	    $dbh->disconnect();
	} else {
	    print "<FONT COLOR=\"#FF0000\"><STRONG>Connect failed: $DBI::errstr</STRONG></FONT>";
	}
    } else {
	print "<FONT COLOR=\"#FF0000\"><STRONG>Server does not respond.</STRONG></FONT>";
    }
}

print $cgi->end_html();

exit(0);
