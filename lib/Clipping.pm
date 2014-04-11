package Clipping;

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


use strict;

# this method is taken from Asp::PhredClip, written by Paul Mooney

sub phred_clip {
    my $self = shift;
    my $threshold = shift;
    my $avquality = shift; # array reference

    my $qualLen  = scalar(@{$avquality});
    my $lastQual = $qualLen - 1;
    my $i;
    my @q;

    for ($i = 0; $i < $qualLen; $i++) {
	$q[$i] = $avquality->[$i] - $threshold;
    }

    my @cleft;
    my @l;

    my $Left = 0;
    $cleft[0] = $q[0] > 0 ? $q[0] : 0;
    $l[0] = $Left;

    for ($i = 1; $i < $qualLen; $i++) {
	$cleft[$i] = $q[$i] + $cleft[$i - 1];

	if ($cleft[$i] <= 0) {
	    $cleft[$i] = 0;
	    $Left = $i;
	}

	$l[$i] = $Left;
    }

    my @cright;
    my @r;

    my $Right = $lastQual;
    $cright[$lastQual] = $q[$lastQual] > 0 ? $q[$lastQual] : 0;
    $r[$lastQual] = $Right;

    for ($i = $lastQual - 1; $i >= 0; $i--) {
	$cright[$i] = $q[$i] + $cright[$i + 1];

	if ($cright[$i] <= 0) {
	    $cright[$i] = 0;
	    $Right = $i;
	}

	$r[$i] = $Right;
    }

    my $best  = 0;
    my $coord = 0;

    for($i = 0; $i < $qualLen; $i++) {
	my $s = $cright[$i] + $cleft[$i];
	if ( $best < $s ) {
	    $best = $s;
	    $coord = $i;
	}
    }
    
    $Right = $r[$coord] + 1;
    $Left  = $l[$coord] + 1; # convert to coords starting at 1

    return ($Left, $Right);
}

1;
