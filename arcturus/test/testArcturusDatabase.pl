#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;
use DBI;
use FileHandle;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $readids = shift @ARGV if ($nextword eq '-readids');

    $filename = shift @ARGV if ($nextword eq '-caf');
}

$instance = 'prod' unless defined($instance);

$readid = 1 unless defined($readid);

die "You must specify the organism" unless defined($organism);
die "You must specify read ids" unless defined($readids);

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

$url = $adb->getURL();
print STDERR "The URL is $url\n";

$dbh = $adb->getConnection();

if (!defined($dbh)) {
    print STDERR "        CONNECT FAILED: : $DBI::errstr\n";
    exit(1);
}

$readranges = &parseReadIDRanges($readids);
$ndone = 0;

if (defined($filename)) {
    $fh = new FileHandle($filename, "w");
} else {
    $fh = new FileHandle(">&STDOUT");
}

foreach $readrange (@{$readranges}) {
    ($idlow, $idhigh) = @{$readrange};

    for ($readid = $idlow; $readid <= $idhigh; $readid++) {
	$ndone++;

	$read = $adb->getReadByID($readid);

	if (defined($read)) {

	    $read->writeToCaf($fh);
	} else {
	    print STDERR "Read $readid does not exist.\n";
	}
    }
}

$fh->close();

exit(0);

sub parseReadIDRanges {
    my $string = shift;

    my @ranges = split(/,/, $string);

    my $result = [];

    foreach my $subrange (@ranges) {
	if ($subrange =~ /^\d+$/) {
	    push @{$result}, [$subrange, $subrange];
	}

	if ($subrange =~ /^(\d+)(\.\.|\-)(\d+)$/) {
	    push @{$result}, [$1, $3];
	}
    }

    return $result;
}
