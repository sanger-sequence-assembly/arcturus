package Mapping;

use strict;

use Segment;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
    my $class   = shift;
    my $mapping = shift; # mapping number or name, optional

    my $this = {};

    bless $this, $class;

    $this->{MappingSegments} = [];
    $this->{assembledFrom}   = [];
    $this->{alignToTrace}    = [];

    $this->{mapping} = $mapping if defined($mapping);

    return $this;
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub getReadID {
    my $this = shift;

    return $this->{data}->{read_id};
}

sub setReadID {
    my $this = shift;

    $this->{data}->{read_id} = shift;
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub addAlignToTrace {
    my $this = shift;

#print "addAlignToTrace: @_\n";

    my $segment = new Segment(@_);

    my $added = 0;
    if ($segment->getMapping) { 
        push @{$this->{alignToTrace}},$segment;
        $added = scalar(@{$this->{alignToTrace}});
    }

    return $added;
}

sub addAssembledFrom {
    my $this = shift;

#print "addAssembledFrom: @_\n";

    my $segment = new Segment(@_);

    my $added = 0;
    if ($segment->getMapping) { 
        push @{$this->{alignToAssembly}},$segment;
        $added = scalar(@{$this->{alignToAssembly}});
    }

    return $added;
}

1;

