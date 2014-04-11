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
	    print $fh "\n" if ($ndone > 1);
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
