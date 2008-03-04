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

# create a token which can be used to identify this Mapping to its Segments

    my $token = "$this";
    $token =~ s/.*\((\S+)\).*/$1/;
    $this->{token} = $token;

# optionally set the identifier

    $this->setMappingName($identifier) if $identifier;

    return $this;
}
    
my %NORMALISATION = (x => 1, X => 1, y => 2, Y => 2); # class variable
 
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

sub getMappedRange {
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
    my $adir = shift || 0;

    return unless (abs($adir) == 1); # accepts only +1 or -1

    $this->{direction} = $adir;
}

sub getAlignment {
# returns +1, -1 or undef
    my $this = shift;

# if the direction is undefined (or 0), analyse the segments (if any)
# (orders the segments and determines the mapping alignment direction)

    $this->normalise() unless $this->{direction};

    return $this->{direction};
}

#-------------------------------------------------------------------
# compare mappings
#-------------------------------------------------------------------

sub isEqual {
# compare this Mapping instance with input Mapping
# return 0 if mappings are in any respect different
    my $mapping = shift;
    my $compare = shift;
    my %options = @_; # domain=>'Y' (default) , or 'X'

    $options{domain} = uc($options{domain}) if $options{domain};

    if (ref($compare) ne 'Mapping') {
        die "Mapping->isEqual expects an instance of the Mapping class";
    }

    my $tmaps = $mapping->normalise(%options); # also sorts segments 
    my $cmaps = $compare->normalise(%options); # also sorts segments

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

sub compare {
# compare this Mapping instance with input Mapping at the segment level
    my $mapping = shift;
    my $compare = shift;
    my %options = @_; # domain=>'Y' (default) or 'X'

    $options{domain} = uc($options{domain}) if $options{domain};

    if (ref($compare) ne 'Mapping') {
        die "Mapping->compare expects an instance of the Mapping class";
    }

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
            return 0,undef unless ($align == $aligned);

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

    $newmapping->normalise();

    return $newmapping unless $options{useold};

    return $align,[@osegments]; # old system, to be deprecated
}

#-------------------------------------------------------------------
# normalisation : order each segment in the x or y domain 
#                 order the segments according to x or y position
#-------------------------------------------------------------------

sub normaliseOnX {
# alias for normalise: order segments in x domain
    my $this = shift;
    my %options = @_; # silent=>
    $options{domain} = 'X';
    return $this->normalise(%options);
}

sub normaliseOnY {
# alias for normalise: order segments in y domain
    my $this = shift;
    my %options = @_; # silent=>
    $options{domain} = 'Y';
    return $this->normalise(%options);
}

sub normalise {
# sort the segments according to increasing read position
# determine/test alignment direction from the segments
    my $this = shift;
    my %options = @_; # normalise, silent
 
# set up the required normalization status

    return 0 unless $this->hasSegments();

    my $segments = $this->getSegments();

# check the current normalization status of the segments against requirement

    my $requirement = $options{domain} || 'Y'; # default

    $requirement = $NORMALISATION{$requirement} || $requirement || 2;

    if (my $normalisation = $this->{normalisation}) {
# return if the normalization already matches the required one
        return $segments if ($normalisation == $requirement);
# if the current normalisation is on x, invert array to speed up sorting
# &invertArray($segments) if ($normalisation == 1);
        @$segments = reverse(@$segments) if ($normalisation == 1);
    }

    $this->{normalisation} = 0; # as it is going to be determined

# default normalization and sort on Y (read) domain, sort on Y-start

    my $mid = $this->{token}; # mapping ID token

    foreach my $segment (@$segments) {
        $segment->normaliseOnY($mid);
    }

    @$segments = sort { $a->getYstart() <=> $b->getYstart() } @$segments;

# determine the alignment direction from the range covered by all segments
# if it is a reverse alignment we have to reset the alignment direction in
# single base segments by applying the counterAlign... method

    my $n = scalar(@$segments) - 1;
 
    my $globalalignment = 1; # overall alignment
    if ($segments->[0]->getXstart() > $segments->[$n]->getXfinis()) {
        $globalalignment = -1;
# counter align unit-length alignments if mapping is counter-aligned
        foreach my $segment (@$segments) {
# the counter align method only works for unit length intervals
            $segment->counterAlignUnitLengthInterval($mid);
        }
    }

# test consistency of alignments

    my $localalignment = 0;
    foreach my $segment (@$segments) {
# ignore unit-length segments
        next if ($segment->getYstart() == $segment->getYfinis());
# register alignment of first segment longer than one base
        $localalignment = $segment->getAlignment() unless $localalignment;
# test the alignment of each subsequent segment; exit on inconsistency
	if ($segment->getAlignment() != $localalignment) {
# if this error occurs it is an indication for an erroneous alignment
# direction in the MAPPING table; on first encounter, printer error message
            unless ($options{silent}) {
                print STDERR "Inconsistent alignment(s) in mapping "
                           . ($this->getMappingName || $this->getSequenceID)
			   . " :\n".$this->assembledFromToString();
	    }
            $globalalignment = 0;
            last;
        }
    }

# if alignment == 0, all segments are unit length: adopt globalalignment
# if local and global alignment are different, the mapping is anomalous with
# consistent alignment direction, but inconsistent ordering in X and Y; then
# use the local alignment direction. (re: contig-to-contig mapping) 

    $localalignment = $globalalignment unless $localalignment;

    if ($localalignment == 0 || $localalignment != $globalalignment) {
        unless ($options{silent}) {
            print STDERR "Anomalous alignment in mapping "
                       . ($this->getMappingName || $this->getSequenceID)
	               . " ($localalignment $globalalignment) :\n"
                       .  $this->writeToString('segment',extended=>1);
        }
        $globalalignment = $localalignment;
    }

# register the alignment direction
    
    $this->setAlignment($globalalignment);

# reorder the alignments if normalisation on X is required (re: sub multiply)

    if ($requirement == 1) {
# non-standard normalisation and sort
        foreach my $segment (@$segments) {
            $segment->normaliseOnX($mid);
        }
# sorting may be very slow for a large number of segments, because
# we had earlier sorted according to Y, we better reverse the array order

# &invertArray($segments) unless ($globalalignment >= 0);
        @$segments = reverse(@$segments) unless ($globalalignment >= 0);

# just to be sure, we now sort again
        @$segments = sort { $a->getXstart() <=> $b->getXstart() } @$segments;
# set normalization status
        $this->{normalisation} = 1;
    }
# else keep current normalisation (on Y)
    else {
        $this->{normalisation} = 2;
    }

    return $segments;
}

sub invertArray {
# private; helper method for normalise, normaliseOnX, normaliseOnY
    my $segments = shift;

#    @$segments = reverse(@$segments); return;
           
    my $length = scalar(@$segments);
    for (my $i = 0 ; $i < $length ; $i++) {
        my $j = $length - $i - 1;
        last unless ($i < $j);
        my $segment = $segments->[$i];
        $segments->[$i] = $segments->[$j];
        $segments->[$j] = $segment;
    }
}

#-------------------------------------------------------------------
# apply linear transformation to mapping; access only via Contig
#-------------------------------------------------------------------

sub applyShiftToContigPosition { # shiftXPosition
# apply a linear contig (i.e. X) shift to each segment
    my $this = shift;
    my $shift = shift;

    return 0 unless ($shift && $this->hasSegments());

    my $mid = $this->{token};

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(1,$shift,$mid); # apply shift to X
    }

    undef $this->{objectrange}; # force re-initialisation of cache

    return 1;
}

sub applyMirrorTransform { # mirror (different from inverse)
# apply a contig mapping reversion and shift to each segment
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (= contig_length + 1)

    return 0 unless $this->hasSegments();

    my $mid = $this->{token};

    $this->normalise(); # must do, before the next transform ??

# apply the mirror transformation (y = -x + m) to all segments

    my $segments = $this->getSegments();
    foreach my $segment (@$segments) {
        $segment->applyLinearTransform(-1,$mirror,$mid);
    }

# invert alignment status

    $this->setAlignment(-$this->getAlignment());

    undef $this->{objectrange}; # force re-initialisation of cache

    undef $this->{normalisation};

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

    $_[4] = $this->{token}; # add mapping identifier at the end

    my $segment = new Segment(@_);

    return undef unless $segment; # process externally

    $this->{mySegments} = [] if !$this->{mySegments};

    push @{$this->{mySegments}},$segment;

    $this->{normalisation} = 0; # set to undefined

# assign a (possibly preliminary) alignment direction

    unless ($segment->getSegmentLength() <= 1) {
# no test for consistence (do that with normalise afterwards)
        $this->setAlignment($segment->getAlignment());
    }

    return scalar(@{$this->{mySegments}});
}

#-------------------------------------------------------------------
# creating a new mapping, inverting and multiplying
#-------------------------------------------------------------------

sub copy {
# return a complete copy of this mapping
    my $this = shift;

    my $copy = $this->new($this->getMappingName());

    $copy->setSequenceID($this->getSequenceID()); # if any

    my $segments = $this->getSegments();

    foreach my $segment (@$segments) {
        my @copysegment = $segment->getSegment();
        $copy->putSegment(@copysegment);
    }

    $copy->normalise(); # on y

    return $copy;
}

sub inverse {
# return inverse mapping as new mapping
    my $this = shift;
    my %options = @_;

    my $segments = $this->getSegments();

    return undef unless ($segments && @$segments);

    my $name = $this->getMappingName() || $this;
    $name = "inverse of $name";
    $name =~ s/inverse of inverse of //; # two consecutive inversions
# perhaps this should be replaced by Sequence_ysequence domain ??
#   $name = sprintf("sequence_%08d",($this->getSequenceID('y')); # if defined

    my $inverse = new Mapping($name);

    foreach my $segment (@$segments) {
        my @segment = $segment->getSegment();
        $inverse->putSegment($segment[2],$segment[3],
                             $segment[0],$segment[1]);
    }

    $inverse->normalise(@_); # port options

    $inverse->setSequenceID($this->getSequenceID('x'),'y');
    $inverse->setSequenceID($this->getSequenceID('y'),'x');

#$inverse->setSequenceID($this->getSequenceID()); # temporary

    return $inverse;   
}

sub multiply {
# return the product R x T of this (mapping) and another mapping
# returns a mapping without segments if product is empty
    my $thismap = shift; # mapping R
    my $mapping = shift; # mapping T
    my %options = @_; # e.g. repair=>1; default 0

# align the mappings such that the Y (mapped) domain of R and the 
# X domain of T are both ordered according to segment position 

    my $rname = $thismap->getMappingName() || 'R';
    my $tname = $mapping->getMappingName() || 'T';

    my $rsegments = $thismap->normaliseOnY();
    my $tsegments = $mapping->normaliseOnX();

    my $product = new Mapping("$rname x $tname");

    return $product unless ($rsegments && $tsegments); # product empty 

# find the starting point in segment arrays if activated

    my ($rs,$ts) = (0,0);
# tracking of segments option to start the search at a different position
# (use this method repeatedly for a list of mappings sorted on mapped? position) 
my $nzs = $options{nonzerostart};
if ($nzs && ref($nzs) eq 'HASH') {
 $rs = $nzs->{rstart} if ($nzs->{rstart} && $nzs->{rstart} > 0);
 $ts = $nzs->{tstart} if ($nzs->{tstart} && $nzs->{tstart} > 0);
print STDERR "segment tracking: start rs=$rs  ts=$ts\n";
}
# new construction (TO BE VERIFIED)

    if (my $track = $options{tracksegments}) { # undef,0  or  1,2,3
        my $backskip = $options{'ts-backskip'}; 
        $backskip = 1 unless defined($backskip); # default backskip one
        $rs = $thismap->getSegmentTracker(-$backskip) if ($track != 2);
        $ts = $mapping->getSegmentTracker(-$backskip) if ($track >= 2);
print STDERR "segment tracking: start rs=$rs  ts=$ts\n";
    }

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
		print STDOUT "Mapping->multiply: should not occur (1) !!\n";
                &dump($thismap,$mapping,$rs,$ts);
                return undef;
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
	        print STDOUT "Mapping->multiply: should not occur (2) !!\n";
                &dump($thismap,$mapping,$rs,$ts);
                return undef;
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
	        print STDOUT "Mapping->multiply: should not occur (3) !!\n";
                &dump($thismap,$mapping,$rs,$ts);
                return undef;
            }
        }
        else {
# no segment matching or overlap 
            $ts++ if ($ryf >= $txf);
            $rs++ if ($ryf <= $txf);
	}
    }

# adjust the non-zero start parameters TO BE DEPRECATED
if ($nzs && ref($nzs) eq 'HASH') {
 $nzs->{rstart} = $rs;
 $nzs->{tstart} = $ts;
print STDERR "segment tracking:  end  rs=$rs  ts=$ts\n";
}

# register the current segment counter numbers

    $thismap->setSegmentTracker($rs);
    $mapping->setSegmentTracker($ts);

# cleanup and analyse the segments

    $product->normalise(); # on Y

    $product->collate($options{repair});

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
    my ($thismap,$mapping,$rs,$ts) = @_;
	
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
# transform an input x-range to an (array of) y-position intervals
    my $this = shift;
    my @position = sort {$a <=> $b} (shift,shift);

# represent the position range as a 1-1 mapping

    my $helper = new Mapping("scratch");
    $helper->putSegment(@position,@position);

# the segments of 'transform' represent the parts of the input range
# which map to the output range

    my $transform = $helper->multiply($this);
    my $segments = $transform->normaliseOnY();

# extract the actual mapped part as a list of arrays of length 2

    my @output;
    foreach my $segment (@$segments) {
        my @section = $segment->getYstart(),$segment->getYfinis();
        push @output,[@section];
    }

# return the mapped interval(s) and the transform (which has alignment info)

    return [@output],$transform;
}

sub transformString {
# map an input string to an output string, replacing gaps by gapsymbol
    my $this = shift;
    my $string = shift || return undef;
    my %options = @_; # gapsymbol=>

# get the part(s) in the mapped domain (starts at position 1)

    my ($list,$transform) = $this->transform(1,length($string));
    my $alignment = $transform->getAlignment() || return undef;
#print STDOUT $transform->toString();

    $options{gapsymbol} = 'n' unless defined $options{gapsymbol};
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
            $pfinal = $segment->getYfinis();
	}
    }
    
    return $output;
}

sub transformArray {
# map an input array to an output array, replacing gaps by gap values
    my $this = shift;
    my $array = shift || return undef; # array reference
    my %options = @_; # gapvalue=>

# get the part(s) in the mapped domain (starts at position 1)

    my ($output,$transform) = $this->transform(1,scalar(@$array));
    my $alignment = $transform->getAlignment() || return undef;

    $options{gapvalue} = 1 unless defined $options{gapsymbol};
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
	else {
            $pfinal = $segment->getYfinis();
	}
        push @output,@subarray;
    }
    
    return [@output];
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
    my %options = @_;

    my $segments = $this->getSegments();

    my $string = '';
    foreach my $segment (@$segments) {
# unless option asis use standard representation: align on Y
        my @segment = $segment->getSegment();
        unless ($options{asis} || $segment[2] <= $segment[3]) {
            ($segment[0],$segment[1]) = ($segment[1],$segment[0]);
            ($segment[2],$segment[3]) = ($segment[3],$segment[2]);
        }
        $string .= $text." @segment";
        if ($options{extended}) {
            $string .= " a:".($segment->getAlignment() || 'undef');
            $string .= " o:".($segment->getOffset()    || 0);
            $string .= " l:". $segment->getSegmentLength();
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

    my $mappingname = $this->getMappingName()      || 'undefined';
    my $direction = $this->getAlignmentDirection() || 'UNDEFINED';

    my $string = "Mapping: name=$mappingname, sense=$direction";

    unless (defined($options{range}) && !$options{range}) {
	my ($cstart, $cfinis,$range);
# force redetermination of intervals
        if (!$options{range} || $options{range} eq 'X') {
           ($cstart, $cfinis) =  $this->getContigRange(1);
	    $range = 'contig';
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
