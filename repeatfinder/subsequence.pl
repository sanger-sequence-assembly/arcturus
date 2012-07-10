#!/usr/local/bin/perl

$fastafile = shift;

die "No FASTA file specified" unless $fastafile;

die "File $fastafile does not exist" unless -f $fastafile;

die "Unable to open file $fastafile" unless open(FASTA, $fastafile);

while ($line = <FASTA>) {
    chop($line);

    if ($line =~ /^>(\S+)/) {
	$seqname = $1;
	$sequence{$lastname} = $seq if defined($lastname);
	$seq = '';
	$lastname = $seqname;
    } else {
	$line =~ s/[^ACGTNacgtn]//g;
	$seq .= $line;
    }
}

$sequence{$lastname} = $seq if defined($lastname);

close(FASTA);

$seqnum = 0;

while ($line = <STDIN>) {
    ($seqname, $start, $seqlen) = $line =~ /^(\S+)\s+(\d+)\s+(\d+)/;

    $seq = $sequence{$seqname};

    next unless defined($seq);

    $repname = "$seqname-$start-$seqlen";

    $subseq = substr($seq, $start-1, $seqlen);

    print ">$repname\n";

    for ($j = 0; $j < length($subseq); $j += 50) {
	print substr($subseq, $j, 50),"\n";
    }
}

exit(0);
