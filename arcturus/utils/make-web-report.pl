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

my $bigbrother = 0;

my $minlen;
my $filename;
my $caption;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $bigbrother = 1 if ($nextword eq '-bigbrother');

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

my $description = $ds->getDescription() || "$instance:$organism";

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $prefix = lc($organism);

my $dateline = &makeDateline();

&makeHeader($instance, $organism, $description);

&makeIndexPage($prefix, $description);

my $fhSection = new FileHandle("${prefix}-project-index.html", "w");

print $fhSection "<html><head><title>Project</title></head><body bgcolor=\"#ffffee\">\n";

print $fhSection "<h3>PROJECTS</h3>\n";

print $fhSection "Statistics for each project, from the current contig set.\n";

print $fhSection "<h3>Select contigs by length</h3>\n" if ($minlen == 0);

foreach $minlen (0, 1, 2, 5, 10, 100) {
    $filename = $prefix . "-project-" . ($minlen == 0 ? "all" : "${minlen}kb") . ".html";
    $caption = ($minlen == 0) ? "All contigs" : "$minlen kb or longer";

    print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br>\n";

    print $fhSection "<p>\n" if ($minlen == 0);

    my $fhProject = new FileHandle($filename, "w");

    &makeProjectStats($dbh, $minlen, 0, $fhProject, $dateline, $description);

    $fhProject->close();
}

print $fhSection "<h3>Select contigs by reads</h3>\n";

my $filename = $prefix . "-project-3reads.html";
my $caption = "Three or more reads";

print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br>\n";

my $fhProject = new FileHandle($filename, "w");

&makeProjectStats($dbh, 0, 3, $fhProject, $dateline, $description);

$fhProject->close();

print $fhSection "</body></html>\n";

$fhSection->close();

$fhSection = new FileHandle("${prefix}-contig-index.html", "w");

print $fhSection "<html><head><title>Contig</title></head><body bgcolor=\"#ffffee\">\n";

print $fhSection "<h3>CONTIGS</h3>\n";

print $fhSection "Month-by-month historical view.\n";

print $fhSection "<h3>Select contigs by length</h3>\n";

print $fhSection "Statistics are given for the start of each month,\n";
print $fhSection "for all projects combined.<p>\n";

foreach $minlen (0, 10, 100) {
    $filename = $prefix . "-contig-" . ($minlen == 0 ? "all" : "${minlen}kb") . ".html";
    $caption = ($minlen == 0) ? "All contigs" : "$minlen kb or longer";

    print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br>\n";

    print $fhSection "<p>\n" if ($minlen == 0);

    my $fhContig = new FileHandle($filename, "w");

    &makeContigStats($dbh, $minlen, $fhContig, $dateline, $description);

    $fhContig->close();
}

if ($bigbrother) {
    print $fhSection "<h3>Select contigs by project</h3>\n";

    print $fhSection "Statistics are given for the start of each month,\n";
    print $fhSection "for the selected project.<p>\n";

    my $projects = &enumerateProjects($dbh);

    foreach my $projinfo (@{$projects}) {
	my ($projid, $projname, $projowner) = @{$projinfo};

	if (defined($projowner)) {
	    my @pwinfo = getpwnam($projowner);
	    $projowner = $pwinfo[6] if (scalar(@pwinfo));
	} else {
	    $projowner = "";
	}
	
	$filename = $prefix . "-contig-${projname}.html";
	$caption = $projname;
	
	print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br>\n";
	
	my $fhContig = new FileHandle($filename, "w");
	
	&makeContigStats($dbh, 0, $fhContig, $dateline, $description, $projid, $projname, $projowner);
	
	$fhContig->close();
    }
}

print $fhSection "</body></html>\n";

$fhSection->close();

$fhSection = new FileHandle("${prefix}-read-index.html", "w");

print $fhSection "<html><head><title>Read</title></head><body bgcolor=\"#ffffee\">\n";

print $fhSection "<h3>READS</h3>\n";

print $fhSection "Month-by-month historical view.<p>\n";

$filename = $prefix . "-read-asped.html";
$caption = "All passed reads";

print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br>\n";

my $fhRead = new FileHandle($filename, "w");

&makeReadStats($dbh, $fhRead, $dateline, $description);

$fhRead->close();

print $fhSection "</body></html>\n";

$fhSection->close();

&makeFooter();

$dbh->disconnect();

exit(0);

sub makeHeader {
    my $instance = shift;
    my $organism = shift;
    my $description = shift;

    my $prefix = lc($organism);

    my @lines = ("<HTML>",
		 "<HEAD>",
		 "<TITLE>Progress report for $description</TITLE>",
		 "</HEAD>",
		 "<FRAMESET cols=\"20%,80%\" title=\"\">",
		 "\t<FRAMESET rows=\"30%,70%\" title=\"\">",
		 "\t\t<FRAME src=\"${prefix}-main-index.html\" name=\"indexFrame\" title=\"Index\">",
		 "\t\t<FRAME src=\"${prefix}-project-index.html\" name=\"sectionFrame\" title=\"Section\">",
		 "\t</FRAMESET>",
		 "\t<FRAME src=\"${prefix}-project-all.html\" name=\"pageFrame\" title=\"Page\">",
		 "</FRAMESET>"
		 );

    foreach my $line (@lines) {
	print $line,"\n";
    }
}

sub makeIndexPage {
    my $prefix = shift;
    my $description = shift;

    my $fhIndex = new FileHandle("${prefix}-main-index.html", "w");

    print $fhIndex "<html><head><title>Index</title></head><body bgcolor=\"#ffffee\">\n";

    print $fhIndex "<h3>SECTION</h3>\n";

    print $fhIndex "<a href=\"${prefix}-project-index.html\" target=\"sectionFrame\">Project stats</a><br>\n";
    print $fhIndex "<a href=\"${prefix}-contig-index.html\" target=\"sectionFrame\">Contig stats</a><br>\n";
    print $fhIndex "<a href=\"${prefix}-read-index.html\" target=\"sectionFrame\">Read stats</a>\n";
    
    print $fhIndex "</body></html>\n";

    $fhIndex->close();
}

sub makeFooter {

    my @lines = ("</BODY>",
		 "</HTML>"
		 );

    foreach my $line (@lines) {
	print $line,"\n";
    }
}

sub makeDateline {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);

    $year += 1900;

    my $timestamp = sprintf("%02d:%02d:%02d GMT", $hour, $min, $sec);

    my $dayname = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')[$wday];
    my $mname = ('January','February','March','April','May','June',
		 'July','August','September','October','November','December')[$mon];

    return "This page was generated dynamically at $timestamp on $dayname, $mday $mname $year";
}

sub makeProjectStats {
    my $dbh = shift;
    my $minlen = shift;
    my $minreads = shift;
    my $fh = shift;
    my $dateline = shift;
    my $description = shift;

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

    my $headers = ['PROJECT','CONTIGS','READS','LENGTH','AVERAGE','STD DEV','MAXIMUM'];

    my $caption = ($minreads == 0) ? (($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR LONGER")
	: "CONTIGS WITH $minreads OR MORE READS";

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>$caption</H3>\n";

    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";

    print $fh "<TR>\n";

    print $fh "<TH></TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"3\">CONTIG LENGTH</TH>\n";

    print $fh "</TR>\n";

    print $fh "<TR>\n";

    foreach my $header (@{$headers}) {
	print $fh "<TH>$header</TH>\n";
    }

    print $fh "</TR>\n";

    $minlen *= 1000;

    $sth->execute($minlen, $minreads);

    my $ar = "ALIGN=\"RIGHT\"";

    while (my ($project,$contigs,$nreads,$totlen,$avglen,$stdlen,$maxlen) = $sth->fetchrow_array()) {
	print $fh "<TR>\n";

	print $fh "<TD>$project</TD>\n";
	print $fh "<TD $ar>$contigs</TD>\n";
	print $fh "<TD $ar>$nreads</TD>\n";
	print $fh "<TD $ar>$totlen</TD>\n";
	print $fh "<TD $ar>$avglen</TD>\n";
	print $fh "<TD $ar>$stdlen</TD>\n";
	print $fh "<TD $ar>$maxlen</TD>\n";

	print $fh "</TR>\n";
    }

    print $fh "</TABLE>\n";

    print $fh "<p><em>$dateline</em>\n" if $dateline;

    print $fh "</body></html>\n";

    $sth->finish();
}

sub makeContigStats {
    my $dbh = shift;
    my $minlen = shift;
    my $fh = shift;
    my $dateline = shift;
    my $description = shift;
    my $projid = shift;

    my @mnames = ('January', 'February', 'March', 'April', 'May', 'June',
		  'July', 'August', 'September', 'October', 'November', 'December');

    my $sql = "select year(min(created)),month(min(created)) from CONTIG";

    my $sth = $dbh->prepare($sql);

    $sth->execute();

    my ($year_start, $month_start) = $sth->fetchrow_array();

    $sth->finish();

    $sql = "select year(NOW()),month(NOW())";

    $sth = $dbh->prepare($sql);

    $sth->execute();

    my ($year_end, $month_end) = $sth->fetchrow_array();

    $sth->finish();

    $sql = "select count(*) as contigs,sum(CA.nreads),sum(CA.length),round(avg(CA.length)),round(std(CA.length)),max(CA.length)" .
	" from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)" .
	" on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)" .
	" where CA.created < ?  and CA.nreads > 1 and CA.length >= ? and (C2CMAPPING.parent_id is null or CB.created > ?)";

    $sql .= " and CA.project_id = $projid" if defined($projid);

    $sth = $dbh->prepare($sql);

    my $caption;
    
    if (defined($projid)) {
	my $projname = shift;
	my $projowner = shift;

	$caption = "CONTIGS FOR PROJECT $projname" . (defined($projowner) && length($projowner) > 0 ? " (Owner: $projowner)" : "");
    } else {
	$caption = ($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR MORE";
    }

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>$caption</H3>\n";
   
    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print $fh "<TR>\n";

    print $fh "<TH></TH>\n<TH></TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"3\">CONTIG LENGTH</TH>\n";

    print $fh "</TR>\n";

    my $headers = ['YEAR', 'MONTH', 'CONTIGS', 'READS', 'LENGTH', 'AVERAGE','STD DEV','MAXIMUM'];

    print $fh "<TR>\n";

    foreach my $header (@{$headers}) {
	print $fh "<TH>$header</TH>\n";
    }

    print $fh "</TR>\n";

    my $ar = "ALIGN=\"RIGHT\"";
    my $nbsp = "&nbsp;";

    my $bg;

    my $year = $year_start;
    my $month = $month_start + 1;

    if ($month > 12) {
	$year++;
	$month -= 12;
    }

    $minlen *= 1000;

    while ($year < $year_end || $month < $month_end) {
	$bg = "BGCOLOR=\"#" . (($month%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";

	my $date = sprintf("%04d-%02d-01", $year, $month);

	$sth->execute($date, $minlen, $date);

	my ($contigs, $nreads, $totlen, $avglen, $stdlen, $maxlen) = $sth->fetchrow_array();
	
	($nreads,$totlen,$avglen,$stdlen,$maxlen) = ($nbsp,$nbsp,$nbsp,$nbsp,$nbsp) if ($contigs == 0);

	print $fh "<TR $bg>\n";

	print $fh "<TD>$year</TD>\n";
	print $fh "<TD>$mnames[$month-1]</TD>\n";

	print $fh "<TD $ar>$contigs</TD>\n";
	print $fh "<TD $ar>$nreads</TD>\n";
	print $fh "<TD $ar>$totlen</TD>\n";
	print $fh "<TD $ar>$avglen</TD>\n";
	print $fh "<TD $ar>$stdlen</TD>\n";
	print $fh "<TD $ar>$maxlen</TD>\n";

	print $fh "</TR>\n";

	$month++;

	if ($month > 12) {
	    $year++;
	    $month -= 12;
	}
    }

    print $fh "</TABLE>\n";

    print $fh "<p>This table <strong>excludes</strong> single-read contigs.";

    print $fh "<p><em>$dateline</em>\n" if $dateline;

    print $fh "</body></html>\n";

    $sth->finish();
}

sub enumerateProjects {
    my $dbh = shift;

    my $query = "select project_id,name,owner from PROJECT order by name";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $projects = [];

    while (my ($projid, $projname, $projowner) = $sth->fetchrow_array()) {
	push @{$projects}, [$projid, $projname, $projowner];
    }

    $sth->finish();

    return $projects;
}

sub makeReadStats {
    my $dbh = shift;
    my $fh = shift;
    my $dateline = shift;
    my $description = shift;

    my @mnames = ('January', 'February', 'March', 'April', 'May', 'June',
		  'July', 'August', 'September', 'October', 'November', 'December');

    my $query = "select year(asped) as year,month(asped) as month,count(*) as hits" .
	" from READINFO left join STATUS on (READINFO.status = STATUS.status_id)" .
	" where asped is not null and STATUS.name='PASS'" .
	" group by year,month order by year asc,month asc";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>READS ASPED BY MONTH</H3>\n";
   
    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";

    my $headers = ['YEAR', 'MONTH', 'READS'];

    print $fh "<TR>\n";

    foreach my $header (@{$headers}) {
	print $fh "<TH>$header</TH>\n";
    }

    print $fh "</TR>\n";

    my $ar = "ALIGN=\"RIGHT\"";

    my $bg;

    while (my ($year, $month, $nreads) = $sth->fetchrow_array()) {
	$bg = "BGCOLOR=\"#" . (($year%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";
	
	print $fh "<TR $bg>\n";

	print $fh "<TD>$year</TD>\n";
	print $fh "<TD>$mnames[$month-1]</TD>\n";
	print $fh "<TD $ar>$nreads</TD>\n";

	print $fh "</TR>\n";
    }

    print $fh "</TABLE>\n";

    print $fh "<p><em>$dateline</em>\n" if $dateline;

    print $fh "</body></html>\n";

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
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
}
