#!/usr/local/bin/perl
#
# testreadrecall
#
# This script extracts one or more reads and generates a CAF file

use ArcturusDatabase;
use Read;

$verbose = 0;
$loadsequence = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $readids = shift @ARGV if ($nextword eq '-readids');

    $verbose = 1 if ($nextword eq '-verbose');

    $loadsequence = 1 if ($nextword eq '-loadsequence');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($readids)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$instance = 'dev' unless defined($instance);

$adb = new ArcturusDatabase(instance => $instance,
			    organism => $organism);

die "Failed to create ArcturusDatabase object" unless defined($adb);

$readranges = &parseReadIDRanges($readids);

$ndone = 0;
$nfound = 0;

printf STDERR "%8d %8d", $ndone, $nfound unless $verbose;
$format = "\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010%8d %8d";

foreach $readrange (@{$readranges}) {
    ($idlow, $idhigh) = @{$readrange};

    for ($readid = $idlow; $readid <= $idhigh; $readid++) {
	$ndone++;

	$read = $adb->getReadByID($readid);

	if (defined($read)) {
	    $read->importSequence() if $loadsequence;

	    $nfound++;
	}

	printf STDERR $format, $ndone, $nfound if (($ndone % 50) == 0);
    }
}

printf STDERR $format, $ndone, $nfound;
print STDERR "\n";

$adb->disconnect();

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

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -readids\t\tRange of read IDs to process\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: dev]\n";
}
