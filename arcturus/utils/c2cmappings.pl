#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;
use Compress::Zlib;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigids;
my $logfile;
my $outfile;
my $loose = 0;
my $align = 0;
my $terse = 0;
my $newmappingtable;
my $newsegmenttable;
my %seqdb;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigids = shift @ARGV if ($nextword eq '-contigs');
    $logfile  = shift @ARGV if ($nextword eq '-log');
    $outfile  = shift @ARGV if ($nextword eq '-out');
    $loose    = 1 if ($nextword eq '-loose');
    $align    = 1 if ($nextword eq '-align');
    $terse    = 1 if ($nextword eq '-terse');

    if ($nextword eq '-saveto') {
	($newmappingtable,$newsegmenttable) = split(/,/, shift @ARGV);
    }
}

unless (defined($instance) && defined($organism)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $query = "SELECT contig_id,nreads,length,updated FROM CONTIG";

$query .= " WHERE contig_id IN ($contigids)" if defined($contigids);

my $contig_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "SELECT age,parent_id,cstart,cfinish,direction FROM C2CMAPPING WHERE contig_id = ? ORDER BY cstart ASC";

my $parent_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "SELECT count(*) FROM C2CMAPPING WHERE contig_id = ?";

my $parentcount_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $seq_stmt; 

if ($align) {
    $query = "SELECT sequence FROM CONSENSUS WHERE contig_id = ?";
    $seq_stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");
}

$query = "SELECT seq_id,mapping_id,cstart,cfinish,direction FROM MAPPING WHERE contig_id = ? ORDER BY cstart ASC";

my $map_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "SELECT cstart,rstart,length FROM SEGMENT WHERE mapping_id = ? AND length > 1 ORDER BY rstart ASC";

my $seg_stmt =  $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $newmapping_stmt;
my $newsegment_stmt;
my $saving = 0;

if (defined($newmappingtable) && defined($newsegmenttable)) {
    $query = "INSERT INTO $newmappingtable(age,contig_id,parent_id,cstart,cfinish,direction)" .
	" VALUES(?,?,?,?,?,?)";

    $newmapping_stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $query = "INSERT INTO $newsegmenttable(mapping_id, cstart, pstart, length)" .
	" VALUES(?,?,?,?)";

    $newsegment_stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $saving = 1;
}

my ($logfh, $outfh);

if (defined($logfile)) {
    $logfh = new FileHandle("> $logfile");
} else {
    $logfh = new FileHandle(">&STDERR");
}

if (defined($outfile)) {
    $outfh = new FileHandle("> $outfile");
} else {
    $outfh = new FileHandle(">&STDOUT");
}

$contig_stmt->execute();

while (my ($contigid, $ctglen, $nreads, $updated) = $contig_stmt->fetchrow_array()) {
    print $logfh "PROCESSING CONTIG: $contigid\n\n";
    print $outfh "PROCESSING CONTIG: $contigid\n\n";

    $parentcount_stmt->execute($contigid);

    my ($nparents) = $parentcount_stmt->fetchrow_array();

    $parentcount_stmt->finish();

    if ($nparents < 1) {
	print $logfh "--- NO CHILDREN ---\n\n";
	print $outfh "--- NO CHILDREN ---\n\n";
	next;
    }

    my $mappings = &getReadToContigMappings($map_stmt, $seg_stmt, $contigid);

    my $masterseq;

    if ($align) {
	$masterseq = $seqdb{$contigid};

	unless (defined($masterseq)) {
	    $seq_stmt->execute($contigid);
	    ($masterseq) = $seq_stmt->fetchrow_array();
	    $masterseq = uncompress($masterseq);
	    $seqdb{$contigid} = $masterseq;
	    $seq_stmt->finish();
	}
    }

    $parent_stmt->execute($contigid);

    while (my ($age, $parentid, $cstart, $cfinish, $direction) = $parent_stmt->fetchrow_array()) {
	print $logfh "Parent contig: $parentid (age $age)";
	if (defined($cstart) && defined($cfinish) && defined($direction)) {
	    print $logfh "      Mapping: $cstart $cfinish $direction\n";
	} else {
	    print $logfh "      --- NO MAPPING ---\n";
	}

	print $logfh "\n";

	my $newMappings = &getReadToContigMappings($map_stmt, $seg_stmt, $parentid);

	my $segments = [];
	my $sense;

	foreach my $seqid (keys %{$newMappings}) {
	    my $oldmapping = $mappings->{$seqid};
	    my $newmapping = $newMappings->{$seqid};
	    
	    my $newsegs;
	    
	    ($newsegs, $sense) = &processMappings($seqid, $oldmapping, $newmapping, $logfh, $loose)
		if defined($oldmapping);

	    push @{$segments}, @{$newsegs};
	    
	    print $logfh "\n";
	}

	&normaliseMappings($segments);
	
	my @sortedsegments = sort byOldStartThenFinish @{$segments};

	print $logfh "\nOVERALL MAPPING:\n\n";

	print $logfh "RAW SEGMENTS\n\n";

	&displaySegments(\@sortedsegments, $logfh);

	$segments = &mergeContigSegments(\@sortedsegments, $sense, $loose);

	print $logfh "\n\nMERGED\n\n";

	&displaySegments($segments, $logfh);

	print $logfh "\n\n";

	print $outfh "CONTIG $contigid PARENT $parentid SENSE $sense\n";
	&displaySegments($segments, $outfh);

	if ($saving) {
	    my $newcstart = $segments->[0]->[0];
	    my $nsegs = scalar(@{$segments});
	    my $newcfinish = $segments->[$nsegs - 1]->[1];

	    my $rc = $newmapping_stmt->execute($age, $contigid, $parentid,
					       $newcstart, $newcfinish, $sense);

	    if (defined($rc) && ($rc == 1)) {
		my $newmappingid = $dbh->{'mysql_insertid'};

		$newmapping_stmt->finish();

		foreach my $newsegment (@{$segments}) {
		    my $newcstart = $newsegment->[0];
		    my $newpstart = $newsegment->[2];
		    my $newlength = $newsegment->[1] - $newcstart + 1;

		    my $rc2 = $newsegment_stmt->execute($newmappingid, $newcstart, $newpstart, $newlength);

		    if (!defined($rc2) || ($rc2 != 1)) {
			print $logfh "*** ERROR SAVING TO $newsegmenttable (" .
			    "$newmappingid, $newcstart, $newpstart, $newlength): ",
			    $DBI::errstr, "\n";
		    }
		}
	    } else {
		print $logfh "*** ERROR SAVING TO $newmappingtable (" .
		    "$age, $contigid, $parentid,$newcstart, $newcfinish, $sense): ",
		    $DBI::errstr, "\n";
	    }
	}

	if ($align) {
	    my $parentseq = $seqdb{$parentid};

	    unless (defined($parentseq)) {
		$seq_stmt->execute($parentid);
		($parentseq) = $seq_stmt->fetchrow_array();
		$parentseq = uncompress($parentseq);
		$seqdb{$parentid} = $parentseq;
		$seq_stmt->finish();
	    }

	    foreach my $segment (@{$segments}) {
		print $outfh "\n\n";
		&displayAlignment($segment, $masterseq, $parentseq, 50, $sense, $outfh, $terse);
	    }
	}
	
	print $outfh "\n\n";
    }
}

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contigs\tComma-separated list of contig IDs [default: all contigs]\n";
    print STDERR "-log\t\tName of log file [default: standard error]\n";
    print STDERR "-out\t\tName of output file [default: standard output]\n";
    print STDERR "-loose\t\tAllow merging of non-contiguous contig-to-contig segments\n";
    print STDERR "-align\t\tCalculate and display contig-to-contig sequence alignments\n";
    print STDERR "-terse\t\tOnly display discrepant contig-to-contig alignments\n";
    print STDERR "-saveto\t\tComma-separated names of mapping and segment tables to save data\n";
}

sub getReadToContigMappings {
    my $map_stmt = shift;
    my $seg_stmt = shift;
    my $contigid = shift;

    my $mappings = {};

    $map_stmt->execute($contigid);

    while (my ($seqid,$mappingid,$cstart,$cfinish,$direction) = $map_stmt->fetchrow_array()) {
	my $entry = [$cstart, $cfinish, $direction];

	$seg_stmt->execute($mappingid);

	my $segments = [];

	while (my ($segcstart, $segrstart, $seglength) = $seg_stmt->fetchrow_array()) {
	    my $segcfinish = $segcstart + $seglength - 1;
	    
	    my $segrfinish;

	    if ($direction eq 'Forward') {
		$segrfinish = $segrstart + ($seglength - 1);
	    } else {
		$segrfinish = $segrstart - ($seglength - 1);
	    }

	    push @{$segments}, [$segcstart, $segcfinish, $segrstart, $segrfinish];
	}
	
	$seg_stmt->finish();

	push @{$entry}, $segments;

	$mappings->{$seqid} = $entry;
    }

    $map_stmt->finish();

    return $mappings;
}

sub processMappings {
    my $seqid = shift;
    my $oldmapping = shift;
    my $newmapping = shift;
    my $logfh = shift;
    my $loose = shift || 0;

    my ($oldcstart, $oldcfinish, $olddirection, $oldsegments) = @{$oldmapping};

    my ($newcstart, $newcfinish, $newdirection, $newsegments) = @{$newmapping};

    print $logfh "SEQUENCE $seqid\n";

    my $format = "%3s  %8d  %8d  %4d  %s\n";

    printf $logfh $format, "OLD", $oldcstart, $oldcfinish, scalar(@{$oldsegments}), $olddirection;
    printf $logfh $format, "NEW", $newcstart, $newcfinish, scalar(@{$newsegments}), $newdirection;

    my $sense;

    if (($olddirection eq 'Forward') xor ($newdirection eq 'Forward')) {
	# Counter-aligned contigs
	$sense = 'Reverse';
    } else {
	# Co-aligned contigs
	$sense = 'Forward';
    }

    print $logfh "SENSE: $sense\n\n";

    my $c2csegments = &processSegments($oldsegments, $olddirection, $newsegments, $newdirection, $logfh);

    print $logfh "SEGMENTS BEFORE MERGING:\n\n";

    &displaySegments($c2csegments, $logfh);

    $c2csegments = &mergeSegments($c2csegments, $olddirection, $newdirection, $loose);

    print $logfh "\nSEGMENTS AFTER MERGING:\n\n";

    &displaySegments($c2csegments, $logfh);

    return ($c2csegments, $sense);
}

sub processSegments {
    my $oldsegments = shift;
    my $olddirection = shift;
    my $newsegments = shift;
    my $newdirection = shift;
    my $logfh = shift;

    my @oldsegs = sort byReadStart @{$oldsegments};

    my @newsegs = sort byReadStart @{$newsegments};

    my $segments = [];

    foreach my $oldseg (@oldsegs) {
	foreach my $newseg (@newsegs) {
	    next unless (my $ovlap = &overlap($oldseg, $newseg));

	    my ($rstart, $rfinish) = @{$ovlap};

	    my $olddelta;

	    if ($olddirection eq 'Forward') {
		$olddelta = $oldseg->[0] - $oldseg->[2];
	    } else {
		$olddelta = $oldseg->[0] + $oldseg->[2];
	    }

	    my $newdelta;

	    if ($newdirection eq 'Forward') {
		$newdelta = $newseg->[0] - $newseg->[2];
	    } else {
		$newdelta = $newseg->[0] + $newseg->[2];
	    }

	    my $delta;

	    if (($olddirection eq 'Forward') xor ($newdirection eq 'Forward')) {
		# Counter-aligned contigs
		$delta = $newdelta + $olddelta;
	    } else {
		# Co-aligned contigs
		$delta = $newdelta - $olddelta;
	    }

	    my ($oldcstart, $oldcfinish) = &readToContig($rstart, $rfinish, $oldseg, $olddirection);

	    my ($newcstart, $newcfinish) = &readToContig($rstart, $rfinish, $newseg, $newdirection);

	   push @{$segments}, [$oldcstart, $oldcfinish, $newcstart, $newcfinish, $delta];
	}
    }

    return $segments;
}

sub mergeContigSegments {
    my $segments = shift;
    my $newdirection = shift;
    my $loose = shift || 0;

    my $nsegs = scalar(@{$segments});

    my $curseg = 0;

    for (my $nextseg = $curseg + 1; $nextseg < $nsegs; $nextseg++) {
	if ($segments->[$curseg]->[4] == $segments->[$nextseg]->[4]) {
	    if ($segments->[$curseg]->[1] < $segments->[$nextseg]->[1]) {
		$segments->[$curseg] = &doMerge($segments->[$curseg], $segments->[$nextseg], 'Forward', $newdirection);
	    }
	} else {
	    $curseg++;
	    $segments->[$curseg] = $segments->[$nextseg];
	}
    }

    my $newsegs = [];

    for ($nsegs = 0; $nsegs <= $curseg; $nsegs++) {
	push @{$newsegs}, $segments->[$nsegs];
    }

    return $newsegs;
}

sub mergeSegments {
    my $segments = shift;
    my $olddirection = shift;
    my $newdirection = shift;
    my $loose = shift || 0;

    my $nsegs = scalar(@{$segments});

    my $curseg = 0;

    for (my $nextseg = $curseg + 1; $nextseg < $nsegs; $nextseg++) {
	if (&canMerge($segments->[$curseg], $segments->[$nextseg], $olddirection, $newdirection, $loose)) {
	    $segments->[$curseg] = &doMerge($segments->[$curseg], $segments->[$nextseg], $olddirection, $newdirection);
	} else {
	    $curseg++;
	    $segments->[$curseg] = $segments->[$nextseg];
	}
    }

    my $newsegs = [];

    for ($nsegs = 0; $nsegs <= $curseg; $nsegs++) {
	push @{$newsegs}, $segments->[$nsegs];
    }

    return $newsegs;
}

sub canMerge {
    my $leftseg = shift;
    my $rightseg = shift;
    my $olddirection = shift;
    my $newdirection = shift;
    my $loose = shift || 0;

    return 0 unless ($leftseg->[4] == $rightseg->[4]);

    return 1 if $loose;

    my $olddiff = ($olddirection eq 'Forward') ?
	($rightseg->[0] - $leftseg->[1] - 1) : ($leftseg->[1] - $rightseg->[0] - 1);

    my $newdiff = ($newdirection eq 'Forward') ?
	($rightseg->[2] - $leftseg->[3] - 1) : ($leftseg->[3] - $rightseg->[2] - 1);

    return ($olddiff <= 0 && $newdiff <= 0);
}

sub doMerge {
    my $leftseg = shift;
    my $rightseg = shift;
    my $olddirection = shift;
    my $newdirection = shift;

    return [$leftseg->[0], $rightseg->[1], $leftseg->[2], $rightseg->[3], $leftseg->[4]];
}

sub displaySegments {
    my $segments = shift;
    my $fh = shift;
    my $nsegs = scalar(@{$segments});

    for (my $segnum = 0; $segnum < $nsegs; $segnum++) {
	my $segment = $segments->[$segnum];
	printf $fh "%8d %8d   %8d %8d   %8d\n", @{$segment};
    }
}

sub displayAlignment {
    my $segment = shift;
    my $childseq = shift;
    my $parentseq = shift;
    my $linelen = shift;
    my $sense = shift;
    my $fh = shift;

    my $forward = $sense eq 'Forward';

    my ($cstart, $cfinish, $pstart, $pfinish, $offset) = @{$segment};

    print $fh "SEGMENT [$cstart, $cfinish] --> [$pstart, $pfinish]\n\n";

    ($pstart, $pfinish) = ($pfinish, $pstart) if ($pstart > $pfinish);

    my $cseq = substr($childseq,  $cstart - 1, $cfinish - $cstart + 1);
    my $pseq = substr($parentseq, $pstart - 1, $pfinish - $pstart + 1);

    if ($sense ne 'Forward') {
	$pseq = scalar reverse $pseq;
	$pseq =~ tr/ACGTacgt/TGCAtgca/;
    }

    my $seqlen = length($cseq);

    if ($cseq eq $pseq) {
	print $fh "MISMATCHES 0 $seqlen\n";
    } else {
	my $diffcount = &countDiffs($cseq, $pseq);
	print $fh "MISMATCHES $diffcount $seqlen\n";
    }

    unless ($terse) {
	print $fh "\n";

	while (length($cseq)) {
	    printf $fh "%6d  ", $cstart;
	    my $subseq = substr($cseq, 0, $linelen);
	    $seqlen = length($subseq);
	    print $fh $subseq;
	    $cseq = substr($cseq, $linelen);
	    printf $fh "  %6d\n", $cstart + $seqlen - 1;
	    $cstart += $linelen;

	    printf $fh "%6d  ", $forward ? $pstart : $pfinish;
	    $subseq = substr($pseq, 0, $linelen);
	    my $seqlen = length($subseq);
	    print $fh $subseq;
	    $pseq = substr($pseq, $linelen);
	    if ($forward) {
		printf $fh "  %6d\n", $pstart + $seqlen - 1;
		$pstart += $linelen;
	    } else {
		printf $fh "  %6d\n", $pfinish - $seqlen + 1;
		$pfinish -= $linelen;
	    }

	    print $fh "\n";
	}
    }
}

sub countDiffs {
    my $seqa = shift;
    my $seqb = shift;

    my ($diffs, $chara, $charb);

    $diffs = 0;

    while (($chara = chop($seqa)) && ($charb = chop($seqb))) {
	$diffs += 1 if ($chara ne $charb);
    }

    return $diffs;
}

sub byReadStart ($$) {
    my $sega = shift;
    my $segb = shift;

    return $sega->[2] <=> $segb->[2];
}

sub byOldStartThenFinish ($$) {
    my $sega = shift;
    my $segb = shift;

    my $cond = $sega->[0] <=> $segb->[0];

    return ($cond != 0) ? $cond : $sega->[1] <=> $segb->[1];
}

sub overlap {
    my $sega = shift;
    my $segb = shift;

    my ($rstarta, $rfinisha) = ($sega->[2], $sega->[3]);

    ($rstarta, $rfinisha) = ($rfinisha, $rstarta) if ($rstarta > $rfinisha);

    my ($rstartb, $rfinishb) = ($segb->[2], $segb->[3]);

    ($rstartb, $rfinishb) = ($rfinishb, $rstartb) if ($rstartb > $rfinishb);

    return 0 if (($rfinisha < $rstartb) || ($rfinishb < $rstarta));

    my $left = ($rstarta > $rstartb) ? $rstarta : $rstartb;

    my $right = ($rfinisha < $rfinishb) ? $rfinisha : $rfinishb;

    return [$left, $right];
}

sub readToContig {
    my ($rstart, $rfinish, $segment, $direction, $junk) = @_;

    if ($direction eq 'Forward') {
	return ($segment->[0] + ($rstart - $segment->[2]),
		$segment->[0] + ($rfinish - $segment->[2]));
    } else {
	return ($segment->[0] - ($rstart - $segment->[2]),
		$segment->[0] - ($rfinish - $segment->[2]));
    }
}

sub normaliseMappings {
    my $segments = shift;

    my $nsegs = scalar(@{$segments});

    for (my $segnum = 0; $segnum < $nsegs; $segnum++) {
	my $segment = $segments->[$segnum];

	if ($segment->[0] > $segment->[1]) {
	    $segments->[$segnum] = [$segment->[1], $segment->[0], $segment->[3], $segment->[2], $segment->[4]];
	}
    }

    return $segments;
}
