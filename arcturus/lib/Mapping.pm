package Mapping;

use strict;

use Segment;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
    my $class = shift;
    my $identifier = shift; # mapping number or name, optional

    my $this = {};

    bless $this, $class;

    $this->setReadName($identifier) if $identifier;

    return $this;
}
 
#-------------------------------------------------------------------
# mapping metadata (readname, sequence ID, mapping ID and alignment)
#-------------------------------------------------------------------

sub getMappingID {
    my $this = shift;
    return $this->{mapping_id};
}

sub setMappingID {
    my $this = shift;
    $this->{mapping_id} = shift;
}

sub getSequenceID {
    my $this = shift;
    return $this->{seq_id};
}

sub setSequenceID {
    my $this = shift;
    $this->{seq_id} = shift;
}

sub getReadName {
    my $this = shift;
    return $this->{readname};
}

sub setReadName {
    my $this = shift;
    $this->{readname} = shift;
}

sub setAlignment {
# must be defined when creating Mapping instance from database
    my $this = shift;
    my $direction = shift;

    if ($direction eq 'Forward') {
        $this->{direction} = 1;
    }
    elsif ($direction eq 'Reverse') {
        $this->{direction} = -1;
    }
}

sub getAlignmentDirection {
# returns 'Forward', 'Reverse' or undef
    my $this = shift;

    my $direction = $this->getAlignment() || 0;

    if ($direction > 0) {
        return 'Forward';
    }
    elsif ($direction < 0) {
        return 'Reverse';
    }
    return undef;
}

sub getAlignment {
# returns +1, -1 or undef
    my $this = shift;

# if the direction is undefined, get it from Segments, if any

    if (!defined($this->{direction}) && $this->hasSegments()) {
        my $segments = $this->getSegments();
        $this->{direction} = $segments->[0]->getAlignment();
    }

    return $this->{direction};
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

    my $lmaps = $this->getSegments();
    my $fmaps = $mapping->getSegments();

    return 0 unless (scalar(@$lmaps) == scalar(@$fmaps));

# compare each segment individually; if the mappings are identical
# apart from a linear shift and possibly counter alignment, all
# return values of of alignment and offset will be identical

    
}
 
#-------------------------------------------------------------------
# store alignment segments
#-------------------------------------------------------------------

sub addAlignmentFromDatabase {
# input 3 array (cstart, rstart, length) and combine with direction
    my $this = shift;
    my ($cstart, $rstart, $length, $dummy) = @_;

    $length -= 1;

    my $rfinis = $rstart + $length;

    if ($length < 0) {
        die "Invalid length specification in Mapping ".$this->getReadName; 
    }
    elsif (my $direction = $this->{direction}) {
       
        $length = -$length if ($direction < 0);
        my $cfinis = $cstart + $length;

        $this->addAssembledFrom($cstart, $cfinis, $rstart, $rfinis);
    }
    else {
        die "Undefind alignment direction in Mapping ".$this->getReadName;
    }
}

sub addAssembledFrom {
# from contig to sequence
# input 4 array (contigstart, contigfinis, seqstart, seqfinis) 
    my $this = shift;

# validity input is tested in Segment constructor

    my $segment = new Segment(@_); 

    $this->{assembledFrom} = [] if !$this->{assembledFrom};

    push @{$this->{assembledFrom}},$segment;

    return scalar(@{$this->{assembledFrom}});
}

sub hasSegments {
# returns true if at least one alignment exists
    my $this = shift;

    return 0 unless $this->{assembledFrom};

    return scalar(@{$this->{assembledFrom}});
}

#-------------------------------------------------------------------
# export of alignments
#-------------------------------------------------------------------

sub getSegments {
# export the assembledFrom mappings as array of segments
    my $this = shift;

# NOTE: the segments are internally normalised (aligned) on read data
#       you may want to normalise on contig data if the segments are
#       used in a consensus calculation (and e.g. need to be sorted)
#       re: use Segment->normaliseOnX method on all segments

    return $this->{assembledFrom}; # array reference
}

sub getContigRange {
# find contig begin and end positions from segments of the assembledFrom map
    my $this = shift;

    my ($first, $final) = $this->getOuterSegments();

    return undef if !$first;

    if ($this->getAlignment() > 0) {
# co-aligned contig and read segments
	return ($first->getXstart, $final->getXfinis);
    }
    else {
# counter-aligned contig and read segments
        return ($final->getXstart, $first->getXfinis);
    }
}

sub getOuterSegments {
# private method
    my $this = shift;

# find contig begin and end positions from segments of the assembledFrom map

    my ($first,$final);

    foreach my $segment (@{$this->{assembledFrom}}) {
# ensure the correct alignment (it may have been changed outside after export)
        $segment->normaliseOnY(); # ensure rstart <= rfinish
        $first = $segment if (!defined($first) || 
                              $first->getYstart < $segment->getYstart);
        $final = $segment if (!defined($final) || 
                              $final->getYfinis > $segment->getYfinis);
    }
print "OverallAlignment UNDEFINED \n" unless $first;
    return undef if !$first;

    return ($first, $final);
}

sub assembledFromToString {
# write alignments as (block of) 'Assembled_from' records
    my $this = shift;

    my $assembledFrom = "Assembled_from ".$this->getReadName()." ";

    my $string = '';
    foreach my $segment (@{$this->{assembledFrom}}) {
        $segment->normaliseOnY(); # ensure rstart <= rfinish
        $string .= $assembledFrom.$segment->toString()."\n";
    }
    return $string;
}

#-------------------------------------------------------------------

1;










