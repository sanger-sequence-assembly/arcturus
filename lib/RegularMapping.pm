package RegularMapping;

use strict;

use CanonicalMapping;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
    my $prototype = shift;
    my $identifier = shift; # mapping number or name, optional

    my $class = ref($prototype) || $prototype;

    my $this = {};

    bless $this, $class;

# optionally set the identifier

    $this->setMappingName($identifier) if $identifier;

    return $this;
}

#-----------------------------------------------------------------------------
# parameters of the canonical mapping
#-----------------------------------------------------------------------------

sub setCanonicalMapping {
    my $this = shift;
    my $cmap = shift;

    if (ref($cmap) eq 'CanonicalMapping') {
        $this->{CanonicalMapping} = $cmap;
    }
}

sub getCanonicalMapping {
    my $this = shift;
# if we use a construction scheme in MappingFactory only, the next can not be done
#    MappingFactory->buildCanonicalMapping($this) unless $this->{CanonicalMapping};
    return $this->{CanonicalMapping};
}

sub getCanonicalMappingID {
    my $this = shift;
    my $canonicalmapping = $this->{CanonicalMapping};
    return undef unless defined $canonicalmapping; # just test
    return $canonicalmapping->getMappingID();
}

sub setCanonicalOffsetX { # contig domain
    my $this = shift;
    $this->{canonicaloffsetx} = shift;
}

sub getCanonicalOffsetX {
    my $this = shift;
    $this->getCanonicalMapping() unless defined $this->{canonicaloffsetx};
    return $this->{canonicaloffsetx} || 0;
}

sub setCanonicalOffsetY { # read / parent-contig / tag domain
    my $this = shift;
    $this->{canonicaloffsety} = shift;
}

sub getCanonicalOffsetY {
    my $this = shift;
    $this->getCanonicalMapping() unless defined $this->{canonicaloffsety};
    return $this->{canonicaloffsety} || 0;
}

sub getCheckSum() {
# return the checksum from the canonical mapping; if not there, build it
    my $this = shift;
    my $canonicalmapping = $this->getCanonicalMapping();
    return $canonicalmapping->getCheckSum() if $canonicalmapping;
# returns undef if no canonical segments defined; test return value
}
 
#-------------------------------------------------------------------
# mapping domain information
#-------------------------------------------------------------------

sub getContigRange { # alias
    return &getObjectRange(@_);
}

sub getContigStart {
    my $this = shift;
    return $this->getCanonicalOffsetX() + 1;
}

sub getObjectRange { # range on the host object, i.p. Contig
    my $this = shift;
    my $cmap = $this->getCanonicalMapping();
    my $span = $cmap->getSpanX();
    if ($this->isCounterAligned()) {
        return $this->getCanonicalOffsetX() - $span,
               $this->getCanonicalOffsetX() - 1;
    }
    else {
        return $this->getCanonicalOffsetX() + 1,
               $this->getCanonicalOffsetX() + $span;
    }
}

sub getMappedRange { # e.g. range on mapped object (read / parent / tag)
    my $this = shift;
    my $cmap = $this->getCanonicalMapping();
    my $span = $cmap->getSpanY();
    return $this->getCanonicalOffsetY() + 1,
           $this->getCanonicalOffsetY() + $span;
}

#-------------------------------------------------------------------
# mapping metadata (mappingname, mapping ID)
#-------------------------------------------------------------------

sub getMappingName { # e.g. for read-to-contig mappings : readname
    my $this = shift;
    return $this->{mappingname};
}

sub setMappingName {
    my $this = shift;
    $this->{mappingname} = shift;
}

#------------------------------------------------------------------------------
# the sequence IDs to which the mapping relates in the x and y domains
# e.g. for r-to-c mapping the y-domain has read seq_id, y-domain contig seq_id
# e.g. for p-to-c mapping the y-domain has parent seq_id, y-domain contig s_id
#------------------------------------------------------------------------------

sub getSequenceID {
    my $this = shift;
    my $domain = shift || 'y'; # default y-domain
    $domain = 'x' unless ($domain eq 'y'); # allow only 'x' or 'y'
    return $this->{$domain."seq_id"};
}

sub setSequenceID {
    my $this = shift;
    my $seq_id = shift;
    my $domain = shift || 'y'; # default y-domain
    $domain = 'x' unless ($domain eq 'y'); # allow only 'x' or 'y'
    $this->{$domain."seq_id"} = $seq_id;
}

sub setHostSequenceID { # alias 
    my $this = shift;
    $this->setSequenceID(shift,'x');
}

#-------------------------------------------------------------------
# alignment 
#-------------------------------------------------------------------

my %DIRECTION = (Forward => 1, Reverse => -1, F => 1, R => -1); # class variable

sub setAlignmentDirection {
# must be defined when creating Mapping instance from database
    my $this = shift;
    $this->setAlignment($DIRECTION{$_[0]});
}

sub getAlignmentDirection {
# returns 'Forward', 'Reverse' or undef
    my $this = shift;
    my $direction = $this->getAlignment() || return undef;
    return ($direction > 0) ? 'Forward' : 'Reverse';
}

sub setAlignment {
# define alignment direction as +1 or -1
    my $this = shift;
    my $adir = shift;
    return unless ($adir && abs($adir) == 1); # accepts only +1 or -1
    $this->{direction} = $adir;
}

sub getAlignment {
# returns +1, -1 or undef, the alignment of the mapping
    my $this = shift;
    return $this->{direction};
}

sub isCounterAligned {
    my $this = shift;
    return ($this->getAlignment() < 0) ? 1 : 0;
}

#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub isEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
#    my $mapping = shift;
#    my $compare = shift;
    return MappingFactory::isEqual(@_);
}

sub oldcompare {
    my $mapping = shift;
    my $compare = shift;

    return $mapping->multiply($compare->inverse(),@_); # test
}

sub compare {
# compare this Mapping instance with input Mapping at the segment level
#    my $mapping = shift;
#    my $compare = shift;
    return MappingFactory::compare(@_);
}

#-------------------------------------------------------------------
# apply linear transformation to mapping; access only via Contig
#-------------------------------------------------------------------

sub applyShiftToContigPosition { # shiftXPosition
# apply a linear contig (i.e. X) shift to each segment
    my $this = shift;
    my $shift = shift;

    $shift = -$shift if ($this->getAlignment() < 0);

# we do the shift on the c-offset parameter for the canonical mapping
# the next call on getCanonicalOffsetX builds the mapping from regular
# mapping segments, if not done before and resets the regular mappings

    $this->setCanonicalOffsetX( $this->getCanonicalOffsetX() + $shift);
#    $this->setCanonicalOffsetX( $this->getCanonicalOffsetX() + $shift); # wrong for counter aligned case

    undef $this->{RegularSegments}; # forces recalculation ?
}

sub applyMirrorTransform { # mirror (different from inverse)
# apply a contig mapping reversion and shift to each segment
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (= contig_length + 1)

    $this->setCanonicalOffsetX( $mirror - $this->getCanonicalOffsetX() );
#    $this->setCanonicalOffsetX( $mirror - $this->getCanonicalOffsetX() ); # wrong for counter aligned case

# invert alignment status

    $this->setAlignment(-$this->getAlignment());

    undef $this->{RegularSegments}; # forces recalculation ?
}

sub extendToFill {
# extend first and last segment to fill a given range in Y-domain
    my $this = shift;
    my $scfstart = shift;
    my $scffinal = shift;

# return a new mapping via MappingFactory

    return $this;
}
 
#-------------------------------------------------------------------
# importing alignment segments THIS SHOUL GO INTO THE MappingFactory
#-------------------------------------------------------------------

# sub addAlignmentFromDatabase  moved to canonical mapping 
# import regular alignment in local buffer              

sub addAssembledFrom {
# alias of putSegment: input (contigstart, contigfinis, (read)seqstart, seqfinis)
    return &putRegularSegment(@_);
}    

sub putRegularSegment {
# input 4 array (Xstart, Xfinis, Ystart, Yfinis)
    my $this = shift;
    my ($xs, $xf, $ys, $yf, @dummy) = @_;

# test validity of input; order segment in x-domain

    if ($xs > $xf) { # reorder
        ($xs, $xf) = ($xf, $xs);
        ($ys, $yf) = ($yf, $ys);
    }

    my $xl = $xf - $xs;
    my $yl = $yf - $ys;
# test equality of segments
    unless ($xl == abs($yl)) {
        print STDERR "Invalid segment sizes in Segment constructor: @_\n";
	return undef; # process outside
    }
# if length > 0, test alignment of new segment against mapping direction
    if ($xl > 0) {
        my $direction = ($xl == $yl) ? 1 : -1;
#        if (my $alignment = ($canonical ? 1 : $this->getAlignment())) {
        if (my $alignment = $this->getAlignment()) {  # add canonical?
            unless ($alignment == $direction) {
                print STDERR "Inconsistent alignment direction in Segment constructor: @_\n";
    	        return 0; # process outside
	    }
	}
# else unless canonical?
#        elsif (!$canonical) {
        else { # the alignment direction is not yet defined; do it here
            $this->setAlignment($direction);
	}
    }

# add the segments to this mappings segment list

#    my $segments = $this->getSegments($canonical);
    my $segments = $this->getRegularSegments();
    return 0 unless $segments;

#    push @$segments, $segment;

#    undef $this->{orderdomain};

#    return $this->hasSegments($canonical);
    return $this->hasRegularSegments();
}    

#-------------------------------------------------------------------
# export of alignment segments
#-------------------------------------------------------------------

sub hasSegments {
# returns number of (canonical) segments (may be 0) or undef
    my $this = shift;
    my $mark = shift; # optional
# cache the array_ref to the canonical segments
    unless ($this->{canonicalsegments}) {
        my $canonicalmapping = $this->{CanonicalMapping};
        return undef unless $canonicalmapping;
        $this->{canonicalsegments} = $canonicalmapping->getSegments();
    }

    my $size = scalar(@{$this->{canonicalsegments}});
# return 0 if a mark is set and size < mark, else return size
    return ($mark && $size < $mark) ? 0 : $size; 
}

sub getSegment { 
# get regular segment by number from canonical segment
    my $this = shift;
    my $segmentnumber = shift;

    return undef unless $this->hasSegments($segmentnumber);

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber];

    my $xoffset = $this->getCanonicalOffsetY();
    my $yoffset = $this->getCanonicalOffsetX();

    my @segment = $canonicalsegment->getSegment();
# transform the x and y coordinates from canonical coordinates
    foreach my $i (0,1) {
        $segment[$i] = -$segment[$i] if $this->isCounterAligned();
        $segment[$i]   += $xoffset;
        $segment[$i+2] += $yoffset;
    }

    return @segment; # an array
}

sub getXforY {
# return the X coordinate for a given segment and input Y coordinate
    my $this = shift;
    my $segmentnumber = shift;
    my $y = shift;

    return undef unless $this->hasSegments($segmentnumber);

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber];

    $y -= $this->getCanonicalOffsetY(); #   to canonical coordinates
    my $x = $canonicalsegment->getXforY($y,@_);
    return undef unless defined($x);

    $x = -$x if $this->isCounterAligned();
    $x += $this->getCanonicalOffsetX(); # from canonical coordinates

    return $x;
}

sub getYforX {
# return the Y coordinate for a given segment and input X coordinate
    my $this = shift;
    my $segmentnumber = shift;
    my $x = shift;

    return undef unless $this->hasSegments($segmentnumber);

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber];

    $x -= $this->getCanonicalOffsetX();
    $x = -$x if $this->isCounterAligned(); # to canonical coordinates

    my $y = $canonicalsegment->getYforX($x,@_);
    return undef unless defined($y);
    $y += $this->getCanonicalOffsetY(); #  from canonical coordinates
    
    return $y;
}

#-------------------------------------------------------------------
# tracking of alignment segments
#-------------------------------------------------------------------

sub setSegmentTracker {
# set counter to keep track of (last) segment used in multiply operation
    my $this = shift;
    $this->{currentsegment} = shift;
}

sub getSegmentTracker {
# get counter, e.g. of next segment to be used in multiply operation
    my $this = shift;
    my $vary = shift;

    $this->{currentsegment} = 0 unless defined $this->{currentsegment};

    my $rank = $this->{currentsegment};

    $rank += $vary if $vary; # optional offset NEEDS UPDATING based on alignment
#    if ($vary) {
#        $vary = -$vary if $this->isCounterAligned();
#        $rank += $vary;
#    }

    $rank = 0 if ($rank < 0 || $rank >= $this->hasSegments());

    return $rank;
}

#-------------------------------------------------------------------
# creating a new mapping, inverting and multiplying
#-------------------------------------------------------------------

sub copy {
# return a copy of this mapping or a segment as a new mapping
    my $this = shift; 
    my %options = @_; # segment=> (to select segment) , extend=> (name)
    return MappingFactory->copy($this,%options);
}

sub inverse {
# return inverse mapping as new mapping
    my $this = shift;
    return MappingFactory->inverse($this);
}

sub split {
# split the mapping in a list of new mappings
# default, split into the smallest number of regular mappings
# if full split, return one mapping for each segment 
    my $this = shift;
    my %options = @_; # full=> 
    return MappingFactory->split($this,%options); # returns array ref
}

sub join {
# join two mappings into an individually regular mapping if possible
    my $thismap = shift;
    my $thatmap = shift;
    return MappingFactory->join($thismap,$thatmap);
}

sub multiply {
# return the product R x T of this (mapping) and another mapping
# returns a mapping without segments if product is empty
    my $thismap = shift; # mapping R
    my $mapping = shift; # mapping T
    my %options = @_; # e.g. repair=>1  tracksegments=> 0,1,2,3 backskip after
    return MappingFactory->multiply($thismap,$mapping);
}

#-------------------------------------------------------------------
# transformation of objects in x-domain to y-domain
#-------------------------------------------------------------------

sub transform {
#sub transformPositions {
# transform an input x-range to an (array of) y-position intervals
    my $this = shift;
    my @position = sort {$a <=> $b} (shift,shift); # or array of positions(s)
    return MappingFactory($this,@position);
}

sub sliceString {
#sub transformString { # used in ContigHelper (1979) new-contig-loader (1478)
# map an input string in the x-domain to a string in the y-domain, replacing gaps by gapsymbol
    my $this = shift;
    my $string = shift || return undef;
    my %options = @_; # gapsymbol=>
    return MappingFactory->transformString($this,$string,%options);
}

sub sliceArray {
#sub transformArray {
# map an input array in the x-domain to an array in the y-domain, replacing gaps by gap values
    my $this = shift;
    my $array = shift || return undef; # array reference
    my %options = @_; # gapvalue=>
    return MappingFactory->transformArray($this,$array,%options);
}

#-------------------------------------------------------------------
# formatted export
#-------------------------------------------------------------------

sub assembledFromToString {
# write alignments as (block of) 'Assembled_from' records
    my $this = shift;

    my $text = "Assembled_from ".$this->getMappingName()." ";

    return $this->writeToString($text,@_);
}

sub writeToString {
# write alignments as (block of) "$text" records
    my $this = shift;
    my $text = shift || '';
    my %options = @_; # canonical ?


    my @xrange = $this->getObjectRange();
    my @yrange = $this->getMappedRange();

    my $maximum = 1;
    foreach my $position (@xrange,@yrange) {
        $maximum = abs($position) if (abs($position) > $maximum);
    }
    my $nd = int(log($maximum)/log(10)) + 2;

    my $string = '';

#    my $numberofsegments = $this->hasSegments();
#    foreach my $segmentnumber (1 .. $numberofsegments) {
#        my @segment = $this->getSegment($segmentnumber);
    my $segments = $this->getSegments();
#    my $segments = $this->getRegularSegments();

    foreach my $segment (@$segments) {
# unless option asis use standard representation: align on Y
        my @segment = $segment->getSegment();

        unless ($options{asis} || $segment[2] <= $segment[3]) {
            ($segment[0],$segment[1]) = ($segment[1],$segment[0]);
            ($segment[2],$segment[3]) = ($segment[3],$segment[2]);
        }
        $string .= $text;
        foreach my $position (@segment) {
#            $string .= sprintf " %${nd}d",$position;
            $string .= sprintf " %d",$position;
	}
        if ($options{extended}) {
            $string .= "   a:".($segment->getAlignment() || 'undef');
            $string .=   " o:".($segment->getOffset()    || 0);
            $string .=   " l:". $segment->getSegmentLength();
	}
        $string .= "\n";
    }

    $string = $text." is undefined\n" unless $string; 

    return $string;
}

sub toString {
# primarily for diagnostic purposes
    my $this = shift;
    my %options = @_; # text=>...  extended=>...  norange=>...

    my $mappingname = $this->getMappingName()        || 'undefined';
    my $direction   = $this->getAlignmentDirection() || 'UNDEFINED';
    my $targetsid   = $this->getSequenceID('y')      || 'undef';
    my $hostseqid   = $this->getSequenceID('x')      || 'undef';

    my $string = "Mapping: name=$mappingname, sense=$direction"
	       .         " target=$targetsid  host=$hostseqid";

    unless (defined($options{range}) && !$options{range}) {
	my ($cstart, $cfinis,$range);
# force redetermination of intervals
        if (!$options{range} || $options{range} eq 'X') {
           ($cstart, $cfinis) =  $this->getContigRange();
	    $range = 'object';
        }
	else {
           ($cstart, $cfinis) =  $this->getMappedRange();
	    $range = 'mapped';
        }
        $cstart = 'undef' unless defined $cstart;
        $cfinis = 'undef' unless defined $cfinis;
	$string .= ", ${range}range=[$cstart, $cfinis]";
    }

    $string .= "\n";

    unless ($options{Xdomain} || $options{Ydomain}) {
        $string .= $this->writeToString($options{text},%options);
        return $string;
    }

# list the windows and the sequences 

#    my $numberofsegments = $this->hasSegments();
#    foreach my $segmentnumber (1 .. $numberofsegments) {
#        my @segment = $this->getSegment($segmentnumber);

    my $segments = $this->getSegments();
#    my $segments = $this->getRegularSegments();

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
#        my @segment = @$segment;
# diagnostic output with mapped sequence segments
        my $length = abs($segment[1] - $segment[0]) + 1;
        if (my $sequence = $options{Xdomain}) {
            my $k = ($segment[2] <= $segment[3]) ? 2 : 3;
            $string .= sprintf("%7d",$segment[2])
		    .  sprintf("%7d",$segment[3]);
            my $substring = substr($sequence,$segment[$k]-1,$length);
            $substring = reverse($substring)    if ($k == 3);
            $substring =~ tr/acgtACGT/tgcaTGCA/ if ($k == 3);    
            $string .= "  " . $substring ."\n";
 	}
        if (my $template = $options{Ydomain}) {
            my $k = ($segment[0] <= $segment[1]) ? 0 : 1;
            $string .= sprintf("%7d",$segment[0])
	    	    .  sprintf("%7d",$segment[1]);
            my $substring = substr($template,$segment[$k]-1,$length);
            $substring = reverse($substring)    if ($k == 1);
            $substring =~ tr/acgtACGT/tgcaTGCA/ if ($k == 1); 
            $string .= "  " . $substring ."\n";
        }
    }

    return $string;
}

#-------------------------------------------------------------------

1;
