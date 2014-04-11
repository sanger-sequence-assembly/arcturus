#!/usr/local/bin/perl

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

#
# testreadrecall
#
# This script extracts one or more reads and generates a CAF file

use ArcturusDatabase;
use Read;

$quiet = 0;
$loadsequence = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $readids = shift @ARGV if ($nextword eq '-readids');

    $quiet = 1 if ($nextword eq '-quiet');

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

printf STDERR "%8d %8d", $ndone, $nfound unless $quiet;
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

	printf STDERR $format, $ndone, $nfound if (!$quiet && ($ndone % 50) == 0);
    }
}

if ($quiet) {
    print STDERR "Loaded $nfound reads out of $ndone\n";
} else {
    printf STDERR $format, $ndone, $nfound;
    print STDERR "\n";
}

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
    print STDERR "    -quiet\t\tDo not display running count of reads loaded\n";
    print STDERR "    -loadsequence\tLoad sequence and base quality data\n";
}
