package Alignment;

use strict;

use Mapping;

# use Exporter;
# my @ISA = qw

#--------------------------------------------------------------------------
# class variables
#--------------------------------------------------------------------------

my %inverse; # for inverted k-mers

my %translate = (A => 'T', C => 'G', G => 'C', T => 'A');

my $DEBUG = 0;

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
#              repeat   for default threshold determination  
#           peakdrift   expected drift in offset; default 3
#           coaligned   -1, +1, 0; default 0
#        bandedlinear   expecting a (roughly) linear shift
#        bandedoffset   idem, the constant term 
#        bandedwindow   expected drift in offset with respect to linear, default 10

# experimental/not yet implemented
#             iterate   through gaps between segments
#            autoclip   require subsegments larger than value x average length; e.g. 0.3  
#            tquality   reference to quality array for template data
#            squality   reference to quality array for sequence data

$DEBUG = $options{debug} || 0;

print $DEBUG "correlate: @_\n" if $DEBUG;

# PRELIMINARIES : test if kmer hashes are present/compatible; if not, build them

    unless ($tkmerhash && $skmerhash
        &&  $tkmerhash->{kmersize} && $skmerhash->{kmersize}
        &&  $tkmerhash->{kmersize} == $skmerhash->{kmersize}) {
# get the kmersize
        my $kmersize = $options{kmersize} || 7;
        $kmersize = 7 unless ($kmersize > 0);
        my $halfsize = int(($kmersize-1)/2 + 0.5);
        $kmersize = $halfsize * 2 + 1; # ensure an odd number
# build the hashes
        $tkmerhash = &buildKmerHash($template,$kmersize,1,length($template));
        $skmerhash = &buildKmerHash($sequence,$kmersize,1,length($sequence));
    }

    return 0 unless (&verifyKmerHash($tkmerhash) && &verifyKmerHash($skmerhash));

# get boundaries on the sequence (from the hash)

    my @borders;
    push @borders, $tkmerhash->{sequencestart};
    push @borders, $tkmerhash->{sequencefinal};
    push @borders, $skmerhash->{sequencestart};
    push @borders, $skmerhash->{sequencefinal};
       
    my $templatelength = $borders[1] - $borders[0] + 1;
    my $sequencelength = $borders[3] - $borders[2] + 1;

    my $kmersize = $tkmerhash->{kmersize};
    my $halfkmersize = int(($kmersize+1)/2);

# MAIN : ** here starts the real work **

    my $reverse = 0;
    my $offset  = 0;

# get control parameters or their defaults

    my $coaligned = $options{coaligned} || 0;
    my $peakdrift = $options{peakdrift} || 3;

    my %coptions;
    if ($options{bandedwindow} || $options{bandedlinear} || $options{bandedoffset}) {
# the approximate linear relation is known and used to limit search domain
        $coptions{linear} = $options{bandedlinear} || 1.0;
        $coptions{offset} = $options{bandedoffset} || 0.0;
        $coptions{window} = $options{bandedwindow} || $peakdrift;
# the banded search specification overrides any coaligned setting
        $reverse = 1 if ($coptions{linear} < 0);
        $coaligned = $coptions{linear}/abs($coptions{linear});
# just signal an inconsistency of input parameters 
        unless ($options{coaligned} * $coaligned >= 0) {
            print STDERR "Incompatible alignment specification adjusted\n";
        }
    }

# INTERMEZZO : for un-banded search, determine alignment direction and offset

    unless ($coptions{window}) {

# determination of minimum required count

        my $threshold = $options{threshold} || 0;

        unless ($threshold) {
# determine threshold as approximate expectation for random coincidences
            $threshold = &threshold($templatelength,$sequencelength,$peakdrift,$kmersize);
            $threshold = 10 if ($threshold < 10);
print $DEBUG "Threshold: $threshold ($templatelength,$sequencelength)\n" if $DEBUG;
        }

# collate the index counts for coincident k-mers in template and sequence

        my $repeat = $options{repeat}; # iteration counter (default no iteration)

        my ($foffset,$fcount,$roffset,$rcount) = (0,0,0,0);

print $DEBUG "Building correlation hash\n" if $DEBUG;

        if ($coaligned >= 0) {
# co-aligned (forward alignment) case
            my $forwardhash = &buildCorrelationHash($tkmerhash,$skmerhash,%coptions);
# analyse the distribution of forward counts
           ($foffset,$fcount) = &findpeak($forwardhash,$threshold,$peakdrift,$repeat);
        }

        if ($coaligned <= 0) {
# counter-aligned (reverse compliment alignment) case
            $coptions{reverse} = 1;
            my $reversehash = &buildCorrelationHash($tkmerhash,$skmerhash,%coptions);
# analyse the distribution of reverse counts
           ($roffset,$rcount) = &findpeak($reversehash,$threshold,$peakdrift,$repeat);
        }

# test both results against threshold & determine the "best" distributions

        my $count   = ($fcount > $rcount) ? $fcount  : $rcount;

        $offset  = ($fcount > $rcount) ? $foffset : $roffset;
        $reverse = ($fcount > $rcount) ? 0 : 1;

# NOTE: it is not clear if a threshold preselection is usefull, perhaps the actual
# determination of the alignment segments provides a better test for significance

print $DEBUG "result forward: $foffset,$fcount   reverse: $roffset,$rcount "
           . " threshold $threshold  \n" unless ($count && $count >= $threshold);

        return undef unless ($count && $count >= $threshold);

print $DEBUG "result forward: $foffset,$fcount   reverse: $roffset,$rcount "
           . " threshold $threshold  \n" if $DEBUG;
print $DEBUG "\nAlignment $reverse offset $offset   count $count "
           . "($threshold)  $kmersize\n\n" if $DEBUG;

# define the constraints for the offset 

        $coptions{offsetlowerbound} = $offset - $peakdrift;
        $coptions{offsetupperbound} = $offset + $peakdrift;
# END INTERMEZZO
    }

# MAIN ACT : build and analyze the correlation hash

# determine the correlation hash by sampling under the constraints on either
# offset (un-banded search) or a moving position window (banded search)

print $DEBUG "Sampling correlation hash\n" if $DEBUG;
    $coptions{reverse} = $reverse;

    my $samplehash = &sampleCorrelationHash($tkmerhash,$skmerhash,%coptions);

# build a list of segments, contiguous runs of matches in $template and $sequence

print $DEBUG "Getting alignment segments\n" if $DEBUG;

    my $minimum;
    my $iterate = $options{iterate};
    if ($options{autoclip}) {
# determine the minimum acceptable length for an interval
        my $average = 0.5*($templatelength + $sequencelength)/$peakdrift;
        $minimum = $options{autoclip} * $average;
# activate iteration to fill in gaps
        $iterate = $kmersize unless $iterate; 
    }

    my $segments = &getAlignmentSegments($samplehash,$minimum);

# extend segments by half of kmersize

print $DEBUG "Extend alignment segments\n" if $DEBUG;

    &extendSegments($segments,$kmersize,$reverse);

# remove redundent segments and test the segments for overlap

print $DEBUG "Cleanup/Shrink alignment segments\n" if $DEBUG;

    if ($options{fullrange}) {
# do a cleanup only (but keep possible overlaps)
        &cleanupSegments($segments,$reverse);
    }
    else {
# do a detailed analysis to find the best series of non-overlapping segments 
        &goldenPath($segments,$options{tquality},$options{squality},$reverse);
    }

# iterate to fill the remaining gaps

    my $offsetlowerbound = $offset - $peakdrift; # default setting
    my $offsetupperbound = $offset + $peakdrift; # default setting

# test for gaps 

    unless ($iterate) {
# activate iteration if gaps are found to try to fill in
        my $gaps = &gapSegments($segments,$reverse,[@borders]);
print $DEBUG scalar(@$gaps)." gaps found\n" if $DEBUG; 
        $iterate = 1 if @$gaps;
    }

    while ($iterate && $kmersize > $iterate) {
# determine gaps
        my $gaps = &gapSegments($segments,$reverse,[@borders]);

        $kmersize -= 2; # decrease 

print $DEBUG "Doing kmersize $kmersize on ".scalar(@$gaps)." gaps\n" if $DEBUG;

#        $extend = 0 if ($kmersize < 3);

        foreach my $gap (@$gaps) {
# build the hashes, using only the data in the interval
            $tkmerhash = &buildKmerHash($template,$kmersize,$gap->[0],$gap->[1]);
# NOTE: inverted case requires [3],[2] ?? 
#       what about alowing [0]-1 to [1]+1 to allow overlap ??
            $skmerhash = &buildKmerHash($sequence,$kmersize,$gap->[2],$gap->[3]);
# determine  offset ranges (from surrounding intervals)
            my @offsets;
            foreach my $i (0,1) {
                $offsets[$i]  = $gap->[$i];
                $offsets[$i] -= $gap->[$i+2] unless $reverse;
                $offsets[$i] += $gap->[3-$i] if $reverse;
	    }
            @offsets = sort {$a <=> $b} @offsets;
            $offsets[0] = $offsetlowerbound if ($offsets[0] < $offsetlowerbound);
            $offsets[1] = $offsetupperbound if ($offsets[1] > $offsetupperbound);
print $DEBUG "kmer $kmersize;  gap @$gap;   offsets @offsets\n" if $DEBUG;
# widen the offset range if it's too small
            if ($kmersize > 3 || ($offsets[1] - $offsets[0]) <= 1) {
                $offsets[0]--;
                $offsets[1]++;
	    }

# we do an un-banded search because its a very limited search domain

            my %roptions = (reverse=>$reverse,
                            offsetlowerbound=>$offsets[0], 
                            offsetupperbound=>$offsets[1]); 
            my $shash = &sampleCorrelationHash($tkmerhash,$skmerhash,%roptions);
print $DEBUG "No segments found\n" if (!$shash && $DEBUG);
            next unless $shash;

# add new segments to the existing segments

            my $newsegments = &getAlignmentSegments($shash);
print $DEBUG scalar(@$newsegments)." segments found\n" if $DEBUG;

            if (@$newsegments) {
                &extendSegments($newsegments,$kmersize,$reverse);
                push @$segments,@$newsegments;
# &joinSegments?
            }
        }
#        $gaps = &cleanupSegments($segments,$reverse,[@borders]);
    }

# do a final cleanup, just in case (no gap determination)

    &cleanupSegments($segments,$reverse);

# export the segments as a Mapping

    my $mapping = new Mapping();

#    $mapping->setMappingName($mappingname);

    foreach my $segment (sort {$a->[0] <=> $b->[0]} @$segments) {
if ($DEBUG) {
#my $length = ($segment->[1] - $segment->[0] + 1);
#print $DEBUG "segment: @$segment    ($length)\n";
#print $DEBUG "f:".substr($template,$segment->[0]-1,$length)." "
#                 . (substr($template,$segment->[1], 1) || 'e')."\n";
#print $DEBUG "a:".substr($sequence,$segment->[2]-1,$length)." "
#                 . (substr($sequence,$segment->[3], 1) || 'e')."\n";
}
if (abs($segment->[1] - $segment->[0]) != abs($segment->[3] - $segment->[2])) {
    print STDOUT "INVALID segment @$segment\n";
#    next;
}
        $mapping->putSegment(@$segment);
    }

    return $mapping;
}

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
# PRIVATE methods producing k-mer hashes
#--------------------------------------------------------------------------

sub verifyAccess {
# test if reference of parameter is not package name
    my $caller = shift;
    my $origin = shift || 'verifyAccess';

    return unless (ref($caller) eq 'Correlate');
	
    die "Invalid usage of private method '$origin' in package Corralate";
}
 
sub buildKmerHash {
# build and return a k-mer hash structure
    my $sequence = shift;
    my $kmersize = shift;
    my $start = shift;
    my $final = shift;
    my $name = shift; # optional

    &verifyAccess($sequence,'buildKmerHash');

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

    &verifyAccess($kmerhash,'verifyKmerHash');

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
    my %options = @_; # print $DEBUG "buildCorrelationHash @_\n";

    my $reverse = $options{reverse} || 0;
    my $wbanded = $options{window}; # has to be defined for banded matching
    my $lbanded = $options{linear} || 1.0;
    my $obanded = $options{offset} || 0.0;
# test input arguments
    if ($lbanded > 0 && $reverse || $lbanded < 0 && !$reverse) {
        print STDERR "Incompatible parameter values in 'buildCorrelationHash'\n";
	return undef;
    }

    &verifyAccess($thiskmerhash,'buildCorrelationHash');

    my $thiskmerdata = $thiskmerhash->{kmers};
    my $thatkmerdata = $thatkmerhash->{kmers};

# cross-match the two k-mer hashes to get the correlation hash

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
                    $hashcount->{$offset}++;
		}
	    }
	}
    }

    return $hashcount;
}

sub sampleCorrelationHash {
# returns position correspondences as a hash keyed on postion of this read
    my $thiskmerhash = shift || return undef; # kmer counts keyed on position
    my $thatkmerhash = shift || return undef; # kmer counts keyed on position
    my %options = @_;

    &verifyAccess($thiskmerhash,'sampleCorrelationHash');

#  test control parameters

    my $reverse = $options{reverse} || 0;
    my $wbanded = $options{window}; # has to be defined for banded matching
    my $lbanded = $options{linear} || 1.0;
    my $obanded = $options{offset} || 0.0;
# test input arguments
    if ($lbanded > 0 && $reverse || $lbanded < 0 && !$reverse) {
        print STDERR "Incompatible parameter values in 'sampleCorrelationHash'\n";
	return undef;
    }

# define default lower/upper boundaries for offset

    my $offsetlowerbound = $options{offsetlowerbound}; # if any
    my $offsetupperbound = $options{offsetupperbound}; # if any

    my $nowarning = $options{nowarning};

# get the k-mer hashes

    my $thiskmerdata = $thiskmerhash->{kmers} || return undef;
    my $thatkmerdata = $thatkmerhash->{kmers} || return undef;

# cross-match the two k-mer hashes

    my $correlationhash = {};
    foreach my $key (keys %$thiskmerdata) {

# get the k-mer corresponding to $key

        my $kmer = $reverse ? $inverse{$key} : $key;
        unless (defined($kmer)) {
# this should not occur (inverse hash was built earlier in buildCorrelationHash
            unless ($nowarning) {
                print STDERR "Unexpected undefined inverse hash element for $key\n";
                next;
            }
            $kmer = &complement($key);
            $inverse{$key} = $kmer;
        }

# sample matching kmers in the test read, using the offset window

        my ($positionlowerbound,$positionupperbound);
        if (my $match = $thatkmerdata->{$kmer}) {
            my $local = $thiskmerdata->{$key };
# collate all combinations of positions in this and read 
            foreach my $thisposition (@$local) {
# for banded sampling, define upper and lower bounds
                if ($wbanded) {
                    $positionlowerbound = $thisposition * $lbanded + $obanded;
                    $positionupperbound = $positionlowerbound + $wbanded;
                    $positionlowerbound -= $wbanded;
                }
                foreach my $thatposition (@$match) {
# for banded sampling, apply filter to positions
                    if ($wbanded) {
                        next if ($thatposition < $positionlowerbound);
                        next if ($thatposition > $positionupperbound);
		    }
                    my $offset = $thisposition;
                    $offset -= $thatposition unless $reverse;
                    $offset += $thatposition if $reverse;
# apply possible filter to offset
                    next if ($offsetlowerbound && $offset < $offsetlowerbound);
                    next if ($offsetupperbound && $offset > $offsetupperbound);
# sample the matching positions in hash element keyed on offset
                    my $segmenthash = $correlationhash->{$offset};
                    unless (defined $segmenthash) {
                        $correlationhash->{$offset} = {}; # autovivify
                        $segmenthash = $correlationhash->{$offset};
                    }
                    if ($segmenthash->{$thisposition}) {
# this test could be part of subsequent segment analysis
                        print $DEBUG "DUPLICATE correlationhash element!!\n";
                    }
                    $segmenthash->{$thisposition} = $thatposition;
		}
	    }
	}
    }

    return $correlationhash;
}

#--------------------------------------------------------------------------------
# private methods dealing with alignment segments
#--------------------------------------------------------------------------------

sub getAlignmentSegments {
# helper method for 'correlate': return a list of alignment segments
    my $correlationhash = shift;
    my $minimum = shift;

# a segment consists of contiguous matching positions without constraints
# on the boundaries; however, a minimum length can be specified 

    &verifyAccess($correlationhash,'getAlignmentSegments');

    my $segments = [];
    foreach my $offset (sort {$a <=> $b} keys %$correlationhash) {

        undef my $segment; # for alignment segment
        my $segmenthash = $correlationhash->{$offset};
# run through positions and record the uninterrupted sequences
        my @positions = sort {$a <=> $b} keys %$segmenthash;
        next if ($minimum && scalar(@positions) < $minimum);

        foreach my $position (@positions) {
# if there is a discontinuity: complete previous segment and initiate a new one
            if (defined($segment) && $position > ($segment->[1]+1)) {
                push @$segments,$segment;
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
        }
        push @$segments,$segment if defined($segment);
    }

# return an array of segment mappings (4 numbers each)

    return $segments;
}

sub extendSegments {
# helper method for 'correlate': add half the kmes size at either end of segments
    my $segments = shift;
    my $kmersize = shift;
    my $inverted = shift;


    &verifyAccess($segments,'extendSegments');


    my $extend = int(($kmersize-1)/2);
    return unless ($extend > 0);

    $extend = -$extend if $inverted;

    foreach my $segment (@$segments) {
        $segment->[0] = $segment->[0] - abs($extend);
        $segment->[1] = $segment->[1] + abs($extend);
        $segment->[2] = $segment->[2] - $extend;
        $segment->[3] = $segment->[3] + $extend;
    }
}

sub cleanupSegments {
# helper method for 'correlate': remove segments which are completely embedded in others
    my $segments = shift;
    my $reverse = shift;

    &verifyAccess($segments,'cleanupSegments');

# order the segments with start position

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

# collect segments that need to be removed because they fall inside another one

    my %remove;
    my $ns = scalar(@$segments);
    for (my $i = 0 ; $i < $ns ; $i++) {
        next if $remove{$i};
        my $si = $segments->[$i];
        for (my $j = $i+1 ; $j < $ns ; $j++) {
            next if $remove{$j};
            my $sj = $segments->[$j];
# test if segment j is inside segment i on this read
            if ($si->[0] <= $sj->[0] && $si->[1] >= $sj->[1]) {
                $remove{$j}++;
	    }
# test if segment j is inside segment i on the matching read
            elsif ( $reverse && $si->[2] >= $sj->[2] && $si->[3] <= $sj->[3]) {
                $remove{$j}++;
	    }
            elsif (!$reverse && $si->[2] <= $sj->[2] && $si->[3] >= $sj->[3]) {
                $remove{$j}++;
	    }
            next if $remove{$j}; # try next $j for same $i
            next if ($sj->[0] <= $si->[1]); # this segment may mask the next
            last; # intervals $i and $j are disconnected: next $i
        }
    }

    foreach my $j (sort {$b <=> $a} keys %remove) { # reverse order!
        splice @$segments, $j, 1;
    }

    return;
}

sub shrinkSegments {
# helper method for 'correlate': clip ends of segments if they overlap
    my $segments = shift;
    my $inverted = shift;

    &verifyAccess($segments,'shrinkSegments');

    @$segments = sort {$a->[0] <=> $b->[0]} @$segments;

    my $ns = scalar(@$segments);

# NOTE: REVERSE case still to be tested

    for (my $i = 0 ; $i < $ns-1 ; $i++) {
# get the (possible) overlap between successive segments
        my $overlap = $segments->[$i]->[1] + 1 - $segments->[$i+1]->[0];
        if ($overlap > 0) {
            $segments->[$i]->[1] -= $overlap;
            $segments->[$i]->[3] -= $overlap unless $inverted;
            $segments->[$i]->[2] += $overlap if $inverted;
	}
# same but now for the complementary domain
        $overlap = $segments->[$i]->[3] + 1 - $segments->[$i+1]->[2] unless $inverted;
        $overlap = $segments->[$i+1]->[3] + 1 - $segments->[$i]->[2] if $inverted;
        if ($overlap > 0) {
            $segments->[$i]->[1] -= $overlap;
            $segments->[$i]->[3] -= $overlap unless $inverted;
            $segments->[$i]->[2] += $overlap if $inverted;
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

sub goldenPath {
# cleanup and shrink segments TO BE DEVELOPED
    my $segments = shift;
    my $tquality = shift;
    my $squality = shift;
    my $reverse = shift;
#    my %options = @_;

# NOTE: cleanup and shrink could be combined into one method, also using quality
# NOTE: data to better handle the treatment of ambiguity in overlapping segments

# TO BE DEVELOPED, for the moment we use  cleanup and shrink

print $DEBUG "Cleanup alignment segments\n" if $DEBUG;

    &cleanupSegments($segments,$reverse);

    &inverseSegments($segments);

    &cleanupSegments($segments,$reverse);

    &inverseSegments($segments);

print $DEBUG "Shrink alignment segments\n" if $DEBUG;

    &shrinkSegments($segments,$reverse);
}

sub gapSegments {
# helper method for 'correlate': find gaps between segments
    my $segments = shift;
    my $reverse = shift;
    my $borders = shift; # array reference

    &verifyAccess($segments,'gapSegments');

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

sub complement {
# helper method for 'buildCorrelationHash': return inverse complement of input sequence
    my $sequence = shift;


    &verifyAccess($sequence,'complement');


    my $length = length($sequence);

    my $inverse;

    for my $i (1 .. $length) {
        my $j = $length - $i;
        my $base = substr $sequence, $j, 1;
        $inverse .= ($translate{$base} || $base);
    }
    return $inverse;
}

sub threshold {
# return number of expected random coincidences (un-banded search)
    my $rlength = shift; # this read's length
    my $mlength = shift; # the matching read's length
    my $peakdrift = shift || 3;
    my $kmersize = shift;


    &verifyAccess($rlength,'threshold');


    $rlength /= $peakdrift;
    $mlength /= $peakdrift;

    my $result = ($rlength - $kmersize)  # number of trial kmers in this read
               * ($mlength - $kmersize)  # number of trial matches to other read
	       / (3**$kmersize); # empirical add hoc normalisation

    return int($result+0.5);
}

sub findpeak {
# coarse determination of alignment in un-banded search
    my $counthash = shift;
    my $threshold = shift;
    my $spread = shift;
    my $repeat = shift || 0;


    &verifyAccess($counthash,'findpeak');


    my @offset = sort {$a <=> $b} keys %$counthash;

    unless (scalar @offset) {
        print $DEBUG "Empty count hash\n" if $DEBUG;
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

if ($DEBUG) {
print $DEBUG "\n";
print $DEBUG "maximum $maximum ($counthash->{$maximum})\n";
print $DEBUG "Offsets :\n";
for (my $i = $maximum-10 ; $i <= $maximum+10 ; $i++) {
    print $DEBUG " $i (".($counthash->{$i}||0).")";
}
print $DEBUG "\n";
#print $DEBUG "Distribution :\n";
#foreach my $count (sort {$b <=> $a} keys %$accumulated) {
#    print $DEBUG " $count (".($accumulated->{$count}||0).")";
#} 
#print $DEBUG "\n";
}


# sample around the maximum above the threshold

    my $peakcount = 0;
    my $ks = $maximum - $spread;
    my $kf = $maximum + $spread;
    for my $offset ($ks .. $kf) {
	my $count = $counthash->{$offset};
        next unless ($count && $count >= $threshold);
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

    return ($maximum,$peakcount) unless ($repeat > 0);

# remove the hash entries inside the window and repeat the process
# this will scan a series of peaks in the count distribution and
# may reveal a better count at lower peak level but broader distribution

    foreach my $offset (($maximum - 2*$spread) .. ($maximum + 2*$spread)) {
        delete $counthash->{$offset};
    }

    my ($newmax,$newc) = &findpeak ($counthash,$threshold,$spread,--$repeat);

    if ($newmax > $maximum) {
        $maximum = $newmax;
        $peakcount = $newc;
    }

    return ($maximum,$peakcount);
}
    
#--------------------------------------------------------------------------

1;
