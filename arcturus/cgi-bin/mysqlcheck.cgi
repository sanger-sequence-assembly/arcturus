#!/usr/local/bin/perl

use CGI;

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

print "<TABLE BORDER=1 CELLPADDING=3>\n";

print "<TR><TH>Host</TH><TH>Port</TH><TH>STATUS</TH></TR>\n";

foreach $servport (@servers) {
    ($host, $port) = split(/:/, $servport);

    $port = 3306 unless defined($port);

    `$mysqladmin -h $host -P $port -u ping ping >/dev/null 2>&1`;

    $alive = ($? == 0);

    print "<TR><TD>$host</TD><TD>";
    print "<A HREF=\"/cgi-bin/mysqlprocess.cgi?servers=$host:$port\">" if $alive;
    print "$port";
    print "</A>" if $alive;
    print "</TD><TD>";

    if ($alive) {
	open(CMD, "$mysqladmin -h $host -P $port -u ping status |");
	while (<CMD>) {
	    print;
	}
	close(CMD);
    } else {
	print "<FONT COLOR=\"#FF0000\">Server does not respond</FONT>";
    }

    print "</TD></TR>\n";
}

print "</TABLE>\n";

print $cgi->end_html();

exit(0);
