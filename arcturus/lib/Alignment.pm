package Alignment;

use strict;

use Mapping;

use Segment;

#--------------------------------------------------------------------------
# class variables
#--------------------------------------------------------------------------

my %inverse; # for inverted k-mers

#--------------------------------------------------------------------------

sub correlate {
# public method; returns mapping from template to sequence
    my $class = shift;
    my $template = shift; # the reference sequence
    my $tkmerhash = shift; # the k-mer hash for this template (can be undef)
    my $sequence  = shift; # the test sequence
    my $skmerhash = shift; # the k-mer hash for this sequence (can be undef)
    my %options = @_;

# options :  kmersize   default 7
#           threshold   default determined from data
##              repeat   for default threshold determination  
#           peakdrift   expected drift in offset; default 3
#           coaligned   -1, +1, 0; default 0
#        bandedlinear   expecting a (roughly) linear shift
#        bandedoffset   idem, the constant term 
#        bandedwindow   expected drift in offset with respect to linear, default 10
#    offsetlowerbound
#    offsetupperbound

# experimental/not yet implemented
#             iterate   through gaps between segments
#            autoclip   require subsegments larger than value x average length
#?            tquality   reference to quality array for template data
#?            squality   reference to quality array for sequence data
#?            clip       clip low quality data according to some model

    my $logger = &verifyLogger('correlate');

#------------------------------------------------------------------------------
# test if kmer hashes are present/compatible; if not, build them
#------------------------------------------------------------------------------

    unless ($tkmerhash && $skmerhash
        &&  $tkmerhash->{kmersize} && $skmerhash->{kmersize}
        &&  $tkmerhash->{kmersize} == $skmerhash->{kmersize}) {
# get the kmersize
        my $kmersize = $options{kmersize} || 7;
        $kmersize = 7 unless ($kmersize > 0);
        my $halfsize = int(($kmersize-1)/2 + 0.5);
        $kmersize = $halfsize * 2 + 1; # ensure an odd number
# build the hashes
        $tkmerhash = &buildKmerHash($template,$kmersize);
        $skmerhash = &buildKmerHash($sequence,$kmersize);
    }

    return 0 unless (&verifyKmerHash($tkmerhash) && &verifyKmerHash($skmerhash));

#------------------------------------------------------------------------------
# get boundaries on the sequence (from the hash, in case it's defined outside)
#------------------------------------------------------------------------------

    my @borders;
    push @borders, $tkmerhash->{sequencestart};
    push @borders, $tkmerhash->{sequencefinal};
    push @borders, $skmerhash->{sequencestart};
    push @borders, $skmerhash->{sequencefinal};
       
    my $templatelength = $borders[1] - $borders[0] + 1;
    my $sequencelength = $borders[3] - $borders[2] + 1;

# minimum segments size (based on random largest expected length)

    my $mrss =int((log($templatelength*$sequencelength)/0.434)/0.45 + 0.5);

    my $kmersize = $tkmerhash->{kmersize};
    my $halfkmersize = int(($kmersize+1)/2 + 0.1); # kmersize odd

#------------------------------------------------------------------------------
# get (& process/copy) control parameters or their defaults
#------------------------------------------------------------------------------

    my $coaligned  = $options{coaligned} || 0; # ensure definition
    my $ofilter    = $options{filteroffsets}; 
    my $searchmode = $options{searchmode};

    my $monotonous = $options{nomonotomous} ? 0 : 1; # allow mixed alignment directions

    my $peakdrift  = $options{peakdrift};

# correlation options: banded search (or not) & offset filter (or not)

    my $reverse = 0;
    my $banding = 0;
    my $owindow = 0;

    my %coptions; # correlation options
    if ($options{bandedwindow} || $options{bandedlinear} || $options{bandedoffset}) {
# the approximate linear relation is known and used to limit search domain
        $coptions{linear} = $options{bandedlinear} || 1.0;
        $coptions{offset} = $options{bandedoffset} || 0.0;
        $coptions{window} = $options{bandedwindow} || $peakdrift;
        $coptions{window} = 7 unless defined $coptions{window};
        $peakdrift = $coptions{window} unless defined $peakdrift;
# set to no autoclip, unless it is already defined
        $options{autoclip} = 0 unless defined $options{autoclip};
# the banded search specification overrides any coaligned setting
        $reverse = 1 if ($coptions{linear} < 0);
        my $aligned = $coptions{linear}/abs($coptions{linear});
# just signal an inconsistency of input parameters 
        unless ($coaligned * $aligned >= 0) {
            $logger->error("Incompatible alignment specification adjusted (c:$coaligned a:$aligned)");
        }
        $coaligned = $aligned;
        $banding = 1;
    }
    else {
        $reverse = 1 if ($options{coaligned} && $options{coaligned} < 0);

        $peakdrift = 5 unless defined $peakdrift; # ???
    }

# more general constraint on offset

    if ($options{offsetlowerbound} || $options{offsetupperbound}) {
        $coptions{offsetlowerbound} = $options{offsetlowerbound} || 0;
        $coptions{offsetupperbound} = $options{offsetupperbound} || 0;
        $owindow = 1;
        unless ($coptions{offsetupperbound} > $coptions{offsetlowerbound}) {
            $logger->error("invalid offset boundaries: $coptions{offsetlowerbound} - "
			   ."$coptions{offsetupperbound}");
            $owindow = 0;
        }
 	$searchmode = 1 unless defined $searchmode;
    }

#------------------------------------------------------------------------------
# ** here starts the real work **
#
#    sample correlation hash 
#------------------------------------------------------------------------------

    my $correlationhash = {};

    $logger->fine("Sampling correlation hash");
   
    if ($banding || ($owindow && !$searchmode)) {

# determine the correlation hash by sampling under the constraints on either
# offset (but un-banded search) or a moving position window (banded search)

        $correlationhash = &sampleCorrelationHash($tkmerhash,$skmerhash,undef,
                                                  reverse=>$reverse,%coptions);
    }
    else {

# determine sample offset values (full scan) for the forward and reverse cases

        my %soptions = (offsetcount => 1);

        if ($banding || $owindow) {
            foreach my $key (keys %coptions) {
                $soptions{$key} = $coptions{$key};
	    }
	}
        else {
# unrestricted global search requires special treatment for abundant kmers
            $soptions{guillotine} = 1; 
	}

# collate the index counts for coincident k-mers in template and sequence, forward

# these control params to be replaced/removed by better findpeak algorithm
           my $threshold = $options{threshold} || 0;
  	   $options{repeat} = 10 unless defined $options{repeat};
           my $repeat = $options{repeat}; # iteration counter

        my $fcount = 0;
        my $foffsets = [];
        if ($coaligned >= 0) {
# co-aligned (forward alignment) case
$logger->info("Building co-aligned correlation hash");
            my $forwardhash = &sampleCorrelationHash($tkmerhash,$skmerhash,undef,
                                                     reverse=>0,%soptions);
# analyse the distribution of forward counts

$logger->info("Analysing distribution (TO BE REFINED)");
# NOTE: it is not clear if a threshold preselection is usefull, perhaps the actual
# determination of the alignment segments provides a better test for significance
           ($foffsets,$fcount) = &findpeak($forwardhash,$threshold,$peakdrift,$repeat);
$logger->fine("offset $foffsets count $fcount");
            foreach my $offset (@$foffsets) {
                $offset->[3] = 0; # forward
$logger->fine("foffset: @$offset");
            } 
        }

# collate the index counts for coincident k-mers in template and sequence, reverse

        my $rcount = 0;
        my $roffsets = [];
        if ($coaligned <= 0) {
# counter-aligned (reverse compliment alignment) case
            $soptions{reverse} = 1;
$logger->debug("Building reverse correlation hash");
&printoptions('soptions',%soptions);
            my $reversehash = &buildCorrelationHash($tkmerhash,$skmerhash,%soptions);
#            my $reversehash = &sampleCorrelationHash($tkmerhash,$skmerhash,undef,
#                                                     reverse=>1,%soptions);
# analyse the distribution of reverse counts
$logger->debug("Analysing distribution");
           ($roffsets,$rcount) = &findpeak($reversehash,$threshold,$peakdrift,$repeat);
$logger->debug("offset $roffsets count $rcount"); 
            foreach my $offset (@$roffsets) {
                $offset->[3] = 1; # reverse
$logger->info("roffset: @$offset");
            } 
        }

# test both results against eachother & determine the "best" offsets

        my $count;
        my @offsets;
        if ($monotonous && $fcount > $rcount) {
            @offsets = @$foffsets;
            $count = $fcount;
	}
        elsif ($monotonous && $fcount < $rcount) {
            @offsets = @$roffsets;
            $count = $rcount;
	}
	elsif (!$monotonous) {
            @offsets = @$foffsets;
            push @offsets, @$roffsets;
            $count = $fcount + $rcount;
	}
	else {
            $logger->error("ambiguous correlation result: alignment undetermined");
            return undef;
        }

        return undef unless ($count && $count >= $threshold);

# here an offset value, or list of offset values is determined, now build 

        foreach my $offset (@offsets) {
 $logger->fine("testing offset: @$offset");
            my %coptions = (reverse => $offset->[3]);
            $coptions{offsetlowerbound} = $offset->[0];
            $coptions{offsetupperbound} = $offset->[1];
            $correlationhash = &sampleCorrelationHash($tkmerhash,$skmerhash,
                                                    $correlationhash,%coptions);
        }
    }

#------------------------------------------------------------------------------
#  analyze the correlation hash
#------------------------------------------------------------------------------
 
# build a list of segments, contiguous runs of matches in $template and $sequence

    $options{minimumsegmentsize} = $mrss unless defined $options{minimumsegmentsize};
    my $mss = $options{minimumsegmentsize} - ($kmersize-1); # adjust for endregion extension 

    $logger->info("Getting initial set of alignment segments (mss = $mss)");

delete $options{threshold};
    my $segments = &getAlignmentSegments($correlationhash,minimumsegmentsize=>$mss,
                                                     threshold=>$options{threshold}); # raw scan

    &diagnose($correlationhash,$segments) if ($options{diagnose});

#-----------------------------------------------------------------------------------------
#  extend the segments to full size by adding half kmersize at the end 
#-----------------------------------------------------------------------------------------

$logger->info("Extend alignment segments");
    &extendSegments($segments,$kmersize,$reverse);

#-----------------------------------------------------------------------------------------
# prune the segments found
#-----------------------------------------------------------------------------------------
            
    my %ceasoptions = (reverse => $reverse);
    my %cosoptions  = (reverse => $reverse);

    $options{autoclip} = 1 unless defined($options{autoclip}); # default

    my $overlap = 0;
    if ($options{autoclip}) {
# determine the minimum acceptable length for an interval
        my $minimumsegmentsize = $options{autoclip} * $mrss; # starting value

        while ($minimumsegmentsize) {
$logger->info("number of segments ".scalar(@$segments),skip=>1);
$logger->info("minimum segment-length required: $minimumsegmentsize");

            $mss = int($minimumsegmentsize+0.5);
            my $removed = &cleanupEmbeddedAndShortSegments($segments,reverse=>$reverse,
                                                            minimumsegmentsize=>$mss);

$logger = &verifyLogger('after cleanupEmbeddedAndShortSegments');  
$logger->info("$removed segments removed with cleanup");
$logger->info(&listSegments($segments,"minimized selection"));

            $overlap = &cleanupOverlappingSegments($segments,reverse=>$reverse);
$logger->info("$overlap overlapping segments"); 
            unless ($overlap && @$segments > 2 && $minimumsegmentsize < $templatelength/3) {
                $minimumsegmentsize /= 2;
                last;
	    }
# there are overlapping segments, try an increased minimumlength
            $minimumsegmentsize *= 1.1;
        }
    }
    else {
# no selection on minimum length, cleanup and remove overlapping 
        my $removed = &cleanupEmbeddedAndShortSegments($segments,reverse=>$reverse);
$logger->fine("$removed segments removed on initial cleanup");
        $overlap = &cleanupOverlappingSegments($segments,reverse=>$reverse);
$logger->fine("$overlap overlapping segments"); 
    }

    $logger->info(&listSegments($segments,"segment minimized selection")) if $options{diagnose};

#-----------------------------------------------------------------------------------------
# filter segments to remove discordant ones and add half a kmer size at either end
#-----------------------------------------------------------------------------------------

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;
    
#    $options{filteroffsets} = 1 unless defined $options{filteroffsets}; # default

    &filterOffsets($segments) if $options{filteroffsets};


# remove redundent segments and test the segments for overlap

#    unless ($options{fullrange}) {
# do a detailed analysis to find the best series of non-overlapping segments 
#        my %gpoptions = (reverse => $reverse, extend => 0);
#        $gpoptions{tquality} = $options{tquality} if $options{tquality};
#        $gpoptions{squality} = $options{squality} if $options{squality};
#      $gpoptions{template} = $template; # temp
#      $gpoptions{sequence} = $sequence; # temp
#$logger->debug("Cleanup/Shrink alignment segments");
#        &goldenPath($segments,%gpoptions);# may be redundent?
#    }

# iterate to fill the gaps

    my @offsets = sort {$a <=> $b} keys %$correlationhash;
    my $offsetlowerbound = $offsets[0] - $peakdrift; # default setting;
    my $offsetupperbound = $offsets[$#offsets] + $peakdrift; # default setting;
 

$options{iterate}  = 9;
    $options{iterate}  = 1 unless defined($options{iterate}); # default
    my $iterate = $options{iterate};

$logger->info("iterate = $iterate  olb:$offsetlowerbound  oub:$offsetupperbound");

    $options{minimumsegmentsize} = 1 unless defined $options{minimumsegmentsize}; # ?

    my $minimum = $options{minimum} || 5; # starting value

    my %cuosoptions = (reverse => $reverse, extend => 0);
    $cuosoptions{tquality} = $options{tquality} if $options{tquality};
    $cuosoptions{squality} = $options{squality} if $options{squality};

    while ($iterate && $kmersize > $iterate || $minimum >= $options{minimumsegmentsize}) {
# determine gaps
        my $gaps = &gapSegments($segments,$reverse,[@borders]);

        $kmersize -= 2 if ($kmersize > 2); # decrease 

        $peakdrift = $kmersize - 1 if ($kmersize <= $peakdrift);

$logger->info("Doing kmersize $kmersize on ".scalar(@$gaps)." gaps; drift $peakdrift",ss=>1);

        foreach my $gap (@$gaps) {
            $logger->info("t-gap : $gap->[0] - $gap->[1] , s-gap : $gap->[2] - $gap->[3]");
# build the hashes, using only the data in the interval
            $tkmerhash = &buildKmerHash($template,$kmersize,$gap->[0],$gap->[1]);
# NOTE: inverted case requires [3],[2] TO BE TESTED
            my $j = $reverse ? 3 : 2; 
            $skmerhash = &buildKmerHash($sequence,$kmersize,$gap->[$j],$gap->[5-$j]);
# determine  offset ranges (from surrounding intervals)
            my @offsets;
            foreach my $i (0,1) {
                $offsets[$i]  = $gap->[$i];
                $offsets[$i] -= $gap->[$i+2] unless $reverse;
                $offsets[$i] += $gap->[3-$i] if $reverse;
	    }
            @offsets = sort {$a <=> $b} @offsets;
            my $toffset = ($offsets[0] + $offsets[1])/2; # nominal target
            if (($offsets[1] - $offsets[0]) > $kmersize) { # extend range for this gaps
                $offsets[0] -= $kmersize;
                $offsets[1] += $kmersize;
            }
            $offsets[0] = $offsetlowerbound if ($offsets[0] < $offsetlowerbound);
            $offsets[1] = $offsetupperbound if ($offsets[1] > $offsetupperbound);
# widen the offset range if it's too small
            if ($kmersize > 3 || ($offsets[1] - $offsets[0]) <= 1) {
                $offsets[0]--;
                $offsets[1]++;
	    }
$logger->info("kmer $kmersize;  gap @$gap;   offsets @offsets");

# we do an un-banded search because it's a very limited search domain

            my %roptions = (reverse=>$reverse,
                            offsetlowerbound=>$offsets[0], 
                            offsetupperbound=>$offsets[1]); 
            my $shash = &sampleCorrelationHash($tkmerhash,$skmerhash,undef,%roptions);
$logger->info("No segments found") unless $shash;
            next unless $shash;
# NOTE : here add a search using the reverse complement

# add new segments to the existing segments

            my $newsegments = &getAlignmentSegments($shash,minimumlength=>$minimum);
$logger->info(scalar(@$newsegments)." segments found for minimumlength $minimum");


            if (@$newsegments) {
#$logger->info(&listSegments($newsegments,"before extend"));
                &extendSegments($newsegments,$kmersize,$reverse);
#$logger->info(&listSegments($newsegments,"before cleanup"));
                my %ceasoptions = (reverse => $reverse, targetoffset => $toffset);
                my $removed = &cleanupEmbeddedAndShortSegments($newsegments,%ceasoptions);
$logger->info("$removed segments removed with gap cleanup",skip=>1);
$logger->info(&listSegments($newsegments,"after cleanup"));

                my $overlap = &cleanupOverlappingSegments($newsegments,%cuosoptions);
                push @$segments,@$newsegments;
            }
            @$segments = sort {$a->[0] <=> $b->[0]} @$segments;
        }
        $minimum = int($minimum/2);
        $minimum = 1 unless $minimum;
    }

# do a final cleanup, just in case (no gap determination)

#$logger->info(&listSegments($segments,"final raw segment ")) if $options{diagnose};

#    &cleanupEmbeddedAndShortSegments($segments,%soptions);

#$logger->info(&listSegments($segments,"final cleaned segment ")) if $options{diagnose};

    my %moptions = (lowqsymbol => 'NX\*\-', window => 1);
    $moptions{lqextend} = $options{lqextend} if defined $options{lqextend}; # default 'NX\*\-'
    $moptions{lqsymbol} = $options{lqsymbol} if defined $options{lqsymbol}; # default 1   
    &mergeSegments($segments,$reverse,$template,$sequence,%moptions);
    
$logger->info(&listSegments($segments,"final merged segment ")) if $options{diagnose};

# and analyze remaining gaps
        
    my $gaps = &gapSegments($segments,$reverse,[@borders]);
$logger->info(scalar(@$gaps)." gaps found"); 

# export the segments as a Mapping

    my $mapping = new Mapping();

# define a mapping name outside this method

    foreach my $segment (sort {$a->[0] <=> $b->[0]} @$segments) {
        unless ($mapping->putSegment(@$segment)) {
            print STDERR "Alignment->correlate: INVALID segment @$segment\n";
	}
    }

    $mapping->normalise();

    return $mapping;
}
    
#--------------------------------------------------------------------------
# public methods to inspect k-mer hashes
#--------------------------------------------------------------------------

sub listKmerHash {
# takes a hash generated by 'buildKmerHash' and prints it out
    my $class = shift;
    my $kmerhash = shift;
    my %options = @_;

    return "Unrecognized kmerhash" unless &verifyKmerHash($kmerhash);

    my $identifier = $kmerhash->{name} || $kmerhash->{identity};

    my $listing = "k-mer counts for k-mer hash $identifier\n"
                . "k-mer size = $kmerhash->{kmersize}\n"
                . "number     = $kmerhash->{kmercount}  (different k-mers)\n"
                . "total      = $kmerhash->{kmertotal}  (accepted  k-mers)\n"
		. "rejected   = $kmerhash->{kmereject}\n\n";

    return $listing if $options{short}; # short list option

    my $kmerdata = $kmerhash->{kmers};

    $listing .= "position distibution : \n\n";
    foreach my $kmer (sort keys %$kmerdata) {
        my $positions = $kmerdata->{$kmer};
        $listing .= "$kmer @$positions\n";
    }

    return $listing;
}


sub getKmerHash {
# public method, returns k-mer hash
    my $class = shift;
    my $sequence = shift;
    my %options = @_;

# options: kmersize    ( >=1 , default 7 )
#          lower       (starting point in sequence; default 1)
#          upper       (end point in sequence; default length of sequence)

# get the kmersize; ensure an odd number

    my $kmersize = $options{kmersize} || 7;
    $kmersize = 7 unless ($kmersize > 0);
    my $halfsize = int(($kmersize-1)/2 + 0.5);
    $kmersize = $halfsize * 2 + 1;

# get the boundaries for the data to be hashed

    my $l = length($sequence);
    my $start = ($options{lower} && $options{lower} >  1) ? $options{lower} : 1;
    my $final = ($options{upper} && $options{upper} < $l) ? $options{upper} : $l;

# build the hash

    return &buildKmerHash(uc($sequence),$kmersize,$start,$final,$options{name});
}
    
#--------------------------------------------------------------------------
# private methods producing k-mer hashes
#--------------------------------------------------------------------------

sub buildKmerHash {
# build and return a k-mer hash structure
    my $sequence = shift || return undef;
    my $kmersize = shift || 7;
    my $start = shift || 1;
    my $final = shift || length($sequence);
    my $name = shift; # optional

    &verifyPrivate($sequence,'buildKmerHash');

# check the boundaries

    return 0 if ($start > $final - $kmersize + 1);

# ok, build the hash (a multidimensional hash of arrays, keyed on kmer)

    my $kmerhash = {};

# generate an identifier

    my $random = int(rand 1000); # random integer between 0 and 999
    $kmerhash->{identity} = 'Correlate::buildKmerHash-'.sprintf "%04d",$random;

# store the build parameters

    $kmerhash->{kmersize} = $kmersize;
    $kmerhash->{sequencestart} = $start;
    $kmerhash->{sequencefinal} = $final;
    $kmerhash->{name} = $name if $name;

# allocate space for the hash itself

    $kmerhash->{kmers} = {};
    my $kmerdata = $kmerhash->{kmers};

# run through the sequence and collect the centre positions of the k-mers

    my $ktotal = 0;
    my $reject = 0;
    my $halfsize = int($kmersize/2);

    for my $i ($start .. $final) {
        last if ($i > $final - $kmersize + 1);
# the counter ($i) is the number of the base in the read starting with 1
        my $kmer = substr $sequence, $i-1, $kmersize;
        if ($kmer =~ /[^ACGT]/) {
            $reject++;
            next;
        }
        $kmerdata->{$kmer} = [] unless defined $kmerdata->{$kmer};
        push @{$kmerdata->{$kmer}}, ($i+$halfsize);
        $ktotal++;
    }

# store the reporting parameters

    $kmerhash->{kmercount} = scalar(keys %$kmerdata); # nr. of different kmers
    $kmerhash->{kmertotal} = $ktotal; # total number of accepted kmers
    $kmerhash->{kmereject} = $reject;

    return $kmerhash;
}

sub verifyKmerHash {
# return 1 if the hash has the signature of one created by the method above
    my $kmerhash = shift;

    &verifyPrivate($kmerhash,'verifyKmerHash');

    return 0 unless (ref($kmerhash) eq 'HASH');

    return 0 unless ($kmerhash->{identity} =~ /Correlate\:\:buildKmerHash/);

    return 0 unless (ref($kmerhash->{kmers}) eq 'HASH');

    return 0 unless ($kmerhash->{kmercount} > 0);

    return 1;
}

#-------------------------------------------------------------------------------
# private methods for analyzing k-mer hashes
#-------------------------------------------------------------------------------

sub buildCorrelationHash {
# return correlation counts keyed on position offset
    my $thiskmerhash = shift; # kmer counts keyed on position
    my $thatkmerhash = shift; # kmer counts keyed on position
    my %options = @_;

    &verifyPrivate($thiskmerhash,'buildCorrelationHash');

    my $logger = &verifyLogger('buildCorrelationHash');
$logger->debug("ENTER opts: @_");

    my $reverse = $options{reverse} || 0;
    my $wbanded = $options{window}; # has to be defined for banded matching
    my $lbanded = $options{linear} || 1.0;
    my $obanded = $options{offset} || 0.0;
# test input arguments
    if ($wbanded && ($lbanded > 0 && $reverse || $lbanded < 0 && !$reverse)) {
        print STDERR "Incompatible parameter values in 'buildCorrelationHash'\n";
	return undef;
    }

# prescription for the offset window

    my ($owindow,$offsetlowerbound,$offsetupperbound);
    if (defined($options{offsetlowerbound}) || defined($options{offsetupperbound})) { 
        $offsetlowerbound = $options{offsetlowerbound} || 0;
        $offsetupperbound = $options{offsetupperbound} || 0;
        $owindow = 1;
    }

    my $thiskmerdata = $thiskmerhash->{kmers};
    my $thatkmerdata = $thatkmerhash->{kmers};

# cross-match the two k-mer hashes to get the correlation hash

    my $line = 0; 
    my $size = scalar(keys %$thiskmerdata);
    my $hashcount = {};
    foreach my $key (keys %$thiskmerdata) {

# get the kmer to be used in both hashes

        my $kmer = $key; # the forward case
        if ($reverse) {
# build the inverse look-up hash on the fly
            $kmer = $inverse{$key};
            unless (defined $kmer) {
                $kmer = &complement($key);
                $inverse{$key} = $kmer;
	    }
        } 

# find matching kmers in the test read; the reverse case
        
        my ($positionlowerbound,$positionupperbound);
        if (my $match = $thatkmerdata->{$kmer}) {
            my $local = $thiskmerdata->{$key};
# test number of trials; test if very large numbers
            my $trials = scalar(@$match) * scalar(@$local);
            if ($trials > 1000000 && $options{guillotine}) {
                $logger->info("$trials trials for kmers $kmer (".scalar(@$match)
                                                 .") and $key (".scalar(@$local).")");
                my $remk = &reverse($kmer);
		next if ($kmer eq $remk); # palidromic kmer
		$logger->info("accepted: '$kmer'  vs '$remk'");
            }  
            foreach my $thisposition (@$local) {
# for banded search, define upper and lower bounds
                if ($wbanded) {
                    $positionlowerbound = $thisposition * $lbanded + $obanded;
                    $positionupperbound = $positionlowerbound + $wbanded;
                    $positionlowerbound -= $wbanded;
                }
                foreach my $thatposition (@$match) {
                    if ($wbanded) {
                        next if ($thatposition < $positionlowerbound);
                        next if ($thatposition > $positionupperbound);
		    }
                    my $offset = $thisposition;
                    $offset -= $thatposition unless $reverse;
                    $offset += $thatposition if $reverse;

# apply possible filter to offset

                    if ($owindow) {
                        next if ($offset < $offsetlowerbound);
                        next if ($offset > $offsetupperbound); # offset not ordered
		    }
                    $hashcount->{$offset}++;
		}
	    }
	}
        next if (($line++)%10000);
        $logger->fine("processing ".sprintf("%4.2f",($line/$size))." fraction"); 
   }

    return $hashcount;
}

sub sampleCorrelationHash {
# returns position correspondences as a hash keyed on postion of this read
    my $thiskmerhash = shift || return undef; # kmer counts keyed on position
    my $thatkmerhash = shift || return undef; # kmer counts keyed on position
    my $correlationhash = shift; # optional, can be undef
    my %options = @_;

    &verifyPrivate($thiskmerhash,'sampleCorrelationHash');

    my $logger = &verifyLogger('sampleCorrelationHash');

$logger->fine("sampleCorrelationHash ENTER opts: @_");

#  test control parameters

    my $reverse = $options{reverse} || 0;
    my $ocounts = $options{offsetcount}; # count offset, else sample position matches

# banding prescription with linear relation describing expected matching

    my $bwindow = $options{window}; # has to be defined for banded matching
    my $blinear = $options{linear} || 1.0; # linear coefficient of banded relation
    my $boffset = $options{offset} || 0.0; # linear coefficient of banded relation
# test input arguments
    if ($blinear > 0 && $reverse || $blinear < 0 && !$reverse) {
        $logger->error("incompatible parameter values : lbanded $blinear  reverse $reverse");
	return undef;
    }

# banding prescription for the offset window

    my ($owindow,$offsetlowerbound,$offsetupperbound);
    if (defined($options{offsetlowerbound}) || defined($options{offsetupperbound})) { 
        $offsetlowerbound = $options{offsetlowerbound} || 0;
        $offsetupperbound = $options{offsetupperbound} || 0;
        $owindow = 1;
    }

    my $nowarning = $options{nowarning};

# get the k-mer hashes

    my $thiskmerdata = $thiskmerhash->{kmers} || return undef;
    my $thatkmerdata = $thatkmerhash->{kmers} || return undef;

# cross-match the two k-mer hashes

my $list = 0;
$logger->fine("correlate kmer hashes ($list) ") if $list;

    $correlationhash = {} unless (ref($correlationhash) eq 'HASH');

    my $line = 0; 
    my $size = scalar(keys %$thiskmerdata);
    foreach my $key (keys %$thiskmerdata) {

# get the k-mer corresponding to $key

        my $kmer = $reverse ? $inverse{$key} : $key;
        unless (defined($kmer)) {
# this should not occur (inverse hash was built earlier in buildCorrelationHash
            unless ($nowarning) {
                $logger->error("Unexpected undefined inverse hash element for $key");
                next;
            }
            $kmer = &complement($key);
            $inverse{$key} = $kmer;
        }

# sample matching kmers in the test read, using the offset window

        my ($positionlowerbound,$positionupperbound);

        if (my $match = $thatkmerdata->{$kmer}) {
            my $local = $thiskmerdata->{$key };
# test number of potential trials, possibly applying a guillotine to abundant kmers
            my $trials = scalar(@$match) * scalar(@$local);
            if ($trials > 1000000 && $options{guillotine}) {
                $logger->fine("$trials trials for kmers $kmer (".scalar(@$match)
                                                 .") and $key (".scalar(@$local).")");
                my $remk = &reverse($kmer);
		next if ($kmer eq $remk); # palidromic kmer
		$logger->fine("accepted: '$kmer'  vs '$remk'");
            }  
# collate all combinations of positions in this and read 
            my $jstart = 0;
            foreach my $thisposition (@$local) {

# for banded sampling on a linear relation, define upper and lower bounds

                if ($bwindow) {
                    $positionlowerbound = $thisposition * $blinear - $boffset;
# ? $positionlowerbound = ($thisposition + $boffset) * $blinear; # ??
                    $positionupperbound = $positionlowerbound + $bwindow;
                    $positionlowerbound -= $bwindow;
$logger->info("local boundaries: $positionlowerbound $positionupperbound ($thisposition)") if $list;
                }

                undef my $jfirst;
		for (my $j = $jstart ; $j < @$match ; $j++) {
                    my $thatposition = $match->[$j];
# for banded sampling, apply filter to positions
                    if ($bwindow) {
$logger->fine("(banded) matched testposition $thatposition") if $list;
                        next if ($thatposition < $positionlowerbound);
                        last if ($thatposition > $positionupperbound); # check for reverse case!
#                        next if ($thatposition > $positionupperbound);
		    }
                    my $offset = $thisposition;
                    $offset -= $thatposition unless $reverse;
                    $offset += $thatposition if $reverse;

# apply possible filter to offset

                    if ($owindow && $reverse) {
# the counter-aligned case, increasing offset
                        next if ($offset < $offsetlowerbound);
                        last if ($offset > $offsetupperbound);
		    }
                    elsif ($owindow) {
# the co-aligned case, decreasing offset
                        last if ($offset < $offsetlowerbound);
                        next if ($offset > $offsetupperbound);
		    }

$logger->fine("accepted, offset $offset") if $list; $list-- if $list;

# register first hit (used in banded or filtered search

                    $jfirst = $j unless defined($jfirst);

# get offset count, or sample the matching positions in hash element keyed on offset

                    if ($ocounts) {
			$correlationhash->{$offset}++;
                        next;
		    }

                    my $segmenthash = $correlationhash->{$offset};
                    unless (defined($segmenthash)) {
                        $correlationhash->{$offset} = {}; # autovivify
                        $segmenthash = $correlationhash->{$offset};
                    }
                    if ($segmenthash->{$thisposition}) {
# this test could be part of subsequent segment analysis
                        $logger->error("DUPLICATE correlationhash element!!");
                    }
                    $segmenthash->{$thisposition} = $thatposition;
		}
# for banded search (either explicit with banded or implicit on offset) adjust starting point
                $jstart = $jfirst if (defined($jfirst) && ($bwindow || $owindow));
	    }
	}
        next if (($line++)%10000);
        $logger->fine("processing ".sprintf("%4.2f",($line/$size))." fraction");
    }

    return $correlationhash;
}

#--------------------------------------------------------------------------------
# private methods dealing with alignment segments
#--------------------------------------------------------------------------------

sub getAlignmentSegments {
# helper method for 'correlate': return a list of alignment segments
    my $correlationhash = shift;
    my %options = @_;

# a segment consists of contiguous matching positions without constraints
# on the boundaries; however, a minimum length can be specified 

    &verifyPrivate($correlationhash,'getAlignmentSegments');

    my $logger = &verifyLogger('getAlignmentSegments');

    my $minimumlength = $options{minimumsegmentsize} || 1;

    my @offsets = sort {$a <=> $b} keys %$correlationhash;
    my $lio = $#offsets; # last @offsets index

    my $maxoffset;
    my $offsetcount = {};
    foreach my $offset (@offsets) {
	my $segmenthash = $correlationhash->{$offset};
        $offsetcount->{$offset} = scalar(keys %$segmenthash);
        $maxoffset = $offset unless defined $maxoffset;
        $maxoffset = $offset if ($offsetcount->{$offset} > $offsetcount->{$maxoffset});
    }

    my $segments = [];

    unless (defined($maxoffset)) {
        $logger->info("getAlignmentSegments: empty correlation hash");
	return $segments;
    }

    my $threshold = $offsetcount->{$maxoffset}/20;  
    $threshold = $options{threshold} if defined $options{threshold};
    $logger->info("largest count $offsetcount->{$maxoffset} for offset $maxoffset"); 
    $logger->info("offset range sampled : $offsets[0] - $offsets[$lio];  threshold $threshold");

# collect all peaks in offset distribution above threshold
    
    $logger->fine("offsets to be investigated: @offsets");

    foreach my $offset (@offsets) {
# ignore counts below the threshold
        next unless ($offsetcount->{$offset} && $offsetcount->{$offset} >= $threshold);
        $logger->fine("sampling offset $offset: counts $offsetcount->{$offset} ($threshold)");

        undef my $segment; # for alignment segment
        my $segmenthash = $correlationhash->{$offset};

# run through positions and record the uninterrupted sequences

        my @positions = sort {$a <=> $b} keys %$segmenthash;

        next if (scalar(@positions) < $minimumlength);

        my $segmentsize = 0;
        foreach my $position (@positions) {
# if there is a discontinuity: complete previous segment and initiate a new one
            if (defined($segment) && $position > ($segment->[1]+1)) {
                push @$segments,$segment if ($segmentsize >= $minimumlength);
                undef $segment; # initiate a new alignment segment
            }
# on starting a new interval (undefined segment)
            unless (defined $segment) {
                $segment = []; # initiate an array
                $segment->[0] = $position; # start on this
                $segment->[2] = $segmenthash->{$position}; # start on read
            }
            $segment->[1] = $position; # final on this
            $segment->[3] = $segmenthash->{$position}; # final on read     
            $segmentsize = $segment->[1] - $segment->[0] + 1;
        }
        if (defined($segment)) {
            push @$segments,$segment if ($segmentsize >= $minimumlength);
	}
        $logger->fine(scalar(@$segments)." segments collected after offset $offset");
    }

# return an array of segment mappings (4 numbers each)

    return $segments;
}

sub extendSegments {
# helper method for 'correlate': add half the kmes size at either end of segments
    my $segments = shift;
    my $kmersize = shift;
    my $inverted = shift;

    &verifyPrivate($segments,'extendSegments');

    my $extend = int(($kmersize-1)/2 + 0.1);
    return unless ($extend > 0);

    $extend = -$extend if $inverted;

    foreach my $segment (@$segments) {
        $segment->[0] = $segment->[0] - abs($extend);
        $segment->[1] = $segment->[1] + abs($extend);
        $segment->[2] = $segment->[2] - $extend;
        $segment->[3] = $segment->[3] + $extend;
    }
}

sub cleanupEmbeddedAndShortSegments {
# helper method: remove segments which are completely embedded in others
    my $segments = shift;
    my %options = @_;

    &verifyPrivate($segments,'cleanupEmbeddedAndShortSegments');

    my $reverse = $options{reverse} || 0;

    my $minimum = $options{minimumsegmentsize} || 0;

# order the segments with start position

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

# collect segments that need to be removed because they fall inside another one

    my %remove;
    my $ns = scalar(@$segments);
    for (my $i = 0 ; $i < $ns ; $i++) {
        my $si = $segments->[$i];
        my $li = abs($si->[1] - $si->[0]) + 1;
	$remove{$i}++ if ($minimum && $li < $minimum);
        next if $remove{$i};
        for (my $j = 0 ; $j < $ns ; $j++) {
            next if ($j == $i);
            my $sj = $segments->[$j];
            my $lj = abs($sj->[1] - $sj->[0]) + 1;
  	    $remove{$j}++ if ($minimum && $lj < $minimum);
            next if $remove{$j};
# optionally skip embedded test
            next if $options{minimumonly};
# test if segment j is inside segment i 
            my $isembedded = 0;
            if ($si->[0] <= $sj->[0] && $si->[1] >= $sj->[1]) {
                $isembedded = 1;
	    }
# test if segment j is inside segment i on the matching read
            elsif ( $reverse && $si->[2] >= $sj->[2] && $si->[3] <= $sj->[3]) {
                $isembedded = 1;
	    }
            elsif (!$reverse && $si->[2] <= $sj->[2] && $si->[3] >= $sj->[3]) {
                $isembedded = 1;
	    }
# if segment j is embedded in segment i decide if i or j or both have to be deleted
            if ($isembedded) {
                unless ($li == $lj) {
# segment j is the smaller one and is deleted
                    $remove{$j}++;
                    next; # next $j for same $i
		}
# the segments are of equal length
                unless ($options{targetoffset}) {
                    $remove{$j}++;
                    $remove{$i}++;
                    last; # next $i
                }
# delete whichever segment has the most discreapant offset
                my $toffset = $options{targetoffset};
                my $ioffset = abs( ($si->[0] - $si->[2]) - $toffset);
                my $joffset = abs( ($sj->[0] - $sj->[2]) - $toffset);
                $remove{$i}++ if ($ioffset >= $joffset);
                $remove{$j}++ if ($ioffset <= $joffset);
                last if ($ioffset == $joffset); # next $i
                next; #  try next $j for same $i
	    }
# $i and $j are disjunct
            next if ($sj->[0] <= $si->[1]); # this segment may mask the next
            last; # intervals $i and $j are disconnected: next $i
        }
    }

    my $removed = scalar(keys %remove);

    return 0 unless $removed;

    foreach my $j (sort {$b <=> $a} keys %remove) { # reverse order!
        splice @$segments, $j, 1;
    }

    return $removed;
}

sub filterOffsets {
# filter segment offsets with a median filter, to weed out widely discordant segments
    my $segments = shift;
    my %options = @_; # medianwindow => ...  threshold => ...  list => ...

    &verifyPrivate($segments,'filterOffsets');

    my $logger = &verifyLogger('filterOffsets');

# build a scratch table of offset versus segment position

    my $alignmenthash = {};

    foreach my $segmentdata (@$segments) {
        my $segment = new Segment(@$segmentdata,0); # dummy identifier
        my $alignment = $segment->getAlignment();
        $alignmenthash->{$alignment} = {} unless defined $alignmenthash->{$alignment};
        my $alignmentdata = $alignmenthash->{$alignment};
        $alignmentdata->{offset} = [] unless defined $alignmentdata->{offset};
        $alignmentdata->{posits} = [] unless defined $alignmentdata->{posits};
        my $offset = $alignmentdata->{offset}; # array reference
        push @$offset, $segment->getOffset();
        my $posits = $alignmentdata->{posits};
        push @$posits, ($segment->getXstart() + $segment->getXfinis())/2;
    }

    $options{medianwindow} = 5 unless defined $options{medianwindow}; 
    my $window = $options{medianwindow};
    $options{threshold} = 10 unless defined $options{threshold};
    my $threshold = $options{threshold};

    my $deleted = 0;
    foreach my $alignment (keys %$alignmenthash) {
        my $offset = $alignmenthash->{$alignment}->{offset}; # array ref
        my $posits = $alignmenthash->{$alignment}->{posits}; # array ref
        my $deviationhash = {};
        my $delete = []; # list of elements to be removed
        my $m = scalar(@$offset) - 1;
        for (my $i = 0 ; $i < @$offset ; $i++) {
            my $js = $i - $window; $js = 0  if ($js < 0);
            my $jf = $i + $window; $jf = $m if ($jf > $m);
            my @slice = sort {$a <=> $b} @$offset[$js .. $jf];
            my $reference = $slice[int(($jf-$js)/2 + 0.5)];
            my $deviation = abs(int($reference - $offset->[$i]));
            if ($deviation > $threshold) {
                push @$delete, $i if ($deviation > $threshold);
                $deviationhash->{$deviation}++;
            }
	}

        if ($options{list}) {
            $logger->info("DH deviation hash");
            foreach my $deviation (sort {$a <=> $b} keys %$deviationhash) {
                $logger->info("DH $deviation $deviationhash->{$deviation}");
	    }
	}

        @$delete = sort {$b <=> $a} @$delete; # reverse order

        foreach my $delete (@$delete) {
            splice @$segments,$delete,1;
	    $deleted++;
        }
    }

# warning section for badly conditioned input

    if (scalar(keys %$alignmenthash) > 1) {
        $logger->error("Multiple alignment directions found:");
        foreach my $alignment (sort {$a <=> $b} keys %$alignmenthash) {
            my $counts = scalar(@{$alignmenthash->{$alignment}});
            $logger->error("alignment direction $alignment : counted $counts");
	}
    }

    return $deleted,$alignmenthash;   
}

sub cleanupOverlappingSegments {
# helper method for 'correlate': clip ends of segments if they overlap
    my $segments = shift;
    my %options = @_;

    &verifyPrivate($segments,'cleanupOverlappingSegments');

    my $logger = &verifyLogger('cleanupOverlappingSegments');

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

    my $ns = scalar(@$segments);

# NOTE: REVERSE case still to be tested

    my $reverse = $options{reverse};

    my $ts = $options{tsequence} || '';
    my $tq = $options{tquality};
    $tq = 0 unless ($tq && @$tq);
    my $ss = $options{ssequence} || '';
    my $sq = $options{squality}; 
    $sq = 0 unless ($sq && @$sq);

    my $overlapcount = 0;

$logger->debug("SS looking for overlapping segments");

    my ($soverlap,$toverlap);
    for (my $i = 0 ; $i < $ns-1 ; $i++) {
# get the (possible) overlap between successive segments
        $toverlap = $segments->[$i]->[1] - $segments->[$i+1]->[0] + 1;
        $soverlap = $segments->[$i]->[3] - $segments->[$i+1]->[2] + 1 unless $reverse;
        $soverlap = $segments->[$i+1]->[2] - $segments->[$i]->[3] + 1 if $reverse;
        next unless ($toverlap > 0 || $soverlap > 0);
$logger->info("SS regular overlap $toverlap $soverlap");
$logger->info("SS regular overlap @{$segments->[$i]} : @{$segments->[$i+1]}");
        $overlapcount++;
# find the domain with the largest overlap
        my $overlap = ($toverlap >= $soverlap) ? $toverlap : $soverlap;
# define a default break point as the centre of the overlap
        my $shrink = int(($overlap+1)/2);
        my $rhshrink = $shrink; # right hand 
        my $lhshrink = $shrink; # left hand
$logger->info("SS shrinking segments by $shrink");

# do a quality scan if overlap > 1 and at least on quality data set is available

        if ($overlap > 1 && ($tq || $sq)) {
# at least one set of quality data is specified: use lowest quality as breaking point
# TO BE TESTED
#$logger->info("quality to be taken into account; overlap $overlap");
	    my $lsegment = new Segment(@{$segments->[$i]}); # segment on left
	    my $rsegment = new Segment(@{$segments->[$i+1]}); # segment on right

            my $k = ($toverlap >= $soverlap) ? 0 : 2; # k=0 if t domain overlap largest

            my $ls = $segments->[$i+1]->[$k]; # start of largest overlap
            my $lf = $segments->[$i]->[$k+1]; #  end  of largest overlap

            my ($pq,$cq) = ($tq,$sq); # change from template-sequence to primary-complement
	   ($pq,$cq) = ($sq,$tq) if $k; # the largest gap is on sequence


            my @quality; # scratch array for quality estimators in overlap area
            for (my $i = $ls ; $i <= $lf ; $i++) {
 
                my ($cil,$cir); # complements on left and right
                $cil = $lsegment->getXforY($i) unless $k;
                $cir = $lsegment->getYforX($i) if $k;
                $cir = $rsegment->getXforY($i) unless $k;
                $cil = $rsegment->getYforX($i) if $k;

# get combined quality as the largest of two measures
 
                my $lquality = 0;
                $lquality = $pq->[$i] if $pq;
                $lquality = $sq->[$cil] if $sq;

                my $rquality = 0;
                $rquality = $pq->[$i] if $pq;
                $rquality = $sq->[$cir] if $sq;

                $quality[$i-$ls] = ($lquality >= $rquality) ? $lquality : $rquality;
#	my $sstring = substr $ss,$begin-2-1,$end-$begin+1+4;
#       my $tstring = substr $ts,$start-2-1,$final-$start+1+4;
	    }

# find the minimum of the quality measure and clip at that point

            my $minimum;
            for (my $i = 1 ; $i <= $#quality ; $i++) {
                next if ($quality[$i] == $quality[$i-1]);
                $minimum = $i - 1 unless defined($minimum);
                next if ($quality[$i] > $quality[$i-1]);
                $minimum = $i;
            }
# change default shrink only if a minimum could be defined
            if (defined($minimum)) {
                $lhshrink = $minimum;
#                $lhshrink = $overlap - $lhshrink - 1 if $reverse; # ?
                $rhshrink = $overlap - $lhshrink - 1;
	    }
        }

# clip lefthand segment on the righthand side
        $segments->[$i]->[1]   -= $rhshrink;
        $segments->[$i]->[3]   -= $rhshrink   unless $reverse;
        $segments->[$i+1]->[2] -= $rhshrink       if $reverse;
# clip righthand segment on the lefthand side
        $segments->[$i+1]->[0] += $lhshrink;
        $segments->[$i+1]->[2] += $lhshrink   unless $reverse;
        $segments->[$i]->[3]   += $lhshrink       if $reverse;
$logger->info("SS new segments @{$segments->[$i]} : @{$segments->[$i+1]}");
    }
    return $overlapcount;
}

sub mergeSegments {
# helper method to goldenpath
# combine segments if the sequence inbetween (is low quality but) matches
    my $segments = shift;
    my $inverted = shift;
    my $template = shift;
    my $sequence = shift;
    my %options = @_;

    &verifyPrivate($segments,'mergeSegments');

    $options{lqextend} = 1 unless defined $options{lqextend};

    my $window = $options{lqextend}; # default 1 
    my $symbol = $options{lqsymbol}; # symbol, or list of symbols to be accepted as matching

    my $tlength = length($template);
    my $slength = length($sequence);

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

    my $ns = scalar(@$segments);

    my $k = $inverted ? 3 : 2;

    my $i = $ns-1;
    while (--$i >= 0) {
# get the gaps between successive segments
        my ($tgap,$sgap);
        $tgap = $segments->[$i+1]->[0]  - $segments->[$i]->[1]; # - 1 for actual size
        $sgap = $segments->[$i+1]->[$k] - $segments->[$i]->[5-$k]; # apart from sign!
        next if ($tgap <= 1 || $tgap != abs($sgap));

# gaps on both template and sequence are of equal size; get the sequence in the gap
# possibly with some overflow specified by window

        my $wstart = $window;
        my $tstart = $segments->[$i]->[1] + 1;
        my $sstart = $segments->[$i]->[5-$k] + 1;
# protect against boundary under flow at beginning
        $wstart = $tstart - 1 if ($tstart-1-$window < 0);
        $wstart = $sstart - 1 if ($sstart-1-$window < 0);

        my $wfinal = $window;
        my $tfinal = $segments->[$i+1]->[0] - 1;
        my $sfinal = $segments->[$i+1]->[$k] - 1;
# protect against boundary overflow at end of strings
        $wfinal = $tlength - $tfinal if ($tfinal + $wfinal > $tlength);
        $wfinal = $slength - $sfinal if ($sfinal + $wfinal > $slength);

# extract the sequence fragments

        my $tstring = substr $template,$tstart-1-$window,$tfinal-$tstart+1+$wstart+$wfinal;
        my $sstring = substr $sequence,$sstart-1-$window,$sfinal-$sstart+1+$wstart+$wfinal;

#my $squality = $options{squality}; # debug mode
#if ($squality && @$squality) {
#    print STDOUT "start $tstart  final $tfinal    begin $sstart  end $sfinal\n";
#    my $segmenti = $segments->[$i];
#    my $segmentj = $segments->[$i+1];
#    print STDOUT "gap $sgap  segment $i @$segmenti  $i+1 @$segmentj \n";
#    print STDOUT "sq $sstart-$sfinal  $sstring  $tstring\n";
#    my @squality = @$squality [($sstart-1-$window) .. ($sfinal-1+$window)];
#    print STDOUT "sq $sstart-$sfinal   @squality \n";
#}

# test the two sequence fragments against one another and see if they are compatible
# if no symbol is specified, compare case only; if (low quality) pad symbols are
# provided (e.g. N, X, *, -), generate a regular expression from the template sequence 

        if (defined($symbol) || $symbol =~ /\S/) {
            $tstring =~ s/(\w)/[$1$symbol]/g; # generate a regexp 
        }
            
        if ($sstring =~ /^$tstring$/i) {
# the sequence in the gap matches: merge the two segments
            my @segment = ($segments->[$i]->[0] ,$segments->[$i+1]->[1],
                           $segments->[$i]->[$k],$segments->[$i+1]->[5-$k]);
            splice @$segments,$i,2,[@segment];
        }    
    }
}

sub inverseSegments {
    my $segments = shift;
    foreach my $segment (@$segments) {
        my @segment = ($segment->[2],$segment->[3],$segment->[0],$segment->[1]);
        @$segment = @segment; 
    }
}

 my $DEBUG;

sub goldenPath {
# cleanup and shrink segments TO BE DEVELOPED
    my $segments = shift;
    my %options = @_;

# NOTE: cleanup and shrink could be combined into one method, also using quality
# NOTE: data to better handle the treatment of ambiguity in overlapping segments

# TO BE DEVELOPED, for the moment we use  cleanup, filter and shrink

    my $c = &cleanupEmbeddedAndShortSegments($segments,%options);

    &inverseSegments($segments);

    my $d = &cleanupEmbeddedAndShortSegments($segments,%options);

    &inverseSegments($segments);

print $DEBUG "Cleanup alignment segments $c , $d\n" if $DEBUG;

    my @f = &filterOffsets($segments,%options);

print $DEBUG "Median filter @f\n" if $DEBUG;

#    my $tquality = $options{tquality};
#    my $squality = $options{squality};
    my $template = $options{template};
    my $sequence = $options{sequence};
    
    my $e = &cleanupOverlappingSegments($segments,%options);

print $DEBUG "cleanupOverlappingSegments $e\n" if $DEBUG;

    my %moptions;
    $options{window} =  1  unless defined $options{window};
    $moptions{window} = $options{window};
    $options{symbol} = 'N' unless defined $options{symbol};
    $moptions{lowqsymbol} = $options{symbol};
#    $moptions{squality} = $options{squality} if $options{squality};
    &mergeSegments($segments,$options{reverse},$template,$sequence,%moptions);
}


sub gapSegments {
# helper method for 'correlate': find gaps between segments
    my $segments = shift;
    my $reverse = shift;
    my $borders = shift; # array reference

    &verifyPrivate($segments,'gapSegments');

    return if (defined($borders) && ref($borders) ne 'ARRAY');

# order the segments with position

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

# if defined $borders find gaps between borders, else only between segments

    my $gaps = [];

# to be developed further: gap should also be on test sequence side

    my $ns = scalar(@$segments);
    for (my $i = 0 ; $i <= $ns ; $i++) {
# if no extension indicated, skip i=0 and i=ns case
        next unless ($borders || ($i > 0 && $i < $ns));
# get the interval for $this part of the alignment
	my ($gts,$gtf,$grs,$grf);

        $gts = ($i == 0)   ? $borders->[0] : $segments->[$i-1]->[1] + 1;
        $gtf = ($i == $ns) ? $borders->[1] : $segments->[$i]->[0]   - 1;

        if ($reverse) {
            $grf = ($i == 0)   ? $borders->[3] : $segments->[$i-1]->[3] - 1;
            $grs = ($i == $ns) ? $borders->[2] : $segments->[$i]->[2]   + 1;
        }
        else {
            $grs = ($i == 0)   ? $borders->[2] : $segments->[$i-1]->[3] + 1;
            $grf = ($i == $ns) ? $borders->[3] : $segments->[$i]->[2]   - 1;
	}

        push @$gaps, [($gts,$gtf,$grs,$grf)] if ($gtf > $gts && $grf > $grs);

    }

    return $gaps; # array ref
}

#--------------------------------------------------------------------------------
# private methods (other)
#--------------------------------------------------------------------------------

sub reverse {
# return inverse of input sequence
    my $sequence = shift;

    &verifyPrivate($sequence,'inverse');

    my $reverse;

    my $length = length($sequence);

    for my $i (1 .. $length) {
        my $j = $length - $i;
        $reverse .= substr $sequence, $j, 1;
    }

    return $reverse;
}

my %translate = (A => 'T', C => 'G', G => 'C', T => 'A');

sub complement {
# return inverse complement of input sequence

    my $inverse = &reverse(@_);

    $inverse =~ tr/ACGTacgt/TGCAtgca/;

    return $inverse;

#----------------
    my $sequence = shift;

#    my $inverse;

    my $length = length($sequence);

    for my $i (1 .. $length) {
        my $j = $length - $i;
        my $base = substr $sequence, $j, 1;
        $inverse .= ($translate{$base} || $base);
    }
    return $inverse;
}

sub threshold {
# return number of expected random coincidences (un-banded search)
    my $rlength = shift; # this sequence's length
    my $mlength = shift; # test sequence's length
    my $peakdrift = shift || 3;
    my $kmersize = shift;


    &verifyPrivate($rlength,'threshold');


    $rlength /= $peakdrift;
    $mlength /= $peakdrift;

    my $result = ($rlength - $kmersize)  # number of trial kmers in this sequence
               * ($mlength - $kmersize)  # number of trial matches to other sequence
	       / (3**$kmersize); # empirical add hoc normalisation

    return int($result+0.5);
}

sub findpeak {
# coarse determination of alignment in un-banded search
    my $counthash = shift;
    my $threshold = shift;
    my $spread = shift;
    my $repeat = shift || 0;

    &verifyPrivate($counthash,'findpeak');

    my $logger = &verifyLogger('findpeak');

    my @offset = sort {$a <=> $b} keys %$counthash;

    unless (scalar @offset) {
        $logger->error("Empty count hash $counthash");
        return 0,0; 
    }

# find the offset for the maximum count

    undef my $maximum;
    my $accumulated = {};
    foreach my $offset (@offset) {
	my $count = $counthash->{$offset};
        next unless $count;
        $maximum = $offset unless defined $maximum;
        $maximum = $offset if ($count > $counthash->{$maximum});
        $accumulated->{$count}++;
    }

$logger->debug("maximum $maximum ($counthash->{$maximum})",ss=>1);
$logger->debug("Offsets :");
for (my $i = $maximum-10 ; $i <= $maximum+10 ; $i++) {
#    next if ($i < 0);
    $logger->debug(" $i (".($counthash->{$i} || 0).")");
}


# sample around the maximum above the threshold

    my $peakcount = 0;
    my $ks = $maximum - $spread;
    my $kf = $maximum + $spread;
    my ($start,$final);
    for my $offset ($ks .. $kf) {
	my $count = $counthash->{$offset};
        next unless ($count && $count >= $threshold);
        $start = $offset unless defined($start); # register first above threshold
        $final = $offset; # register last above threshold
        $peakcount += $count;
    }

# determine the median position as the best overall shift

    my $partialcount = 0;
    for my $offset ($ks .. $kf) {
	my $count = $counthash->{$offset};
        next unless ($count && $count >= $threshold);
        $partialcount += $count;
        $maximum = $offset;
# we have encountered the median when the partial count exceeds half the total
        last if ($partialcount > $peakcount/2);
    }

# assemble output array of arrays

    my @data;

    push @data,[($start,$final,$peakcount)];

$logger->fine("findpeak ($repeat) result $maximum  peakcount $peakcount");

    return [@data],$peakcount unless ($peakcount && $repeat > 0);

# remove the hash entries inside the window and repeat the process
# this will scan a series of peaks in the count distribution and
# may reveal a better count at lower peak level but broader distribution

    foreach my $offset (($maximum - 2*$spread) .. ($maximum + 2*$spread)) {
        delete $counthash->{$offset};
    }

    my ($data,$count) = &findpeak ($counthash,$threshold,$spread,$repeat-1);

    push @data,@$data if $count; # add to output array

    $peakcount += $count; # total count in alignments

    return [@data],$peakcount;
}
 
sub listSegments {
    my $segments = shift;
    my $text = shift || "segment";

    my $mapping = new Mapping(@_);
    foreach my $segment (@$segments) {
        $mapping->putSegment(@$segment);
    }
    $mapping->normalise();
    return $mapping->writeToString($text,extended=>1);
}

sub diagnose {
# ad hoc listing of preliminary results
    my $correlationhash = shift;
    my $segments = shift;

    my $logger = &verifyLogger();
# list intermediate results
    my @offsets = sort {$a <=> $b} keys %$correlationhash;
    $logger->fine(scalar(@offsets)." offsets detected: \n@offsets");
# block to list initial search results
    $logger->info("diagnose: ".scalar(@$segments)." segments found");
# create list of Segment objects 
    my @segments;
    foreach my $segment (@$segments) {
        my $Segment = new Segment(@$segment,0);
        push @segments,$Segment;
    }
# sort according to length
    @segments = sort {$b->getSegmentLength() <=> $a->getSegmentLength()} @segments;
# and list the ten largest
    my $min = (scalar(@segments) > 10) ? 10 : scalar(@segments);
    for (my $i = 0 ; $i < $min ; $i++) {
        my @segmentdata = $segments[$i]->getSegment();
        push @segmentdata,$segments[$i]->getSegmentLength();
        push @segmentdata,$segments[$i]->getOffset();
        $logger->info("segment : @segmentdata");
    }
}

#-----------------------------------------------------------------------------
# access
#-----------------------------------------------------------------------------

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return unless ($caller && ($caller  eq 'Alignment' ||
                           ref($caller) eq 'Alignment'));
    print STDERR "Invalid usage of private method '$method' in package Alignment\n";
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

        if (defined($prefix)) {

            $prefix = "Alignment->".$prefix unless ($prefix =~ /\-\>/); 

            $LOGGER->setPrefix($prefix);
        }
        return $LOGGER;
    }

# no (valid) logging unit is defined, create a default unit

    $LOGGER = new Logging();

    return &verifyLogger($prefix);
}

sub setLogger {
# assign a Logging object 
    my $this = shift;
    my $logger = shift;

    return if (!$logger || ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

#    &verifyLogger(); # creates a default if $LOGGER undefined
}
   
#--------------------------------------------------------------------------

sub printoptions {
    my $name = shift || 'undefined';
    my $logger = &verifyLogger();
    $logger->info("$name : @_");
}

1;
