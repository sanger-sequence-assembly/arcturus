package Segment;

use strict;

#----------------------------------------------------------------------
# Segment: store an individual alignment and the coefficients of the 
#       corresponding linear transformation in array length 4 on $this
#----------------------------------------------------------------------

sub new {
# constructor takes a 4-vector xs,xf ys,yf mapping X domain to Y domain
    my $class = shift;


    my $this = [];

    bless $this,$class;

# take care all 4 input parameters are defined

    my ($xs, $xf, $ys, $yf, $dummy) = @_;

    if (!defined($yf) || !defined($ys) || !defined($xf) || !defined($xs)) {
        die "Segment constructor expects a 4 vector";
    }

# the interval covered by the x and y domains have to be identical

    if (abs($xf-$xs) != abs($yf-$ys)) {
        print STDOUT "Invalid segment sizes in Segment constructor: @_\n";
	return undef;
    }

# calculate the transformation between Y and X domains: X = d*Y + o

    my $direction = (($yf-$ys) == ($xf-$xs)) ? 1 : -1;

# NOTE: unit-length intervals get direction = 1 by default. If direction -1
#       is required use method counterAlignUnitLengthInterval to invert
#       however, either +/-1, but not 0, is required to calculate the offset

    my $offset = $xs - $direction * $ys;

    @{$this} = ($direction,$offset,$ys,$yf); # copy to local array

    return $this;
}

sub invert {
# private method: invert by interchanging ystart and yfinis
    my $this = shift;

    my $dummy = $this->[2];
    $this->[2] = $this->[3];
    $this->[3] = $dummy;
}

sub normaliseOnY {
# order Y interval, return Y start position
    my $this = shift;

    my $length = $this->[3] - $this->[2];

#   ($this->[2],$this->[3]) = ($this->[3],$this->[2]) if ($length < 0); 
    $this->invert() if ($this->[2] > $this->[3]);

    return $this->getYstart(); # (re: Mapping->analyseSegments)
}

sub normaliseOnX {
# order X interval, return length of interval 
    my $this = shift;

    my $length = $this->getXfinis() - $this->getXstart();

   ($this->[2],$this->[3]) = ($this->[3],$this->[2]) if ($length < 0); 
#    $this->invert() if ($length < 0);

    return abs($length) + 1; # (re: ArcturusDatabase->putMappingsForContig)
}

sub applyShiftToX {
# apply a linear shift to X domain (transform X = d * Y + o)
    my $this = shift;
    my $shift = shift || return;

# the shift is done by adjusting the offset (shift X with respect to Y)

    $this->[1] += $shift;
}

sub applyLinearTransform {
# apply a linear transformation to X domain (transform X = d * Y + o)
    my $this = shift;
    my $alpha = shift; # direction info
    my $shift = shift;

# multiply the local transformation (alpha considered be +1 or -1) 
# new transform: X = D * Y + O, with  D = alpha*d and O = alpha*o+shift

    if (defined($alpha) && $alpha < 0) {
        $this->[0] = -$this->[0];
        $this->[1] = -$this->[1];
    }

    $this->[1] += $shift if $shift;
}

#----------------------------------------------------------------------

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

    if (ref($segment) ne 'Segment') {
        die "Segment->compare expects an instance of the Segment class";
    }

# 1: determine the offset and alignment between the X ranges of the segments

# the transformation between X (this) and X (segment) is given by
# X(segment) = align * X(this) + (offset(segment) - align * offset(this)) 

    my $alignment = $this->getAlignment();
    $alignment = -$alignment if ($segment->getAlignment() < 0);

    my $offset = $this->getOffset();
    $offset = -$offset if ($alignment < 0);
    $offset -= $segment->getOffset();

# 2: test the size and Y position of the segments

    my $equalsize = 1;

# both segments should be normalized on Y and have identical Y (read) range

    $equalsize = 0 if ($this->getYstart() != $segment->getYstart());
    $equalsize = 0 if ($this->getYfinis() != $segment->getYfinis());

    return ($equalsize, $alignment, $offset);
}

sub counterAlignUnitLengthInterval {
# change the alignment direction for a unit-length interval
    my $this = shift;

    return if ($this->getAlignment() < 0); # already done

    my $ystart = $this->getYstart();

    return if ($ystart != $this->getYfinis()); # not a unit interval

# calculate new offset from current value and invert direction

    $this->[1] = $ystart + $ystart + $this->getOffset();

    $this->[0] = -1;
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
