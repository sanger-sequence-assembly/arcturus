package Mapping;

use strict;

use Segment;

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

sub setCanonicalOffsetX { # contig domain
    my $this = shift;
    $this->{canonicaloffsetx} = shift;
}

sub getCanonicalOffsetX {
    my $this = shift;
    $this->hasSegments(1); # builds the canonical map if not yet done
    return $this->{canonicaloffsetx} || 0;
}

sub setCanonicalOffsetY { # read / parent-contig / tag domain
    my $this = shift;
    $this->{canonicaloffsety} = shift;
}

sub getCanonicalOffsetY {
    my $this = shift;
    $this->hasSegments(1); # builds the canonical map if not yet done
    return $this->{canonicaloffsety} || 0;
}

sub setCheckSum {
    my $this = shift;
    $this->{segmentchecksum} = shift;
}

sub getCheckSum {
    my $this = shift;
# ???
    MappingFactory->getCheckSum($this) unless $this->{segmentchecksum};
    return $this->{segmentchecksum};
}
 
#-------------------------------------------------------------------
# mapping domain information
#-------------------------------------------------------------------

sub getContigRange { # alias
    return &getObjectRange(@_);
}

sub getContigStart {
    my @range = &getObjectRange(@_);
    return $range[0];
}

sub getObjectRange { # range on the host object, i.p. Contig
    my $this = shift;
    my $test = shift; # force testing the current range

    my $range = $this->{objectrange};

    unless ($range && @$range && !$test) {
# no contig range defined, use (all) segments to find it
        $range = &findXrange($this->getSegments()); # returns array-ref
	return undef unless defined($range);
	$this->{objectrange} = $range; # cache
    }

    return @$range;
}

sub getMappedRange { # range on mapped object (read / parent / tag)
    my $this = shift;

    my $range = &findYrange($this->getSegments());

    return @$range if $range;
}

#-------------------------------------------------------------------
# mapping metadata (mappingname, mapping ID)
#-------------------------------------------------------------------

sub getMappingID {   # Arcturus mapping_id
    my $this = shift;
    return $this->{mapping_id};
}

sub setMappingID {
    my $this = shift;
    $this->{mapping_id} = shift;
}

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
    $this->setAlignment($DIRECTION{shift});
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
    my $adir = shift || 0;
    return unless (abs($adir) == 1); # accepts only +1 or -1
    $this->{direction} = $adir;
}

sub getAlignment {
# returns +1, -1 or undef, the alignment of the mapping
    my $this = shift;
#    if ($this->Canonical()) {
#        return 1 unless (shift); # canonical mapping by definition co-aligned
#    }
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

sub compare {
# return &oldcompare(@_);
    my $mapping = shift;
    my $compare = shift;

    return $mapping->multiply($compare->inverse(),@_); # test
}

sub oldcompare { # TO BE DEPRECATED after replacement by mapping operations 
# compare this Mapping instance with input Mapping at the segment level
#    my $mapping = shift;
#    my $compare = shift;
    return MappingFactory::compare(@_);
}

#-------------------------------------------------------------------
# normalisation : order the segments according to x or y position
#-------------------------------------------------------------------

sub orderSegmentsInXdomain {
    return &orderSegments(shift,domain=>'x');
}

sub orderSegmentsInYdomain {
    return &orderSegments(shift,domain=>'y');
}

sub orderSegments {
# order the segments in the x or y domain
    my $this = shift;
    my %options = @_; # domain => 

# if the current order domain of the mapping is unknown, dfefault order on y

    unless ($this->{orderdomain}) {
        my $segments = $this->getSegments();
        @$segments = sort {$a->getYstart() <=> $b-getYfinis()} @$segments;
        $this->{orderdomain} = 'y';
    }

# a co-aligned mapping is ordered the same in both domains

    return 1 unless $this->isCounterAligned();

# depending on the specified domain, reverse the order 

    my $desiredorderdomain = lc($options{domain}) || 'y';
    return 0 unless ($desiredorderdomain =~ /^(x|y)$/); # invalid specification

    my $currentorderdomain = $this->{orderdomain}; # the current state

    return 1 if ($currentorderdomain eq $desiredorderdomain);

    my $segments = $this->getSegments();
    @$segments = reverse (@$segments);

# set domain;

    $this->{orderdomain} = $desiredorderdomain;

    return -1; # success, but signal a reversal
}

#------------------
# to be replaced

sub isRegularMapping {
# returns 0 for anomalous or inconsistent mapping; else the alignment direction +1 or -1
    my $this = shift;
    my %options = @_; # list=>1 or full produces report only IF NOT a regular mapping

    $this->normaliseOnX(silent=>1) if $options{complement};

    $this->normalise(silent=>1) unless $this->{normalisation};

    my $sdomain = $this->{normalisation}; # sort domain 1 for X domain, 2 for Y 

    my ($alignment,$report) = &diagnose($this->getSegments(),$this->{token},2-$sdomain);

    return $alignment unless $report; # returns +1 or -1 it's  a regular mapping

    return 0 unless $options{list};  # returns false, it's not a regular mapping

# reporting option active 

    $report .= " ".($this->getMappingName || $this->getSequenceID)."\n"; # minimal

    my $list = $options{list};                        
    if ($list eq 'long' || $list eq 'full') { # add mapping info
        $report .= $this->assembledFromToString() if ($report =~ /inc/i); # inconsistent
        $report .= $this->writeToString('segment',extended=>1) if ($report =~ /ano|inv/i);
    }

    return $report; # returns true, but not numerical
}

sub diagnose {
# private, test segments for consistent alignment
    my $segments = shift;
    my $mapping = shift;
    my $cdomain = shift; # compare domain : 0 for X, 1 for Y

# determine the alignment direction from the range covered by all segments
# if it is a reverse alignment we have to reset the alignment direction in
# single base segments by applying the counterAlign... method

    my $n = scalar(@$segments) - 1;
    my $segmenti = $segments->[0];
    my $segmentf = $segments->[$n];
 
    my $globalalignment = 1; # overall alignment
    
    $cdomain = 1 if $cdomain; # ensure either 0 or 1
    if ($segmenti->getStart($cdomain) > $segmentf->getFinis($cdomain)) {
        $globalalignment = -1;
    }

# test consistency of alignments

    my $report;
    my $localalignment = 0; # inside  segments
    my $lastsegment;
    my @revisit; # if initial segment(s) are unit length
    foreach my $segment (@$segments) {
        next unless $segment;
# counter align unit-length alignments if (local) mapping is counter-aligned
        if ($segment->getYstart() == $segment->getYfinis()) {
            next if ($localalignment > 0); # no need to change anything
            $segment->counterAlignUnitLengthInterval($mapping) if $localalignment; # i.e. la < 0
            next if $localalignment;
# here localalignment is not yet determined, i.e. it's the first segment
            push @revisit,$segment;
	    next;
	}
# register alignment of first segment longer than one base
        $localalignment = $segment->getAlignment() unless $localalignment;
# test the alignment of each subsequent segment; exit on inconsistency
	if ($segment->getAlignment() != $localalignment) {
# this inconsistency is an indication of e.g. an alignment reversal among segments
            next if $report; # skip after first encounter
            $report = "Inconsistent alignment (l:$localalignment g:$globalalignment)";
            $globalalignment = 0;
        }
# test alignment between segments
	$lastsegment = $segment unless $lastsegment;
        next if ($lastsegment eq $segment);

        my $gapfinis = $segment->getStart($cdomain);
        my $gapstart = $lastsegment->getFinis($cdomain);
        my $interalignment = ($gapfinis > $gapstart) ? 1 : -1;
        if ($interalignment != $localalignment) {
#my @last = $lastsegment->getSegment(); my @next = $segment->getSegment(); print STDERR "alignment inversion l:@last  n:@next\n";
            $report = "Segment inconsistency detected" unless $report;
	}

        $lastsegment = $segment;
    }

    foreach my $segment (@revisit) {
        last unless ($localalignment < 0);
        $segment->counterAlignUnitLengthInterval($mapping);
    }

# if alignment == 0, all segments are unit length: adopt globalalignment
# if local and global alignment are different, the mapping is anomalous with
# consistent alignment direction, but inconsistent ordering in X and Y; then
# use the local alignment direction. (re: contig-to-contig mapping) 

    $localalignment = $globalalignment unless $localalignment;

    if ($localalignment == 0 || $localalignment != $globalalignment) {
        $report .= "\n" if $report;
        $report .= "Anomalous alignment (l:$localalignment g:$globalalignment)";
        $globalalignment = $localalignment;
    }

    return $globalalignment,$report;
}

# see collate

#-------------------------------------------------------------------
# apply linear transformation to mapping; access only via Contig
#-------------------------------------------------------------------

sub applyShiftToContigPosition { # shiftXPosition
# apply a linear contig (i.e. X) shift to each segment
    my $this = shift;
    my $shift = shift;

    return 0 unless ($shift && $this->hasSegments());

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(1,$shift,$this); # apply shift to X
    }

    undef $this->{orderdomain};

    undef $this->{objectrange}; # force re-initialisation of cache

    return 1;
}

sub applyMirrorTransform { # mirror (different from inverse)
# apply a contig mapping reversion and shift to each segment
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (= contig_length + 1)

    return 0 unless $this->hasSegments();

    $this->normalise(); # must do, before the next transform ??

# apply the mirror transformation (y = -x + m) to all segments

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(-1,$mirror,$this);
    }

# invert alignment status

    $this->setAlignment(-$this->getAlignment());

    undef $this->{objectrange}; # force re-initialisation of cache

    undef $this->{orderdomain};

    return 1;
}

sub extendToFill {
# extend first and last segment to fill a given range in Y-domain
    my $this = shift;
    my $scfstart = shift;
    my $scffinal = shift;

    my $mid = $this->{token};

    $this->normalise();

    my $segments = $this->getSegments();

    return unless $segments->[0];

    my $segment = $segments->[0];
    if ($scfstart < $segment->getYfinis()) {
        $segment->modify('L',$scfstart,$mid);
    }
    $segment = $segments->[$#$segments];
    if ($scffinal > $segment->getYstart()) { 
        $segment->modify('R',$scffinal,$mid);
    }

    undef $this->{objectrange}; # force re-initialisation of cache

    return $this;
}
 
#-------------------------------------------------------------------
# importing alignment segments
#-------------------------------------------------------------------

sub addAlignmentFromDatabase {
    my $this = shift;
    my ($cs, $rs, $length, @dummy) = @_;

    my $canonical = @dummy ? 1 : 0;

    my $segments = $this->getSegments($canonical); # canonical segments

    my $segment = new NewSegment($cs, $rs, $length, $this);

    return 0 unless $segment;

    push @$segments, $segment;

    undef $this->{orderdomain};

    return $this->hasSegments($canonical);
}

sub addAssembledFrom {
# alias of putSegment: input (contigstart, contigfinis, (read)seqstart, seqfinis)
    return &putSegment(@_);
}    

sub putSegment {
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

#    my $segments = $this->getSegments($canonical);
    my $segments = $this->getSegments();

    my $segment = new NewSegment($xs, $ys, $xl+1, $this);

    return 0 unless $segment;

    push @$segments, $segment;

    undef $this->{orderdomain};

#    return $this->hasSegments($canonical);
    return $this->hasSegments();
}    

#-------------------------------------------------------------------
# export of alignment segments
#-------------------------------------------------------------------

sub hasSegments {
# returns true if at least one alignment segment exists, else 0
    my $this = shift;
    my $canonical = shift; # true accesses canonical mapping segments
    return scalar(@{$this->getSegments($canonical)}); # else regular
}

sub getSegments {
# export the array of alignment segments
    my $this = shift;
    my $canonical = shift; # true returns canonical mapping segments

    my $segmentlist = $canonical ? 'CanonicalSegments' : 'RegularSegments';

    $this->{$segmentlist} = [] if !$this->{$segmentlist}; # ensure an array ref
    my $segments = $this->{$segmentlist};
# return a ref to the segment list if it has at least one element
    return $segments if @$segments;

# else pack or unpack the mapping (if the complementary segments exist)

    MappingFactory->pack($this) if $canonical;
    MappingFactory->unpack($this) unless $canonical;
    return $segments;
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
    return MappingFactory->copy($this);
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

    $rank += $vary if $vary; # optional offset

    $rank = 0 if ($rank < 0 || $rank >= $this->hasSegments());

    return $rank;
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

    my $segments = $this->getSegments();

    my $xrange = findXrange($segments);
    my $yrange = findYrange($segments);

    my $maximum = 1;
    foreach my $position (@$xrange,@$yrange) {
        $maximum = abs($position) if (abs($position) > $maximum);
    }
    my $nd = int(log($maximum)/log(10)) + 2;

    my $string = '';
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
           ($cstart, $cfinis) =  $this->getContigRange(1);
	    $range = 'object';
        }
	else {
           ($cstart, $cfinis) =  $this->getMappedRange(1);
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

    my $segments = $this->getSegments();

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
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
# private
#-------------------------------------------------------------------

sub findXrange {
# private find X (contig) begin and end positions from input mapping segments
    my $segments = shift; # array-ref

    return undef unless (ref($segments) eq 'ARRAY');

    my ($xstart,$xfinal);

# should use only first and last element
# my $ns = scalar(@$segment);
# foreach my $segment ($segments->[0],$segment->[$ns])
    foreach my $segment (@$segments) {
# ensure the correct alignment xstart <= xfinish
        my ($xs,$xf) = ($segment->getXstart(),$segment->getXfinis());
       ($xs,$xf) = ($xf,$xs) if ($xf < $xs);
        $xstart = $xs if (!defined($xstart) || $xs < $xstart);
        $xfinal = $xf if (!defined($xfinal) || $xf > $xfinal);
    }

    return defined($xstart) ? [($xstart, $xfinal)] : undef;
}

sub findYrange {
# private find Y (read) begin and end positions from input mapping segments
    my $segments = shift; # array-ref

# if no segments specified default to all

    return undef unless (ref($segments) eq 'ARRAY');

    my ($ystart,$yfinal);

    foreach my $segment (@$segments) {
# ensure the correct alignment ystart <= yfinish
        my ($ys,$yf) = ($segment->getYstart(),$segment->getYfinis());
       ($ys,$yf) = ($yf,$ys) if ($yf < $ys);
        $ystart = $ys if (!defined($ystart) || $ys < $ystart);
        $yfinal = $yf if (!defined($yfinal) || $yf > $yfinal);
    }

    return defined($ystart) ? [($ystart, $yfinal)] : undef;
}

#-------------------------------------------------------------------

1;
