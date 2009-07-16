#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use FileHandle;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $instance;
my $organism;
my $cafname;
my $caf;
my $quiet = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $cafname  = shift @ARGV if ($nextword eq '-caf');

    $quiet = 1 if ($nextword eq '-quiet');
}

$instance = 'dev' unless defined($instance);

unless (defined($organism) && defined($cafname)) {
    &showUsage();
    exit(1);
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

die "Failed to create ArcturusDatabase" if $adb->errorStatus();

$caf = new FileHandle($cafname);

die "Failed to open CAF file \"$cafname\"" unless defined($caf);

my $dbh = $adb->getConnection();

my $query = "insert into CONTIG(length,nreads,updated,readnamehash) values(?,?,NOW(),?)";

my $sth_newcontig = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into MAPPING(contig_id, seq_id, direction, cstart, cfinish) values(?,?,?,?,?)";

my $sth_newmapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into SEGMENT(mapping_id, cstart, rstart, length) values(?,?,?,?)";

my $sth_newsegment = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $ncontigs = 0;
my $nmappings = 0;
my $nsegments = 0;
my $nlines = 0;

my $format = '%8d %8d %8d %10d';
my $bs = "\010";
my $bs8 = "\010\010\010\010\010\010\010\010";
my $bs10 = "\010\010\010\010\010\010\010\010\010\010";
my $backspace = $bs8 . $bs . $bs8 . $bs . $bs8 . $bs . $bs10;

printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines unless $quiet;

while (my $line = <$caf>) {
    chop($line);

    $nlines++;

    if (!$quiet && ($nlines % 100) == 0) {
	print STDERR $backspace;
	printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
    }

    next unless $line =~ /^Sequence\s+:\s+(\S+)/;

    my $seqname = $1;

    $line = <$caf>;
    $nlines++;

    next unless $line =~ /^Is_contig/;

    my $afdata = {};

    my $ctgstart = undef;
    my $ctgfinish = undef;

    while ($line = <$caf>) {
	$nlines++;

	if (!$quiet && ($nlines % 100) == 0) {
	    print STDERR $backspace;
	    printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
	}

	last if $line =~ /^\s*$/;

	if ($line =~ /^Assembled_from\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
	    my ($readname, $cs, $cf, $rs, $rf) = ($1, $2, $3, $4, $5);

	    ($cs, $cf, $rs, $rf) = ($cf, $cs, $rf, $rs) if ($cf < $cs);

	    my $afrecord = [$cs, $cf, $rs, $rf];

	    $ctgstart = $cs if (!defined($ctgstart) || ($cs < $ctgstart));
	    $ctgfinish = $cf if (!defined($ctgfinish) || ($cf > $ctgfinish));

	    $afdata->{$readname} = [] unless defined($afdata->{$readname});

	    push @{$afdata->{$readname}}, $afrecord;
	}
    }

    my @sortedreadnames = sort keys %{$afdata};

    my $nreads = scalar(@sortedreadnames);

    my $readnamehash = md5(@sortedreadnames);

    my $ctglen = 1 + $ctgfinish - $ctgstart;

    my $rc = $sth_newcontig->execute($ctglen, $nreads, $readnamehash);
    &db_die("sth_newcontig->execute($ctglen, $nreads, readnamehash) failed");

    next unless (defined($rc) && $rc == 1);

    my $contig_id = $dbh->{'mysql_insertid'};

    $sth_newcontig->finish();
    
    foreach my $readname (@sortedreadnames) {
	my $seq_id = $adb->getSequenceIDForRead(readname => $readname);

	if (defined($seq_id)) {
	    my @segments = sort afsort @{$afdata->{$readname}};

	    my $nsegs = scalar(@segments);

	    my $firstsegment = $segments[0];

	    my $lastsegment = $segments[$nsegs - 1];

	    my $csglobal = $firstsegment->[0];

	    my $cfglobal = $lastsegment->[1];

	    my $direction = undef;
	    my $segnum = 0;

	    while (!defined($direction) && ($segnum < $nsegs)) {
		my $afrecord = $segments[$segnum];

		$segnum++;

		my $cdiff = $afrecord->[1] - $afrecord->[0];

		next if ($cdiff == 0);

		my $rdiff = $afrecord->[3] - $afrecord->[2];

		$direction = (($cdiff * $rdiff) > 0) ? 'Forward' : 'Reverse';
	    }

	    $rc = $sth_newmapping->execute($contig_id, $seq_id, $direction, $csglobal, $cfglobal);
	    &db_die("sth_newmapping->execute($contig_id, $seq_id, $direction, $csglobal, $cfglobal) failed");

	    next unless (defined($rc) && $rc == 1);

	    $nmappings++;

	    if (!$quiet && ($nmappings % 50) == 0) {
		print STDERR $backspace;
		printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
	    }

	    my $mapping_id = $dbh->{'mysql_insertid'};

	    $sth_newmapping->finish();

	    foreach my $afrecord (@segments) {
		my ($cs, $cf, $rs, $rf) = @{$afrecord};

		my $seglen = 1 + $cf - $cs;

		$rc = $sth_newsegment->execute($mapping_id, $cs, $rs, $seglen);
		&db_die("sth_newmapping->execute($mapping_id, $cs, $rs, $seglen) failed");

		if (defined($rc) && $rc == 1) {
		    $nsegments++;

		    if (!$quiet && ($nsegments % 50) == 0) {
			print STDERR $backspace;
			printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
		    }
		}
	    }
	} else {
	    print STDERR "$readname not in Arcturus\n";
	}
    }

    $ncontigs++;

    if (!$quiet) {
	print STDERR $backspace;
	printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
    }
}

if (!$quiet) {
    print STDERR $backspace;
    printf STDERR $format, $ncontigs, $nmappings, $nsegments, $nlines;
    print STDERR "\n";
}

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-caf\t\tCAF file name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'dev' (default) or 'prod'\n";
    print STDERR "-maxcontigs\tmaximum number of contigs to load\n";
    print STDERR "-quiet\t\tRun silently\n";
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    #exit(0);
}

sub afsort ($$) {
    my $a = shift;
    my $b = shift;

    return $a->[0] - $b ->[0];
}
