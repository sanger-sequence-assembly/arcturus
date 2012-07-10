#!/usr/local/bin/perl

while ($nextword = shift) {
    $dirname = shift if ($nextword eq '-dir');
    $minlen  = shift if ($nextword eq '-minlen');
    $minreplen  = shift if ($nextword eq '-minreplen');
    $thresh  = shift if ($nextword eq '-thresh');
}

$dirname = '.' unless defined($dirname);

die "$dirname is not a directory" unless -d $dirname;

$minlen = 1000 unless defined($minlen);
$thresh = 10 unless defined($thresh);
$minreplen = 100 unless defined($minreplen);

die "Unable to open directory $dirname" unless opendir(DIR,$dirname);

@files = grep(/\.(depth|histo)$/, readdir(DIR));

closedir(DIR);

foreach $file (@files) {
    &ProcessFile($dirname, $file, $minlen, $thresh);
}

exit(0);

sub ProcessFile {
    my ($dirname, $file, $minlen, $thresh, $junk) = @_;

    my $seqname = $file;
    $seqname =~ s/\.(depth|histo)$//;

    my $fullfilename = "$dirname/$file";

    return unless open(FILE, $fullfilename);

    my @bins;

    my $maxcount = 0;
    my $sumcount = 0;
    my $sumcount2 = 0;

    while (my $line = <FILE>) {
	my ($pos, $count) = $line =~ /^\s*(\d+)\s+(\d+)/;

	push @bins, $count;

	$sumcount += $count;
	$sumcount2 += $count * $count;

	$maxcount = $count if ($count > $maxcount);
    }
    close(FILE);

    my $seqlen = scalar(@bins);

    return if ($seqlen < $minlen || $maxcount < $thresh);

    my $meancount = $sumcount/$seqlen;

    my $histart = -1;
    my $format = "%-20s %8d %8d %4d %5.0lf %8d %5.0lf\n";

    for (my $i = 0; $i < $seqlen; $i++) {
	if ($bins[$i] < $thresh) {
	    if ($histart >= 0) {
		$replen = $i - $histart;
		if ($replen >= $minreplen) {
		    $avg = $sumcount/($i-$histart);
		    printf $format,$seqname,$histart+1,$replen,$maxcount,$avg,$seqlen,$meancount;
		}
		$histart = -1;
	    }
	} else {
	    if ($histart < 0) {
		$histart = $i;
		$maxcount = $bins[$i];
		$sumcount = $bins[$i];
	    } else {
		$maxcount = $bins[$i] if ($bins[$i] > $maxcount);
		$sumcount += $bins[$i];
	    }
	}
    }

    if ($histart >= 0) {
	$replen = $seqlen - $histart;
	if ($replen >= $minreplen) {
	    $avg = $sumcount/($seqlen-$histart);
	    printf $format,$seqname,$histart+1,$seqlen-$histart,$maxcount,$avg,$seqlen,$meancount;
	}
    }
}

