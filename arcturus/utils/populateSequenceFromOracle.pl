#!/usr/local/bin/perl

use DataSource;
use DBI;
use Compress::Zlib;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $schema = shift @ARGV if ($nextword eq '-schema');

    $limit = shift @ARGV if ($nextword eq '-limit');

    $debug = 1 if ($nextword eq '-debug');
}

$debug = 0 unless defined($debug);

die "You must specify the organism" unless defined($organism);

$instance = 'prod' unless defined($instance);
$schema = $organism unless defined($schema);

$mysqlds = new DataSource(-instance => $instance,
			  -organism => $organism);

$url = $mysqlds->getURL();
print STDERR "The MySQL URL is $url\n";

$dbh = $mysqlds->getConnection();

unless (defined($dbh)) {
    print STDERR "MySQL: CONNECT FAILED: $DBI::errstr\n";
    exit(1);
}

$oracleds = new DataSource(-instance => $instance,
			   -organism => 'PATHLOOK');

$url = $oracleds->getURL();
print STDERR "The Oracle URL is $url\n";

$oradbh = $oracleds->getConnection();

unless (defined($oradbh)) {
    print STDERR "Oracle: CONNECT FAILED: $DBI::errstr\n";
    exit(1);
}

print STDERR "Making list of reads in Arcturus ...\n";

$query = "select read_id,readname,slength from READS";

$query .= " LIMIT $limit" if defined($limit);

$sth = $dbh->prepare($query);
$sth->execute();

$nfound = 0;

printf STDERR "%8d", $nfound;
$format = "\010\010\010\010\010\010\010\010%8d";

while (@ary = $sth->fetchrow_array()) {
    push @reads, [@ary];
    $nfound++;
    printf STDERR $format, $nfound if (($nfound % 50) == 0);
}

printf STDERR $format, $nfound;

$sth->finish();

print STDERR "\nFound ",scalar(@reads)," reads.\n";

$oradbh->{'LongReadLen'} = 32768;

$sth_readid = $oradbh->prepare(qq[select readid
				  from $schema.read
				  where readname=?]);

$sth_seqid = $oradbh->prepare(qq[select seqid
				 from $schema.read2seq
				 where readid = ?]);

$sth_dna = $oradbh->prepare(qq[select dna
			       from $schema.sequence
			       where seqid = ?]);

$sth_qual = $oradbh->prepare(qq[select qual
				from $schema.basequality
				where seqid = ?]);

$sth_insert = $dbh->prepare(qq[insert into SEQUENCE(read_id,sequence,quality)
			       values(?,?,?)]);

print STDERR "Copying sequence and base quality data to Arcturus ...\n";

$nfound = 0;
$ntotal = 0;
$nbad = 0;
$fmt = "%8d %8d %8d";

$eight = "\010\010\010\010\010\010\010\010";
$bs = "\010";
$format = $eight . $bs . $eight . $bs . $eight . $fmt;

printf STDERR $fmt, $ntotal, $nfound, $nbad unless $debug;

while ($readinfo = shift @reads) {
    ($arcturusid, $readname, $seqlen) = @{$readinfo};

    $ntotal++;

    $sth_readid->execute($readname);

    printf STDERR "%8d %-20s %4d", $arcturusid, $readname, $seqlen
	if $debug;

    ($oracleid) = $sth_readid->fetchrow_array();

    if (defined($oracleid)) {
	$nfound++;

	print STDERR " READID=$oracleid" if $debug;

	$sth_seqid->execute($oracleid);

	($seqid) = $sth_seqid->fetchrow_array();

	print STDERR " SEQID=$seqid" if ($debug && defined($seqid));

	if (defined($seqid)) {
	    $sth_dna->execute($seqid);

	    #$res = $sth_dna->fetchrow_hashref("NAME_lc");
	    #$dna = $res->{'dna'};

	    ($dna) = $sth_dna->fetchrow_array();

	    $dnaok = defined($dna) && ($seqlen == length($dna));

	    print STDERR " DNALEN=",length($dna)
		if ($debug && defined($dna));

	    $dna = compress($dna) if defined($dna);

	    $sth_qual->execute($seqid);

	    #$res = $sth_qual->fetchrow_hashref("NAME_lc");
	    #$qual = $res->{'qual'};

	    ($qual) = $sth_qual->fetchrow_array();

	    $qualok = defined($qual) && ($seqlen == length($qual));

	    print STDERR " BQLEN=", length($qual)
		if ($debug && defined($qual));

	    $qual = compress($qual) if defined($qual);

	    $nbad++ unless ($dnaok && $qualok);

	    if (defined($dna) || defined($qual)) {
		$sth_insert->execute($arcturusid, $dna, $qual);
	    }
	}
    }

    print STDERR "\n" if $debug;

    printf STDERR $format, $ntotal, $nfound, $nbad
	if (!$debug && ($ntotal%50 == 0));
}

printf STDERR $format, $ntotal, $nfound, $nbad unless $debug;

print STDERR "\n";

$sth_readid->finish();
$sth_seqid->finish();
$sth_dna->finish();
$sth_qual->finish();

$sth_insert->finish();

$dbh->disconnect;
$oradbh->disconnect();

exit(0);
