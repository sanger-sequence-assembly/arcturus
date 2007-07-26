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

&makeContigStats($dbh);

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

sub makeContigStats {
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

    my $headers = ['PROJECT','READS','LENGTH','AVG LEN','STD LEN','MAX LEN'];

    foreach my $minlen (0, 2, 5, 10, 100) {
	&makeContigTable($sth, $minlen, 0, $headers);
    }

    &makeContigTable($sth, 0, 3, $headers);

    $sth->finish();

    print "<H3>CONTIGS CREATED BY MONTH</H3>\n";

    $query = "select year(created) as year, month(created) as month, count(*)," .
	"sum(nreads), sum(length)" .
	" from CURRENTCONTIGS" .
	" group by year, month" .
	" order by year asc, month asc";

    $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();

    $headers = ['YEAR', 'MONTH', 'READS', 'LENGTH'];

    print "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print "<TR>\n";

    foreach my $header (@{$headers}) {
	print "<TH>$header</TH>\n";
    }

    print "</TR>\n";

    while (my ($year, $month, $nreads, $ctglen) = $sth->fetchrow_array()) {
	print "<TR>\n";

	print "<TD>$year</TD>\n";
	print "<TD>$month</TD>\n";
	print "<TD>$nreads</TD>\n";
	print "<TD>$ctglen</TD>\n";

	print "</TR>\n";
    }

    print "</TABLE>\n";

    $sth->finish();
}
    

sub makeContigTable {
    my $sth = shift;
    my $minlen = shift;
    my $minreads = shift;
    my $headers = shift;

    my $caption = ($minreads == 0) ? (($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR MORE")
	: "CONTIGS WITH $minreads OR MORE READS";

    print "<H3>$caption</H3>\n";

    print "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print "<TR>\n";

    foreach my $header (@{$headers}) {
	print "<TH>$header</TH>\n";
    }

    print "</TR>\n";

    $minlen *= 1000;

    $sth->execute($minlen, $minreads);

    while (my ($project,$nreads,$totlen,$avglen,$stdlen,$maxlen) = $sth->fetchrow_array()) {
	print "<TR>\n";

	print "<TD>$project</TD>\n";
	print "<TD>$nreads</TD>\n";
	print "<TD>$totlen</TD>\n";
	print "<TD>$avglen</TD>\n";
	print "<TD>$stdlen</TD>\n";
	print "<TD>$maxlen</TD>\n";

	print "</TR>\n";
    }

    print "</TABLE>\n";
}

sub makeReadStats {
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
