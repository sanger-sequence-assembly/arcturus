package CanonicalSegment;

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

#----------------------------------------------------------------------
# Segment: store an individual alignment as x-start, y-start, length in
#          an array of length 3 on $this.
#----------------------------------------------------------------------

sub new {
# constructor takes a 3-vector xs, ys, length
    my $class = shift;

    my $this = [];

    bless $this,$class;

# take care all 3 input parameters are defined and positive

    my ($xs, $ys, $length) = @_;

    foreach my $item ($xs, $ys, $length) {
        next if (defined($item) && $item > 0);
        die "Segment constructor expects a 3 vector of positive numbers";
    }

    @$this = ($xs, $ys, $length);

    return $this;
}

#---------------------------------------------------------------------------
# access methods
#---------------------------------------------------------------------------

sub getXstart {
    my $this = shift;
    return $this->[0];
}

sub getXfinis {
    my $this = shift;
    return $this->[0] + $this->[2] - 1;
}

sub getYstart {
    my $this = shift;
    return $this->[1];
}

sub getYfinis {
    my $this = shift;
    return $this->[1] + $this->[2] - 1;
}

sub getSegment {
    my $this = shift;
    return $this->getXstart(), $this->getXfinis(),
           $this->getYstart(), $this->getYfinis();
}

sub getSegmentLength {
    my $this = shift;
    return $this->[2];
}

sub getOffset {
    my $this = shift;
    return $this->[0] - $this->[1]; # x-domain position - y-domain position
#    return $this->[1] - $this->[0]; ?
}

#----------------------------------------------------------------------

sub getXforY { 
# mapYvalueToXdomain (inside this mapping segment) in canonical coordinates
    my $this = shift;
    my $ypos = shift;
    my $full = shift; # allow outside segment range

    $ypos -= $this->[1];

    if ($ypos < 0 || $ypos >= $this->[2]) {
        return undef unless $full; # out of range
    }

    return $this->[0] + $ypos;
}

sub getYforX {
# mapXvalueToYdomain in canonical coordinates
    my $this = shift;
    my $xpos = shift;
    my $full = shift; # allow outside segment range

    $xpos -= $this->[0];

    if ($xpos < 0 || $xpos >= $this->[2]) {
        return undef unless $full; # out of range
    }
    
    return $this->[1] + $xpos;    
}

#----------------------------------------------------------------------

#sub getXforY { return &getPosition(1,@_) }

#sub getYforX { return &getPosition(0,@_) }

sub getPosition {
# mapYvalueToXdomain (k=1) or mapXvalueToYdomain (k=0) 
#(inside this mapping segment) in canonical coordinates
    my $k    = shift;
    my $this = shift;
    my $pos  = shift;
    my $full = shift; # allow outside segment range

    $pos -= $this->[$k];

    if ($pos < 0 || $pos > $this->[2]) {
        return undef unless $full; # out of range
    }
    
    return $this->[1-$k] + $pos;    
}

#----------------------------------------------------------------------

1;
