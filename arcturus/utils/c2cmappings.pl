#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigid;
my $logfile;
my $outfile;
my $loose = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigid = shift @ARGV if ($nextword eq '-contig');
    $logfile  = shift @ARGV if ($nextword eq '-log');
    $outfile  = shift @ARGV if ($nextword eq '-out');
    $loose    = 1 if ($nextword eq '-loose');
}

unless (defined($instance) && defined($organism) && defined($contigid)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $mappings = &getReadToContigMappings($dbh, $contigid);

my $query = "SELECT parent_id,cstart,cfinish,direction FROM C2CMAPPING WHERE contig_id = ? ORDER BY cstart ASC";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute($contigid);
&db_die("Failed to execute query \"$query\"");

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

while (my ($parentid, $cstart, $cfinish, $direction) = $stmt->fetchrow_array()) {
    print $logfh "Parent contig: $parentid";
    if (defined($cstart) && defined($cfinish) && defined($direction)) {
	print $logfh "      Mapping: $cstart $cfinish $direction\n";
    } else {
	print $logfh "      --- NO MAPPING ---\n";
    }

    print $logfh "\n";

    my $newMappings = &getReadToContigMappings($dbh, $parentid);

    my $segments = [];
    my $sense;

    foreach my $seqid (keys %{$newMappings}) {
	my $oldmapping = $mappings->{$seqid};
	my $newmapping = $newMappings->{$seqid};

	my $newsegs;

	($newsegs, $sense) = &processMappings($seqid, $oldmapping, $newmapping, $logfh, $loose) if defined($oldmapping);

	push @{$segments}, @{$newsegs};

	print $logfh "\n";
    }

    &normaliseMappings($segments);

    my @sortedsegments = sort byOldStartThenFinish @{$segments};

    $segments = &mergeSegments(\@sortedsegments, 'Forward', $sense, $loose);

    print $logfh "\nOVERALL MAPPING:\n\n";

    &displaySegments($segments, $logfh);

    print $outfh "CONTIG $contigid PARENT $parentid SENSE $sense\n";
    &displaySegments($segments, $outfh);
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
    print STDERR "-contig\t\tID of contig\n";
}

sub getReadToContigMappings {
    my $dbh = shift;
    my $contigid = shift;

    my $mappings = {};

    my $query = "SELECT seq_id,mapping_id,cstart,cfinish,direction FROM MAPPING WHERE contig_id = ? ORDER BY cstart ASC";

    my $seq_stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $seq_stmt->execute($contigid);
    &db_die("Failed to execute query \"$query\"");

    $query = "SELECT cstart,rstart,length FROM SEGMENT WHERE mapping_id = ? ORDER BY rstart ASC";

    my $seg_stmt =  $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    while (my ($seqid,$mappingid,$cstart,$cfinish,$direction) = $seq_stmt->fetchrow_array()) {
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

    $seq_stmt->finish();

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
