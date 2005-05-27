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

sub getContigRange {
    my $this = shift;

    my $range = $this->{contigrange};

    unless ($range && @$range) {
# no contig range defined, use (all) segments to find it
	my $segments = $this->getSegments();
	$range = &findContigRange($segments); # returns arrayref
	return undef unless defined($range);
	$this->{contigrange} = $range; # cache
    }

    return @$range;
}

sub getContigStart {
    my $this = shift;
    my @range = $this->getContigRange();
    return $range[0];
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

sub isEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
    my $this = shift;
    my $compare = shift;

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

    my $tmaps = $this->analyseSegments();    # also sorts segments
    my $cmaps = $compare->analyseSegments(); # also sorts segments

# test presence of mappings

    return (0,0,0) unless ($tmaps && $cmaps && scalar(@$tmaps));

# compare each segment individually; if the mappings are identical
# apart from a linear shift and possibly counter alignment, all
# return values of alignment and offset will be identical.

    return (0,0,0) unless (scalar(@$tmaps) == scalar(@$cmaps));

# return 0 on first encountered mismatch of direction, offset (or 
# segment size); otherwise return true and alignment direction & offset 

    my ($align,$shift);
    for (my $i = 0 ; $i < scalar(@$tmaps) ; $i++) {

	my $tsegment = $tmaps->[$i];
	my $csegment = $cmaps->[$i];

        my ($identical,$aligned,$offset) = $tsegment->compare($csegment);

# we require all mapped read segments to be identical

        return 0 unless $identical;

# on first segment register shift and alignment direction

        if (!defined($align) && !defined($shift)) {
            $align = $aligned; # either +1 or -1
            $shift = $offset;
        }
# the alignment and offsets between the mappings must all be identical 
        elsif ($align != $aligned || $shift != $offset) {
            return 0;
        }
    }

# the mappings are identical under the linear transform with $align and $shift

    return (1,$align,$shift);
}

sub compare {
# compare this Mapping instance with input Mapping at the segment level
    my $this = shift;
    my $compare = shift;

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

    my $tmaps = $this->analyseSegments();    # also sorts segments
    my $cmaps = $compare->analyseSegments(); # also sorts segments

# test presence of mappings

    return (0,0,0) unless ($tmaps && $cmaps && scalar(@$tmaps)&& scalar(@$cmaps));

# go through the segments of both mappings and collate consecutive overlapping
# contig segments (on $cmapping) of the same offset into a list of output segments


    my @osegments; # list of output segments

    my $it = 0;
    my $ic = 0;

    my ($align,$shift);
    while ($it < @$tmaps && $ic < @$cmaps) {

        my $tsegment = $tmaps->[$it];
        my $csegment = $cmaps->[$ic];
# get the interval on both $this and the $compare segment 
        my $ts = $tsegment->getYstart(); # read positions
        my $tf = $tsegment->getYfinis();
        my $cs = $csegment->getYstart();
        my $cf = $csegment->getYfinis();

# determine if the intervals overlap by finding the overlapping region

        my $os = ($cs > $ts) ? $cs : $ts;
        my $of = ($cf < $tf) ? $cf : $tf;

        if ($of >= $os) {
# test at the segment level to obtain offset and alignment direction
            my ($identical,$aligned,$offset) = $tsegment->compare($csegment);

# on first interval tested register alignment direction

	    $align = $aligned unless defined($align);
# break on alignment inconsistency; fatal error, but should never occur
            return 0,undef unless ($align == $aligned);

# initialise or update the contig alignment segment information on $csegment
# we have to ensure that the contig range increases in the output segments

            $os = $csegment->getXforY($os); # contig position
            $of = $csegment->getXforY($of);
# ensure that the contig range increases
           ($os, $of) = ($of, $os) if ($csegment->getAlignment < 0);

            if (!defined($shift) || $shift != $offset) {
# it's the first time we see this offset value: open a new output segment
                $shift = $offset;
                my @osegment = ($offset, $os, $of);
                push @osegments, [@osegment];
            }
            else {
# we're still in the same output segment: adjust its end position
                my $n = scalar(@osegments);
                my $osegment = $osegments[$n-1];
                $osegment->[2] = $of if ($of > $osegment->[2]);
                $osegment->[1] = $os if ($os < $osegment->[1]);
            }

# get the next segments to investigate
            $it++ if ($tf <= $cf);
            $ic++ if ($cf <= $tf);
        }

        elsif ($tf < $cs) {
# no overlap, this segment to the left of compare
            $it++;
        }
        elsif ($ts > $cf) {
# no overlap, this segment to the right of compare
            $ic++;
        }
    }

# convert the segments into a Mapping object

    my $mapping = new Mapping('CC:'.$this->getMappingName);
    $mapping->setAlignment($align) if defined($align);

    foreach my $osegment (@osegments) {
        my ($offset,@cpos) = @$osegment;
        for my $i (0,1) {
            $cpos[$i+2] = $cpos[$i] + $offset;
            $cpos[$i+2] = -$cpos[$i+2] if ($align < 0);
        }
	$mapping->putSegment(@cpos);
    }

    return $mapping unless (shift);

    return $align,[@osegments]; # old system
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
# apply linear transformation to mapping; access only via Contig
#-------------------------------------------------------------------

sub applyShiftToContigPosition {
# apply a linear contig (i.e. X) shift to each segment
    my $this = shift;
    my $shift = shift;

    return 0 unless ($shift && $this->hasSegments());

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(1,$shift); # apply shift to X
    }

    undef $this->{contigrange}; # force re-initialisation of cache

    return 1;
}

sub applyMirrorTransform {
# apply a contig mapping inversion (i.e. mirror X) to each segment
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (= contig_length + 1)

    return 0 unless $this->hasSegments();

# apply the mirror transformation (y = -x + m) all segments

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(-1,$mirror);
    }

# invert alignment status

    $this->setAlignment(-$this->getAlignment());

    undef $this->{contigrange}; # force re-initialisation of cache

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

        $this->putSegment($cstart, $cfinis, $rstart, $rfinis);
    }
    else {
        die "Undefind alignment direction in Mapping ".$this->getMappingName;
    }
}

sub addAssembledFrom {
# alias of putSegment: input (contigstart, contigfinis, (read)seqstart, seqfinis)
    return &putSegment(@_);
}    

sub putSegment {
# input 4 array (Xstart, Xfinis, Ystart, Yfinis)
    my $this = shift;

# validity input is tested in Segment constructor

    my $segment = new Segment(@_); 

    $this->{mySegments} = [] if !$this->{mySegments};

    push @{$this->{mySegments}},$segment;

    return scalar(@{$this->{mySegments}});
}
 
#-------------------------------------------------------------------
# inverting and multiplying mappings (re: padded - unpadded)
#-------------------------------------------------------------------

sub inverse {
# return inverse mapping
    my $this = shift;

    my $segments = $this->getSegments();

    return undef unless ($segments && @$segments);

    my $name = $this->getMappingName() || $this;
    my $mapping = new Mapping("inverse of $name");

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
        $mapping->putSegment($segment[2],$segment[3],
                             $segment[0],$segment[1]);
    }

#    @$segments = sort { $a->getYstart() <=> $b->getYstart() } @$segments;

    return $mapping;   
}

sub multiply {
# return the product of this (mapping) and another mapping
    my $this = shift;
    my $mapping = shift;
    my $repair = shift || 0;

    my $rsegments = $this->getSegments();
    my $tsegments = $mapping->getSegments();

    my $rname = $this->getMappingName() || 'R';
    my $tname = $mapping->getMappingName() || 'T';

    my $product = new Mapping("$rname x $tname");

    my ($rs,$ts) = (0,0);

    while ($rs < scalar(@$rsegments) && $ts < scalar(@$tsegments)) {

	my $rsegment = $rsegments->[$rs];
	my $tsegment = $tsegments->[$ts];

        my ($rxs,$rxf,$rys,$ryf) = $rsegment->getSegment();
        my ($txs,$txf,$tys,$tyf) = $tsegment->getSegment();

        if (my $mxs = $tsegment->getYforX($rys)) {
# begin of x window of R maps to y inside the T window
            if (my $mxf = $tsegment->getYforX($ryf)) {
# also end of x window of R maps to y inside the T window
                $product->putSegment($rxs,$rxf,$mxs,$mxf);
                $rs++;
	    }
# no, end of x window of R does not map to y inside the T window
# break this segment by finding the end via backtransform of $txf
	    elsif (my $bxf = $rsegment->getXforY($txf)) {
                $product->putSegment($rxs,$bxf,$mxs,$tyf);
                $ts++;
	    }
	    else {
		print STDERR "Mapping->multiply: should not occur (1) !!\n";
	    }
	}
# begin of x window of R does not map to y inside the T window
# check if the end falls inside the segment
        elsif (my $mxf = $tsegment->getYforX($ryf)) {
# okay, the end falls inside the window, get the begin via back tranform 
            if (my $bxs = $rsegment->getXforY($txs)) {
                $product->putSegment($bxs,$rxf,$tys,$mxf);
                $rs++;
            }
            else {
	        print STDERR "Mapping->multiply: should not occur (2) !!\n";
		exit;
	    }
	}
# both end points fall outside the T mapping; test if T falls inside R
        elsif (my $bxs = $rsegment->getXforY($txs)) {
# the t segment falls inside the r segment
            if (my $bxf = $rsegment->getXforY($txf)) {
                $product->putSegment($bxs,$bxf,$tys,$tyf);
                $ts++;
            }
            else {
	        print STDERR "Mapping->multiply: should not occur (3) !!\n";
            }
        }
        else {
            $ts++ if ($ryf >= $txf);
            $rs++ if ($ryf <= $txf);
	}
    }

    $product->collate($repair);

    return $product;
}

sub collate {
# determine if consecutive segments are butted together, if so merge them
    my $this = shift;
    my $repair = shift || 0;

    my $segments = $this->getSegments() || return;
     
    @$segments = sort {$a->getYstart <=> $b->getYstart} @$segments;

    my $i = 1;
    while ($i < scalar(@$segments)) {
        my $ls = $segments->[$i-1];
        my $ts = $segments->[$i++];
        my $xdifference = $ts->getXstart() - $ls->getXfinis();
        my $ydifference = $ts->getYstart() - $ls->getYfinis();
        next unless (abs($xdifference) == abs($ydifference));
        next if ($xdifference > $repair+1);
# replace the two segments ($i-2 and $i-1) by a single one
        splice @$segments, $i-2, 2;
        $this->putSegment($ls->getXstart(), $ts->getXfinis(),
			  $ls->getYstart(), $ts->getYfinis());
        @$segments = sort {$a->getYstart <=> $b->getYstart} @$segments;
        $i = 1;
    }
}

#-------------------------------------------------------------------
# export of alignment segments
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
    $this->{mySegments} = [] if !$this->{mySegments};

    return $this->{mySegments}; # array reference
}

sub assembledFromToString {
# write alignments as (block of) 'Assembled_from' records
    my $this = shift;

    my $text = "Assembled_from ".$this->getMappingName()." ";

    return $this->writeToString($text);
}

sub writeToString {
# write alignments as (block of) "$text" records
    my $this = shift;
    my $text = shift || '';

    my $segments = $this->getSegments();

    my $string = '';
    foreach my $segment (@$segments) {
        $segment->normaliseOnY(); # ensure rstart <= rfinish
        my @segment = $segment->getSegment();
        $string .= $text." @segment\n";
    }

    $string = $text." is undefined\n" unless $string; 

    return $string;
}

sub toString {
    my $this = shift;
    my $flags = shift || 0;

    $this->{contigrange} = undef;
    my $mappingname = $this->getMappingName() || 'undefined';
    my $direction = $this->getAlignmentDirection();

    my $string = "Mapping: name=$mappingname, sense=$direction";

    if (!$flags) {
	my ($cstart, $cfinish) =  $this->getContigRange();
	$string .= ", contigrange=[$cstart, $cfinish]";
    }

    $string .= "\n";

    $string .= $this->writeToString();

    return $string;
}

#-------------------------------------------------------------------
# private function
#-------------------------------------------------------------------

sub findContigRange {
# private find contig begin and end positions from input mapping segments
    my $segments = shift; # arrayref for Segments

# if no segments specified default to all

    return undef unless (ref($segments) eq 'ARRAY');

    my ($cstart,$cfinal);

    foreach my $segment (@$segments) {
# ensure the correct alignment cstart <= cfinish
        $segment->normaliseOnX();
        my $cs = $segment->getXstart();
        $cstart = $cs if (!defined($cstart) || $cs < $cstart);
        my $cf = $segment->getXfinis();
        $cfinal = $cf if (!defined($cfinal) || $cf > $cfinal);
    }

    return defined($cstart) ? [($cstart, $cfinal)] : undef;
}

#-------------------------------------------------------------------

1;
