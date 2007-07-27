#!/usr/local/bin/perl
#
# make-web-report
#
# This script generates a report in HTML format about a specified organism

use strict;

use DBI;
use DataSource;
use FileHandle;

my $instance;
my $organism;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

        if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

&makeHeader($instance, $organism);

print "<H2>Project statistics</H2>\n";

&makeProjectStats($dbh);

print "<P><HR>\n<H2>Contig statistics</H2>\n";

&makeContigStats($dbh);

print "<P><HR>\n<H2>Read statistics</H2>\n";

&makeReadStats($dbh);

&makeFooter();

$dbh->disconnect();

exit(0);

sub makeHeader {
    my $instance = shift;
    my $organism = shift;

    my @lines = ("<HTML>",
		 "<HEAD>",
		 "<TITLE>Progress report for $organism</TITLE>",
		 "</HEAD>",
		 "<BODY BGCOLOR=\"#FFFFEE\">",
		 "<H1>Progress report for $organism</H1>"
		 );

    foreach my $line (@lines) {
	print $line,"\n";
    }
}

sub makeFooter {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);

    $year += 1900;

    my $timestamp = sprintf("%02d:%02d:%02d GMT", $hour, $min, $sec);

    my $dayname = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')[$wday];
    my $mname = ('January','February','March','April','May','June',
		 'July','August','September','October','November','December')[$mon];

    my @lines = ("<HR>",
		 "This page was generated dynamically at $timestamp on $dayname, $mday $mname $year",
		 "</BODY>",
		 "</HTML>"
		 );

    foreach my $line (@lines) {
	print $line,"\n";
    }
}

sub makeProjectStats {
    my $dbh = shift;

    my $fields = "PROJECT.name,count(*) as contigs," .
	"sum(nreads) as `reads`," .
	"sum(length) as length," .
	"round(avg(length)) as avglen," .
	"round(std(length)) as stdlen," .
	"max(length) as maxlen";

    my $query = "select $fields from CURRENTCONTIGS left join PROJECT using(project_id)" .
	" where length >= ? and nreads >= ? and PROJECT.name is not null" .
	" group by CURRENTCONTIGS.project_id order by name asc";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    foreach my $minlen (0, 2, 5, 10, 100) {
	&makeProjectTable($sth, $minlen, 0);
    }

    &makeProjectTable($sth, 0, 3);

    $sth->finish();
}

sub makeProjectTable {
    my $sth = shift;
    my $minlen = shift;
    my $minreads = shift;

    my $headers = ['PROJECT','CONTIGS','READS','LENGTH','AVERAGE','STD DEV','MAXIMUM'];

    my $caption = ($minreads == 0) ? (($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR MORE")
	: "CONTIGS WITH $minreads OR MORE READS";

    print "<H3>$caption</H3>\n";

    print "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";

    print "<TR>\n";

    print "<TH></TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"3\">CONTIG LENGTH</TH>\n";

    print "</TR>\n";

    print "<TR>\n";

    foreach my $header (@{$headers}) {
	print "<TH>$header</TH>\n";
    }

    print "</TR>\n";

    $minlen *= 1000;

    $sth->execute($minlen, $minreads);

    my $ar = "ALIGN=\"RIGHT\"";

    while (my ($project,$contigs,$nreads,$totlen,$avglen,$stdlen,$maxlen) = $sth->fetchrow_array()) {
	print "<TR>\n";

	print "<TD>$project</TD>\n";
	print "<TD $ar>$contigs</TD>\n";
	print "<TD $ar>$nreads</TD>\n";
	print "<TD $ar>$totlen</TD>\n";
	print "<TD $ar>$avglen</TD>\n";
	print "<TD $ar>$stdlen</TD>\n";
	print "<TD $ar>$maxlen</TD>\n";

	print "</TR>\n";
    }

    print "</TABLE>\n";
}

sub makeContigStats {
    my $dbh = shift;

    &makeContigTable($dbh, "CURRENTCONTIGS", "CURRENT CONTIGS");

    &makeContigTable($dbh, "CONTIG", "ALL CONTIGS");
}

sub makeContigTable {
    my $dbh = shift;
    my $table = shift;
    my $caption = shift;

    my @mnames = ('January', 'February', 'March', 'April', 'May', 'June',
		  'July', 'August', 'September', 'October', 'November', 'December');

    print "<H3>$caption CREATED BY MONTH</H3>\n";

    my $query = "select year(created) as year, month(created) as month, count(*)," .
	"sum(nreads), sum(length)" .
	" from $table" .
	" group by year, month" .
	" order by year asc, month asc";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();

    my $headers = ['YEAR', 'MONTH', 'CONTIGS', 'READS', 'LENGTH'];

    print "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print "<TR>\n";

    foreach my $header (@{$headers}) {
	print "<TH>$header</TH>\n";
    }

    print "</TR>\n";

    my $ar = "ALIGN=\"RIGHT\"";

    my $bg;

    while (my ($year, $month, $contigs, $nreads, $ctglen) = $sth->fetchrow_array()) {
	$bg = "BGCOLOR=\"#" . (($year%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";
	
	print "<TR $bg>\n";

	print "<TD>$year</TD>\n";
	print "<TD>$mnames[$month-1]</TD>\n";
	print "<TD $ar>$contigs</TD>\n";
	print "<TD $ar>$nreads</TD>\n";
	print "<TD $ar>$ctglen</TD>\n";

	print "</TR>\n";
    }

    print "</TABLE>\n";

    $sth->finish();
}
    

sub makeReadStats {
    my $dbh = shift;

    my @mnames = ('January', 'February', 'March', 'April', 'May', 'June',
		  'July', 'August', 'September', 'October', 'November', 'December');

    my $query = "select year(asped) as year,month(asped) as month,count(*) as hits" .
	" from READINFO where asped is not null" .
	" group by year,month order by year asc,month asc";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    print "<H3>READS ASPED BY MONTH</H3>\n";
   
    print "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";

    my $headers = ['YEAR', 'MONTH', 'READS'];

    print "<TR>\n";

    foreach my $header (@{$headers}) {
	print "<TH>$header</TH>\n";
    }

    print "</TR>\n";

    my $ar = "ALIGN=\"RIGHT\"";

    my $bg;

    while (my ($year, $month, $nreads) = $sth->fetchrow_array()) {
	$bg = "BGCOLOR=\"#" . (($year%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";
	
	print "<TR $bg>\n";

	print "<TD>$year</TD>\n";
	print "<TD>$mnames[$month-1]</TD>\n";
	print "<TD $ar>$nreads</TD>\n";

	print "</TR>\n";
    }

    print "</TABLE>\n";

    $sth->finish();
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
}
