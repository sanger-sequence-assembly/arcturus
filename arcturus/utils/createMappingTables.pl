#!/usr/local/bin/perl

use DataSource;
use DBI;
use Compress::Zlib;

$debug = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $debug = 1 if ($nextword eq '-debug');
}

die "You must specify the organism" unless defined($organism);

$instance = 'prod' unless defined($instance);

$mysqlds = new DataSource(-instance => $instance,
			  -organism => $organism);

$url = $mysqlds->getURL();
print STDERR "The MySQL URL is $url\n";

$dbh = $mysqlds->getConnection();

unless (defined($dbh)) {
    print STDERR "MySQL: CONNECT FAILED: $DBI::errstr\n";
    exit(1);
}

$query = "select contig_id from CONTIGS";

$sth_contigs = $dbh->prepare($query);
$sth_contigs->execute();

$query = "select distinct(read_id) from READS2CONTIG where contig_id=?";

$sth_reads = $dbh->prepare($query);

$query = "select pcstart,pcfinal,prstart,prfinal,label" .
    " from READS2CONTIG where contig_id=? and read_id=?";

$sth_segments = $dbh->prepare($query);

$query = "insert into MAPPING(contig_id,read_id) values(?,?)";

$sth_new_mapping = $dbh->prepare($query);

$query = "insert into MAPPINGSEGMENT(mapping_id,pcstart,pcfinal,prstart,prfinal,label)" .
    " values(?,?,?,?,?,?)";

$sth_new_segment = $dbh->prepare($query);

$ncontigs = 0;
$nreads = 0;
$nmappings = 0;

$fmt = "%8d %8d %8d";

$eight = "\010\010\010\010\010\010\010\010";
$bs = "\010";
$format = $eight . $bs . $eight . $bs . $eight . $fmt;

printf STDERR $fmt, $ncontigs, $nreads, $nmappings;

while (($contigid) = $sth_contigs->fetchrow_array()) {
    $ncontigs++;

    $sth_reads->execute($contigid);

    while (($readid) = $sth_reads->fetchrow_array()) {
	$nreads++;

	$nrows = $sth_new_mapping->execute($contigid, $readid);

	$mappingid = $dbh->{'mysql_insertid'};

	$sth_segments->execute($contigid, $readid);

	while (($pcstart,$pcfinal,$prstart,$prfinal,$label) =
	       $sth_segments->fetchrow_array()) {
	    $sth_new_segment->execute($mappingid,$pcstart,$pcfinal,$prstart,$prfinal,$label);
	    $nmappings++;
	}

	printf STDERR $format, $ncontigs, $nreads, $nmappings
	    if (($nreads % 50) == 0);
    }
}

printf STDERR $format, $ncontigs, $nreads, $nmappings;

print STDERR "\n";

$sth_contigs->finish();
$sth_reads->finish();
$sth_mappings->finish();

$sth_new_mapping->finish();
$sth_new_segment->finish();

$dbh->disconnect;

exit(0);
