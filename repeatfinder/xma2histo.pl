#!/usr/local/bin/perl

use FileHandle;

while ($nextword = shift) {
    $destdir = shift if ($nextword eq '-destdir');
    $maxsubs = shift if ($nextword eq '-maxsubs');
    $maxindel = shift if ($nextword eq '-maxindel');
}

$maxsubs = 5.0 unless defined($maxsubs);
$maxindel = 5.0 unless defined($maxindel);

$destdir = "/tmp/histo-$$" unless defined($destdir);;

mkdir($destdir) unless -d $destdir;

while ($line = <STDIN>) {
    chop($line);

    if ($line =~ /^\s*(\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+\((\d+)/) {
	($score, $subs, $ins, $del, $seqname, $pstart, $pfinis, $tail) = ($1, $2, $3, $4, $5, $6, $7, $8);

	next if ($subs > $maxsubs || $ins > $maxindel || $del > $maxindel);

	$slen = $pfinis + $tail;

	if (!defined($lastname) || $lastname ne $seqname) {
	    if (defined($lastname)) {
		$fh = new FileHandle("$destdir/$lastname.histo", "w");
		for ($j = 1; $j <= $lastlen; $j++) {
		    print $fh $j, " ", $bin[$j], " ", $bin[$j]-$bin[$j-1], "\n";
		}
		$fh->close();
	    }

	    $lastname = $seqname;
	    $lastlen = $slen;

	    for ($j = 1; $j <= $lastlen; $j++) {
		$bin[$j] = 0;
	    }
	}

	for ($j = $pstart; $j <= $pfinis; $j++) {
	    $bin[$j] += 1;
	}
    }
}

$fh = new FileHandle("$destdir/$lastname.histo", "w");
for ($j = 1; $j <= $lastlen; $j++) {
    print $fh $j, $bin[$j], "\n";
}
$fh->close();

exit(0);
