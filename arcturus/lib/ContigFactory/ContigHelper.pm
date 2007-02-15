package ContigHelper;

use strict;

use Contig;

use Mapping;

use Read;

use Tag;

use TagFactory::ReadTagFactory;

use TagFactory::ContigTagFactory;

use Clipping;

use Logging;

# ----------------------------------------------------------------------------
# class variable
# ----------------------------------------------------------------------------

# my $LOGGER;

#-----------------------------------------------------------------------------
# methods which take a Contig instance as input and (can) return a new Contig 
#-----------------------------------------------------------------------------

sub reverse {
# inverts all read alignments TO BE TESTED
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'reverse');

    $contig = &copy($contig) unless $options{nonew};

    my $length = $contig->getContigLength();

# the read mappings

    if ($contig->getMappings()) {
        my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
# and sort the mappings according to increasing contig position
        @$mappings = sort {$a->getContigStart <=> $b->getContigStart} @$mappings;
    }

# possible parent contig mappings

    if ($contig->getContigToContigMappings()) {
        my $mappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
    }

# tags

    my $tags = $contig->getTags();
    foreach my $tag (@$tags) {
        $tag->mirror($length+1);
    }

# replace the consensus sequence with the inverse complement

    if (my $consensus = $contig->getConsensus()) {
        my $newsensus = inverse($consensus);
        $newsensus =~ tr/ACGTacgt/TGCAtgca/;
	$contig->setConsensus($newsensus);
    }

    if (my $quality = $contig->getBaseQuality()) {
# invert the base quality array
        for (my $i = 0 ; $i < $length ; $i++) {
            my $j = $length - $i - 1;
            last unless ($i < $j);
            my $swap = $quality->[$i];
            $quality->[$i] = $quality->[$j];
            $quality->[$j] = $swap;
        }
    }
}

#-------------------------------------------------------------------------
# remove or replace bases
#-------------------------------------------------------------------------

sub deleteLowQualityBases {
# remove low quality dna from input contig
    my $class = shift;
    my $contig = shift;
    my %options = @_;


    &verifyParameter($contig,'deleteLowQualityBases');

    my $logger = &verifyLogger('deleteLowQualityBases');

    $logger->debug("ENTER @_");

# step 1: analyse DNA and Quality data to determine the clipping points

    my $pads = &findlowquality($contig->getSequence(),
                               $contig->getBaseQuality(),
# options: symbols (ACTG), threshold (20), minimum (15), window (9), hqpm (30)
                               %options);

    unless ($pads) {
        my $cnm = $contig->getContigName();
        $logger->error("Missing DNA or quality data in $cnm");
        return $contig, 0; # no low quality stuff found
    }

# step 2: remove low quality pads from the sequence & quality;

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);
my $slength = length($sequence);
my $qlength = scalar(@$quality);
$logger->error("ContigFactory->deleteLowQualityBases  sl:$slength  ql:$qlength");

# out: new sequence, quality array and thye mapping from original to new

$logger->("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED')) if $logger;

    unless ($sequence && $quality && $ori2new) {
        my $cnm = $contig->getContigName();
        $logger->error("Failed to determine new DNA or quality data");
        return undef;
    }

    my $segments = $ori2new->getSegments();
    if (scalar(@$segments) == 1) {
        my $segment = $segments->[0];
        my $length = $segment->[1] - $segment->[0];
        if ($length == length($contig->getSequence())) {
            return $contig, 0.0; # no bases clipped
        }
    }

# build the new contig

    my $clippedcontig = new Contig();

# add descriptors and sequence

    $clippedcontig->setContigName($contig->getContigName);
                
    $clippedcontig->setGap4Name($contig->getGap4Name);
                
    $clippedcontig->setSequence($sequence);
                
    $clippedcontig->setBaseQuality($quality);

    $clippedcontig->addContigNote("low_quality_removed");

# either treat the new contig as a child of the input contig

    if ($options{exportaschild}) {

$logger->info("exporting as CHILD") if $logger;

        my $mapping = $ori2new->inverse();
        $mapping->setSequenceID($contig->getContigID());
        $clippedcontig->addContigToContigMapping($mapping);
        $clippedcontig->addParentContig($contig);
        $contig->addChildContig($clippedcontig);
    }
# or port the transformed contig components by re-mapping from old to new
    elsif ($options{components}) {
        &remapcontigcomponents($contig,$ori2new,$clippedcontig,%options);
    }
 
    return $clippedcontig, 1;
}

#-----------------------------------------------------------------------------

sub replaceLowQualityBases {
# replace low quality pads by a given symbol
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'replaceLowQualityBases');

my $log = &verifyLogger('replaceLowQualityBases');
$log->debug("options  @_");

# test input contig data

    my $sequence = $contig->getSequence();
    my $quality  = $contig->getBaseQuality();

    return undef unless ($sequence && $quality && @$quality);

    my $length = length($sequence);

    return undef unless ($length && $length == scalar(@$quality));

# create a new Contig instance if so specified

    my $contigname = $contig->getContigName() || '';

    $contig = &copy($contig) if $options{new};

# replace low quality bases by the chosen symbol

    $options{padsymbol} = 'N' unless defined $options{padsymbol};

    my $padsymbol = $options{padsymbol};

# choose mode of replacement

    my $lowercase = 1; 
    if (defined($padsymbol) && length($padsymbol) == 1) {
# use the single symbol as replacement
        $lowercase = 0;
    }
    else {
# use lowercase for low quality stuff; hence switch high quality to UC
        $sequence = uc($sequence);
    }

    my $pads = &findlowquality(0,                   # no test DNA
                               $quality,
                               $options{symbols},   # default 'ACGT'
                               $options{threshold}, # default 20
                               $options{minimum},   # default 15
                               $options{hqpm},      # default 30
                               $options{window});   # default 9

    if ($pads && @$pads) {
# there are low quality bases
        my @dna = split //,$sequence;

        foreach my $pad (@$pads) {
            $dna[$pad] = $padsymbol unless $lowercase;
            $dna[$pad] = lc($dna[$pad]) if $lowercase;
	}
# reconstruct the sequence
        $sequence = join '',@dna;
# amend contig note
        if ($lowercase) {
            $contig->addContigNote("[lc] low_quality_marked");
	}
	else {
            $contig->addContigNote("[$padsymbol] low_quality_marked");
	}
    }

    $contig->setSequence($sequence);

    return $contig;
}

#-----------------------------------------------------------------------------
# removing reads from contigs
#-----------------------------------------------------------------------------

sub deleteReads {
# remove a list of reads from a contig
    my $class  = shift;
    my $contig = shift;
    my $reads = shift;
    my %options = @_;

    &verifyParameter($contig,'deleteReads');

    $contig = &copy($contig) if $options{new};

    my ($count,$parity,$total) = &removereads($contig,$reads);

    unless ($total) {
        return undef,"No reads to be deleted specified";
    }

# parity and count must be 0 and a multiple of 3 respectively

    my $status = "p:$parity c:$count t:$total";

    if ($parity || $count%3) {
        return undef,"Badly configured input contig or returned contig ($status)";
    }
    
# test actual count against input read specification
    
    unless ($count > 0 && $count == 3*$total || $options{force}) {
        return undef,"No reads deleted from input contig ($status)" unless $count;
        return undef,"Badly configured input contig or returned contig ($status)";
    }

    return $contig,"OK ($status)";
}

#-----------------------------------------------------------------------------
# TO BE DEVELOPED

sub removeLowQualityReads {
# remove low quality bases and the low quality reads that cause them
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'removeLowQualityBases');

    my $logger = &verifyLogger('removeLowQualityBases');

$logger->debug("ENTER @_");

# step 1: analyse DNA and Quality data to determine the clipping points

    my $pads = &findlowquality($contig->getSequence(),
                               $contig->getBaseQuality(),
                               $options{symbols},   # default 'ACGT'
                               $options{threshold}, # default 20
                               $options{minimum},   # default 15
                               $options{hqpm},      # default 30
                               $options{window});   # default 9

    return $contig unless ($pads && @$pads); # no low quality stuff found

# step 2: make a copy of the contig 

    $contig = &copy($contig) unless $options{nonew};

# step 3: make an inventory of reads stradling the pad positions

    my $mappings = $contig->getMappings() || return undef; # missing mappings

    @$mappings = sort {$a->getContigStart() <=> $b->getContigStart()} @$mappings; 

    my $padhash = &getCountsAtPadPositions($mappings,$pads,%options);

    my $readnamehash = $padhash->{readname};
    my $padcounthash = $padhash->{padcount};

$logger->warning(scalar(keys %$readnamehash)." bad reads found");

    my $badcounts = {};
    foreach my $read (keys %$readnamehash) {
#        $logger->warning("read $read  count $readnamehash->{$read}") if $logger;
        $badcounts->{$readnamehash->{$read}}++;
    }

foreach my $count (sort {$a <=> $b} keys %$badcounts) {
    $logger->warning("count : $count  frequency $badcounts->{$count}");
}

# 

    my $crosscount = {};
    foreach my $pad (keys %$padcounthash) {
        my $reads = $padcounthash->{$pad};
        next unless (scalar(@$reads) > 1);
        $logger->warning("pad $pad has reads @$reads");
        foreach my $readi (@$reads) {
            foreach my $readj (@$reads) {
                next unless ($readi ne $readj); 
                $crosscount->{$readi} = {} unless $crosscount->{$readi};
                $crosscount->{$readi}->{$readj}++;
	    }
	}
    }

return $contig;

# step 4: delete both the Read and the Mapping for the reads

    &removereads($contig,$readnamehash);

# step 5: remove low quality pads from the sequence & quality

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);

$logger->warning("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED')) if $logger;

    unless ($sequence && $quality && $ori2new) {
        $logger->error("Failed to determine new DNA or quality data");
        return undef;
    }

# step 6, redo the mappings

    foreach my $mappingset ($mappings, $contig->getContigToContigMappings()) {
        next unless $mappingset;
        foreach my $mapping (@$mappingset) {
            my $newmapping = $mapping->multiply($ori2new);
            unless ($newmapping) {
                $logger->severe("Failed to transform mappings");
                return undef;
	    }
            $mapping = $newmapping;
	}
    }

    return $contig;
}

sub removeShortReads {
# remove reads spanning less than a minimum number of bases
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'removeShortReads');

    my $logger = &verifyLogger('removeShortReads');

    $contig->hasMappings(1); # delayed loading

    $contig = &copy($contig,includeIDs=>1) unless $options{nonew}; # new instance

# determine clipping threshold

    $options{threshold} = 1 unless defined($options{threshold});
    my $rejectionlevel = $options{threshold};
    
# process mappings

    my $mappings = $contig->getMappings();

    $logger->info("(new) contig ".$contig->getContigName()
                . " has mappings ". scalar(@$mappings)) if $logger;

    my $i = 0;
    my $readhash = {};
    while ($i < scalar(@$mappings)) {
        my $mapping = $mappings->[$i];
        my @position = $mapping->getContigRange();
        my $size = $position[1] - $position[0] + 1;
        if ($size <= $rejectionlevel) {
            my $mappingname = $mapping->getMappingName();
            $readhash->{$mappingname}++;
            splice @$mappings, $i,1;
            $logger->info("mapping $mappingname removed, left "
                        .  scalar(@$mappings)) if $logger;
        }
        else {
            $i++;
        }
    }

    my $delete = scalar(keys %$readhash);

    $logger->info("Contig has $delete mappings deleted") if $logger;

    return $contig unless $delete; # no short reads founds

    return $contig unless $contig->hasReads();

# now strip out the reads (if any)

    my $reads = $contig->getReads(); # no delayed loading

    $logger->info("(new) contig ".$contig->getContigName()
                . " has reads ". scalar(@$reads) ." ("
                . $contig->getNumberOfReads() . ")") if $logger;

    $i = 0;
    while ($i < scalar(@$reads)) {
        my $readname = $reads->[$i]->getReadName();

        if ($readhash->{$readname}) {
            splice @$reads, $i,1;
            $logger->info("read $readname removed, left ".scalar(@$reads));
            $contig->setNumberOfReads($contig->getNumberOfReads()-1);
            $delete--;
        }
        else {
            $i++;
        }
    }

    return undef if $delete; # the mappings do not match the reads

    $logger->info("Number of deleted reads matches removed mapping(s) on contig "
                .  $contig->getContigName()) if $logger;

    return $contig;
}

sub removeEdits {
# to be developed: restore edited reads to the original 
}

#-----------------------------------------------------------------------------

sub extractEndRegion {
# cut out the central part of the consensus and replace sequence by X-s in
# order to get a fixed length string which could be used in e.g. crossmatch
# returns a new contig object with only truncated sequence and quality data
    my $class  = shift;
    my $contig = shift;
    my %options = @_; 

    &verifyParameter($contig,'endRegionOnly');

    my $logger = &verifyLogger('endRegionOnly');

    $logger->debug("ENTER");

    my ($sequence,$quality) = &endregiononly($contig->getSequence(),
                                             $contig->getBaseQuality(),
                                             $options{endregiononly},
                                             $options{maskingsymbol},
                                             $options{shrink},
                                             $options{qfill});
# create a new output contig

    my $newcontig = new Contig();
    $newcontig->setContigName($contig->getContigName);
    $newcontig->setSequence($sequence);
    $newcontig->setBaseQuality($quality);
    $newcontig->addContigNote("endregiononly");
    $newcontig->setGap4Name($contig->getGap4Name);

    return $newcontig;
}

sub endregiononly {
# strictly private: generate masked sequence and quality data
    my $sequence = shift;
    my $quality  = shift;

    &verifyPrivate($sequence,'endregiononly');

# options

    my $unmask = shift || 100; # unmasked length at either end
    my $symbol = shift || 'X'; # replacement symbol for remainder
    my $shrink = shift || 0; # replace centre with string of this length
    my $qfill  = shift || 0;  # quality value to be used in centre

    &verifyPrivate($sequence,'endregiononly');

# apply lower limit, if shrink option active

    $shrink = $unmask if ($shrink < $unmask);

    my $length = length($sequence);

    if ($unmask > 0 && $symbol && $length > 2*$unmask) {

        my $begin  = substr $sequence,0,$unmask;
        my $centre = substr $sequence,$unmask,$length-2*$unmask;
        my $end = substr $sequence,$length-$unmask,$unmask;

# adjust the center, if shrink option

        if ($shrink && $length-2*$unmask >= $shrink) {
            $centre = '';
            while ($shrink--) {
                $centre .= $symbol;
            }
        }
	else {
            $centre =~ s/./$symbol/g;
	}

        $sequence = $begin.$centre.$end;

# assemble new quality array, if an input was defined

        if ($quality) {

            my @newquality = @$quality[0 .. $unmask-1];
            my $length = length($centre);
            while ($length--) {
		push @newquality, $qfill;
	    }
            push @newquality, @$quality[$length-$unmask .. $length-1];

            $quality = \@newquality;
	}
    }

    return $sequence,$quality;
}

#-----------------------------------------------------------------------------

sub endRegionTrim {
# trim low quality data from the end of the contig
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'endRegionTrim');

    my $logger = &verifyLogger('endRegionTrim');

    $logger->debug("ENTER");

    my ($sequence,$quality,$mapping) = &endregiontrim($contig->getSequence(),
                                                      $contig->getBaseQuality(),
                                                      $options{cliplevel});
    unless ($sequence && $quality && $mapping) {
        return undef,"Can't do trimming: missing quality data in "
                    . $contig->getContigName()."\n";
    }

    if (ref($mapping) ne 'Mapping') {
        return $contig, "No change";
    }

# create a new contig

    my $clippedcontig = new Contig();

    $clippedcontig->setSequence($sequence);

    $clippedcontig->setBaseQuality($quality);

    $clippedcontig->setContigNote("endregiontrimmed [$options{cliplevel}]");

# and port the components, if any, to the newly created clipped contig

# breaktags,mergetags
    &remapcontigcomponents($contig,$mapping,$clippedcontig,%options); # TO BE TESTED

    my @range = $mapping->getContigRange();

    return $clippedcontig, "clipped range @range";
}

sub endregiontrim {
# strictly private: trim low quality data from the end of the contig
    my $sequence = shift;
    my $quality  = shift;

    &verifyPrivate($sequence,'endregiontrim');

# parameter

    my $cliplevel = shift;

    return $sequence, $quality, 1  unless $cliplevel; # no change

# test input

    return undef unless ($sequence && $quality && @$quality);

# clipping algorithm for the moment taken from Asp

    my ($QL,$QR) = Clipping->phred_clip($cliplevel, $quality);

# adjust the sequence and quality data

    my $newsequence = substr($sequence,$QL-1,$QR-$QL+1);

    my @newquality  = @$quality [$QL-1 .. $QR-1];

    my $mapping = new Mapping();
    $mapping->putSegment($QL, $QR, 1, $QR-$QL+1);

    return $newsequence, \@newquality, $mapping;
}

#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# private methods
#-----------------------------------------------------------------------------

sub copy {
# create a copy of input contig and (some of) its components (as they are)
    my $contig = shift;
    my %options = @_;

    &verifyPrivate($contig,'copy');

    my $logger = &verifyLogger('copy');

# create a new instance

    my $newcontig = new Contig();

# (default do not) add name and sequence ID 

    if ($options{includeIDs}) {
        $newcontig->setContigName($contig->getContigName());
        $newcontig->setContigID($contig->getContigID());
        $newcontig->setGap4Name($contig->getGap4Name());
    }

# always add consensus data
                
    $newcontig->setSequence($contig->getSequence);
                
    $newcontig->setBaseQuality($contig->getBaseQuality);

    $newcontig->setContigNote($contig->getContigNote); # if any

# (optionally) copy the arrays of references to any other components

    my @components  = ('Read','Mapping','Tag','ParentContig',
                       'ChildContig','ContigToContigMapping');

    return $newcontig if $options{nocomponents};

    foreach my $component (@components) {

       eval "\$newcontig->add$component(\$contig->get${component}s())";
       $logger->error("$@") if $@; 
    }

    return $newcontig;
}

sub findlowquality {
# scan quality data and/or dna data; return an array of low quality positions
    my $sequence = shift;
    my $quality = shift;

    &verifyPrivate($sequence,'findlowquality');

# options (and defaults if 0 or undef)
 
    my $symbols               = shift || 'ACGT';
    my $threshold             = shift;
    my $minimum               = shift;
    my $highqualitypadminimum = shift;
    my $fwindow               = shift || 9;
# check defaults if undef
    $threshold = 20 unless defined($threshold);
    $minimum = 15   unless defined($minimum);
    $highqualitypadminimum = 30 unless defined($highqualitypadminimum);

    my $logger = &verifyLogger('findlowquality');

# check input; return undef if data missing or inconsistent

    return undef unless $quality;

    my $qlength = scalar(@$quality);

$logger->debug("ENTER ($qlength) $symbols,$threshold,$minimum,$highqualitypadminimum,$fwindow");

    if ($sequence) {
        my $slength = length($sequence);
        unless ($qlength == $slength) {
            $logger->error("length mismatch! s:$slength q:$qlength");
	    $logger->error("$quality->[0],$quality->[1]   "
                          ."$quality->[$qlength-2],$quality->[$qlength-1]");
            return undef;
	}
    }

# ensure window of odd length

    my $hwindow = int($fwindow/2);
    $fwindow = 2 * $hwindow + 1;

# ok, scan the quality array/dna to locate low quality pads

    my $pads = [];

    my $reference = &slidingmeanfilter($quality,$fwindow) || [];

    for (my $i = $hwindow ; $i <= $qlength - $hwindow ; $i++) {
# test the base against accepted symbols ("high" quality pads)
        if ($sequence && substr($sequence, $i, 1) !~ /[$symbols]$/) {
# setting $highqualitypadminimum to 0 accepts ALL (non) matches as "real" pad
            next unless ($quality->[$i] >= $highqualitypadminimum); # NOT LQ
            push @$pads, $i; # zeropoint 0
            next;
	}
# there's a base at this position; test the quality against a reference level
# if no reference level provided determine it using a default mean filter
        unless ($reference && $reference->[$i]) {
            $reference->[$i] = ($quality->[$i-2] + $quality->[$i+2]) / 2;
	}
# test the quality: LQ when deviation is larger than the threshold
        if ($reference->[$i] - $quality->[$i] > $threshold) {
# but itself not too high; setting minimum to 0 accepts NONE as low quality pad
            next if ($quality->[$i] >= $minimum); 
            push @$pads, $i; # zeropoint 0
	}
    }

#    @$pads = sort {$a <=> $b} @$pads;

    return $pads;
}

sub slidingmeanfilter {
# sliding mean filtering of (quality) array
    my $qinput = shift;
    my $window = shift;

    &verifyPrivate($qinput,'slidingmeanfilter');

    my $logger = &verifyLogger('slidingmeanfilter');

$logger->debug("ENTER slidingmeanfilter $window");

# step 1 : determine filter to be used

    my $nfwhalf = int(($window-1)/2 + 1 +0.5); # half filter width
    my $nfilter = $nfwhalf + $nfwhalf - 1;     # ensure odd length

    my @filter;
    for (my $i = 0 ; $i < $window ; $i++) {
        $filter[$i] = $1.0;
    }

# step 2: apply log transform

    my $qoutput = [];
    my $loghash = {};

    my $logtransform;
    my $offset = 10000.0;
$logger->debug("begin LOG transform");
    foreach my $value (@$qinput) {
        my $logkey = int($value+$offset+0.5);
        unless ($logtransform = $loghash->{$logkey}) {
            $loghash->{$logkey} = log($logkey);
            $logtransform = $loghash->{$logkey};
$logger->debug("creating log hash element for key $logkey"); 
        }
        push @$qoutput,$logtransform;
    }
$logger->debug("DONE LOG transform");

# step 3: apply sliding mean filter

    my $b = []; # scratch buffer

    my $filtersum = 0.0;
    foreach my $element (@filter) {
	$filtersum += $element;
    }
   
    

# step 4: apply inverse log transform

$logger->debug("begin EXP transform");
    foreach my $value (@$qoutput) {
        $value = int(exp($value) - $offset + 0.5);
    } 
$logger->debug("DONE EXP transform");
    return undef;
}

sub removepads {
# remove base and quality data at given pad positions 
    my $sequence = shift; # string
    my $quality = shift; # array ref
    my $pads = shift; # array ref

    &verifyPrivate($sequence,'removepads');

    my $logger = &verifyLogger('removepads');

$logger->debug("ENTER @_ PADS @$pads");

    my $sorted = [];
    @$sorted = sort {$a <=> $b} @$pads;
# extend the array with an opening and closing pad (pads start counting at 1)
    push @$sorted, length($sequence);
    unshift @$sorted, -1;

    my $newquality = [];
    my $newsequence = '';
    my $mapping = new Mapping();

    for (my $i = 1 ; $i < scalar(@$sorted) ; $i++) {
# get the begin and end of the interval in the original sequence (zeropoint = 1)
        my $final = $sorted->[$i] - 1;
        my $start = $sorted->[$i-1] + 1;
        my $interval = $final - $start + 1;
        next unless ($interval > 0);
# get the begin of the interval from the current size of the ouput array
        my $newstart = scalar(@$newquality);
# assemble the sequence
        $newsequence .= substr($sequence, $start, $interval);        
        push @$newquality, @$quality [$start .. $final];
# assemble the segment for the mapping
        $mapping->putSegment($start+1,$final+1,$newstart+1,$newstart+$interval);
    }
    return $newsequence,$newquality,$mapping;
}

#-----------------------------------------------------------------------------------

sub getCountsAtPadPositions {
# private: build count table at input pad positions
    my $mappings = shift; # array ref
    my $pads = shift; # array ref with pad positions to be tested

    &verifyPrivate($mappings,'testPaPositions');

    my $padhash = {};
    $padhash->{readname} = {};
    $padhash->{padcount} = {};

    my $trialpad = 0;
    foreach my $mapping (@$mappings) {
        next unless $mapping->hasSegments();
        my $segments = $mapping->getSegments();
        my ($cs,$cf) = $mapping->getContigRange();
        while ($pads->[$trialpad] && $pads->[$trialpad] + 1 < $cs) {
            $trialpad++;
	}
        next unless ($pads->[$trialpad] && $pads->[$trialpad] + 1 < $cf);

        my $readname = $mapping->getMappingName();
        foreach my $segment (@$segments) {
# register the mapping name (= read name) if a pad position falls inside a segment
            my $pad = $trialpad;
            while ($pads->[$pad] && $pads->[$pad] + 1 < $cf) {
                if (my $y = $segment->getYforX($pads->[$pad] + 1)) {
                    $padhash->{readname}->{$readname}++;
                    unless ($padhash->{$pad}) {
                        $padhash->{padcount}->{$pad} = [];
                    }
                    push @{$padhash->{padcount}->{$pad}},$readname;
		}
		$pad++;
            }
	}
    }

    return $padhash;
}

#----------------------------------------------------------------------------------
sub remapcontigcomponents {
# take components from oldcontig, remap using ori2new, put into newcontig
    my $oldcontig = shift; # original contig
    my $ori2new   = shift; # mapping original to new
    my $newcontig = shift; 
    my %options = @_;

    &verifyPrivate($oldcontig,'remapcontigcomponents');

    my $logger = &verifyLogger('remapcontigcomponents');

    $logger->debug("ENTER @_");

# add and transform the mappings; keep track of the corresponding reads

    my $readnamehash = {};
    my $mappings = $oldcontig->getMappings();
    foreach my $mapping (@$mappings) {
        my $newmapping = $mapping->multiply($ori2new);
        next unless $newmapping;
        $readnamehash->{$mapping->getMappingName()}++;
        $newcontig->addMapping($newmapping);
    }

# add the reads, if they are present in the input oldcontig

    my $reads = $oldcontig->getReads();
    foreach my $read (@$reads) {
        next unless $readnamehash->{$read->getReadName()};
        $newcontig->addRead($read);
    }

# and remap the tags on the sequence

    if ($oldcontig->hasTags()) {

        my $tagfactory = new ContigTagFactory();

        my $tags = $oldcontig->getTags();

        my $breaktags = $options{breaktags} || 'ANNO';
        $breaktags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $breaktags =~ s/\W+/|/g;

        my @newtags;
        foreach my $tag (@$tags) {
# special treatment for ANNO tags?
            my $tagtype = $tag->getType();
            if ($tagtype =~ /$breaktags/) {
                my $newtags = $tagfactory->remap($tag,$ori2new,break=>1);
                push @newtags, @$newtags if $newtags;
            }
            else {
                my $newtag  = $tagfactory->remap($tag,$ori2new,break=>0);
                push @newtags, $newtag if $newtag;
	    }
	}

# test if some tags can be merged (using the Tag factory)

        my $mergetags = $options{mergetags} || 'ANNO';
        $mergetags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $mergetags =~ s/\W+/|/g;

        my @tags = $tagfactory->mergeTags([@newtags],$mergetags);        

# and add to the new contig

        $newcontig->addTag(@tags);
    }

# finally, investigate possible parent links

    if ($oldcontig->hasContigToContigMappings()) {
# get the mapping of newcontig to each parent of oldcontig
        my $new2old = $ori2new->inverse();
        my $parentmappings = $oldcontig->getContigToContigMappings();
        my $parentnamehash = {};
        foreach my $mapping (@$parentmappings) {
            my $newmapping = $new2old->multiply($mapping);
            next unless $newmapping;
            $newcontig->addContigToContigMapping($newmapping);
            $parentnamehash->{$mapping->getMappingName()}++;
	}
# and add the parent(s)
        my $parentcontigs = $oldcontig->getParentContigs();
        foreach my $parent (@$parentcontigs) {
            next unless $parentnamehash->{$parent->getContigName()};
	    $newcontig->addParentContig($parent);
	}
    }
}

sub removereads {
# remove named reads from the Read and Mapping stock
    my $contig = shift;
    my $readrf = shift; # readid, array-ref or hash

    &verifyPrivate($contig,"removeRead");

    my $logger = &verifyLogger("removeRead");

# get the readname hash

    my $readidhash = {};
    if (ref($readrf) eq 'HASH') {
        $readidhash = $readrf;
    }
    elsif (ref($readrf) eq 'ARRAY') {
        foreach my $identifier (@$readrf) {
            $readidhash->{$identifier}++;
        }
    }
    else {
        $readidhash->{$readrf}++;
    }
    
# run through the reads and mappings and remove the ones that match

    my $parity = 0;
    my $splicecount = 0;
    my $total = scalar(keys %$readidhash);

    my $reads = $contig->getReads(1);
    for (my $i = 0 ; $i < scalar(@$reads) ; $i++) {
        next unless ($readidhash->{$reads->[$i]->getReadName()}
             or      $readidhash->{$reads->[$i]->getReadID()});
        delete $readidhash->{$reads->[$i]->getReadID()}; # remove read ID
        $readidhash->{$reads->[$i]->getSequenceID()}++;  # and replace by sequence ID
        splice @$reads,$i,1;
        $contig->setNumberOfReads(scalar(@$reads));
        $splicecount += 2;
        $parity++;
        $logger->warning("read ".$reads->[$i]->getReadName()." ($i) removed");
    }
            
    my $mapps = $contig->getMappings(1);
    for (my $i = 0 ; $i < scalar(@$mapps) ; $i++) {
        next unless ($readidhash->{$mapps->[$i]->getMappingName()}
             or      $readidhash->{$mapps->[$i]->getSequenceID()});
        splice @$mapps,$i,1;
        $splicecount++;
        $parity--;
        next unless $logger;
        $logger->warning("mapping ".$mapps->[$i]->getMappingName()." ($i) removed");
    }

    return $splicecount,$parity,$total;
}

#-----------------------------------------------------------------------------
# access protocol
#-----------------------------------------------------------------------------

sub verifyParameter {
    my $object = shift;
    my $method = shift || 'UNDEFINED';
    my $class  = shift || 'Contig';

    return if ($object && ref($object) eq $class);
    print STDOUT "ContigHelper->$method expects a $class instance as parameter\n";
    exit 1;
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return unless ($caller && ref($caller) eq 'ContigHelper');
    print STDERR "Invalid usage of private method '$method' in package ContigHelper\n";
    exit 1;
}

#-----------------------------------------------------------------------------
# log file
#-----------------------------------------------------------------------------

my $LOGGER;

sub verifyLogger {
# private, test the logging unit; if not found, build a default logging module
    my $prefix = shift;

    &verifyPrivate($prefix,'verifyLogger');

    if ($LOGGER && ref($LOGGER) eq 'Logging') {

        $LOGGER->setPrefix($prefix) if defined($prefix);

        return $LOGGER;
    }

# no (valid) logging unit is defined, create a default unit

    $LOGGER = new Logging();

    $prefix = 'ContigHelper' unless defined($prefix);

    $LOGGER->setPrefix($prefix);
    
    return $LOGGER;
}

sub setLogger {
# assign a Logging object 
    my $this = shift;
    my $logger = shift;

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $LOGGER undefined
}

#-----------------------------------------------------------------------------

1;
