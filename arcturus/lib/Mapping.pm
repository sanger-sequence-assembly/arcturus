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

    $this->setMappingName($identifier) if $identifier;

    return $this;
}
 
#-------------------------------------------------------------------
# mapping metadata (mappingname, sequence ID, mapping ID and alignment)
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

sub getMappingName {
    my $this = shift;
    return $this->{mappingname};
}

sub setMappingName {
    my $this = shift;
    $this->{mappingname} = shift;
}

sub getSequenceID {
    my $this = shift;
    return $this->{seq_id};
}

sub setSequenceID {
    my $this = shift;
    $this->{seq_id} = shift;
}

sub setAlignmentDirection {
# must be defined when creating Mapping instance from database
    my $this = shift;
    my $direction = shift;

    if ($direction eq 'Forward') {
        $this->setAlignment(1);
    }
    elsif ($direction eq 'Reverse') {
        $this->setAlignment(-1);
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

sub setAlignment {
# define alignment direction as +1 or -1
    my $this = shift;
    my $adir = shift;

    return unless (abs($adir) == 1);
    $this->{direction} = $adir;
}

sub getAlignment {
# returns +1, -1 or undef
    my $this = shift;

# if the direction is undefined (or 0), analyse the segments (if any)
# (orders the segments and determines the mapping alignment direction)

    $this->analyseSegments() unless $this->{direction};

    return $this->{direction};
}
 
#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub compare {
# compare this Mapping instance with input Mapping
    my $this = shift;
    my $compare = shift;
    my $relaxed = shift; # optional

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

    my $tmaps = $this->analyseSegments();
    my $cmaps = $compare->analyseSegments();

# test presence of mappings

    return (0,0,0) unless ($tmaps && $cmaps && scalar(@$tmaps));

# compare each segment individually; if the mappings are identical
# apart from a linear shift and possibly counter alignment, all
# return values of alignment and offset will be identical.
# if relaxed mode active, ignore differences of segment size (and number)
# but only consider the alignment direction and offset.

    return (0,0,0) unless (scalar(@$tmaps) == scalar(@$cmaps) || $relaxed);

# return 0 on first encountered mismatch of direction, offset (or 
# segment size); otherwise return true and alignment direction & offset 

    my ($identical,$align,$shift);
    for (my $i = 0 ; $i < scalar(@$tmaps) ; $i++) {
	my $tsegment = $tmaps->[$i];
	my $csegment = $cmaps->[$i] || next; # can occur when relaxed
        my ($identical,$aligned,$offset) = $tsegment->compare($csegment);
        return 0 unless ($identical || $relaxed);
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

sub analyseSegments {
# sort the segments according to increasing read position
# determine/test alignment direction from the segments
    my $this = shift;

    return 0 unless $this->hasSegments();

    my $segments = $this->getSegments();

# ensure all segments are normalised on the read domain and sort on Ystart

    foreach my $segment (@$segments) {
        $segment->normaliseOnY();
    }

    @$segments = sort { $a->getYstart() <=> $b->getYstart() } @$segments;

# determine the alignment direction from the range covered by all segments
# if it is a reverse alignment we have to reset the alignment direction in
# single base segments by applying the counterAlign... method

    my $n = scalar(@$segments) - 1;
 
    my $direction = 1;
    if ($segments->[0]->getXstart() > $segments->[$n]->getXfinis()) {
# the counter align method only works for unit length intervals
        $direction = -1;
        foreach my $segment (@$segments) {
            $segment->counterAlignUnitLengthInterval();
        }
    }

# test consistency of alignments

    foreach my $segment (@$segments) {
	if ($segment->getAlignment() != $direction) {
# if this error occurs it is an indication for an erroneous alignment
# direction in the MAPPING table, likely in a read with unit-length segment
            print STDERR "Inconsistent alignment direction in mapping "
                         .($this->getMappingName || $this->getSequenceID).
			 "\n: ".$this->assembledFromToString;
            $direction = 0;
            last;
        }
    }

# register the alignment direction
    
    $this->setAlignment($direction);

    return $segments;
}

#-------------------------------------------------------------------
# apply linear translation to mapping
#-------------------------------------------------------------------

sub applyShiftToContigPosition {
# apply a linear contig (i.e. X) shift to each segment
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
# importing alignment segments
#-------------------------------------------------------------------

sub addAlignmentFromDatabase {
# input 3 array (cstart, rstart, length) and combine with direction
# this import requires that the alignment direction is defined beforehand
    my $this = shift;
    my ($cstart, $rstart, $length, $dummy) = @_;

    $length -= 1;

    my $cfinis = $cstart + $length;

    if ($length < 0) {
        die "Invalid length specification in Mapping ".$this->getMappingName; 
    }
    elsif (my $direction = $this->{direction}) {
       
        $length = -$length if ($direction < 0);
        my $rfinis = $rstart + $length;

        $this->addAssembledFrom($cstart, $cfinis, $rstart, $rfinis);
    }
    else {
        die "Undefind alignment direction in Mapping ".$this->getMappingName;
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
# export of alignment segments and 
#-------------------------------------------------------------------

sub hasSegments {
# returns true if at least one alignment exists
    my $this = shift;

    return scalar(@{$this->getSegments});
}

sub getSegments {
# export the assembledFrom mappings as array of segments
    my $this = shift;
# ensure an array ref, also if no segments are defined
    $this->{assembledFrom} = [] if !$this->{assembledFrom};

    return $this->{assembledFrom}; # array reference
}

sub getContigRange {
# find contig begin and end positions from the mapping segments
    my $this = shift;

    my ($cstart,$cfinal);

    foreach my $segment (@{$this->getSegments()}) {
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

    my $assembledFrom = "Assembled_from ".$this->getMappingName()." ";

    my $string = '';
    foreach my $segment (@{$this->{assembledFrom}}) {
        $segment->normaliseOnY(); # ensure rstart <= rfinish
        my $xstart = $segment->getXstart();
        my $xfinis = $segment->getXfinis();
        my $ystart = $segment->getYstart();
        my $yfinis = $segment->getYfinis();
        $string .= $assembledFrom." $xstart $xfinis $ystart $yfinis\n";
#        $string .= $assembledFrom.$segment->toString()."\n";
    }

    $string = "$assembledFrom"."is undefined\n" if (!$string && shift); 

    return $string;
}

#-------------------------------------------------------------------

1;
