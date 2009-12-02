package NewSegment;

use strict;

#----------------------------------------------------------------------
# Segment: store an individual alignment as x-start, y-start, length in
#          an array of length 3 on $this. Append the Mapping ID as the 
#          forth element; it is required to access alignment direction
#          via the parent Mapping
#----------------------------------------------------------------------

sub new {
# constructor takes a 3-vector xs, ys, length plus a Mapping identifier
    my $class = shift;

    my $this = [];

    bless $this,$class;

# take care all 3 + 1 input parameters are defined

    my ($xs, $ys, $length, $mid, @dummy) = @_;

    if (!defined($xs) || !defined($ys) || !$length || ref($mid) ne 'NewMapping') {
        die "Segment constructor expects a 3 vector + host Mapping identifier";
    }

    @{$this} = ($xs, $ys, $length-1, $mid, 0); # copy to local array (+ extra field)

    return $this;
}

#---------------------------------------------------------------------------
# access methods
#---------------------------------------------------------------------------

sub isCounterAligned {
    my $this = shift;
# if element [4] is 0, consult the parent Mapping about alignment
    $this->[4] = ($this->[3]->getAlignmentDirection() || 0) unless $this->[4];
    return ($this->[4] < 0) ? 1 : 0;
}

sub getStart { # generic method ?OBSOLETE?
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
    return $this->[0];
}

sub getXfinis {
    my $this = shift;
    return $this->[0] + $this->[2];
}

sub getYstart {
    my $this = shift;
    return $this->[1];
}

sub getYfinis {
    my $this = shift;
    my $host = $this->[3];
    my $span = $this->[2];
    $span = -$span if $this->isCounterAligned();
    return $this->[1] + $span;
}

sub getSegment {
    my $this = shift;
    return $this->getXstart(), $this->getXfinis(),
           $this->getYstart(), $this->getYfinis();
}

sub getSegmentLength {
    my $this = shift;
    return $this->[2] + 1;
}

sub getOffset {
    my $this = shift;
    return $this->isCounterAligned() ? $this->[0] - $this->[1] 
                                     : $this->[0] + $this->[1];
}

#----------------------------------------------------------------------

sub getXforY { 
# mapYvalueToXdomain (inside this mapping segment)
    my $this = shift;
    my $ypos = shift;
    my $full = shift; # allow outside segment range

    $ypos -= $this->[1];

    $ypos = -$ypos if $this->isCounterAligned();

    if ($ypos < 0 || $ypos > $this->getSegmentLength()) {
        return undef unless $full; # out of range
    }

    return $this->[0] + $ypos;
}

sub getYforX {
# mapXvalueToYdomain
    my $this = shift;
    my $xpos = shift;
    my $full = shift; # allow outside segment range

    $xpos -= $this->[0];

    if ($xpos < 0 || $xpos > $this->getSegmentLength()) {
        return undef unless $full; # out of range
    }

    $xpos = -$xpos if $this->isCounterAligned();
    
    return $this->[1] + $xpos;       
}

#----------------------------------------------------------------------
# protected method can only be invoked by the parent (Mapping) object
#----------------------------------------------------------------------

sub transformXdomain {
# protected method: apply a linear transformation to X domain (transform X = a * Y + s)
    my $this = shift;
    my $alpha = shift;
    my $shift = shift;
    my $mid = shift; # mapping identifier

    return 0 unless ($mid && $mid eq $this->[3]); # process outside

# if a > 0 apply the linear transform to the X starting position

    if ($alpha > 0) {
        $this->[0] += $shift;
    }
# if a < 0 replace xs by xf (and ys by yf) and transform the new xs position  
    elsif ($alpha < 0) {
# we have to transform xf and replace xs by xf to keep the ordering xf > xs
        $this->[0] = - ($this->[0] + $this->[2]) + $shift; # i.e. = -xf + s
        $this->[1] = $this->getYfinis();
        $this->[4] = 0; # forces re-initialisation of alignment info
    }

    return 1; 
}

#----------------------------------------------------------------------
#
#----------------------------------------------------------------------

sub compare { # OBSOLETE ??
# compare two segments; return offset of segment to this and alignment
    my $this = shift;
    my $segment = shift; # another Segment instance
    my %options = @_; # domain

    if (ref($segment) ne 'Segment') {
        die "Segment->compare expects an instance of the Segment class";
    }

# ? just compare length ?

    my $alignment = ($this->isCounterAligned() == $segment->isCounterAligned()) ? 1 : -1;

# default comparison of segments in Y domain; optionally in X domain

    my $useXdomain = ($options{domain} && $options{domain} eq 'X') ? 1 : 0;

# 1: determine the offset and alignment between the X ranges of the segments

# the transformation between X (this) and X (segment) is given by
# X(segment) = align * X(this) + (offset(segment) - align * offset(this)) 

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

1;
