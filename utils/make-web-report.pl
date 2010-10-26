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

my $minlen;
my $filename;
my $caption;

my $minreads = 2;

my @contig_length_cutoffs = (0, 1, 2, 5, 10, 100);

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

my $description = $ds->getDescription() || "$instance:$organism";

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $from_where_clause =
    " from CONTIG as C,PROJECT as P  where C.contig_id in " .
    " (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)" .
    " on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)" .
    " where CA.created < ?  and CA.nreads > 1 and CA.length >= ? and (C2CMAPPING.parent_id is null  or CB.created > ?))".
    "and P.name not in ('BIN','FREEASSEMBLY','TRASH')".
    "and P.project_id = C.project_id";

my $sql = "select count(*) as contigs,sum(C.nreads),sum(C.length),round(avg(C.length)),round(std(C.length)),max(C.length)" .
    $from_where_clause;
print STDERR "$sql\n\n\n";
my $sth_contig_stats = $dbh->prepare($sql);

my $prefix = lc($organism);

my $dateline = &makeDateline();

&makeHeader($instance, $organism, $description);

&makeIndexPage($prefix, $description);

my $fhSection = new FileHandle("${prefix}-project-index.html", "w");

print $fhSection "<html><head><title>Project</title></head><body bgcolor=\"#ffffee\">\n";

print $fhSection "<h3>PROJECTS</h3>\n";

print $fhSection "Statistics for each project, from the current contig set.\n";

print $fhSection "<h3>Select contigs by length</h3>\n<em>(Contigs with $minreads or more reads.)</em>\n<p>\n";

foreach $minlen (@contig_length_cutoffs) {
    $filename = $prefix . "-project-" . ($minlen == 0 ? "all" : "${minlen}kb") . ".html";
    $caption = ($minlen == 0) ? "All contigs" : "$minlen kb or longer";

    print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br/>\n";

    print $fhSection "<br/>\n" if ($minlen == 0);

    my $fhProject = new FileHandle($filename, "w");

    &makeProjectStats($dbh, $minlen, $minreads, $fhProject, $dateline, $description);

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

print $fhSection "Select contigs by minimum length.\n";

print $fhSection "<h3>Monthly summaries</h3>\n";

print $fhSection "Statistics are given for the start of each month,\n";
print $fhSection "for all projects combined.<p>\n";

foreach $minlen (@contig_length_cutoffs) {
    $filename = $prefix . "-contig-" . ($minlen == 0 ? "all" : "${minlen}kb") . "-monthly.html";
    $caption = ($minlen == 0) ? "All contigs" : "$minlen kb or longer";

    print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br/>\n";

    print $fhSection "<br/>\n" if ($minlen == 0);

    my $fhContig = new FileHandle($filename, "w");

    &makeMonthlyContigStats($dbh, $sth_contig_stats, $minlen, $fhContig, $dateline, $description);

    $fhContig->close();
}

print $fhSection "<h3>Weekly summaries</h3>\n";

print $fhSection "Statistics are given for the end of each week,\n";
print $fhSection "for all projects combined.<p>\n";

foreach $minlen (@contig_length_cutoffs) {
    $filename = $prefix . "-contig-" . ($minlen == 0 ? "all" : "${minlen}kb") . "-weekly.html";
    $caption = ($minlen == 0) ? "All contigs" : "$minlen kb or longer";

    print $fhSection "<a href=\"$filename\" target=\"pageFrame\">$caption</a><br/>\n";

    print $fhSection "<br/>\n" if ($minlen == 0);

    my $fhContig = new FileHandle($filename, "w");

    &makeWeeklyContigStats($dbh, $sth_contig_stats, $minlen, $fhContig, $dateline, $description);

    $fhContig->close();
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

$sth_contig_stats->finish();

$dbh->disconnect();

exit(0);

sub makeHeader {
    my $instance = shift;
    my $organism = shift;
    my $description = shift;

    my $prefix = lc($organism);

    my @lines = ("<html>",
		 "<head>",
		 "<title>Progress report for $description</title>",
		 "</head>",
		 #"<body>",
		 "<frameset cols=\"20%,80%\" title=\"\">",
		 "\t<frameset rows=\"20%,80%\" title=\"\">",
		 "\t\t<frame src=\"${prefix}-main-index.html\" name=\"indexFrame\" title=\"Index\" >",
		 "\t\t<frame src=\"${prefix}-project-index.html\" name=\"sectionFrame\" title=\"Section\" >",
		 "\t</frameset>",
		 "\t<frame src=\"${prefix}-project-all.html\" name=\"pageFrame\" title=\"Page\" >",
		 "</frameset>"
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

    my @lines = (#"</body>",
		 "</html>"
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

    my $fields = "C.project_id,P.name,count(*) as contigs," .
	"sum(C.nreads) as `reads`," .
	"sum(C.length) as length," .
	"round(avg(C.length)) as avglen," .
	"round(std(C.length)) as stdlen," .
	"max(C.length) as maxlen";

    my $query = "select $fields from CURRENTCONTIGS C left join PROJECT P using(project_id)" .
	" where length >= ? and nreads >= ? and P.name is not null
	 and P.name not in ('BIN','FREEASSEMBLY','TRASH')" .
	" group by C.project_id order by name asc";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    my $headers = ['PROJECT','CONTIGS','READS','LENGTH','AVERAGE','STD DEV','MAXIMUM','N50'];

    my $caption = ($minreads == 2) ? (($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR LONGER")
	: "CONTIGS WITH $minreads OR MORE READS";

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>$caption</H3>\n";

    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";

    print $fh "<TR>\n";

    print $fh "<TH></TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"4\">CONTIG LENGTH</TH>\n";

    print $fh "</TR>\n";

    print $fh "<TR>\n";

    foreach my $header (@{$headers}) {
	print $fh "<TH>$header</TH>\n";
    }

    print $fh "</TR>\n";

    $minlen *= 1000;

    my $ar = "ALIGN=\"RIGHT\"";

    my $sum_contigs = 0;
    my $sum_nreads = 0;
    my $sum_totlen = 0;
    my $all_maxlen = 0;

    $sql = "select length from CURRENTCONTIGS" .
        " where length > ? and nreads > ? and project_id = ? order by length desc";

    my $sth_contig_lengths = $dbh->prepare($sql);

    $sth->execute($minlen, $minreads);

    while (my ($project_id,$project,$contigs,$nreads,$totlen,$avglen,$stdlen,$maxlen) = $sth->fetchrow_array()) {
	$sum_contigs += $contigs;
	$sum_nreads += $nreads;
	$sum_totlen += $totlen;
	$all_maxlen = $maxlen if ($maxlen > $all_maxlen);

	$sth_contig_lengths->execute($minlen, $minreads, $project_id);

	my $n50 = &get_N50_from_resultset($sth_contig_lengths);

	print $fh "<TR>\n";

	print $fh "<TD>$project</TD>\n";
	print $fh "<TD $ar>$contigs</TD>\n";
	print $fh "<TD $ar>$nreads</TD>\n";
	print $fh "<TD $ar>$totlen</TD>\n";
	print $fh "<TD $ar>$avglen</TD>\n";
	print $fh "<TD $ar>$stdlen</TD>\n";
	print $fh "<TD $ar>$maxlen</TD>\n";
	print $fh "<TD $ar>$n50</TD>\n";

	print $fh "</TR>\n";
    }

    $sth_contig_lengths->finish();

    $sql = "select length from CURRENTCONTIGS C, PROJECT P" .
	" where nreads > 1 and length > ? AND C.PROJECT_ID = P.PROJECT_ID and P.name not in ('BIN','FREEASSEMBLY','TRASH') order by length desc";

    $sth_contig_lengths = $dbh->prepare($sql);

    $sth_contig_lengths->execute($minlen);

    my $n50 = &get_N50_from_resultset($sth_contig_lengths);

    $sth_contig_lengths->finish();

    print $fh "<TR>\n";

    print $fh "<TD><strong>TOTAL</strong></TD>\n";
    print $fh "<TD $ar><strong>$sum_contigs</strong></TD>\n";
    print $fh "<TD $ar><strong>$sum_nreads</strong></TD>\n";
    print $fh "<TD $ar><strong>$sum_totlen</strong></TD>\n";
    print $fh "<TD $ar>&nbsp;</TD>\n";
    print $fh "<TD $ar>&nbsp;</TD>\n";
    print $fh "<TD $ar><strong>$all_maxlen</strong></TD>\n";
    print $fh "<TD $ar><strong>$n50</strong></TD>\n";
    
    print $fh "</TR>\n";

    print $fh "</TABLE>\n";

    print $fh "<p>(Only contigs with $minreads or more reads are included.)\n" if ($minreads > 1);

    print $fh "<p><em>$dateline</em>\n" if $dateline;

    print $fh "</body></html>\n";

    $sth->finish();
}

sub makeMonthlyContigStats {
    my $dbh = shift;
    my $sth_contig_stats = shift;
    my $minlen = shift;
    my $fh = shift;
    my $dateline = shift;
    my $description = shift;

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

    my $caption;
    
    $caption = ($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR MORE";

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>$caption</H3>\n";
   
    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print $fh "<TR>\n";

    print $fh "<TH COLSPAN=\"2\">START OF</TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"4\">CONTIG LENGTH</TH>\n";

    print $fh "</TR>\n";

    my $headers = ['YEAR', 'MONTH', 'CONTIGS', 'READS', 'LENGTH', 'AVERAGE','STD DEV','MAXIMUM','N50'];

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

    while ($year < $year_end || $month <= $month_end) {
	$bg = "BGCOLOR=\"#" . (($month%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";

	my $date = sprintf("%04d-%02d-01", $year, $month);

	$sth_contig_stats->execute($date, $minlen, $date);

	my ($contigs, $nreads, $totlen, $avglen, $stdlen, $maxlen) = $sth_contig_stats->fetchrow_array();
	
	($nreads,$totlen,$avglen,$stdlen,$maxlen) = ($nbsp,$nbsp,$nbsp,$nbsp,$nbsp) if ($contigs == 0);

	my $n50len = &get_N50_for_date($date, $minlen);

	print $fh "<TR $bg>\n";

	print $fh "<TD>$year</TD>\n";
	print $fh "<TD>$mnames[$month-1]</TD>\n";

	print $fh "<TD $ar>$contigs</TD>\n";
	print $fh "<TD $ar>$nreads</TD>\n";
	print $fh "<TD $ar>$totlen</TD>\n";
	print $fh "<TD $ar>$avglen</TD>\n";
	print $fh "<TD $ar>$stdlen</TD>\n";
	print $fh "<TD $ar>$maxlen</TD>\n";
	print $fh "<TD $ar>$n50len</TD>\n";

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
}

sub makeWeeklyContigStats {
    my $dbh = shift;
    my $sth_contig_stats = shift;
    my $minlen = shift;
    my $fh = shift;
    my $dateline = shift;
    my $description = shift;

    my $sql = "select to_days(min(created)),to_days(now()) from CONTIG";

    my $sth = $dbh->prepare($sql);

    $sth->execute();

    my ($day_start, $day_end) = $sth->fetchrow_array();

    $sth->finish();

    my $dow = $day_start % 7;

    $day_start += (7 - $dow);

    $dow = $day_end % 7;

    $day_end += (7 - $dow);

    $sth = $dbh->prepare("select from_days(?),date_format(from_days(?), '%d %b %Y')");

    my $caption;
    
    $caption = ($minlen == 0) ? "ALL CONTIGS" : "CONTIGS $minlen kb OR MORE";

    print $fh "<html><head><title>$caption</title></head><body bgcolor=\"#ffffee\">\n";

    print $fh "<H2>$description</H2>\n";

    print $fh "<H3>$caption</H3>\n";
   
    print $fh "<TABLE  CELLPADDING=\"3\" BORDER=\"1\">\n";
    print $fh "<TR>\n";

    print $fh "<TH></TH>\n<TH COLSPAN=\"3\">TOTAL</TH>\n<TH COLSPAN=\"4\">CONTIG LENGTH</TH>\n";

    print $fh "</TR>\n";

    my $headers = ['WEEK ENDING', 'CONTIGS', 'READS', 'LENGTH', 'AVERAGE','STD DEV','MAXIMUM','N50'];

    print $fh "<TR>\n";

    foreach my $header (@{$headers}) {
	print $fh "<TH>$header</TH>\n";
    }

    print $fh "</TR>\n";

    my $ar = "ALIGN=\"RIGHT\"";
    my $nbsp = "&nbsp;";

    my $bg;


    $minlen *= 1000;

    my $counter = 0;
    my $rows = 0;

    for (my $days = $day_start; $days <= $day_end; $days += 7) {
	$bg = "BGCOLOR=\"#" . (($counter%2 == 0) ? "FFFFEE" : "EEEEDD") . "\"";
	$counter++;

	$sth->execute($days, $days);

	my ($date, $datestr) = $sth->fetchrow_array();



	$sth_contig_stats->execute($date, $minlen, $date);

	my ($contigs, $nreads, $totlen, $avglen, $stdlen, $maxlen) = $sth_contig_stats->fetchrow_array();
	
	if ($rows > 0 || $contigs > 0) { 
	    $rows++;

	    ($nreads,$totlen,$avglen,$stdlen,$maxlen) = ($nbsp,$nbsp,$nbsp,$nbsp,$nbsp) if ($contigs == 0);

	    my $n50len = &get_N50_for_date($date, $minlen);

	    print $fh "<TR $bg>\n";

	    print $fh "<TD>$datestr</TD>\n";

	    print $fh "<TD $ar>$contigs</TD>\n";
	    print $fh "<TD $ar>$nreads</TD>\n";
	    print $fh "<TD $ar>$totlen</TD>\n";
	    print $fh "<TD $ar>$avglen</TD>\n";
	    print $fh "<TD $ar>$stdlen</TD>\n";
	    print $fh "<TD $ar>$maxlen</TD>\n";
	    print $fh "<TD $ar>$n50len</TD>\n";
	    
	    print $fh "</TR>\n";
    }
    }

    print $fh "</TABLE>\n";

    print $fh "<p>This table <strong>excludes</strong> single-read contigs.";

    print $fh "<p><em>$dateline</em>\n" if $dateline;

    print $fh "</body></html>\n";

    $sth->finish();
}

sub get_N50_for_date {
    my $date = shift;
    my $minlen = shift;

    my $from_where_clause =
	" from CONTIG as C where C.contig_id in " .
	" (select distinct CA.contig_id from CONTIG as CA left join (C2CMAPPING,CONTIG as CB)" .
	" on (CA.contig_id = C2CMAPPING.parent_id and C2CMAPPING.contig_id = CB.contig_id)" .
	" where CA.created < ?  and CA.nreads > 1 and CA.length >= ? and (C2CMAPPING.parent_id is null or CB.created > ?))";

    my $sql = "select C.length " . $from_where_clause . " order by C.length desc";

    my $sth_contig_lengths = $dbh->prepare($sql);

    $sth_contig_lengths->execute($date, $minlen, $date);

    my $n50 = &get_N50_from_resultset($sth_contig_lengths);

    $sth_contig_lengths->finish();

    return $n50;
}

sub get_N50_from_resultset {
    my $sth = shift;

    my $lengths = [];

    while (my ($ctglen) = $sth->fetchrow_array()) {
	push @{$lengths}, $ctglen;
    }

    return &get_N50_from_lengths($lengths);
}

# This routine expects a list of contig lengths which are sorted
# in DESCENDING order

sub get_N50_from_lengths {
    my $lengths = shift;

    my $sum_length = 0;

    foreach my $ctglen (@{$lengths}) {
	$sum_length += $ctglen;
    }

    my $target_length = int($sum_length/2);

    #print STDERR "get_N50_from_lengths: list of length ", scalar(@{$lengths}), ", sum_length=$sum_length",
    #", target_length=$target_length\n";

    $sum_length = 0;

     foreach my $ctglen (@{$lengths}) {
	$sum_length += $ctglen;
	#printf STDERR "%10d %8d\n",$sum_length,$ctglen;
	return $ctglen if ($sum_length > $target_length);
    }   

    return 0;
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
