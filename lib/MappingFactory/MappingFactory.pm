package MappingFactory;

use strict;

use NewSegment;

use NewMapping;

use Logging;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {

    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#--------------------------------------------------------------
# transforming to and from a normalised (canonical) mapping
#--------------------------------------------------------------

sub doPack {
    my $class = shift;
# transform to canonical mapping and its offset parameters
    my $mapping = shift;

    return if $mapping->isCanonical();

    my $segments = $mapping->orderSegmentsInYdomain();
    return unless ($segments && @$segments);

# detrmine the offset for the transformation

    my @xrange = $mapping->getObjectRange();
    my $alignment = $mapping->getAlignment();

    $mapping->setCanonicalOffsetX($xrange[0] - 1) unless ($alignment < 0);
    $mapping->setCanonicalOffsetX($xrange[1] + 1) if ($alignment < 0);
    $mapping->setCanonicalOffsetY($segments->[0]->getYstart() - 1);

    my $offsetforx = $mapping->getCanonicalOffsetX();
    my $offsetfory = $mapping->getCanonicalOffsetY();

# remove existing segments and add transformed ones

    $mapping->{mySegments} = [];
    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
        foreach my $k (0,1) {
            $segment[$k]    = abs($segment[$k] - $offsetforx);
            $segment[$k+2] -= $offsetfory;
        } 
	$mapping->addSegment(@segment);
    }
    return $mapping->hasSegments();
}

sub unPack {
    my $class = shift;
# expand a canonical mapping into the real thing
    my $mapping = shift;

    return unless $mapping->isCanonical();

    my $offsetforx = $mapping->getCanonicalOffsetX();
    my $offsetfory = $mapping->getCanonicalOffsetY();
    my $alignment  = $mapping->getAlignment(1);

    my $segments = $mapping->getSegments();

    $mapping->{mySegments} = [];

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
        foreach my $k (0,1) {
            $segment[$k]   += $offsetforx            unless ($alignment < 0);
            $segment[$k]    = $offsetforx - $segment[$k] if ($alignment < 0);
            $segment[$k+2] += $offsetfory;
        } 
	$mapping->addSegment(@segment);
    }
    return $mapping->hasSegments();
}

# needs rewrite *****************
sub getCheckSum {
    my $class = shift;
    my $mapping = shift;

    return $mapping->{segmentchecksum} if defined $mapping->{segmentchecksum};

    if ($mapping->isCanonical()) {
# construct an MD5 checksum on the segment information
        my $segments = $mapping->orderSegmentsInYdomain();
        my @checkingarray;
        foreach my $segment (@$segments) {
            push @checkingarray,$segment->getSegment();
# maybe different data?
	}
        $mapping->setCheckSum(md5(@checkingarray));
    }
    else {
# build the checksum using a work Mapping as intermediary
        my $workmap = $mapping->copy();
        $workmap->doPack();
        $mapping->setCheckSum($workmap->getCheckSum() || 0); # to have it defined
        $mapping->setCanonicalOffsetX($workmap->getCanonicalOffsetX());
        $mapping->setCanonicalOffsetY($workmap->getCanonicalOffsetY());
    }

    return $mapping->getCheckSum();
} 

#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub newisEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
    my $mapping = shift;
    my $compare = shift;
    my %options = @_; # domain=>'Y' (default) , or 'X'

    if (ref($compare) ne 'Mapping') {
        die "Mapping->isEqual expects an instance of the Mapping class";
    }

    my $domain = uc($options{domain}) || 0;

    my $checksumm = $mapping->getCheckSum() || 0;
    my $checksumc = $compare->getChecksum() || 0;

    if ($checksumm && $checksumc) {
# different checksums mean different mappings
        return 0 unless ($checksumm eq $checksumc);
# if domain is specified, test equality in that domain where the comparison is made
        if (!$domain || $domain eq 'X') {
            return 0 if ($mapping->getCanonicalOffsetX() != $compare->getCanonicalOffsetX()); 
	}
        if (!$domain || $domain eq 'Y') {
            return 0 if ($mapping->getCanonicalOffsetY() != $compare->getCanonicalOffsetY()); 
	}
# if no domain specified, return the shift in the X-domain ?

        return 1; 
    }
}

sub isEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
    my $class = shift;
    my $mapping = shift;
    my $compare = shift;
    my %options = @_; # domain=>'Y' (default) , or 'X'

    $options{domain} = uc($options{domain}) if $options{domain};

    if (ref($compare) ne 'Mapping') {
        die "Mapping->isEqual expects an instance of the Mapping class";
    }

    my $tmaps = $mapping->normalise(%options); # also sorts segments 
    my $cmaps = $compare->normalise(%options); # also sorts segments

# return ($mapping->inverse())->isEqual($compare->inverse()) if ($options{domain} eq 'X'); # TO BE TESTED

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

        my ($identical,$aligned,$offset) = $tsegment->compare($csegment,%options);
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

sub compare { # TO BE DEPRECATED after replacement by mapping operations 
# USED in ContigHelper (2548)  TagFactory (1000)
# compare this Mapping instance with input Mapping at the segment level
    my $class = shift;
    my $mapping = shift;
    my $compare = shift;
    my %options = @_; # domain=>'Y' (default) or 'X' silent=> 0 or 1

    $options{domain} = uc($options{domain}) if $options{domain};

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

# return ($mapping->inverse())->compare($compare->inverse()) if ($options{domain} eq 'X');

my $list = $options{list};
print STDOUT "Enter Mapping compare $mapping  $compare @_\n" if $list;
 
    my $tmaps = $mapping->normalise(%options); # also sorts segments

    my $cmaps = $compare->normalise(%options); # also sorts segments

#    return $mapping->multiply($compare->inverse()); # to be tested at some point
#    return $compare->multiply($mapping->inverse()); # to be tested at some point

# test presence of mappings

    return (0,0,0) unless ($tmaps && $cmaps && scalar(@$tmaps)&& scalar(@$cmaps));

# go through the segments of both mappings and collate consecutive overlapping
# contig segments (on $cmapping) of the same offset into a list of output segments


    my @osegments; # list of output segments

print STDOUT "entering segment comparison loop\n" if $list;

    my ($align,$shift);

    my ($ic,$it) = (0,0); 
    while ($it < @$tmaps && $ic < @$cmaps) {

        my $tsegment = $tmaps->[$it];
        my $csegment = $cmaps->[$ic];
# get the interval on both $mapping and the $compare segment 
        my ($ts,$tf,$cs,$cf);
        if ($options{domain} && $options{domain} eq 'X') {
            $ts = $tsegment->getXstart(); # contig positions
            $tf = $tsegment->getXfinis();
            $cs = $csegment->getXstart();
            $cf = $csegment->getXfinis();
        }
	else {
            $ts = $tsegment->getYstart(); # read positions
            $tf = $tsegment->getYfinis();
            $cs = $csegment->getYstart();
            $cf = $csegment->getYfinis();
	}

print STDOUT "testing it=$it  ic=$ic    $ts,$tf,$cs,$cf \n" if $list;

# determine if the intervals overlap by finding the overlapping region

        my $os = ($cs > $ts) ? $cs : $ts;
        my $of = ($cf < $tf) ? $cf : $tf;

print STDOUT "of $of  os $os\n" if $list;

        if ($of >= $os) {
# test at the segment level to obtain offset and alignment direction
            my ($identical,$aligned,$offset) = $tsegment->compare($csegment,%options);

# on first interval tested register alignment direction

	    $align = $aligned unless defined($align);
# break on alignment inconsistency
unless ($align == $aligned) { 
   print STDOUT "aligned $aligned  align $align  o:$offset\n" if $list;
   print STDOUT $mapping->writeToString('mapping',extended=>1) if $list;
   print STDOUT $compare->writeToString('compare',extended=>1) if $list;
}
            return 0,undef unless ($align == $aligned); # and segment > 1!

# initialise or update the contig alignment segment information on $csegment
# we have to ensure that the contig range increases in the output segments

            if ($options{domain} && $options{domain} eq 'X') {
                $os = $csegment->getYforX($os); # complementary domain (Y) position
                $of = $csegment->getYforX($of);
print STDOUT "X  os $os  of $of\n" if $list;
		$offset = -$offset; # to correct for interchanged domain (TO BE VERIFIED)
	    }
	    else {
                $os = $csegment->getXforY($os); # complementary domain (X) position
                $of = $csegment->getXforY($of);
print STDOUT "Y  os $os  of $of\n" if $list;
	    }
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
# no overlap, this segment to the right of sub copy compare
            $ic++;
        }
	else {
            print STDERR "possible normalisation error detected for "
                       . "mapping ".$mapping->getMappingName()."\n";
            return undef;
	}
    }

print STDOUT "after segment test loop\n" if $list;

# convert the segments into a Mapping object

    my $newmapping = new Mapping('CC:'.$mapping->getMappingName);
    $newmapping->setAlignment($align) if defined($align);

    foreach my $osegment (@osegments) {
        my ($offset,@cpos) = @$osegment;
        for my $i (0,1) {
            $cpos[$i+2] = $cpos[$i] + $offset;
            $cpos[$i+2] = -$cpos[$i+2] if ($align < 0);
        }
	$newmapping->putSegment(@cpos);
    }

    $newmapping->normalise(silent=>$options{silent});

    return $newmapping unless $options{useold};

    return $align,[@osegments]; # old system, to be deprecated
}

#-------------------------------------------------------------------

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

#-------------------------------------------------------------------

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
 
# only on non-canonical mapping?
sub newextendToFill {
# extend first and last segment to fill a given range in Y-domain
    my $this = shift;
    my $scfstart = shift;
    my $scffinal = shift;

    my $segments = $this->orderSegmentsInYdomain();

    my $worksegment = pop @$segments; # the last one 
    return unless $worksegment;

    if ($scffinal > $worksegment->getYstart()) { 
        my @segment = $worksegment->getSegment();
        $segment[3] = $scffinal;
        $segment[1] = $worksegment->getXforY($scffinal,1); # allow outside the original segment
        $this->putSegment(@segment);
    }
 
    $worksegment = unshift @$segments; # the first one
    if ($scfstart < $worksegment->getYfinis()) {
        my @segment = $worksegment->getSegment();
        $segment[2] = $scfstart;
        $segment[0] = $worksegment->getXforY($scfstart,1); # allow outside the original segment
        $this->putSegment(@segment);
    }

    return $this;
}

#-------------------------------------------------------------------
# creating a new mapping, inverting and multiplying
#-------------------------------------------------------------------

sub copy {
    my $class = shift;
# return a copy of this mapping or a segment as a new mapping
    my $mapping = shift;
    my %options = @_;

    my $copyname = $mapping->getMappingName();
    $copyname .= $options{extend} if $options{extend};

    my $copy = $mapping->new($copyname);

    $copy->setSequenceID($mapping->getSequenceID('y'),'y'); # if any
    $copy->setSequenceID($mapping->getSequenceID('x'),'x'); # if any

    my $segments = $mapping->getSegments();

    my $select = $options{segment}; # select a specific segment

    foreach my $segment (@$segments) {
        next if ($select && $segment ne $select);
        my @copysegment = $segment->getSegment();
        $copy->putSegment(@copysegment);
    }

    return undef unless $copy->normalise(); # on y

    return $copy;
}

sub inverse {
    my $class = shift;
# return inverse mapping as new mapping
    my $mapping = shift;

    my $segments = $mapping->getSegments();

    return undef unless ($segments && @$segments);

    my $name = $mapping->getMappingName() || $mapping;
    $name = "inverse of $name";
    $name =~ s/inverse of inverse of //; # two consecutive inversions
# perhaps this should be replaced by Sequence_ysequence domain ??
#   $name = sprintf("sequence_%08d",($mapping->getSequenceID('y')); # if defined

    my $inverse = new Mapping($name);

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
        $inverse->putSegment($segment[2],$segment[3],
                             $segment[0],$segment[1]);
    }

    $inverse->setSequenceID($mapping->getSequenceID('x'),'y');
    $inverse->setSequenceID($mapping->getSequenceID('y'),'x');

    return $inverse;   
}

sub split {
    my $class = shift;
# split the mapping in a list of new mappings with 1 segment each
    my $mapping = shift;
    my %options = @_; # full=>  , default minimal split

    my $segments = $mapping->getSegments();

# sort according to alignment or position? Should be an option

    @$segments = sort {$a->getOffset() <=> $b->getOffset()} @$segments;

    my @mappings;
    foreach my $segment (@$segments) {
        my $mapping = $mapping->copy(segment=>$segment,extend=>"-".scalar(@mappings));
        push @mappings,$mapping if $mapping;
    }

    return [@mappings] if $options{full}; # returns a list of one-segment mappings 

    my $m = 0;

    while ($mappings[$m+1]) {
	my $join = $mappings[$m]->join($mappings[$m+1]);
        unless ($join) {
            $m++;
            next;
	}
        $mappings[$m] = $join;
        splice @mappings,$m+1,1;
    }

    return [@mappings];
}

sub join {
    my $class = shift;
# join two mappings into an individually regular mapping if possible
    my $thismap = shift;
    my $thatmap = shift;

# test alignment? What about name?

    my $joinmap = $thismap->copy();

    my $segments = $thatmap->getSegments();

    foreach my $segment (@$segments) {
        $joinmap->putSegment($segment->getSegment());
    }

    return undef unless $joinmap->isRegularMapping(); # can't merge these mappings

    return $joinmap;
}

sub multiply {
    my $class = shift;
# return the product R x T of this (mapping) and another mapping
# returns a mapping without segments if product is empty
    my $thismap = shift; # mapping R
    my $mapping = shift; # mapping T
    my %options = @_; # e.g. repair=>1  tracksegments=> 0,1,2,3 backskip after

# align the mappings such that the Y (mapped) domain of R and the 
# X domain of T are both ordered according to segment position 

    my $rname = $thismap->getMappingName() || 'R';
    my $tname = $mapping->getMappingName() || 'T';

    my $rsegments = $thismap->orderSegmentsInYdomain();
    my $tsegments = $mapping->orderSegmentsInXdomain();

    my $product = new Mapping("$rname x $tname");
    $product->setSequenceID($thismap->getSequenceID('x'),'x');
    $product->setSequenceID($mapping->getSequenceID('y'),'y');
    
    return $product unless ($rsegments && $tsegments); # product empty 

# find the starting point in segment arrays if activated

    my ($rs,$ts) = (0,0);

# tracking of segments option to start the search at a different position

    if (my $track = $options{tracksegments}) { # undef,0  or  1,2,3
        my $backskip = $options{backskip}; 
        $backskip = 1 unless defined($backskip); # default backskip one
        $rs = $thismap->getSegmentTracker(-$backskip) if ($track != 2);
        $ts = $mapping->getSegmentTracker(-$backskip) if ($track >= 2);
    }

    my ($ri,$ti); # register values on first encountered matching segments

    while ($rs < scalar(@$rsegments) && $ts < scalar(@$tsegments)) {

	my $rsegment = $rsegments->[$rs];
	my $tsegment = $tsegments->[$ts];

        my ($rxs,$rxf,$rys,$ryf) = $rsegment->getSegment();
       ($rxs,$rxf,$rys,$ryf) = ($rxf,$rxs,$ryf,$rys) if ($rys > $ryf); # counter-aligned case
        my ($txs,$txf,$tys,$tyf) = $tsegment->getSegment();

        if (my $mxs = $tsegment->getYforX($rys)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
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
                &dump($thismap,$mapping,$rs,$ts,1);
                return undef;
	    }
	}
# begin of x window of R does not map to y inside the T window
# check if the end falls inside the segment
        elsif (my $mxf = $tsegment->getYforX($ryf)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
# okay, the end falls inside the window, get the begin via back tranform 
            if (my $bxs = $rsegment->getXforY($txs)) {
                $product->putSegment($bxs,$rxf,$tys,$mxf);
                $rs++;
            }
            else {
                &dump($thismap,$mapping,$rs,$ts,2);
                return undef;
	    }
	}
# both end points fall outside the T mapping; test if T falls inside R
        elsif (my $bxs = $rsegment->getXforY($txs)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
# the t segment falls inside the r segment
            if (my $bxf = $rsegment->getXforY($txf)) {
                $product->putSegment($bxs,$bxf,$tys,$tyf);
                $ts++;
            }
            else {
                &dump($thismap,$mapping,$rs,$ts,3);
                return undef;
            }
        }
        else {
# no segment matching or overlap 
            $ts++ if ($ryf >= $txf);
            $rs++ if ($ryf <= $txf);
	}
    }

# register the current segment counter numbers (default start values)

    $thismap->setSegmentTracker($options{after} ? $rs : $ri);
    $mapping->setSegmentTracker($options{after} ? $ts : $ti);

# cleanup and analyse the segments

#    $product->orderSegments(); # on Y

    $product->collate($options{repair}); # orders implicitly

    return $product;
}

sub collate {
# private function with isRegular and multiply
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
        next if (abs($xdifference) > $repair);
# replace the two segments ($i-2 and $i-1) by a single one
        splice @$segments, $i-2, 2;
        unless ($this->putSegment($ls->getXstart(), $ts->getXfinis(),
			          $ls->getYstart(), $ts->getYfinis())) {
            print STDOUT "Occurred in collate\n";
            my @ls = $ls->getSegment(); my @ts = $ts->getSegment();
            print STDOUT "segment (l) @ls  \n";
            print STDOUT "segment (t) @ts  \n";
            print STDOUT $this->toString()."\n";
	}

        @$segments = sort {$a->getYstart <=> $b->getYstart} @$segments;
        $i = 1;
    }
}

sub dump {
# private helper method for diagnostic purpose
    my ($thismap,$mapping,$rs,$ts,$m) = @_;

    print STDOUT "Mapping->multiply: should not occur ($m) !!\n" if $m;
	
    my $rsegments = $thismap->getSegments();
    my $tsegments = $mapping->getSegments();

    my $rsegment = $rsegments->[$rs];
    my $tsegment = $tsegments->[$ts];

    my ($rxs,$rxf,$rys,$ryf) = $rsegment->getSegment();
    my ($txs,$txf,$tys,$tyf) = $tsegment->getSegment();

    print STDOUT $thismap->toString()."\n";
    print STDOUT $mapping->toString()."\n";
 
    print STDOUT "this segment [$rs]  ($rxs,$rxf,$rys,$ryf)\n";  
    print STDOUT " map segment [$ts]  ($txs,$txf,$tys,$tyf)\n"; 

    my $tempmxs = $tsegment->getYforX($rys) || 'undef';
    print STDOUT "rys $rys  maps to   mxs $tempmxs\n";
    my $tempmxf = $tsegment->getYforX($ryf) || 'undef';
    print STDOUT "ryf $ryf  maps to   mxf $tempmxf\n";
    my $tempbxs = $rsegment->getXforY($txs) || 'undef';
    print STDOUT "txs $txs  reverse maps to  bxs $tempbxs\n";
    my $tempbxf = $rsegment->getXforY($txf) || 'undef';
    print STDOUT "txf $txf  reverse maps to  bxf $tempbxf\n";

    exit; #?
}

#-------------------------------------------------------------------
# transformation of objects in x-domain to y-domain
#-------------------------------------------------------------------

sub transform {
    my $class = shift;
# transform an input x-range to an (array of) y-position intervals
    my $mapping = shift;
    my @position = sort {$a <=> $b} (shift,shift);

# represent the position range as a 1-1 mapping

    my $helper = new Mapping("scratch");
    $helper->putSegment(@position,@position);

# the segments of 'transform' represent the parts of the input range
# which map to the output range

    my $transform = $helper->multiply($mapping);
# no segments when input range outside mapping input window
    my $segments = $transform->normaliseOnY() || []; 

# extract the actual mapped part as a list of arrays of length 2
# is this actually used anywhere? 

    my @output;
    foreach my $segment (@$segments) {
        my @section = ($segment->getYstart(),$segment->getYfinis());
        push @output,[@section];
    }

# return the mapped interval(s) and the transform (which has alignment info)

    return [@output],$transform;
#   return $transform;
}

sub transformString {
    my $class = shift;
# map an input string to an output string, replacing gaps by gapsymbol
    my $mapping = shift;
    my $string = shift || return undef;
    my %options = @_; # gapsymbol=>

# get the part(s) in the mapped domain (starts at position 1)

#    my ($list,$transform) = $this->transform(1,length($string));
    my $transform = $mapping->transform(1,length($string));
    my $alignment = $transform->getAlignment() || return undef;

    $options{gapsymbol} = '-' unless defined $options{gapsymbol};
    my $gapsymbol = $options{gapsymbol};

    my $output;
    my ($sstart,$pfinal);
    my $segments = $transform->getSegments();

    foreach my $segment (@$segments) {

        my $slength = $segment->getSegmentLength();

        $sstart = $segment->getXstart()-1 if ($alignment > 0);
        $sstart = $segment->getXfinis()-1 if ($alignment < 0);

        my $substring = substr $string,$sstart,$slength;
        $substring = reverse($substring)    if ($alignment < 0);
        $substring =~ tr/acgtACGT/tgcaTGCA/ if ($alignment < 0);    

        if ($output) {
            my $gapsize = $segment->getYstart() -  $pfinal - 1;
            while ($gapsize-- > 0) {
                $output .= $gapsymbol;
	    }
	    $output .= $substring;
	}
	else {
	    $output = $substring;
	}
        $pfinal = $segment->getYfinis();
    }
    
    return $output;
}

sub transformArray {
    my $class = shift;
# map an input array to an output array, replacing gaps by gap values
    my $mapping = shift;
    my $array = shift || return undef; # array reference
    my %options = @_; # gapvalue=>

# get the part(s) in the mapped domain (starts at position 1)

    my $transform = $mapping->transform(1,scalar(@$array));
    my $alignment = $transform->getAlignment() || return undef;

    $options{gapvalue} = 1 unless defined $options{gapvalue};
    my $gapvalue = $options{gapvalue};

    my @output;
    my ($sstart,$pfinal);
    my $segments = $transform->getSegments();

    foreach my $segment (@$segments) {

        my $slength = $segment->getSegmentLength();

        $sstart = $segment->getXstart()-1 if ($alignment > 0);
        $sstart = $segment->getXfinis()-1 if ($alignment < 0);

        my @subarray;
        foreach (my $i = $sstart ; $i < $sstart + $slength ; $i++) {
            push @subarray,$array->[$i];
        }       

        @subarray = reverse(@subarray) if ($alignment < 0);

        if (@output) {
            my $gapsize = $segment->getYstart() -  $pfinal - 1;
            while ($gapsize-- > 0) {
                push @output, $gapvalue;
	    }
	}
        $pfinal = $segment->getYfinis();
        push @output,@subarray;
    }
    
    return [@output];
}

#-------------------------------------------------------------------

1;
