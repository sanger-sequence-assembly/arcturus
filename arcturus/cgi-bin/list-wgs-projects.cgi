#!/usr/local/bin/perl

use WrapDBI;

# List of schemas to exclude
%exclude = ( 'MOUSE' => 1,
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
print "<TR>\n  <TH>Schema</TH>\n  <TH>Project ID</TH>\n  <TH>Project</TH>\n</TR>\n";

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
	print "</TD>\n  <TD>$projid</TD>\n  <TD>project</TD>\n<TR>\n";
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
