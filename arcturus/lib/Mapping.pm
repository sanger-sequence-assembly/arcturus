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

    $this->{assembledFrom}   = [];
    $this->{alignToTrace}    = [];

    $this->setReadName($mapping);

    return $this;
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub getReadID {
    my $this = shift;

    return $this->{read_id};
}

sub setReadID {
    my $this = shift;

    $this->{read_id} = shift;
}

sub getReadName {
    my $this = shift;

    return $this->{readname};
}

sub setReadName {
    my $this = shift;

    $this->{readname} = shift;
}
 
#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub compare {
# compare this Mapping instance with input Mapping
    my $this = shift;
    my $mapping = shift;

    if (ref($mapping) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

    my $lmaps = $this->export();
    my $fmaps = $mapping->export();

    return 0 unless (scalar(@$lmaps) == scalar(@$fmaps));

# compare each segment individually; if the mappings are identical
# apart from a linear shift and possibly counter alignment, all
# return values of of alignment and offset will be identical

    
}
 
#-------------------------------------------------------------------
# store alignment segments
#-------------------------------------------------------------------

sub addAlignToTrace {
# from (possibly edited) read to trace file (raw read)
# input 4 array (readstart, readfinis, tracestart, tracefinis)
    my $this = shift;

    my $segment = new Segment(@_);

    push @{$this->{alignToTrace}},$segment;

    return scalar(@{$this->{alignToTrace}});
}

sub addAssembledFrom {
# from contig to (possibly edited) read
# input 4 array (contigstart, contigfinis, readstart, readfinis) 
    my $this = shift;

    my $segment = new Segment(@_);

    push @{$this->{assembledFrom}},$segment;

    return scalar(@{$this->{assembledFrom}});
}

#-------------------------------------------------------------------
# export of alignments
#-------------------------------------------------------------------

sub export {
# export the assembledFrom mappings as array of segments
    my $this = shift;

# NOTE: the segments are internally normalised (aligned) on read data
#       you may want to normalise on contig data if the segments are
#       used in a consensus calculation (and e.g. need to be sorted)
#       re: use Segment->normaliseOnX method on all segments

    return $this->{assembledFrom}; # array reference
}

sub getOverallAlignment {
    my $this = shift;

# find the first and the last segment of the assembledFrom map

    my ($first, $final);
    foreach my $segment (@{$this->{assembledFrom}}) {
# ensure the correct alignment (on read segment, it may have been changed outside after export)
        $segment->normaliseOnY();
        $first = $segment if (!defined($first) || $first->getYstart < $segment->getYstart);
        $final = $segment if (!defined($final) || $final->getYfinis > $segment->getYfinis);
    }

#print "OverallAlignment UNDEFINED \n" unless $first;
    return undef if !$first;

    return ($first->getXstart, $final->getXfinis, $first->getYstart, $final->getYfinis);
}

sub assembledFromToString {
    my $this = shift;

    my $assembledFrom = "Assembled_from ".$this->getReadName()." ";

    my $string = '';
    foreach my $segment (@{$this->{assembledFrom}}) {
        $string .= $assembledFrom.$segment->toString()."\n";
    }
    return $string;
}

sub alignToTraceToString {
    my $this = shift;
    my $string = '';

    foreach my $segment (@{$this->{alignToTrace}}) {
        $string .= "Align_to_SCF ".$segment->toString()."\n";
    }
    return $string;
}

#-------------------------------------------------------------------

1;










