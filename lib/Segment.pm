package Segment;

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
# Segment: store an individual alignment and the coefficients of the 
#          corresponding linear transformation in array length 4 on
#          $this. The Mapping ID is put as the fifth element; it serves
#          make some methods only accessible via the parent Mapping
#----------------------------------------------------------------------

sub new {
# constructor takes a 4-vector xs,xf ys,yf mapping X domain to Y domain
# plus a Mapping identifier
    my $class = shift;

    my $this = [];

    bless $this,$class;

# take care all 4 + 1 input parameters are defined

    my ($xs, $xf, $ys, $yf, $mid, $dummy) = @_;

    if (!defined($yf) || !defined($ys) || !defined($xf) || !defined($xs)) {
        die "Segment constructor expects a 4 vector + Mapping identifier";
    }
    unless (defined($mid)) { # not fatal
        print STDERR "Segment constructor expects a 4 vector + Mapping identifier";
        $mid = '';
    }

# the interval covered by the x and y domains have to be identical

    if (abs($xf-$xs) != abs($yf-$ys)) {
        print STDERR "Invalid segment sizes in Segment constructor: @_\n";
	return undef;
    }

# calculate the transformation between Y and X domains: X = d*Y + o

    my $direction = (($yf-$ys) == ($xf-$xs)) ? 1 : -1;

# NOTE: unit-length intervals get direction = 1 by default. If direction -1
#       is required use method counterAlignUnitLengthInterval to invert
#       however, either +/-1, but not 0, is required to calculate the offset

    my $offset = $xs - $direction * $ys;

    @{$this} = ($direction,$offset,$ys,$yf,$mid); # copy to local array

    return $this;
}

#----------------------------------------------------------------------
# protected methods can only be invoked by the parent (Mapping) object
#----------------------------------------------------------------------

sub normaliseOnY {
#  protected method: order Y interval, return Y start position
    my $this = shift;
    my $mid = shift || ''; # mapping identifier

    return &error('normaliseOnY') unless ($mid eq $this->[4]);

    my $length = $this->getYfinis() - $this->getYstart();

   ($this->[2],$this->[3]) = ($this->[3],$this->[2]) if ($length < 0); 

    return $this->getYstart(); # (re: Mapping->normalise)
}

sub normaliseOnX {
# protected method: order X interval, return length of interval 
    my $this = shift;
    my $mid = shift || ''; # mapping identifier

    return &error('normaliseOnX') unless ($mid eq $this->[4]); 

    my $length = $this->getXfinis() - $this->getXstart();

   ($this->[2],$this->[3]) = ($this->[3],$this->[2]) if ($length < 0); 

    return abs($length) + 1; # (re: ArcturusDatabase->putMappingsForContig)
}

sub counterAlignUnitLengthInterval {
# protected method: change the alignment direction for a unit-length interval
    my $this = shift;
    my $mid = shift || ''; # mapping identifier

    return &error('counterAlignUnitLengthInterval') unless ($mid eq $this->[4]); 

    return 0 if ($this->getAlignment() < 0); # already done, valid but no action

    my $ystart = $this->getYstart();

    return if ($ystart != $this->getYfinis()); # not a unit interval

# calculate new offset from current value and invert direction

    $this->[1] = $ystart + $ystart + $this->getOffset();

    $this->[0] = -1;

    return 1; # correct termination
}

sub applyLinearTransform {
# protected method: apply a linear transformation to X domain (transform X = d * Y + o)
    my $this = shift;
    my $alpha = shift; # direction info
    my $shift = shift;
    my $mid = shift || ''; # mapping identifier

    return &error('applyLinearTransform') unless ($mid eq $this->[4]);

# multiply the local transformation (alpha considered be +1 or -1) 
# new transform: X = D * Y + O, with  D = alpha*d and O = alpha*o+shift

    if (defined($alpha) && $alpha < 0) {
        $this->[0] = -$this->[0];
        $this->[1] = -$this->[1];
    }

    $this->[1] += $shift if $shift;

    return 1; # correct termination
}

sub modify {
# change left or right end position of segment 
    my $this = shift;
    my $item = shift;      # end to be changed R or L
    my $value = shift;     # new value
    my $mid = shift || ''; # mapping identifier

    return &error('modify') unless ($mid eq $this->[4]);

    $this->[($item eq 'L' ? 2 : 3)] = $value;
}

sub error {
# signal error inmethod call and terminate execution
    my $method = shift;
    print STDERR "Segment->$method called without correct Mapping "
               . "identifier\n";
    exit 1; 
#    return undef;
}

#----------------------------------------------------------------------

sub getStart { # generic method
    my $this = shift;
    my $notx = shift; # 0 for X, 1 for Y domain
    return $notx ? $this->getYstart() : $this->getXstart();
}

sub getFinis { # generic method
    my $this = shift;
    my $notx = shift; # 0 for X, 1 for Y domain
    return $notx ? $this->getYfinis() : $this->getXfinis();
}

sub getXstart {
    my $this = shift;
# transform ystart via X = d * Y + o
    my $xstart = $this->[2]; # ystart
    $xstart = -$xstart if ($this->[0] < 0); # alignment
    $xstart += $this->[1]; # offset
    return $xstart;
}

sub getXfinis {
    my $this = shift;
# transform yfinis via X = d * Y + o
    my $xfinis = $this->[3]; # yfinis
    $xfinis = -$xfinis if ($this->[0] < 0);
    $xfinis += $this->[1];
    return $xfinis;
}

sub getYstart {
    my $this = shift;
    return $this->[2];
}

sub getYfinis {
    my $this = shift;
    return $this->[3];
}

sub getSegment {
    my $this = shift;
    return $this->getXstart(), $this->getXfinis(),
           $this->getYstart(), $this->getYfinis();
}

sub getAlignment {
# return linear transformation direction (+1/-1) between X and Y domains
    my $this = shift;
    return $this->[0];
}

sub getOffset {
# return linear transformation offset between X and Y domains
    my $this = shift;
    return $this->[1];
}

sub getSegmentLength {
    my $this = shift;
    return abs($this->getYfinis() - $this->getYstart()) + 1;
}

#----------------------------------------------------------------------

sub compare {
# compare two segments; return offset of segment to this and alignment
    my $this = shift;
    my $segment = shift; # another Segment instance
    my %options = @_; # domain

    if (ref($segment) ne 'Segment') {
        die "Segment->compare expects an instance of the Segment class";
    }

# default comparison of segments in Y domain; optionally in X domain

    my $useXdomain = ($options{domain} && $options{domain} eq 'X') ? 1 : 0;

# 1: determine the offset and alignment between the X ranges of the segments

# the transformation between X (this) and X (segment) is given by
# X(segment) = align * X(this) + (offset(segment) - align * offset(this)) 

    my $alignment = $this->getAlignment();
    $alignment = -$alignment if ($segment->getAlignment() < 0);

    my $offset = $this->getOffset();
    $offset = -$offset if ($alignment < 0 && !$useXdomain); # y domain only
    $offset -= $segment->getOffset();

# 2: test the size and X/Y position of the segments

    my $equilocate = 1;

# both segments should be normalized on X/Y and have identical X/Y range
# note: either X or Y segments should coincide, length test alone is too weak

    if ($useXdomain) {
        $equilocate = 0 if ($this->getXstart() != $segment->getXstart());
        $equilocate = 0 if ($this->getXfinis() != $segment->getXfinis());
    }
    else { # use Y domain (default)
        $equilocate = 0 if ($this->getYstart() != $segment->getYstart());
        $equilocate = 0 if ($this->getYfinis() != $segment->getYfinis());
    }

    return ($equilocate, $alignment, $offset);
}

#----------------------------------------------------------------------

sub getXforY { 
# mapYvalueToXdomain (inside this mapping segment)
    my $this = shift;
    my $ypos = shift;

# apply transformation X = d * Y + o

    my $k = ($this->[3] >= $this->[2]) ? 2 : 3;

    if ($ypos < $this->[$k] || $ypos > $this->[5-$k]) {
        return undef; # out of range
    }
    else {
        $ypos = -$ypos if ($this->[0] < 0);
        return $ypos + $this->[1];
    }
}

sub getYforX {
# mapXvalueToYdomain (inside this mapping segment)
    my $this = shift;
    my $xpos = shift;

# apply transformation Y = d * [X - o]

    my $ypos = $xpos - $this->[1];
    $ypos = -$ypos if ($this->[0] < 0);

# this interval test is independent of the ordering

    my $k = ($this->[3] >= $this->[2]) ? 2 : 3;

    if ($ypos < $this->[$k] || $ypos > $this->[5-$k]) {
        return undef; # out of range
    }
    else {
        return $ypos;
    }
}

#----------------------------------------------------------------------

1;
