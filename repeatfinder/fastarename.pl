#!/usr/local/bin/perl

while ($thisword = shift) {
    $prefix = shift if ($thisword eq '-prefix');
    $pattern = shift if ($thisword eq '-pattern');
    $nseq = shift if ($thisword eq '-firstid');
}

$prefix = "SEQ" unless defined($prefix);
$pattern = "%04d" unless defined($pattern);

$pattern = $prefix . $pattern;

$nseq = 0 unless (defined($nseq) && ($nseq =~ /^\d+$/));

while ($line = <STDIN>) {
    if ($line =~ /^>/) {
	$nseq++;
	$line = ">" . sprintf($pattern, $nseq) . "\n";
    }

    print $line;
}

print STDERR "Processed $nseq sequences\n";

exit(0);
