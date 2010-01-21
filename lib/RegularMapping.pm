package RegularMapping;

use strict;

use MappingFactory::MappingFactory;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
# constructor takes a list of alignment segments
    my $prototype = shift;
    my $segment_arrayref = shift;

    my $class = ref($prototype) || $prototype;

    my $this = {};

    bless $this, $class;

# pass segment array and options to ->build method; return undef or CanonicalMapping
# options taken : empty     => 1 : allow building an empty mapping (default do not) 
#                 bridgegap => n : merge budding segments if the gap size is <= n
#                 verify    => 1 : (test) switch on verification of mappings against
#                                  the properties of a possible cached version
#                 default values for all three options is 0

    my ($cm, $xo, $yo, $alignment) = MappingFactory->build($segment_arrayref,@_);

    return 0 unless defined $cm; # signal failure of build

    $this->setCanonicalMapping($cm);
    $this->setCanonicalOffsetX($xo);
    $this->setCanonicalOffsetY($yo);
    $this->setAlignment($alignment);

    return $this;
}

#-----------------------------------------------------------------------------
# parameters of the canonical mapping
#-----------------------------------------------------------------------------

sub setCanonicalMapping {
    my $this = shift;
    my $cmap = shift;

    if (ref($cmap) eq 'CanonicalMapping') {
        $this->{canonicalmapping} = $cmap;
    }
}

sub getCanonicalMapping {
    my $this = shift;
    return $this->{canonicalmapping};
}

sub getCanonicalMappingID {
    my $this = shift;
    my $canonicalmapping = $this->getCanonicalMapping();
    return undef unless defined $canonicalmapping; # just test
    return $canonicalmapping->getMappingID();
}

sub setCanonicalOffsetX { # contig domain
    my $this = shift;
    $this->{canonicaloffsetx} = shift;
}

sub getCanonicalOffsetX {
    my $this = shift;
    return $this->{canonicaloffsetx};
}

sub setCanonicalOffsetY { # read / parent-contig / tag domain
    my $this = shift;
    $this->{canonicaloffsety} = shift;
}

sub getCanonicalOffsetY {
    my $this = shift;
    return $this->{canonicaloffsety};
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

sub getContigStart { # re: sort mappings on (contig) position
    my $this = shift;
    my @range = $this->getObjectRange();
    return $range[0];
}

sub getObjectRange { # range on the host object, i.p. Contig
    my $this = shift;
    my $cmap = $this->getCanonicalMapping() || return undef;
    my $span = $cmap->getSpanX() || return (0,0);
    if ($this->isCounterAligned()) {
        return $this->getCanonicalOffsetX() - $span,
               $this->getCanonicalOffsetX() - 1;
    }
    else {
        return $this->getCanonicalOffsetX() + 1,
               $this->getCanonicalOffsetX() + $span;
    }
}

sub getMappedRange { # e.g. range on mapped from object (read / parent / tag)
    my $this = shift;
    my $cmap = $this->getCanonicalMapping() || return undef;
    my $span = $cmap->getSpanY() || return (0,0);
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
# apply linear transformation to mapping; access only via Contig
#-------------------------------------------------------------------

sub applyShiftToContigPosition { # shiftXPosition
# apply a linear contig (i.e. X domain) shift to each segment
    my $this = shift;
    my $shift = shift;

# we do the shift on the x-offset parameter for the canonical mapping

    $this->setCanonicalOffsetX( $this->getCanonicalOffsetX() + $shift );
}

sub applyMirrorTransform { # mirror (different from inverse)
# apply a contig (Y domain) mapping reversion and shift to each segment
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (= contig_length + 1)

    $this->setCanonicalOffsetX( $mirror - $this->getCanonicalOffsetX() );

# invert alignment status

    $this->setAlignment( -$this->getAlignment() );
}

#-------------------------------------------------------------------
# export of alignment segments derived from the canonical mapping
#-------------------------------------------------------------------

sub hasSegments {
# returns number of (canonical) segments (may be 0) or undef
    my $this = shift;
    my $mark = shift; # optional
# cache the array_ref to the canonical segments
    unless ($this->{canonicalsegments}) {
        my $canonicalmapping = $this->getCanonicalMapping(); # may do complete
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

    return undef unless $this->hasSegments($segmentnumber); # does segment exist

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber-1];

    $this->setCurrentSegment($segmentnumber); # record last accessed segment

    my $xoffset = $this->getCanonicalOffsetX();
    my $yoffset = $this->getCanonicalOffsetY();

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

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber-1];

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

    my $canonicalsegment = $this->{canonicalsegments}->[$segmentnumber-1];

    $x -= $this->getCanonicalOffsetX();
    $x = -$x if $this->isCounterAligned(); # to canonical coordinates

    my $y = $canonicalsegment->getYforX($x,@_);
    return undef unless defined($y);
    $y += $this->getCanonicalOffsetY(); #  from canonical coordinates
    
    return $y;
}

#-------------------------------------------------------------------
# tracking of alignment segments (re: multiply operation)
#-------------------------------------------------------------------

sub setCurrentSegment {
    my $this = shift;
    $this->{currentsegment} = shift;
}

sub getCurrentSegment {
    my $this = shift;
    return $this->{currentsegment};
}

#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub isEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
    my $mapping = shift;
    my $compare = shift;

    return MappingFactory::isEqual($mapping,$compare,@_);
}

sub compare { # TO TEST OBSOLETE?
# compare this Mapping instance with input Mapping at the segment level
    my $mapping = shift;
    my $compare = shift;
#    return MappingFactory::compare($mapping,$compare);
    return $mapping->multiply($compare->inverse(),@_); # test
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

sub multiply {
# return the product R x T of this (mapping) and another mapping
# returns a mapping without segments if product is empty
    my $thismap = shift; # mapping R
    my $mapping = shift; # mapping T
    my %options = @_; # e.g. bridgegap=>1  tracksegments=> 0,1,2,3 backskip after
    return MappingFactory->multiply($thismap,$mapping,@_);
}

sub toString {
    my $this = shift;
    return MappingFactory->toString($this);
}

# the next two methods were used in tag remapping; they may be redundent

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

#-------------------------------------------------------------------
# transformation of objects in x-domain to y-domain
#-------------------------------------------------------------------

sub transform { # TO TEST
#sub transformPositions {
# transform an input x-range to an (array of) y-position intervals
    my $this = shift;
    my @position = sort {$a <=> $b} (shift,shift); # or array of positions(s)
    return MappingFactory($this,@position);
}

sub sliceString { # TO TEST
#sub transformString { # used in ContigHelper (1979) new-contig-loader (1478)
# map an input string in the x-domain to a string in the y-domain, replacing gaps by gapsymbol
    my $this = shift;
    my $string = shift || return undef;
    my %options = @_; # gapsymbol=>
    return MappingFactory->transformString($this,$string,%options);
}

sub sliceArray { # TO TEST
#sub transformArray {
# map an input array in the x-domain to an array in the y-domain, replacing gaps by gap values
    my $this = shift;
    my $array = shift || return undef; # array reference
    my %options = @_; # gapvalue=>
    return MappingFactory->transformArray($this,$array,%options);
}

#-------------------------------------------------------------------

sub expand { # TO TEST
# extend first and last segment to fill a given range in Y-domain
    my $this = shift;
    my $scfstart = shift;
    my $scffinal = shift;
# return a new mapping via MappingFactory
    my %options = (domain => 'Y');
    $options{start} = $scfstart if $scfstart;
    $options{final} = $scffinal if $scffinal;
    return MappingFactory->extendToFill($this,%options);
}

#-------------------------------------------------------------------
# formatted export (i.p. read-to-contig alignment)
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
    my %options = @_;


    my @xrange = $this->getObjectRange();
    my @yrange = $this->getMappedRange();

    my $maximum = 1;
    foreach my $position (@xrange,@yrange) {
        next unless defined($position);
        $maximum = abs($position) if (abs($position) > $maximum);
    }
    my $nd = int(log($maximum)/log(10)) + 2;

    my $string = '';

    my $numberofsegments = $this->hasSegments() || 0;
    foreach my $segmentnumber (1 .. $numberofsegments) {
        my @segment = $this->getSegment($segmentnumber);

        unless ($options{asis} || $segment[2] <= $segment[3]) {
# order segment in y domain
            ($segment[0],$segment[1]) = ($segment[1],$segment[0]);
            ($segment[2],$segment[3]) = ($segment[3],$segment[2]);
        }
        $string .= $text;
        foreach my $position (@segment) {
            $string .= sprintf " %${nd}d",$position;
	}
        if ($options{extended}) {
            $string .= "   a:".($this->getAlignment() || 'undef');
            my $offset = $segment[2];
            $offset = -$offset if $this->isCounterAligned();
            $string .=   " o:".($offset);
            $string .=   " l:".($segment[3]-$segment[2]+1);
	}
        $string .= "\n";
    }

    $string = "mapping is empty\n" unless $string; 

    return $string;
}

#-------------------------------------------------------------------

1;
