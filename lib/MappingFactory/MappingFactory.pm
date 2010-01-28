package MappingFactory;

use strict;

use RegularMapping;

use CanonicalMapping;

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
# building a mapping from alignment segments
#--------------------------------------------------------------

my $STATUS; # class variable

sub build {
# takes a list of alignment segments defined for a mapping, test consistency
# build canonical mapping and return mapping parameters
    my $class = shift;
    my $segment_arrayref = shift;
    my %options = @_; # bridgegap=> , noverify=> , empty=>

    undef $STATUS;

# only allow empty mapping to be built if explicitly specified: read-contig 
# and tag-contig mappings cannot be empty; contig-contig mappings can
 
   unless ($segment_arrayref && @$segment_arrayref) {
	$STATUS = "Empty build list";
	return undef unless $options{empty}; # allow empty mapping
        my $emptymapping = new CanonicalMapping();
        my $checksum = $emptymapping->getCheckSum();
# setting the checksum adds the canonical mapping, IF NEW, to the cache
        my $cachedmapping = $emptymapping->lookup($checksum);
        return $cachedmapping,0,0,1;
    }

# check the alignments for consistency of alignment direction

    my $alignment = &verifyAlignmentSegments($segment_arrayref); # also sorts
# test alignment, must be +1 or -1
    unless ($alignment) {
	$STATUS .= "Invalid or inconsistent alignments in build list";
	return undef;
        
    }

# join subsequent alignment segments using the "bridge" filter
# successive segments are collated if the gap between them is the
# same on both sides, and smaller or equal the specified bridgegap

    my $joins = &collate($segment_arrayref,$options{bridgegap});
 
#--------------------------------------------------------------
# determine offset parameters
#--------------------------------------------------------------
        
    my $fs = $segment_arrayref->[0]; # first segment
    my $ls = $segment_arrayref->[$#$segment_arrayref]; # last segment

    my ($offsetforx,$offsetfory);
    if ($alignment > 0 ) {
        $offsetforx = $fs->[0] - 1;
        $offsetfory = $fs->[2] - 1;
    }
    else {
        $offsetforx = $ls->[1] + 1;
        $offsetfory = $ls->[3] - 1;
    }

#--------------------------------------------------------------
# transforming segments and build a canonical mapping
#--------------------------------------------------------------

    my $canonicalmapping = new CanonicalMapping();

    foreach my $segment (@$segment_arrayref) {
# transform each segment to its canonical form
        my ($xstart,$ystart,$length);
        $xstart = $segment->[0] - $offsetforx;
        $length = abs($segment->[1] - $segment->[0]) + 1;
        if ($alignment > 0) {
            $ystart = $segment->[2] - $offsetfory;
	}
	else {
            $xstart = $offsetforx - $segment->[1];
            $ystart = $segment->[3] - $offsetfory;
	}
	$canonicalmapping->addCanonicalSegment($xstart,$ystart,$length);
    }

    unless ($canonicalmapping->verify()) {
        $STATUS = "Alignment segments produce invalid canonical mapping\n";
        $STATUS .= &listsegments($segment_arrayref,"offsetx $offsetforx  offsety $offsetfory");
        return undef;
    }

    my $checksum = $canonicalmapping->getCheckSum();
# setting the checksum adds the canonical mapping, IF NEW, to the cache
    my $cachedmapping = $canonicalmapping->lookup($checksum);
    if ($cachedmapping && $cachedmapping ne $canonicalmapping) { 
# check span against existing value (optional)
        unless ($options{noverify}) {
#        if ($options{verify}) {
            my $xparity = $cachedmapping->getSpanX() - $canonicalmapping->getSpanX();
            my $yparity = $cachedmapping->getSpanY() - $canonicalmapping->getSpanY();
            if ($xparity || $yparity) { # testing option
                $STATUS  = "Parity error on new and cached canonical mapping\n";
                $STATUS .= "x:$xparity y:$yparity for mapping_id ";
                $STATUS .= ($cachedmapping->getMappingID() || 'undef')."\n";
                $STATUS .= &listsegments($canonicalmapping->getSegments(),'new mapping');
                $STATUS .= &listsegments($cachedmapping->getSegments(),'cached mapping');
                return undef;
	    }
        }
	$canonicalmapping = $cachedmapping;
    }

#--------------------------------------------------------------
# complete the input mapping mapping; remove the segment cache
#--------------------------------------------------------------

    return $canonicalmapping,$offsetforx,$offsetfory,$alignment;
}

sub verifyAlignmentSegments {
# private helper method; analyse segments, if consistent return overall alignment
    my $segment_arrayref = shift;
    
    return undef unless (ref($segment_arrayref) eq 'ARRAY');

# check alignment of each segment; order according to increasing x position

    foreach my $segment (@$segment_arrayref) {
# check alignment of segment; align on x-domain
        my ($xs, $xf, $ys, $yf) = @$segment;
        unless (abs($xf-$xs) == abs($yf - $ys)) {
	    print STDOUT "Invalid alignment segment @$segment\n";
            return undef;
	}
        next unless ($xs > $xf);
        @$segment = ($xf,$xs,$yf,$ys);
    }
    
    @$segment_arrayref = sort {$a->[0] <=> $b->[0]} @$segment_arrayref;

# check the alignments for consistency of alignment direction

    my $alignment = 0;
    foreach my $segment (@$segment_arrayref) {
        my $segmentsize = $segment->[3] - $segment->[2];
        next unless $segmentsize; # i.e. skip single base alignments
        my $localalignment = ($segmentsize > 0 ? 1 : -1);
        $alignment = $localalignment unless $alignment;
        next if ($alignment == $localalignment);
# there is an alignment inconsistency: fail the build, exit with undef
        $STATUS = "Alignment inconsistency in segment @$segment ($alignment)\n";
        $STATUS .= &listsegments($segment_arrayref);
        return undef;
    }

    unless ($alignment) {
        my $fs = $segment_arrayref->[0];
	my $ls = $segment_arrayref->[$#$segment_arrayref];
        if ($fs eq $ls || $fs->[2] == $ls->[3]) {
	    $STATUS = "Alignment consists of single-base segment";
	    return undef;
	}
        $alignment = ($fs->[2] > $ls->[3]) ? 1 : -1;
    }

# analyse the alignments, for non overlap and co-linearity

    my $i = 0;
    my $length = scalar(@$segment_arrayref);
    my $isconsistent = 1;
    while ($i < $length-1) {
        my $si = $segment_arrayref->[$i];
        my $sj = $segment_arrayref->[$i+1];
        if ($si->[1] >= $sj->[0]) {
            $STATUS .= "segments (i=$i) overlap in X-domain: @$si , @$sj\n";
	    $isconsistent = 0; # overlapping segments in x domain
	}
        if ($alignment > 0 && $si->[3] >= $sj->[2]) {
            $STATUS .= "segments (i=$i) overlap in y-domain: @$si , @$sj\n";
	    $isconsistent = 0; # overlapping segments in y domain
	}
        if ($alignment < 0 && $sj->[2] >= $si->[3]) {
            $STATUS .= "segments (i=$i) overlap in y-domain: @$si , @$sj\n";
	    $isconsistent = 0; # overlapping segments in y domain
	}
	$i++;
    }

    $STATUS .= &listsegments($segment_arrayref) unless $isconsistent;

    return $isconsistent ? $alignment : 0;
}

sub collate {
    my $segment_arrayref = shift;
    my $bridgegap = shift || 0; # default join budding segments

    my ($i,$join) = (1,0);
    while ($i < scalar(@$segment_arrayref)) {
        my $lsegment = $segment_arrayref->[$i-1];
        my $tsegment = $segment_arrayref->[$i++];

        my $xdifference = $tsegment->[0] - $lsegment->[1];
        my $ydifference = $tsegment->[2] - $lsegment->[3];
        next unless (abs($xdifference) == abs($ydifference));
# the gaps between segments on both sides are equal; it's size is 1 less
        next if (abs($xdifference)-1 > $bridgegap);
# replace the two segments ($i-2 and $i-1) by a single one
        my @newsegment = ($lsegment->[0],$tsegment->[1],
                          $lsegment->[2],$tsegment->[3]);
        splice @$segment_arrayref, $i-2, 2,[@newsegment];
        $join++;
        next if ($i == 1);
        $i--;
    }
    return $join;
}

sub listsegments {
# private helper routine
    my $segment_arrayref = shift;
    my $text = shift || 'input segment list';

    my $outputstring  = "$text\n";
    foreach my $segment (@$segment_arrayref) {
        $outputstring .= "@$segment\n";
    }
    return $outputstring;
}

sub getStatus { return $STATUS || '' };

#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub isEqual {
# compare the two input Mappings for equality; the comparison is made 
# based on the checksum, which must be equal. In the X-domain we allow
# a linear shift (re: read-to-contig mappings, where X-domain is on the
# contig and Y-domain is on the read). If a test is to be made on the
# Y-domain instead, compare the inverses of the input mappings.
    my $mapping = shift;
    my $compare = shift;
    
#   verifyParameter($mapping,'isEqual','RegularMapping');
#   verifyParameter($compare,'isEqual','RegularMapping');

#print STDOUT "MappingFactory->isEqual: $mapping, $compare\n";
    my $checksumm = $mapping->getCheckSum() || 0;
    my $checksumc = $compare->getCheckSum() || 0;

    my $alignment = ($mapping->isCounterAligned() == $compare->isCounterAligned()) ? 1 : -1;


    if ($checksumm && $checksumc && $checksumm eq $checksumc) {
# test equality in the Y domain
        if ($mapping->getCanonicalOffsetY() == $compare->getCanonicalOffsetY()) {
# now determine the offset for the X-domain, considering the alignment direction
            my $mappingoffsetx = $mapping->getCanonicalOffsetX();
            my $compareoffsetx = $compare->getCanonicalOffsetX();
            $mappingoffsetx = -$mappingoffsetx if ($alignment < 0);
            return 1, $alignment,($mappingoffsetx - $compareoffsetx);  # sign TO BE tested
	}
    }

    return 0,0,0; # mappings differ 
}

#-------------------------------------------------------------------

sub extendToFill {
# extend first and last segment to fill a given range
    my $class = shift;
    my $regularmapping = shift;
    my %options = @_;  

    my $domain = $options{domain} || 'X'; # default
    my $start  = $options{start};
    my $final  = $options{final};

    my $nrofsegments = $regularmapping->hasSegments();

    my $alignmentsegment_arrayref = [];
    foreach my $i (1 .. $nrofsegments) {
        my ($xs,$xf,$ys,$yf) = $regularmapping->getSegment($i);

        if (uc($domain) eq 'X') {
           ($xs,$xf,$ys,$yf) = ($xf,$xs,$yf,$ys) if ($xs > $xf);
	    my $limit = $options{extendonly} ? $xs : $xf;
            if ($i == 1 && defined($start) && $start < $limit) {
                $xs = $start;
                $ys = $regularmapping->getYforX($i,$xs,1); # extend         
	    }
	    $limit = $options{extendonly} ? $xf : $xs;
            if ($i == $nrofsegments && defined($final) && $final > $limit) {
                $xf = $final;
                $yf = $regularmapping->getYforX($i,$xf,1);
            }        
	}
        else {
	    my $limit = $options{extendonly} ? $ys : $yf;
            if ($i == 1 && defined($start) && $start < $limit) {
                $ys = $start;
                $xs = $regularmapping->getXforY($i,$ys,1); # extend 
	    }
	    $limit = $options{extendonly} ? $yf : $ys;
            if ($i == $nrofsegments && defined($final) && $final > $limit) {
                $yf = $final;
                $xf = $regularmapping->getXforY($i,$yf,1);
            }        
	}

        push @$alignmentsegment_arrayref, [($xs,$xf,$ys,$yf)];
    }

    my $extendedmapping = new RegularMapping($alignmentsegment_arrayref);
    return undef unless $extendedmapping;
# copy the mapping descriptors
    my $mappingname = $regularmapping->getMappingName();
    $mappingname .= "-adjusted" if $options{namechange};
    $extendedmapping->setMappingName($mappingname);
    $extendedmapping->setSequenceID($regularmapping->getSequenceID('y'),'y'); # if any
    $extendedmapping->setSequenceID($regularmapping->getSequenceID('x'),'x'); # if any
    return $extendedmapping;
}

#-------------------------------------------------------------------
# creating a new mapping, inverting and multiplying
#-------------------------------------------------------------------

sub copy {
    my $class = shift;
# return a copy of this mapping or a segment as a new mapping
    my $regularmapping = shift;
    my %options = @_;

    my $copyname = $regularmapping->getMappingName();
    $copyname .= $options{extend} if $options{extend};

    my $copy = $regularmapping->new(undef,empty=>1);

    $copy->setMappingName($copyname);
    $copy->setSequenceID($regularmapping->getSequenceID('y'),'y'); # if any
    $copy->setSequenceID($regularmapping->getSequenceID('x'),'x'); # if any
    $copy->setAlignment($regularmapping->getAlignment());
    $copy->setCanonicalMapping($regularmapping->getCanonicalMapping());
    $copy->setCanonicalOffsetX($regularmapping->getCanonicalOffsetX());
    $copy->setCanonicalOffsetY($regularmapping->getCanonicalOffsetY());

    return $copy;
}

sub inverse {
    my $class = shift;
# return inverse mapping as new mapping
    my $regularmapping = shift;

    my $nrofsegments = $regularmapping->hasSegments() || return undef;

    my $name = $regularmapping->getMappingName() || $regularmapping;
    $name = "inverse of $name";
    $name =~ s/inverse of inverse of //; # two consecutive inversions

    my $inversesegmentlist = [];
    foreach my $i (1 .. $nrofsegments) {
        my @segment = $regularmapping->getSegment($i);
        push @$inversesegmentlist,[($segment[2],$segment[3],$segment[0],$segment[1])]; 
    }

    my $inverse = new RegularMapping($inversesegmentlist); # use constructor to build

    $inverse->setMappingName($name);
    $inverse->setSequenceID($regularmapping->getSequenceID('x'),'y');
    $inverse->setSequenceID($regularmapping->getSequenceID('y'),'x');

    return $inverse;   
}

sub split {
    my $class = shift;
# split the mapping in a list of new mappings with 1 segment each
    my $regularmapping = shift;

    my $nrofsegments = $regularmapping->hasSegments();

    my $segmentmapping_arrayref = []; # output

    my $segmentlist = []; 
    foreach my $i (1..$nrofsegments) {
        my @segment = $regularmapping->getSegment($i);
        $segmentlist->[0] = [@segment];
        my $segmentmapping = new RegularMapping($segmentlist);
        next unless $segmentmapping;
        push @$segmentmapping_arrayref,$segmentmapping;
    }

    return $segmentmapping_arrayref;
}

sub join {
    my $class = shift;
# join two mappings into an individually regular mapping if possible
    my $thismap = shift;
    my $thatmap = shift; # other mapping or array of mappings

# test alignment? What about name?

    my @tobejoined = ($thismap);
    push @tobejoined, $thatmap unless (ref($thatmap) eq 'ARRAY');
    push @tobejoined, @$thatmap    if (ref($thatmap) eq 'ARRAY');

    my $alignmentsegment_arrayref = [];
    foreach my $mapping (@tobejoined) {
	my $nrofsegments = $mapping->hasSegments();
        foreach my $i (1 .. $nrofsegments) {
	    my @segment = $mapping->getSegment($i);
            push @$alignmentsegment_arrayref,[@segment];
	}
    }

    my $joinedmapping = $thismap->new($alignmentsegment_arrayref);
    return undef unless $joinedmapping;

    $joinedmapping->setMappingName();
    return $joinedmapping;
}

sub multiply {
    my $class = shift;
# return the product R x T of this (mapping) and another mapping
# returns a mapping without segments if product is empty
    my $rmapping = shift; # mapping R
    my $tmapping = shift; # mapping T
    my %options = @_; # e.g. bridgegap=>1  tracksegments=> 0,1,2,3 backskip after

# align the mappings such that the Y (mapped) domain of R and the 
# X domain of T are both ordered according to segment position 

    my $nrofrsegments = $rmapping->hasSegments(); # ordered on Y and in Y domain
    my $nroftsegments = $tmapping->hasSegments(); # ordered on Y and in Y domain

# find the starting point in segment arrays if activated

    my ($rs,$ts) = (1,1); # count segments from 1

# tracking of segments option to start the search at a different position

    if (my $track = $options{tracksegments}) { # undef,0  or  1,2,3
        my $backskip = $options{backskip}; 
        $backskip = 1 unless defined($backskip); # default backskip one
        $rs = $rmapping->getCurrentSegment - $backskip if ($track != 2);
        $ts = $tmapping->getCurrentSegment - $backskip if ($track >= 2);
    }

    my ($ri,$ti); # register values on first encountered matching segments

    my $productsegment_arrayref = [];

    while ($rs <= $nrofrsegments && $ts <= $nroftsegments) {
# r-segments called ordered on y; t-segments assessed ordered on X
        my $nt = $tmapping->isCounterAligned() ? $nroftsegments - $ts + 1 : $ts;

        my ($rxs,$rxf,$rys,$ryf) = $rmapping->getSegment($rs); # always aligned on Y domain

        my ($txs,$txf,$tys,$tyf) = $tmapping->getSegment($nt);
       ($txs,$txf,$tys,$tyf) = ($txf,$txs,$tyf,$tys) if ($txs > $txf); # align on X domain
#print STDOUT "R:($rxs,$rxf,$rys,$ryf)   T:($txs,$txf,$tys,$tyf)  \n";

        if (my $mxs = $tmapping->getYforX($nt,$rys)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
# begin of x window of R maps to y inside the T window
            if (my $mxf = $tmapping->getYforX($nt,$ryf)) {
# also end of x window of R maps to y inside the T window
#print STDOUT "push 1 ($rxs,$rxf,$mxs,$mxf)\n";
                push @$productsegment_arrayref,[($rxs,$rxf,$mxs,$mxf)];
# replace by accumulator in Mapping factory
                $rs++;
	    }
# no, end of x window of R does not map to y inside the T window
# break this segment by finding the end via backtransform of $txf
	    elsif (my $bxf = $rmapping->getXforY($rs,$txf)) {
#print STDOUT "push 2 ($rxs,$bxf,$mxs,$tyf)\n";
                push @$productsegment_arrayref,[($rxs,$bxf,$mxs,$tyf)];
                $ts++;
	    }
	    else { # should not occur
                &dump($rmapping,$tmapping,$rs,$ts,1);
                return undef;
	    }
	}
# begin of x window of R does not map to y inside the T window
# check if the end falls inside the segment
        elsif (my $mxf = $tmapping->getYforX($nt,$ryf)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
# okay, the end falls inside the window, get the begin via back tranform 
            if (my $bxs = $rmapping->getXforY($rs,$txs)) {
#print STDOUT "push 3 ($bxs,$rxf,$tys,$mxf)\n";
                push @$productsegment_arrayref,[($bxs,$rxf,$tys,$mxf)];
                $rs++;
            }
            else { # should not occur
                &dump($rmapping,$tmapping,$rs,$ts,2);
                return undef;
	    }
	}
# both end points fall outside the T tmapping; test if T falls inside R
        elsif (my $bxs = $rmapping->getXforY($rs,$txs)) {
# register the values of $rs and $ts
            $ri = $rs unless defined($ri);
            $ti = $ts unless defined($ti);
# the t segment falls inside the r segment
            if (my $bxf = $rmapping->getXforY($rs,$txf)) {
#print STDOUT "push 4 ($bxs,$bxf,$tys,$tyf)\n";
                push @$productsegment_arrayref,[($bxs,$bxf,$tys,$tyf)];
                $ts++;
            }
            else { # should not occur
                &dump($rmapping,$tmapping,$rs,$ts,3);
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

    unless ($options{after}) { 
        $rmapping->setCurrentSegment($ri);
        $tmapping->setCurrentSegment($ti);
    }

# build the product mapping from the collected product segments

    my %coptions = (bridgegap => $options{bridgegap});

    my $product = new RegularMapping($productsegment_arrayref,%coptions);
    return 0 unless $product;

    my $rname = $rmapping->getMappingName() || 'R';
    my $tname = $tmapping->getMappingName() || 'T';
    $product->setMappingName("$rname x $tname");

    $product->setSequenceID($rmapping->getSequenceID('x'),'x');
    $product->setSequenceID($tmapping->getSequenceID('y'),'y');

    return $product;
}

sub dump {
# private helper method for diagnostic purpose
    my ($rmapping,$tmapping,$rs,$ts,$m) = @_;

    print STDOUT "Mapping->multiply: should not occur ($m) !!\n" if $m;

    my ($rxs,$rxf,$rys,$ryf) = $rmapping->getSegment($rs);
    my ($txs,$txf,$tys,$tyf) = $tmapping->getSegment($ts);

    print STDOUT $rmapping->toString()."\n";
    print STDOUT $tmapping->toString()."\n";
 
    print STDOUT "R mapping segment [$rs]  ($rxs,$rxf,$rys,$ryf)\n";  
    print STDOUT "T mapping segment [$ts]  ($txs,$txf,$tys,$tyf)\n"; 

    my $tempmxs = $tmapping->getYforX($ts,$rys) || 'undef';
    print STDOUT "rys $rys  maps to   mxs $tempmxs\n";
    my $tempmxf = $tmapping->getYforX($ts,$ryf) || 'undef';
    print STDOUT "ryf $ryf  maps to   mxf $tempmxf\n";
    my $tempbxs = $rmapping->getXforY($rs,$txs) || 'undef';
    print STDOUT "txs $txs  reverse maps to  bxs $tempbxs\n";
    my $tempbxf = $rmapping->getXforY($rs,$txf) || 'undef';
    print STDOUT "txf $txf  reverse maps to  bxf $tempbxf\n";

    exit;
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

    my $nrofsegments = $transform->hasSegments();

    foreach my $ns (1 .. $nrofsegments) {

        my @segment = $mapping->getSegment();
        my $slength = $segment[3] - $segment[2] + 1;

        $sstart = ($alignment < 0) ? $segment[1] : $segment[0];

        $sstart--;

        my @subarray;
        foreach (my $i = $sstart ; $i < $sstart + $slength ; $i++) {
            push @subarray,$array->[$i];
        }       

        @subarray = reverse(@subarray) if ($alignment < 0);

        if (@output) {
            my $gapsize = $segment[2] -  $pfinal - 1;
            while ($gapsize-- > 0) {
                push @output, $gapvalue;
	    }
	}
        $pfinal = $segment[3];
        push @output,@subarray;
    }
    
    return [@output];
}

#-------------------------------------------------------------------

sub toString {
# primarily for diagnostic purposes
    my $class = shift;
    my $mapping = shift;
    my %options = @_; # text=>...  extended=>...  norange=>...

    my $mappingname = $mapping->getMappingName()        || 'undefined';
    my $direction   = $mapping->getAlignmentDirection() || 'UNDEFINED';
    my $targetsid   = $mapping->getSequenceID('y')      || 'undef';
    my $hostseqid   = $mapping->getSequenceID('x')      || 'undef';

    my $string = "Mapping: name=$mappingname, sense=$direction"
	       .         " target=$targetsid  host=$hostseqid";

    unless (defined($options{range}) && !$options{range}) {
	my ($cstart, $cfinis,$range);
# force redetermination of intervals
        if (!$options{range} || $options{range} eq 'X') {
           ($cstart, $cfinis) =  $mapping->getObjectRange();
	    $range = 'object';
        }
	else {
           ($cstart, $cfinis) =  $mapping->getMappedRange();
	    $range = 'mapped';
        }
        $cstart = 'undef' unless defined $cstart;
        $cfinis = 'undef' unless defined $cfinis;
	$string .= ", ${range}range=[$cstart, $cfinis]";
    }

    $string .= "\n";

    unless ($options{Xdomain} || $options{Ydomain}) {
        $string .= $mapping->writeToString($options{text},%options);
        return $string;
    }

# list the windows and the sequences 

    my $numberofsegments = $mapping->hasSegments();
    foreach my $segmentnumber (1 .. $numberofsegments) {
        my @segment = $mapping->getSegment($segmentnumber);
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
            if ($k == 1) {
                $substring = reverse($substring);
                $substring =~ tr/acgtACGT/tgcaTGCA/ if ($substring =~ /t/i); 
                $substring =~ tr/acguACGU/ugcaUGCA/ if ($substring =~ /u/i); 
	    }
            $string .= "  " . $substring ."\n";
        }
    }

    return $string;
}

#-------------------------------------------------------------------

1;
