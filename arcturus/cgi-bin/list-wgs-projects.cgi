#!/usr/local/bin/perl

use WrapDBI;
use CGI;

$cgi = new CGI;

$debug = $cgi->param('debug');
$showreadcount = $cgi->param('showreadcount');
$aspedsince = $cgi->param('aspedsince');

if (defined($aspedsince)) {
    undef $aspedsince unless $aspedsince =~ /^\d+$/;
}

print "Content-Type: text/html\n\n";

# List of schemas to exclude
%exclude = ( 'CBRIG' => 1,
	     'MOUSE' => 1,
	     'ZFISH' => 1
	     );

$title = "List of projects in the WGS database";

print "<HTML>\n<HEAD>\n";
print "<TITLE>$title</TITLE>\n";
print "</HEAD>\n<BODY BGCOLOR=\"#FFFFFF\">\n";

$dbh = WrapDBI->connect('pathlook', {PrintError => 0, RaiseError => 0});
&db_die("Unable to connect to database") unless $dbh;

$query = "SELECT owner FROM ALL_TABLES WHERE table_name='PROJECT' ORDER BY owner";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

while(@ary = $sth->fetchrow_array()) {
    ($schema, $junk) = @ary;
    push @schemas, $schema unless $exclude{$schema};
}

$sth->finish();

print "<TABLE>\n";
print "<TR>\n  <TH ALIGN=LEFT>Schema</TH>\n  <TH ALIGN=LEFT>Project ID</TH>\n  ";
print "<TH ALIGN=LEFT>Project</TH>\n  <TH ALIGN=RIGHT>Reads</TH>\n  <TH ALIGN=RIGHT>Asped in last 14 days</TH>\n</TR>\n";

while ($schema = shift @schemas) {
    $query = "SELECT projid,projname FROM $schema.PROJECT ORDER BY projid";
    $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed", "</TABLE>");

    $sth->execute();
    &db_die("execute($query) failed", "</TABLE>");

    $nrow = 0;

    while(@ary = $sth->fetchrow_array()) {
	($projid, $project, $junk) = @ary;
	print "<TR>\n  <TD>";
	print (($nrow > 0) ? "&nbsp;" : $schema);
	$nrow++;

	print "</TD>\n  <TD>$projid</TD>\n  <TD>$project</TD>\n";

	if ($showreadcount) {
	    $query2 = "SELECT COUNT(*) FROM $schema.EXTENDED_READ WHERE projid=$projid AND ".
		"PROCESSSTATUS='PASS'";

	    $sth2 = $dbh->prepare($query2);

	    if ($DBI::err) {
		print "  <TD><STRONG>Cannot show read count:<BR>$DBI::errstr</STRONG></TD>\n";
	    } else {
		$sth2->execute();

		@ary2 = $sth2->fetchrow_array();

		($nreads, $junk) = @ary2;

		print "  <TD ALIGN=RIGHT>$nreads</TD>\n";

		$sth2->finish();
	    }
	}

	if ($aspedsince) {
	    $query3 = "SELECT COUNT(*) FROM $schema.EXTENDED_READ WHERE projid=$projid AND ".
		"PROCESSSTATUS='PASS' AND asped>SYSDATE-$aspedsince";

	    $sth3 = $dbh->prepare($query3);

	    if ($DBI::err) {
		print "  <TD><STRONG>Cannot show read count:<BR>$DBI::errstr</STRONG></TD>\n";
	    } else {
		$sth3->execute();

		@ary3 = $sth3->fetchrow_array();

		($nreads, $junk) = @ary3;

		print "  <TD ALIGN=RIGHT>$nreads</TD>\n";

		$sth3->finish();
	    }
	}

	print "<TR>\n";
    }

    $sth->finish();
}

print "</TABLE>\n";

print "</BODY>\n</HTML>\n";

exit(0);

sub db_die {
    my $msg = shift;
    my $endtag = shift;
    return unless $DBI::err;
    print $endtag,"\n" if $endtag;
    print "<FONT COLOR=\"#FF0000\">Oracle error: $msg $DBI::err ($DBI::errstr)</FONT>\n";
    print "</BODY>\n</HTML>\n";
    exit(0);
}
