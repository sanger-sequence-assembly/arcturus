package CanonicalMapping;

use strict;

use CanonicalSegment;

use MappingFactory::MappingFactory;

#-------------------------------------------------------------------
# Class variable
#-------------------------------------------------------------------

my $CANONICALMAPPING_HASHREF = {}; # cache

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
# if a parameter is passed, use the cache
    my $class = shift;
    my $cache = shift;

    if ($cache && (my $cacheinstance = $CANONICALMAPPING_HASHREF->{$cache})) {
        return $cacheinstance;
    }

    my $this = {};

    bless $this, $class;

    $CANONICALMAPPING_HASHREF->{$cache} = $this if $cache;

    return $this;
}

#-----------------------------------------------------------------------------
# parameters of the canonical mapping
#-----------------------------------------------------------------------------

sub setSpanX { # e.g. contig
    my $this = shift;
    $this->{xrange} = shift;
}

sub getSpanX {
    my $this = shift;
    $this->verify() unless $this->{xrange};
    return $this->{xrange};
}

sub setSpanY { # e.g. read
    my $this = shift;
    $this->{yrange} = shift;
}

sub getSpanY {
    my $this = shift;
    $this->verify() unless $this->{yrange};
    return $this->{yrange};
}

sub setCheckSum {
    my $this = shift;
    $this->{segmentchecksum} = shift;
}

sub getCheckSum {
    my $this = shift;
    MappingFactory->getCheckSum($this) unless $this->{segmentchecksum}; # ? redundent
    return $this->{segmentchecksum};
}

sub verify { # go to MappingFactory ?
# order and test the segments and test parameters of the canonical mapping 
# against its segments, calculate span etc ..
    my $this = shift;
    return MappingFactory->verify($this);
}

#-------------------------------------------------------------------
# canonical mapping ID
#-------------------------------------------------------------------

sub getMappingID {
    my $this = shift;
    return $this->{mapping_id};
}

sub setMappingID {
    my $this = shift;
    $this->{mapping_id} = shift;
}
 
#-------------------------------------------------------------------
# importing alignment segments
#-------------------------------------------------------------------

sub addSegment {
    my $this = shift;
    my ($cs, $rs, $length, @verify) = @_;

    my $segments = $this->getSegments();

    my $segment = new CanonicalSegment($cs, $rs, $length);

    return 0 unless $segment; # failed to create; process outside 

    push @$segments, $segment;

#    $this->verify() if @verify;

    return scalar(@$segments);
}

#-------------------------------------------------------------------
# export of alignment segments
#-------------------------------------------------------------------

sub hasSegments {
# returns true if at least one canonical segment is defined
    my $this = shift;

    return scalar(@{$this->getSegments()}); # else regular
}

sub getSegments {
# export the array of alignment segments
    my $this = shift;

    $this->{Segments} = [] if !$this->{Segments}; # ensure an array ref
    my $segments = $this->{Segments};
    return $segments;
}

sub orderSegments {
# order the canonical segments
    my $this = shift;

    my $segments = $this->getSegments();
    @$segments = sort {$a->getXstart() <=> $b->getXfinis()} @$segments;
    return $segments;
}

#-------------------------------------------------------------------

1;
