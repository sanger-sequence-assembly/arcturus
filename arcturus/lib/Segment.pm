package Segment;

use strict;

#----------------------------------------------------------------------
# constructor takes a 4-vector xs,xf ys,yf mapping x domain to y domain
#----------------------------------------------------------------------

sub new {

    my $class = shift;


    my $this = {};

    bless $this,$class;


    my ($xs, $xf, $ys, $yf, $label) = @_;

    $this->setMapping($xs,$xf,$ys,$yf) if defined($xs);

    $this->setSegmentLabel($label);

    return $this;
}

#----------------------------------------------------------------------

sub setMapping {
    my $this = shift;

    my ($xs, $xf, $ys, $yf, $dummy) = @_;

# test if all elements are defined

    if (!defined($yf) || !defined($ys) || !defined($xf) || !defined($xs)) {
        die "Segment->setMapping expects at least a 4 vector";
    }

# the interval covered by the x and y domains have to be identical

    if (abs($xf-$xs) != abs($yf-$ys)) {
        die "Invalid segment sizes in Segment->setMapping";
    }

    $this->{segment} = [] unless defined $this->{segment};

    @{$this->{segment}} = ($xs,$xf,$ys,$yf); # copy to local array
}

sub getMapping {
    my $this = shift;

    return undef unless defined $this->{segment};

    return @{$this->{segment}};
}

sub setLabel {
    my $this = shift;

    $this->{label} = shift || 0; # set to 0 if not defined
}

sub getLabel {
    my $this = shift;

    return $this->{label};
}

#----------------------------------------------------------------------

1;
