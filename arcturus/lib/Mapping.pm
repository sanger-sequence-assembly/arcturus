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

sub setContigRange {
    my $this = shift;
    my $range = shift || return;

    my @range = @$range; # copy
    $this->{contigrange} = [@range];
}

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
    my $compare = shift;

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

    my $tmaps = $this->orderSegments();
    my $cmaps = $compare->orderSegments();

    return (0,0,0) unless ($tmaps && $cmaps && scalar(@$tmaps));
    return (0,0,0) unless (scalar(@$tmaps) == scalar(@$cmaps));

# compare each segment individually; if the mappings are identical
# apart from a linear shift and possibly counter alignment, all
# return values of alignment and offset will be identical

    my ($identical,$align,$shift);
    for (my $i = 0 ; $i < scalar(@$tmaps) ; $i++) {
	my $tsegment = $tmaps->[$i];
	my $csegment = $cmaps->[$i];
        my ($identical,$aligned,$offset) = $tsegment->compare($csegment);
        return 0 unless $identical;
# on first one register shift and alignment direction
        if (!defined($align) && !defined($shift)) {
            $align = $aligned; # either +1 or -1
            $shift = $offset;
        }
# the alignment and offsets between the mappings must all be identical 
        elsif ($align != $aligned || $shift != $offset) {
            return 0;
        }
    }

    return (1,$align,$shift);
}

sub orderSegments {
# sort the segments according to increasing read position
    my $this = shift;

    my $segments = $this->getSegments() || return;

# ensure all segments are normalised on the read domain and sort on Ystart

    foreach my $segment (@$segments) {
        $segment->normaliseOnY();
    }

    @$segments = sort { $a->getYstart() <=> $b->getYstart() } @$segments;

# deal with unit-length intervals (if the read and contig are counter aligned)

    my $n = scalar(@$segments) - 1;
    if ($segments->[0]->getXstart() > $segments->[$n]->getXfinis()) {
# the counter align method only works for unit length intervals
        foreach my $segment (@$segments) {
            $segment->counterAlignUnitLengthInterval();
        }
    }

    return $segments;
}

#-------------------------------------------------------------------
# apply linear translation to mapping
#-------------------------------------------------------------------

sub applyShiftToContigPosition {
# apply a linear contig shift to each segment
    my $this = shift;
    my $shift = shift;

    return 0 unless ($shift && $this->hasSegments());

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyShiftToX($shift);
    }
    return 1;
}
 
#-------------------------------------------------------------------
# store alignment segments
#-------------------------------------------------------------------

sub addAlignmentFromDatabase {
# input 3 array (cstart, rstart, length) and combine with direction
    my $this = shift;
    my ($cstart, $rstart, $length, $dummy) = @_;

    $length -= 1;

    my $cfinis = $cstart + $length;

    if ($length < 0) {
        die "Invalid length specification in Mapping ".$this->getReadName; 
    }
    elsif (my $direction = $this->{direction}) {
       
        $length = -$length if ($direction < 0);
        my $rfinis = $rstart + $length;

        $this->addAssembledFrom($cstart, $cfinis, $rstart, $rfinis);
    }
    else {
        die "Undefind alignment direction in Mapping ".$this->getReadName;
    }
}

sub addAssembledFrom {
# input 4 array (contigstart, contigfinis, (read)seqstart, seqfinis) 
    my $this = shift;

# validity input is tested in Segment constructor

    my $segment = new Segment(@_); 

    $this->{assembledFrom} = [] if !$this->{assembledFrom};

    push @{$this->{assembledFrom}},$segment;

    return scalar(@{$this->{assembledFrom}});
}

#-------------------------------------------------------------------
# export of alignment / segment info
#-------------------------------------------------------------------

sub hasSegments {
# returns true if at least one alignment exists
    my $this = shift;

    my $segments = $this->getSegments();

    return 0 unless defined($segments);

    return scalar(@$segments);
}

sub getSegments {
# export the assembledFrom mappings as array of segments
    my $this = shift;

    return $this->{assembledFrom}; # array reference or undef
}

sub getContigRange {
# find contig begin and end positions from the mapping segments
    my $this = shift;

    my ($cstart,$cfinal);

    foreach my $segment (@{$this->{assembledFrom}}) {
# ensure the correct alignment cstart <= cfinish
        $segment->normaliseOnX();
        my $cs = $segment->getXstart();
        $cstart = $cs if (!defined($cstart) || $cs < $cstart);
        my $cf = $segment->getXfinis();
        $cfinal = $cf if (!defined($cfinal) || $cf > $cfinal);
    }

    return ($cstart, $cfinal);
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
