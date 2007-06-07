package ContigHelper;

use strict;

use Contig;

use Mapping;

use TagFactory::TagFactory;

use Alignment;

use Clipping;

use Logging;

#-----------------------------------------------------------------------------
# methods which take a Contig instance as input and change its content
#-----------------------------------------------------------------------------

sub statistics{
# collect a number of contig statistics
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'statistics');

    my $logger = &verifyLogger("statistics ".$contig->getContigName());

# $options{pass} >= 2 to allow adjustment of zeropoint, else not

    $options{pass} = 1 unless defined($options{pass});
    $options{pass} = 1 unless ($options{pass} > 0);
    my $pass = $options{pass};

$logger->debug("pass $pass");

# determine the range on the contig and the first and last read

    my $cstart = 0;
    my $cfinal = 0;
    my ($readonleft, $readonright);
    my $totalreadcover = 0;
    my $numberofnames = 0;
    my $isShifted = 0;

    while ($pass) {
# go through the mappings to find begin, end of contig
# and to determine the reads at either end
        my ($minspanonleft, $minspanonright);
        my $name = $contig->getContigName() || 0;
        if (my $mappings = $contig->getMappings()) {
            my $init = 0;
            $numberofnames = 0;
            $totalreadcover = 0;
            foreach my $mapping (@$mappings) {
                my $readname = $mapping->getMappingName();
# find begin/end of contig range cover by this mapping
                my ($cs, $cf) = $mapping->getContigRange();
# test validity of output (just in case)
                unless (defined($cs) && defined($cf)) {
                    $logger->error("Undefined or invalid mapping for read "
                                  .$mapping->getMappingName()." in contig "
				   .$name);
		    next;
		}
# total read cover = sum of contigspan length
                my $contigspan = $cf - $cs + 1;
                $totalreadcover += $contigspan;
# count number of reads
                $numberofnames++;

# find the leftmost readname

                if (!$init || $cs <= $cstart) {
# this read(map) aligns with the begin of the contig (as found until now)
                    if (!$init || $cs < $cstart || $contigspan < $minspanonleft) {
                        $minspanonleft = $contigspan;
                        $readonleft = $readname;
                    }
                    elsif ($contigspan == $minspanonleft) {
# if several reads line up at left, choose the alphabetically lowest 
                        $readonleft = (sort($readonleft,$readname))[0];
                    }
                    $cstart = $cs;
                }

# find the rightmost readname

                if (!$init || $cf >= $cfinal) {
# this read(map) aligns with the end of the contig (as found until now)
                    if (!$init || $cf > $cfinal || $contigspan < $minspanonright) {
                        $minspanonright = $contigspan;
                        $readonright = $readname;
                    }
                    elsif ($contigspan == $minspanonright) {
# if several reads line up at right, choose the alphabetically lowest (again!) 
                        $readonright = (sort($readonright,$readname))[0];
                    }
                    $cfinal = $cf;
                }
                $init = 1;
            }

            if ($cstart == 1) {
# the normal situation, exit the loop
                $pass = 0;
            }
            elsif (--$pass) {
# cstart != 1: this is an unusual lower boundary, apply shift to the 
# Mappings (and Segments) to get the contig starting at position 1
                my $shift = 1 - $cstart;
                $logger->warning("zero point shift by $shift applied to contig $name");
                foreach my $mapping (@$mappings) {
                    $mapping->applyShiftToContigPosition($shift);
                }
# and apply shift to possible tags
                if ($contig->hasTags()) {
                    $logger->fine("adjusting tag positions (to be tested)");
                    my %options = (nonew => 1,postwindowfinal => $cfinal);
                    my $tags = $contig->getTags();
                    foreach my $tag (@$tags) {
                        $tag->transpose(+1,$shift,%options);
                    }
	        }
# what about contig to contig mappings in parents and children?
# apply shift to possible consensus
                if (my $sequence = $contig->getSequence()) {
                    my $newsequence = substr($sequence,$cstart-1,$cfinal-$cstart+1);
                    if (my $quality = $contig->getBaseQuality()) {
                        my @newquality  = @$quality [$cstart-1 .. $cfinal-1];
                        $contig->setBaseQuality(\@newquality);
		    }
                    $contig->setSequence($newsequence);
		}
# and redo the loop (as $pass > 0)
                $isShifted = 1;
            }
            elsif ($isShifted) {
# this should never occur, indicative of corrupted data/code in Mapping/Segment
                $logger->error("Invalid condition detected in contig $name");
                return 0;
            }
            else {
                $logger->warning("contig $name needs a zero point shift ($cstart)");
	    }
        }
        else {
            $logger->error("contig $name has no read-to-contig mappings");
            return 0;
        }
    }

# okay, now we can calculate/assign some overall properties

    my $clength = $cfinal-$cstart+1;
    $contig->setConsensusLength($clength);
    my $averagecover = $totalreadcover/$clength; # ? clength - average readlength?
    $contig->setAverageCover( sprintf("%.2f", $averagecover) );
    $contig->setReadOnLeft($readonleft);
    $contig->setReadOnRight($readonright);

# test number of reads

    if (my $nr = $contig->getNumberOfReads()) {
        unless ($nr == $numberofnames) {
            $logger->error("Inconsistent read ($nr) and mapping ($numberofnames) "
                          ."count in contig ".$contig->getContigName());
	}
    }
    else {
        $contig->setNumberOfReads($numberofnames);
    }

    return 1; # register success
}

#-----------------------------------------------------------------------------
# methods which take a Contig instance as input and (can) return a new Contig 
#-----------------------------------------------------------------------------

sub reverseComplement {
# return the reverse complement of the input contig, reversing mappings and tags 
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'reverseComplement');

    my $logger = &verifyLogger('reverseComplement');

# optional: create copy of the input contig

    my %coptions; # copy options
    foreach my $option ('complete','nocomponents','parent','child') {
        $coptions{$option} = 1 if $options{$option};
    }

    $contig = $contig->copy(%coptions) unless $options{nonew};

    my $length = $contig->getConsensusLength();

# the read mappings

    if ($contig->getMappings($options{complete})) {
        $logger->debug("inverting read-to-contig mappings");
        my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
# and sort the mappings according to increasing contig position
        @$mappings = sort {$a->getContigStart <=> $b->getContigStart} @$mappings;
    }

# possible parent contig mappings

    if ($contig->getContigToContigMappings($options{complete})) {
        $logger->debug("inverting contig-to-contig mappings");
        my $mappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
    }

# tags

    my $tags = $contig->getTags($options{complete});
    foreach my $tag (@$tags) {
        $logger->debug("inverting tags");
        $tag->mirror($length+1);
    }

# replace the consensus sequence with the inverse complement

    if (my $consensus = $contig->getSequence()) {
        $logger->info("inverting sequence");
        my $newsensus = reverse($consensus);
        $newsensus =~ tr/ACGTacgt/TGCAtgca/;
	$contig->setSequence($newsensus);
    }

    if (my $quality = $contig->getBaseQuality()) {
# invert the base quality array
        $logger->info("inverting base quality array");
        for (my $i = 0 ; $i < $length ; $i++) {
            my $j = $length - $i - 1;
            last unless ($i < $j);
            my $swap = $quality->[$i];
            $quality->[$i] = $quality->[$j];
            $quality->[$j] = $swap;
        }
    }

    $contig->getStatistics(1) if $contig->hasMappings();

    return $contig;
}

#-------------------------------------------------------------------------
# remove or replace bases (change content permanently)
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
                               $options{symbols},   # default 'ACGT'
                               $options{threshold}, # default 20
                               $options{minimum},   # default 15
                               $options{hqpm},      # default 30
                               $options{window});   # default 9
# options: symbols (ACTG), threshold (20), minimum (15), window (9), hqpm (30)
#                               %options);

    unless ($pads) {
        my $cnm = $contig->getContigName();
        $logger->error("Missing DNA or quality data in $cnm");
        return $contig, 0; # no low quality stuff found
    }

# step 2: remove low quality pads from the sequence & quality;

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);

$logger->debug("ContigFactory->deleteLowQualityBases  sl:".length($sequence)."  ql:".scalar(@$quality));
$logger->debug("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED'));

# out: new sequence, quality array and the mapping from original to new

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

$logger->info("exporting as CHILD");

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
# replace low quality pads in consensus by a given symbol
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

    $contig = $contig->copy() if $options{new};

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
# use lowercase for low quality stuff; hence first switch high quality to UC
        $sequence = uc($sequence);
    }

    my $pads = &findlowquality($sequence,           # ? no test DNA
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
            $contig->addContigNote("low_quality_marked [$padsymbol]");
	}
    }

    $contig->setSequence($sequence);

    return $contig;
}

#-----------------------------------------------------------------------------
# removing reads from contigs
#-----------------------------------------------------------------------------

sub removeNamedReads {
# remove a list of reads from a contig
    my $class  = shift;
    my $contig = shift;
    my $reads = shift;
    my %options = @_;

    &verifyParameter($contig,'removeNamedReads');

# test for a read name/id or an array

    &verifyParameter($reads,'removeNamedReads','ARRAY') if ref($reads);

my $logger = &verifyLogger('removeNamedReads');
$logger->debug("ENTER");

    $contig = $contig->copy() if $options{new};

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

    $contig = $contig->copy() unless $options{nonew};

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
    my %options = @_; #

    &verifyParameter($contig,'removeShortReads');

    my $logger = &verifyLogger('removeShortReads');

    $contig->hasMappings(1); # delayed loading

    $contig = $contig->copy() unless $options{nonew};

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
                 . $contig->getNumberOfReads() . ")");

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
                .  $contig->getContigName());

    return $contig;
}

sub undoReadEdits {
# to be developed: restore edited reads to the original
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'undoReadEdits');

    my $logger = &verifyLogger('undoReadEdits');

$logger->warning("ENTER undoReadEdits: @_");

    my $reads = $contig->getReads(1); # delayed loading

    my $mappings = $contig->getMappings(1);

# get a list of edited reads

    my $readnamehash = {};
    my $readrankhash = {};
    for (my $i = 0 ; $i < scalar(@$reads) ; $i++) {
        my $read = $reads->[$i];
        next unless $read->isEdited();
$logger->warning("edited read detected : ".$read->getReadName());
        $readnamehash->{$read->getReadName()} = $read;
        $readrankhash->{$read} = $i;
    }

    return $contig unless scalar(keys %$readnamehash);

    $contig = $contig->copy() unless $options{nonew};

&verifyLogger('undoReadEdits');

# run throught the mappings to process the edited reads

    my $adb = $options{ADB}; # may be needed (ACTUALLY, can run without? if not in contig?)

    my $padmapping = new Mapping();

    foreach my $mapping (@$mappings) {
        my $readname = $mapping->getMappingName();
$logger->info("Testing $readname");
        if (my $read = $readnamehash->{$readname}) {

# get for each edited read the original read (version 0)
# note: is required because original may itself have an align to trace mapping

            my $original = $read->getOriginalVersion();
            if (!$original && $adb) { # recover if $read has no db handle
                $original = $adb->getRead(readname=>$readname);
            }
            unless ($original) {
                $logger->error("failure to retrieve original read");
                next; 
	    }
#$logger->debug("old mapping $mapping");
#$logger->debug($mapping->toString());

# translate the current mapping into a mapping to the original read

            my $edittotrace = $read->getAlignToTraceMapping();
#$logger->debug($edittotrace->toString());
            my $readtotrace = $original->getAlignToTraceMapping();
#$logger->debug($readtotrace->toString());
# new mapping C->R = C->E * E->T * (R->T)^-1
            my $interim = $mapping->multiply($edittotrace); 
#$logger->debug($interim->toString());
            my $newmapping = $interim->multiply($readtotrace->inverse());
$logger->debug("new mapping $newmapping");
$logger->debug($newmapping->toString());
# now replace the mapping and replace the edited read by the original
            $newmapping->setMappingName($readname);
            $newmapping->setSequenceID($read->getSequenceID());
            $mapping = $newmapping; # replaces array element

# analyse this mapping to see if and where pad(s) have to be inserted; these
# positions are charaterised by a gap on the read, but not on the contig

	    my $rank = $readrankhash->{$read};
            $reads->[$rank] = $original;
	}
    }

# finally multiply all mappings by the padding transform (using repair=1)

$logger->warning("undoReadEdits TO BE COMPLETED");


$logger->warning("EXIT undoReadEdits: @_");

    return $contig;
}

#-----------------------------------------------------------------------------

sub extractEndRegion {
# cut out the central part of the consensus and replace sequence by X-s in
# order to get a fixed length string which could be used in e.g. crossmatch
# returns a new contig object with only truncated sequence and quality data
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'extractEndRegion');

#    my $logger = &verifyLogger('extractEndRegion');
#$logger->error("ENTER: @_");

    my ($sequence,$quality) = &endregiononly($contig->getSequence(),
                                             $contig->getBaseQuality(),
                                             $options{endregionsize}, # def 100
                                             $options{sfill},  # def X
                                             $options{lfill},  # def 0
                                             $options{qfill}); # def 0
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
# helper method, private: generate masked sequence and quality data
    my $sequence = shift;
    my $quality  = shift;

    &verifyPrivate($sequence,'endregiononly');

# options

    my $ersize = shift || 100; # extracted length at either end
    my $symbol = shift || 'X'; # replacement symbol for central part
    my $centre = shift || 0;   # replace centre with string of this length
    my $qfill  = shift || 0;   # quality value to be used in centre

    &verifyPrivate($sequence,'endregiononly');

# apply lower limit, if shrink option active

    $centre = $ersize if ($centre < $ersize);

    my $length = length($sequence);

    if ($ersize > 0 && $symbol && $length > 2*$ersize) {

        my $begin  = substr $sequence,0,$ersize;
        my $centre = substr $sequence,$ersize,$length-2*$ersize;
        my $end = substr $sequence,$length-$ersize,$ersize;

# adjust the center, if shrink option

        if ($centre && $length-2*$ersize >= $centre) {
            $centre = '';
            while ($centre--) {
                $centre .= $symbol;
            }
        }
	else {
            $centre =~ s/./$symbol/g;
	}

        $sequence = $begin.$centre.$end;

# assemble new quality array, if an input was defined

        if ($quality) {

            my @newquality = @$quality[0 .. $ersize-1];
            my $length = length($centre);
            while ($length--) {
		push @newquality, $qfill;
	    }
            push @newquality, @$quality[$length-$ersize .. $length-1];

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

$logger->debug("ENTER: @_");

    my $clength = $contig->getConsensusLength();

    my $sequence = $contig->getSequence();

    my $basequality = $contig->getBaseQuality();

    my $mapping = &endregiontrim($sequence, $basequality, $options{cliplevel});

    unless ($sequence && $basequality && $mapping) {
        return undef,"Can't do trimming: missing quality data in "
                    . $contig->getContigName();
    }

    if (ref($mapping) ne 'Mapping') {
        return $contig, "No change";
    }

    my @crange = $mapping->getContigRange();

# create a new contig (BETTER: use copy, and nonew option)

    my $trimmedcontig = $contig;

    $trimmedcontig = $contig->copy(includeIDs=>1,nocomponents=>1) if $options{new};

    $trimmedcontig->setContigNote("endregiontrimmed [$options{cliplevel}]");

    $trimmedcontig->getContigName(); # ensure the contigname is defined

# if the standard components (read, mapping and tag) are required test/load them here
# the complete flag forces delayed loading if the components are absent

    my $load = $options{complete} || 0; 
    my $mappings = $trimmedcontig->getMappings($load);
    $load = 0 unless ($mappings && @$mappings);
    my $reads = $trimmedcontig->getReads($load);
    my $tags = $trimmedcontig->getTags($load);
# and erase the contig ID to make hereafter delayed loading impossible
    $trimmedcontig->setContigID();

# if the mappings are present, we now mask the mappings with the clipping range
# if the mappings are absent, we only mask the sequence

    if ($mappings && @$mappings) {

        my $mask = new Mapping('Masking map');
        $mask->putSegment(@crange,@crange);
print "mask mapping ".$mask->writeToString()."\n";

        my @deletereads;
        foreach my $mapping (@$mappings) {
            my $newmap = $mask->multiply($mapping);
            if ($newmap->hasSegments()) {
                my @isequal = $mapping->isEqual($newmap);
                next if ($isequal[0]);
#print "original mapping\n".$mapping->writeToString()."\n";
#print "masked  mapping\n".$newmap->writeToString()."\n";
#print STDOUT "mapping modified:\n".$mapping->writeToString()
#                             ."\n".$newmap->writeToString()."\n@isequal\n";
# replace the current map by the modified one
                $newmap->setMappingName($mapping->getMappingName());
                $mapping = $newmap;
                next; 
   	    }
# new mapping outside range, so delete read
print STDOUT "mapping to be deleted: ".$mapping->writeToString()."\n";
            push @deletereads,$mapping->getMappingName();
        }
# and use the statistic function to cleanup the contig
        $class->statistics($trimmedcontig,pass=>2);
    }

# the case where no mappings are available: only replace the sequence 

    else {
        my ($cstart,$cfinal) = @crange;
        my $newsequence = substr($sequence,$cstart-1,$cfinal-$cstart+1);
        my @newquality  = @$basequality [$cstart-1 .. $cfinal-1];
                        $contig->setBaseQuality(\@newquality);
                    $contig->setSequence($newsequence);
    }

    return $trimmedcontig, "clipped range @crange (1 - $clength)";
}

sub endregiontrim {
# helper method, private: trim low quality data from the end of the contig
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
# private methods
#-----------------------------------------------------------------------------

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

$logger->debug("reference $reference  sequence \n$sequence");

    for (my $i = $hwindow ; $i <= $qlength - $hwindow ; $i++) {
# test the base against accepted symbols ("high" quality pads)
        if ($sequence && substr($sequence, $i, 1) !~ /[$symbols]$/) {
# setting $highqualitypadminimum to 0 accepts ALL (non) matches as "real" pad
$logger->debug("base mismatch at $i");
            next unless ($quality->[$i] >= $highqualitypadminimum); # NOT LQ
$logger->debug("pad at $i");
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
# $logger->debug("begin LOG transform");
    foreach my $value (@$qinput) {
        my $logkey = int($value+$offset+0.5);
        unless ($logtransform = $loghash->{$logkey}) {
            $loghash->{$logkey} = log($logkey);
            $logtransform = $loghash->{$logkey};
# $logger->debug("creating log hash element for key $logkey"); 
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

        my $tags = $oldcontig->getTags();

        my $breaktags = $options{breaktags} || 'ANNO';
        $breaktags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $breaktags =~ s/\W+/|/g;

        my @newtags;
        foreach my $tag (@$tags) {
# special treatment for ANNO tags?
            my $tagtype = $tag->getType();
            if ($tagtype =~ /$breaktags/) {
                my $newtags = $tag->remap($ori2new,break=>1);
                push @newtags, @$newtags if $newtags;
            }
            else {
                my $newtags = $tag->remap($ori2new,break=>0);
                push @newtags, $newtags if $newtags;
	    }
	}

# test if some tags can be merged (using the Tag factory)

        my $mergetags = $options{mergetags} || 'ANNO';
        $mergetags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $mergetags =~ s/\W+/|/g;

        my @tags = TagFactory->mergeTags([@newtags],$mergetags);        

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

    &verifyPrivate($contig,"removereads");

    my $logger = &verifyLogger("removereads");
    $logger->debug("ENTER: $readrf");

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
# Padding
#-----------------------------------------------------------------------------

sub pad {
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'pad');

    print SDTERR "->pad not yet operational\n";
}

sub depad {
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'pad');

    print SDTERR "->pad not yet operational\n";
}

#-----------------------------------------------------------------------------
# operations on two contigs
#-----------------------------------------------------------------------------

sub isEqual {
# compare the $contig against $master Contig instances
# return 0 if different; return +1 or -1 if identical, -1 if inverted
    my $class = shift;
    my $master = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($master,'isEqual');
    &verifyParameter($contig,'isEqual');

    my $logger = &verifyLogger('isEqual');

# ensure that the metadata are defined; do not allow zeropoint adjustments here

    $master->getStatistics(1) unless $master->getReadOnLeft();
    $contig->getStatistics(1) unless $contig->getReadOnLeft();

# if no mappings available, the comparison can only be with the sequence

    unless ($contig->getReadOnLeft() && $master->getReadOnLeft()) {
        $logger->debug("Missing mappings in one or both contig(s)");
# if only one component has mappings, no comparison can be made
        unless ($options{sequenceonly}) {
            return 0 if ($contig->getReadOnLeft() || $master->getReadOnLeft());
	}
# try the sequence
$logger->debug("Trying sequence comparison TO BE DEVELOPED");
        my $mapping = Alignment->correlate(uc($master->getSequence()),undef,
                                           uc($contig->getSequence()),undef); 
# test mapping for length and orientation
        return 0;
    }

# test the length

    return 0 unless ($master->getConsensusLength() == $contig->getConsensusLength());

# test the end reads (allow for inversion)

    my $align;
    if ($contig->getReadOnLeft()  eq $master->getReadOnLeft() && 
        $contig->getReadOnRight() eq $master->getReadOnRight()) {
# if the contigs are identical they are aligned
        $align = 1;
    } 
    elsif ($contig->getReadOnLeft() eq $master->getReadOnRight() && 
           $contig->getReadOnRight() eq $master->getReadOnLeft()) {
# if the contigs are identical they are counter-aligned
        $align = -1;
    }
    else {
# the contigs are different
        return 0;
    }

# compare the mappings one by one
# mappings are identified using their sequence IDs or their readnames
# this assumes that both sets of mappings have the same type of data

    my $sequence = {};
    my $numberofmappings = 0;
    if (my $mappings = $master->getMappings()) {
        $numberofmappings = scalar(@$mappings);
        foreach my $mapping (@$mappings) {
            my $key = $mapping->getSequenceID();
            $sequence->{$key} = $mapping if $key;
            $key =  $mapping->getMappingName();
            $sequence->{$key} = $mapping if $key;
        }
    }

    undef my $shift;
    if (my $mappings = $contig->getMappings()) {
# check number of mappings
        return 0 if ($numberofmappings != scalar(@$mappings));

        foreach my $mapping (@$mappings) {
# find the corresponding mapping in $master Contig instance
            my $key = $mapping->getSequenceID() || $mapping->getMappingName();
            return undef unless defined($key); # incomplete Mapping
            my $match = $sequence->{$key};
            return 0 unless defined($match); # there is no counterpart in $master
# compare the two maps
            my ($identical,$aligned,$offset) = $match->isEqual($mapping);
            return 0 unless $identical;
# on first one register shift
            $shift = $offset unless defined($shift);
# the alignment and offsets between the mappings must all be identical
# i.e.: for the same contig: 1,0; for the same contig inverted: -1, some value 
            return 0 if ($align != $aligned || $shift != $offset);
        }
    }

# returns true  if the mappings are all identical
# returns undef if no or invalid mappings found in the $contig Contig instance
# returns false (but defined = 0) if any mismatch found between mappings

    return $align; # 1 for identical, -1 for identical but inverted
}   

# TO BE TESTED ##################################################################

sub crossmatch {
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# if any, mapping from $compare to $this contig
# returns the number of mapped segments; returns undef if 
# incomplete Contig instances or missing sequence IDs in mappings
    my $class = shift;
    my $cthis = shift;
    my $cthat = shift; # Contig instance to be compared to $thiscontig
    my %options = @_;

    &verifyParameter($cthis,'crossmatch 1-st parameter');

    &verifyParameter($cthat,'crossmatch 2-nd parameter');
# option strong       : set True for comparison at read mapping level
# option readclipping : if set, require a minumum number of reads in C2C segment

    my $logger = &verifyLogger('crossmatch');
$logger->debug("ENTER");

# remove later from HERE
    return &newLinkToContig($class,$cthis,$cthat,@_) if $options{new};

    return &linkToContig($class,$cthis,$cthat,@_);
$logger->debug("EXIT");
# if no link yet, try Alignment on consnesus?
}


sub newLinkToContig {
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# if any, mapping from $compare to $cthis contig
# returns the number of mapped segments; returns undef if 
# incomplete Contig instances or missing sequence IDs in mappings
    my $class = shift;
    my $cthis = shift;
    my $cthat = shift; # Contig instance to be compared to $cthis
    my %options = @_;

# option strong       : set True for comparison at read mapping level
# option readclipping : if set, require a minumum number of reads in C2C segment

    &verifyParameter($cthis,'newLink 1-st parameter');

    &verifyParameter($cthat,'newLink 2-nd parameter');
# TO HERE

my $DEBUG = &verifyLogger('newLinkToContig');

$DEBUG->debug("ENTER");

# test completeness

    return undef unless $cthis->hasMappings(); 
    return undef unless $cthat->hasMappings();

# make the comparison using sequence ID; start by getting an inventory of $cthis
# we build a hash on sequence ID values & one for back up on mapping(read)name

    my $sequencehash = {};
    my $readnamehash = {};
    my $lmappings = $cthis->getMappings();
    foreach my $mapping (@$lmappings) {
        my $seq_id = $mapping->getSequenceID();
        $sequencehash->{$seq_id} = $mapping if $seq_id;
        $seq_id = $mapping->getMappingName();
        $readnamehash->{$seq_id} = $mapping if $seq_id;
    }

# make an inventory hash of (identical) alignments from $cthat to $cthis

    my $alignment = 0;
    my $inventory = {};
    my $accumulate = {};
    my $deallocated = 0;
    my $overlapreads = 0;
    my $cmappings = $cthat->getMappings();
    foreach my $mapping (@$cmappings) {
        my $oseq_id = $mapping->getSequenceID();
        unless (defined($oseq_id)) {
            print STDERR "Incomplete Mapping ".$mapping->getMappingName."\n";
            return undef; # abort: incomplete Mapping; should never occur!
        }
        my $complement = $sequencehash->{$oseq_id};
        unless (defined($complement)) {
# the read in the parent is not identified in this contig; this can be due
# to several causes: the most likely ones are: 1) the read is deallocated
# from the previous assembly, or 2) the read sequence was edited and hence
# its seq_id has been changed and thus is not recognized in the parent; 
# we can decide between these cases by looking at the readnamehash
            my $readname = $mapping->getMappingName();
            my $readnamematch = $readnamehash->{$readname};
            unless (defined($readnamematch)) {
# it's a de-allocated read, except possibly in the case of a split parent
                $deallocated++; 
                next;
	    }
# ok, the readnames match, but the sequences not: its a (new) edited sequence
# we now use the align-to-trace mapping between the sequences and the original
# trace file in order to find the contig-to-contig alignment defined by this read 
            my $eseq_id = $readnamematch->getSequenceID(); # (newly) edited sequence
# check the existence of the database handle in order to get at the read versions
            unless ($cthis->{ADB}) {
		print STDERR "Unable to recover C2C link for read $readname "
                           . ": missing database handle\n";
		next;
            }
# get the versions of this read in a hash keyed on sequence IDs
            my $reads = $cthis->{ADB}->getAllVersionsOfRead(readname=>$readname);
# test if both reads are found, just to be sure
            unless ($reads->{$oseq_id} && $reads->{$eseq_id}) {
		print STDERR "Cannot recover sequence $oseq_id or $eseq_id "
                           . "for read $readname\n";
		next;
	    }
# pull out the align-to-SCF as mappings
            my $omapping = $reads->{$oseq_id}->getAlignToTraceMapping(); # original
            my $emapping = $reads->{$eseq_id}->getAlignToTraceMapping(); # edited
#****
#        - find the proper chain of multiplication to get the new mapping 
if ($DEBUG) {
 print STDOUT "Missing match for sequence ID $oseq_id\n"; 
 print STDOUT "But the readnames do match : $readname\n";
 print STDOUT "sequences: parent $oseq_id   child (edited) $eseq_id\n";
 print STDOUT "original Align-to-SCF:".$omapping->toString();
 print STDOUT "edited   Align-to-SCF:".$emapping->toString();
}
else {
 print STDERR "Recovering link for read $readname (seqs:$oseq_id, $eseq_id)\n";
}
#        - assign this new mapping to $complement
	    $complement = $readnamematch;
# to be removed later (fix only for single read parents, for the moment)
            next if (@$lmappings>1 && @$cmappings>1);
print STDOUT "sequences equated to one another (temporary fix)\n" if $DEBUG;
print STDERR "sequences equated to one another (temporary fix)\n" unless $DEBUG;
#****
        }
# count the number of reads in the overlapping area
        $overlapreads++;

# this mapping/sequence in $cthat also figures in the current Contig

        if ($options{strong}) {
# strong comparison: test for identical mappings (apart from shift)
            my ($identical,$aligned,$offset) = $complement->isEqual($mapping);

# keep the first encountered (contig-to-contig) alignment value != 0 

            $alignment = $aligned unless $alignment;
            next unless ($identical && $aligned == $alignment);

# the mappings are identical (alignment and segment sizes)

            my @segment = $mapping->getContigRange();
# build a hash key based on offset and alignment direction and add segment
            my $hashkey = sprintf("%08d",$offset);
            $inventory->{$hashkey} = [] unless defined $inventory->{$hashkey};
            push @{$inventory->{$hashkey}},[@segment];
            $accumulate->{$hashkey}  = 0 unless $accumulate->{$hashkey};
            $accumulate->{$hashkey} += abs($segment[1]-$segment[0]+1);
        }

# otherwise do a segment-by-segment comparison and find ranges of identical mapping

        else {
# return the ** local ** contig-to-parent mapping as a Mapping object
            my $cpmapping = $complement->compare($mapping);
            my $cpaligned = $cpmapping->getAlignment();

unless ($cpaligned || $cthat->getNumberOfReads() > 1) {
    print STDERR "Non-overlapping read segments for single-read parent contig ".
                  $cthat->getContigID()."\n";
    if ($DEBUG) {
        print STDOUT "parent mapping:".$mapping->toString();
        print STDOUT "contig mapping:".$complement->toString();
        print STDOUT "c-to-p mapping:".$cpmapping->toString();
    }    
}

            next unless defined $cpaligned; # empty cross mapping

# keep the first encountered (contig-to-contig) alignment value != 0

            $alignment = $cpaligned unless $alignment;

            next unless ($alignment && $cpaligned == $alignment);

# process the mapping segments and add to the inventory

            my $osegments = $cpmapping->normaliseOnX() || next; # returns array

            foreach my $osegment (@$osegments) {
                my $offset = $osegment->getOffset();
                $offset = (-$offset+0); # conform to offset convention in this method
                my $hashkey = sprintf("%08d",$offset);
                $inventory->{$hashkey} = [] unless $inventory->{$hashkey};
                my @segment = ($osegment->getXstart(),$osegment->getXfinis());
                push @{$inventory->{$hashkey}},[@segment];
                $accumulate->{$hashkey}  = 0 unless $accumulate->{$hashkey};
                $accumulate->{$hashkey} += abs($segment[1]-$segment[0]+1);
	    }
        }
    }

# OK, here we have an inventory: the number of keys equals the number of 
# different alignments between $cthis and $cthat. On each key we have an
# array of arrays with the individual mapping data. For each alignment we
# determine if the covered interval is contiguous. For each such interval
# we add a (contig) Segment alignment to the output mapping
# NOTE: the table can be empty, which occurs if all reads in the current Contig
# have their mappings changed compared with the previous contig 

# if the alignment offsets vary too much, investigate further

    my @offsets = sort { $a <=> $b } keys %$inventory;
    my $offsetwindow = $options{offsetwindow};
    $offsetwindow = 40 unless $offsetwindow;
    my ($lower,$upper) = (0,0); # default no offset range window
    my $minimumsize = 1; # lowest accepted segment size
    my $threshold = $options{correlation} || 0.75;
    my $defects = $options{defects} || 5;

    if (@offsets && ($offsets[$#offsets] - $offsets[0]) >= $offsetwindow) {
# the offset values vary too much; check how they correlate with position:
# if no good correlation found the distribution is dodgy, then use a window 
# based on the median offset and the nominal range
        my $sumpp = 0.0; # for sum position**2
        my $sumoo = 0.0; # for sum offset*2
        my $sumop = 0.0; # for sum offset*position
        my $weightedsum = 0;
        my $penalty = 0;
        my @ph; # position history
        foreach my $offset (@offsets) {
            $weightedsum += $accumulate->{$offset};
            my $segmentlist = $inventory->{$offset};
$DEBUG->fine("CM offset $offset  segmentlist before ".scalar(@$segmentlist)) if $DEBUG;
            $segmentlist = &cleanupsegmentlist($segmentlist,);
$DEBUG->fine("CM offset $offset  segmentlist  after ".scalar(@$segmentlist)) if $DEBUG;
            unless ($segmentlist && @$segmentlist) {
   	        print STDERR "unexpectedly NO SEGMENTLIST for offset $offset\n";
                next;
	    }
            my $psum = 0; # re: average position
            foreach my $mapping (@$segmentlist) {
$DEBUG->fine("CM offset $offset cleaned mapping @$mapping") if $DEBUG;
                my $position = 0.5 * ($mapping->[0] + $mapping->[1]);
                $sumpp += $position * $position; # weighted?
                $sumop += $position * $offset;
                $sumoo += $offset * $offset;
                $psum += $position;
            }
# collect penalties (if any) if several segments for same offset
            my $numberofsegments = scalar(@$segmentlist);
            if ($numberofsegments > 1) {
                $penalty += $numberofsegments - 1;
                $psum /= $numberofsegments;
	    }
            unshift @ph,$psum; # put new position upfront
# collect penalties for reversals of direction
            next unless (@ph > 2);
# check ordering and apply penalty for position ordering reversal
            if (($ph[0]-$ph[1])*($ph[1]-$ph[2]) < 0) {
$DEBUG->warning("Inversion detected $ph[0] $ph[1] $ph[2]") if $DEBUG;
                $penalty++;
	    }
        }
# get the correlation coefficient
        my $threshold = $options{correlation} || 0.75;
        my $R = $sumop / sqrt($sumpp * $sumoo);
$DEBUG->warning("Correlation coefficient = $R  penalty $penalty") if $DEBUG;
# if CC too small, apply lower and upper boundary to offset
        unless (abs($R) >= $threshold) {
# relation offset-position looks messy
            print STDERR "Suspect correlation coefficient = $R : target "
                       . $cthat->getContigName()." (penalty = $penalty)\n";
# accept the alignment if no penalties are incurred (monotonous alignment)
            if ($penalty > $defects) {
# set up for offset masking
                print STDOUT "Suspect correlation coefficient = $R : target "
                            . $cthat->getContigName()." (penalty = $penalty)\n";
$DEBUG->warning("Offset masking activated") if $DEBUG;
                my $partialsum = 0;
                foreach my $offset (@offsets) { 
                    $partialsum += $accumulate->{$offset};
                    next if ($partialsum < $weightedsum/2);
# the first offset here is the median
                    $lower = $offset - $offsetwindow/2; 
                    $upper = $offset + $offsetwindow/2;
$DEBUG->fine("median: $offset ($lower $upper)") if $DEBUG;
                    $minimumsize = $options{segmentsize} || 2;
                    last;
		}
	    }
        }
    }

# determine guillotine; accept only alignments with a minimum number of reads 

    my $guillotine = 0;
    if ($options{readclipping}) {
        $guillotine = 1 + log(scalar(@$cmappings)); 
# adjust for small numbers (2 and 3)
        $guillotine -= 1 if ($guillotine > scalar(@$cmappings) - 1);
        $guillotine  = 2 if ($guillotine < 2); # minimum required
    }

# go through all offset values and collate the mapping segments;
# if the offset falls outside the offset range window, we are probably
# dealing with data arising from mis-assembled reads, resulting in
# outlier offset values and messed-up rogue alignment segments. We will
# ignore regular segments which straddle the bad mapping range

    my $rtotal = 0;
    my @c2csegments; # for the regular segments
    my $poormapping = new Mapping("Bad Mapping"); # for bad mapping range
#    my $goodmapping = new Mapping("Good Mapping");
$DEBUG->warning("Testing offsets") if $DEBUG;
    foreach my $offset (@offsets) {
# apply filter if boundaries are defined
        my $outofrange = 0;
        if (($lower != $upper) && ($offset < $lower || $offset > $upper)) {
            $outofrange = 1; # outsize offset range, probably dodgy mapping
$DEBUG->warning("offset $offset out of range $lower $upper") if $DEBUG;
        }
# sort mappings according to increasing contig start position
        my @mappings = sort { $a->[0] <=> $b->[0] } @{$inventory->{$offset}};
        my $nreads = 0; # counter of reads in current segment
        my $segmentstart = $mappings[0]->[0];
        my $segmentfinis = $mappings[0]->[1];
        foreach my $interval (@mappings) {
            my $intervalstart = $interval->[0];
            my $intervalfinis = $interval->[1];
            next unless defined($intervalstart);
            next unless defined($segmentfinis);
# break of coverage is indicated by begin of interval beyond end of previous
            if ($intervalstart > $segmentfinis) {
# add segmentstart - segmentfinis as mapping segment
                my $size = abs($segmentfinis-$segmentstart) + 1;
                if ($nreads >= $guillotine && $size >= $minimumsize) {
                    my $start = ($segmentstart + $offset) * $alignment;
                    my $finis = ($segmentfinis + $offset) * $alignment;
		    my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
                    push @c2csegments,[@segment]  unless $outofrange;
                    $poormapping->putSegment(@segment) if $outofrange;
                }
# initialize the new mapping interval
                $nreads = 0;
                $segmentstart = $intervalstart;
                $segmentfinis = $intervalfinis;
            }
            elsif ($intervalfinis > $segmentfinis) {
                $segmentfinis = $intervalfinis;
            }
            $nreads++;
            $rtotal++;
        }
# add segmentstart - segmentfinis as (last) mapping segment
        next unless ($nreads >= $guillotine);
        my $size = abs($segmentfinis-$segmentstart) + 1;
        next unless ($size >= $minimumsize);
        my $start = ($segmentstart + $offset) * $alignment;
        my $finis = ($segmentfinis + $offset) * $alignment;
        my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
        push @c2csegments,[@segment]  unless $outofrange;
#        $goodmapping->putSegment(@segment) unless $outofrange;
        $poormapping->putSegment(@segment) if $outofrange;
    }

# if there are rogue mappings, determine the contig range affected

    my @badmap;
    if ($poormapping->hasSegments()) {
# the contig interval covered by the bad mapping
        @badmap = $poormapping->getContigRange() unless $options{nobadrange};
# subsequently we could use this interval to mask the regular mappings found
$DEBUG->warning("checking bad mapping range") if $DEBUG;
$DEBUG->warning($poormapping->writeToString('bad range')) if $DEBUG;
$DEBUG->warning("bad contig range: @badmap") if $DEBUG;
    }

# the segment list now may on rare occasions (but in particular when
# there is a bad mapping range) contain overlapping segments where
# the position of overlap have conflicting boundaries, and therefore 
# have to be removed or pruned by adjusting the interval boundaries

# the folowing requires segment data sorted according to increasing X values

    foreach my $segment (@c2csegments) {
        my ($xs,$xf,$ys,$yf,$s) = @$segment;
        @$segment = ($xf,$xs,$yf,$ys,$s) if ($xs > $xf);
    }

    @c2csegments = sort {$a->[0] <=> $b->[0]} @c2csegments;

$DEBUG->warning(scalar(@c2csegments)." segments; before pruning") if $DEBUG;

    my $j =1;
    while ($j < @c2csegments) {
        my $i = $j - 1;
        my $cthis = $c2csegments[$i];
        my $next = $c2csegments[$j];
# first remove segments which completely fall inside another
        if ($cthis->[0] <= $next->[0] && $cthis->[1] >= $next->[1]) {
# the next segment falls completely inside this segment; remove $next
            splice @c2csegments, $j, 1;
#            next;
        }
        elsif ($cthis->[0] >= $next->[0] && $cthis->[1] <= $next->[1]) {
# this segment falls completely inside the next segment; remove $cthis
            splice @c2csegments, $i, 1;
#            next;
        }
        elsif (@badmap && $next->[0] >= $badmap[0] && $next->[1] <= $badmap[1]) {
# the next segment falls completely inside the bad mapping range: remove $next
            splice @c2csegments, $j, 1;
        }
        else {
# this segment overlaps at the end with the beginning of the next segment: prune
            while ($alignment > 0 && $cthis->[1] >= $next->[0]) {
                $cthis->[1]--;
                $cthis->[3]--;
                $next->[0]++;
                $next->[2]++;
  	    }
# the counter-aligned case
            while ($alignment < 0 && $cthis->[1] >= $next->[0]) {
                $cthis->[1]--;
                $cthis->[3]++;
                $next->[0]++;
                $next->[2]--;
	    }
            $j++;
	}
    }

$DEBUG->warning(scalar(@c2csegments)." segments after pruning") if $DEBUG;

# create an output Mapping enter the segments

    my $mapping = new Mapping($cthat->getContigName());
    $mapping->setSequenceID($cthat->getContigID());

    foreach my $segment (@c2csegments) {
$DEBUG->warning("segment after filter @$segment") if $DEBUG;
        next if ($segment->[1] < $segment->[0]); # segment pruned out of existence
        $mapping->putSegment(@$segment);
    }

# use the normalise method to handle possible single-base segments

    $mapping->normalise();

    if ($mapping->hasSegments()) {
# here, test if the mapping is valid, using the overall maping range
        my ($isValid,$msg) = &isValidMapping($cthis,$cthat,$mapping,$overlapreads);
$DEBUG->warning("\n isVALIDmapping $isValid\n$msg") if $DEBUG;
# here possible recovery based on analysis of continuity of mapping segments

# if still not valid, 
        if (!$isValid && !$options{forcelink}) {
$DEBUG->warning("Spurious link detected to contig ".$cthat->getContigName()) if $DEBUG;
            return 0, $overlapreads;
        }
# in case of split contig
        elsif ($isValid == 2) {
$DEBUG->warning("(Possibly) split parent contig ".$cthat->getContigName()) if $DEBUG;
            $deallocated = 0; # because we really don't know
        }
# for a regular link
        else {
            $deallocated = $cthat->getNumberOfReads() - $overlapreads; 
        }
# store the Mapping as a contig-to-contig mapping (prevent duplicates)
        if ($cthis->hasContigToContigMappings()) {
            my $c2cmaps = $cthis->getContigToContigMappings();
            foreach my $c2cmap (@$c2cmaps) {
                my ($isEqual,@dummy) = $mapping->isEqual($c2cmap,silent=>1);
                next unless $isEqual;
                next if ($mapping->getSequenceID() != $c2cmap->getSequenceID());
                print STDERR "Duplicate mapping to parent " .
		             $cthat->getContigName()." ignored\n";
if ($DEBUG) {
 $DEBUG->warning("Duplicate mapping to parent " .
	       $cthat->getContigName()." ignored");
 $DEBUG->warning("existing Mappings: @$c2cmaps");
 $DEBUG->warning("to be added Mapping: $mapping, tested against $c2cmap");
 $DEBUG->warning("equal mappings: \n".$mapping->toString()."\n".$c2cmap->toString());
}
                return $mapping->hasSegments(),$deallocated;
            }
        }
        $cthis->addContigToContigMapping($mapping);
# what about the parent?
    }

# and return the number of segments, which could be 0

$DEBUG->debug("EXIT");
   return $mapping->hasSegments(),$deallocated;

# if the mapping has no segments, no mapping range could be determined
# by the algorithm above. If the 'strong' mode was used, perhaps the
# method should be re-run in standard (strong=0) mode

}


sub linkToContig { # will be REDUNDENT
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# if any, mapping from $compare to $this contig
# returns the number of mapped segments (usually 1); returns undef if 
# incomplete Contig instances or missing sequence IDs in mappings
    my $class = shift;
    my $this = shift;
    my $compare = shift; # Contig instance to be compared to $this
    my %options = @_;

# option strong       : set True for comparison at read mapping level
# option readclipping : if set, require a minumum number of reads in C2C segment

    die "$this takes a Contig instance" unless (ref($compare) eq 'Contig');

my $DEBUG = &verifyLogger('linkToContig');
$DEBUG->debug("ENTER");

# test completeness

    return undef unless $this->hasMappings(); 
    return undef unless $compare->hasMappings();

# make the comparison using sequence ID; start by getting an inventory of $this
# we build a hash on sequence ID values & one for back up on mapping(read)name

    my $sequencehash = {};
    my $readnamehash = {};
    my $lmappings = $this->getMappings();
    foreach my $mapping (@$lmappings) {
        my $seq_id = $mapping->getSequenceID();
        $sequencehash->{$seq_id} = $mapping if $seq_id;
        my $map_id = $mapping->getMappingName();
        $readnamehash->{$map_id} = $mapping if $map_id;
    }

# make an inventory hash of (identical) alignments from $compare to $this

    my $alignment = 0;
    my $inventory = {};
    my $accumulate = {};
    my $deallocated = 0;
    my $overlapreads = 0;
    my $cmappings = $compare->getMappings();
    foreach my $mapping (@$cmappings) {
        my $oseq_id = $mapping->getSequenceID();
        unless (defined($oseq_id)) {
            print STDOUT "Incomplete Mapping ".$mapping->getMappingName."\n";
            return undef; # abort: incomplete Mapping; should never occur!
        }
        my $complement = $sequencehash->{$oseq_id};
        unless (defined($complement)) {
# the read in the parent is not identified in this contig; this can be due
# to several causes: the most likely ones are: 1) the read is deallocated
# from the previous assembly, or 2) the read sequence was edited and hence
# its seq_id has been changed and thus is not recognized in the parent; 
# we can decide between these cases by looking at the readnamehash
            my $readname = $mapping->getMappingName();
            my $readnamematch = $readnamehash->{$readname};
            unless (defined($readnamematch)) {
# it's a de-allocated read, except possibly in the case of a split parent
                $deallocated++; 
                next;
	    }
# ok, the readnames match, but the sequences not: its a (new) edited sequence
# we now use the align-to-trace mapping between the sequences and the original
# trace file in order to find the contig-to-contig alignment defined by this read 
            my $eseq_id = $readnamematch->getSequenceID(); # (newly) edited sequence
# check the existence of the database handle in order to get at the read versions
            unless ($this->{ADB}) {
		print STDERR "Unable to recover C2C link for read $readname "
                           . ": missing database handle\n";
		next;
            }
# get the versions of this read in a hash keyed on sequence IDs
            my $reads = $this->{ADB}->getAllVersionsOfRead(readname=>$readname);
# test if both reads are found, just to be sure
            unless ($reads->{$oseq_id} && $reads->{$eseq_id}) {
		print STDERR "Cannot recover sequence $oseq_id or $eseq_id "
                           . "for read $readname\n";
		next;
	    }
# pull out the align-to-SCF as mappings
            my $omapping = $reads->{$oseq_id}->getAlignToTraceMapping(); # original
            my $emapping = $reads->{$eseq_id}->getAlignToTraceMapping(); # edited
#****
#        - find the proper chain of multiplication to get the new mapping 
if ($DEBUG) {
 $DEBUG->info("Missing match for sequence ID $oseq_id"); 
 $DEBUG->info("But the readnames do match : $readname");
 $DEBUG->info("sequences: parent $oseq_id   child (edited) $eseq_id");
 $DEBUG->info("original Align-to-SCF:".$omapping->toString());
 $DEBUG->info("edited   Align-to-SCF:".$emapping->toString());
}
else {
 print STDERR "Recovering link for read $readname (seqs:$oseq_id, $eseq_id)\n";
}
#        - assign this new mapping to $complement
	    $complement = $readnamematch;
# to be removed later (fix only for single read parents, for the moment)
            next if (@$lmappings>1 && @$cmappings>1);
$DEBUG->info("sequences equated to one another (temporary fix)") if $DEBUG;
print STDERR "sequences equated to one another (temporary fix)\n" unless $DEBUG;
#****
        }
# count the number of reads in the overlapping area
        $overlapreads++;

# this mapping/sequence in $compare also figures in the current Contig

        if ($options{strong}) {
# strong comparison: test for identical mappings (apart from shift)
            my ($identical,$aligned,$offset) = $complement->isEqual($mapping);

# keep the first encountered (contig-to-contig) alignment value != 0 

            $alignment = $aligned unless $alignment;
            next unless ($identical && $aligned == $alignment);

# the mappings are identical (alignment and segment sizes)

            my @segment = $mapping->getContigRange();
# build a hash key based on offset and alignment direction and add segment
            my $hashkey = sprintf("%08d",$offset);
            $inventory->{$hashkey} = [] unless defined $inventory->{$hashkey};
            push @{$inventory->{$hashkey}},[@segment];
            $accumulate->{$hashkey}  = 0 unless $accumulate->{$hashkey};
            $accumulate->{$hashkey} += abs($segment[1]-$segment[0]+1);
        }

# otherwise do a segment-by-segment comparison and find ranges of identical mapping

        else {
# return the ** local ** contig-to-parent mapping as a Mapping object
            my $cpmapping = $complement->compare($mapping);
            next unless $cpmapping;
            my $cpaligned = $cpmapping->getAlignment();

unless ($cpaligned || $compare->getNumberOfReads() > 1) {
    print STDERR "Non-overlapping read segments for single-read parent contig ".
                  $compare->getContigID()."\n";
    if ($DEBUG) {
        $DEBUG->info("parent mapping:".$mapping->toString());
        $DEBUG->info("contig mapping:".$complement->toString());
        $DEBUG->info("c-to-p mapping:".$cpmapping->toString());
    }    
}

            next unless defined $cpaligned; # empty cross mapping

# keep the first encountered (contig-to-contig) alignment value != 0

            $alignment = $cpaligned unless $alignment;

            next unless ($alignment && $cpaligned == $alignment);

# process the mapping segments and add to the inventory

            my $osegments = $cpmapping->normaliseOnX() || next;

            foreach my $osegment (@$osegments) {
                my $offset = $osegment->getOffset();
                $offset = (-$offset+0); # conform to offset convention in this method
                my $hashkey = sprintf("%08d",$offset);
                $inventory->{$hashkey} = [] unless $inventory->{$hashkey};
                my @segment = ($osegment->getXstart(),$osegment->getXfinis());
                push @{$inventory->{$hashkey}},[@segment];
                $accumulate->{$hashkey}  = 0 unless $accumulate->{$hashkey};
                $accumulate->{$hashkey} += abs($segment[1]-$segment[0]+1);
	    }
        }
    }

# OK, here we have an inventory: the number of keys equals the number of 
# different alignments between $this and $compare. On each key we have an
# array of arrays with the individual mapping data. For each alignment we
# determine if the covered interval is contiguous. For each such interval
# we add a (contig) Segment alignment to the output mapping
# NOTE: the table can be empty, which occurs if all reads in the current Contig
# have their mappings changed compared with the previous contig 

    my $mapping = new Mapping($compare->getContigName());
    $mapping->setSequenceID($compare->getContigID());

# determine guillotine; accept only alignments with a minimum number of reads 

    my $guillotine = 0;
    if ($options{readclipping}) {
        $guillotine = 1 + log(scalar(@$cmappings)); 
# adjust for small numbers (2 and 3)
        $guillotine -= 1 if ($guillotine > scalar(@$cmappings) - 1);
        $guillotine  = 2 if ($guillotine < 2); # minimum required
    }

# if the alignment offsets vary too much apply a window

    my @offsets = sort { $a <=> $b } keys %$inventory;
    my $offsetwindow = $options{offsetwindow};
    $offsetwindow = 40 unless $offsetwindow;
    my ($lower,$upper) = (0,0); # default no offset range window
    my $minimumsize = 1; # lowest accepted segment size

    if (@offsets && ($offsets[$#offsets] - $offsets[0]) >= $offsetwindow) {
# the offset values vary too much; check how they correlate with position:
# if no good correlation found the distribution is dodgy, then use a window 
# based on the median offset and the nominal range
        my $sumpp = 0.0; # for sum position**2
        my $sumoo = 0.0; # for sum offset*2
        my $sumop = 0.0; # for sum offset*position
        my $weightedsum = 0;
        foreach my $offset (@offsets) {
            $weightedsum += $accumulate->{$offset};
            my $segmentlist = $inventory->{$offset};
            foreach my $mapping (@$segmentlist) {
$DEBUG->fine("offset $offset mapping @$mapping") if $DEBUG;
                my $position = 0.5 * ($mapping->[0] + $mapping->[1]);
                $sumpp += $position * $position;
                $sumop += $position * $offset;
                $sumoo += $offset * $offset;
            }
        }
# get the correlation coefficient
        my $threshold = $options{correlation} || 0.75;
        my $R = $sumop / sqrt($sumpp * $sumoo);
$DEBUG->info("Correlation coefficient = $R\n") if $DEBUG;
        unless (abs($sumop / sqrt($sumpp * $sumoo)) >= $threshold) {
# relation offset-position looks messy: set up for offset masking
            my $partialsum = 0;
            foreach my $offset (@offsets) { 
                $partialsum += $accumulate->{$offset};
                next if ($partialsum < $weightedsum/2);
# the first offset here is the median
                $lower = $offset - $offsetwindow/2; 
                $upper = $offset + $offsetwindow/2;
$DEBUG->info("median: $offset ($lower $upper)") if $DEBUG;
                $minimumsize = $options{segmentsize} || 2;
                last;
	    }
        }
    }

# go through all offset values and collate the mapping segments;
# if the offset falls outside the offset range window, we are probably
# dealing with data arising from mis-assembled reads, resulting in
# outlier offset values and messed-up rogue alignment segments. We will
# ignore regular segments which straddle the bad mapping range

    my $rtotal = 0;
    my @c2csegments; # for the regular segments
    my $badmapping = new Mapping("Bad Mapping"); # for bad mapping range
    foreach my $offset (@offsets) {
# apply filter if boundaries are defined
        my $outofrange = 0;
$DEBUG->info("Testing offset $offset") if $DEBUG;
        if (($lower != $upper) && ($offset < $lower || $offset > $upper)) {
            $outofrange = 1; # outsize offset range, probably dodgy mapping
$DEBUG->info("offset out of range $offset") if $DEBUG;
        }
# sort mappings according to increasing contig start position
        my @mappings = sort { $a->[0] <=> $b->[0] } @{$inventory->{$offset}};
        my $nreads = 0; # counter of reads in current segment
        my $segmentstart = $mappings[0]->[0];
        my $segmentfinis = $mappings[0]->[1];
        foreach my $interval (@mappings) {
            my $intervalstart = $interval->[0];
            my $intervalfinis = $interval->[1];
            next unless defined($intervalstart);
            next unless defined($segmentfinis);
# break of coverage is indicated by begin of interval beyond end of previous
            if ($intervalstart > $segmentfinis) {
# add segmentstart - segmentfinis as mapping segment
                my $size = abs($segmentfinis-$segmentstart) + 1;
                if ($nreads >= $guillotine && $size >= $minimumsize) {
                    my $start = ($segmentstart + $offset) * $alignment;
                    my $finis = ($segmentfinis + $offset) * $alignment;
		    my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
                    push @c2csegments,[@segment]  unless $outofrange;
                    $badmapping->putSegment(@segment) if $outofrange;
                }
# initialize the new mapping interval
                $nreads = 0;
                $segmentstart = $intervalstart;
                $segmentfinis = $intervalfinis;
            }
            elsif ($intervalfinis > $segmentfinis) {
                $segmentfinis = $intervalfinis;
            }
            $nreads++;
            $rtotal++;
        }
# add segmentstart - segmentfinis as (last) mapping segment
        next unless ($nreads >= $guillotine);
        my $size = abs($segmentfinis-$segmentstart) + 1;
        next unless ($size >= $minimumsize);
        my $start = ($segmentstart + $offset) * $alignment;
        my $finis = ($segmentfinis + $offset) * $alignment;
        my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
        push @c2csegments,[@segment]  unless $outofrange;
        $badmapping->putSegment(@segment) if $outofrange;
    }

# if there are rogue mappings, determine the contig range affected

    my @badmap;
    if ($badmapping->hasSegments()) {
# the contig interval covered by the bad mapping
        @badmap = $badmapping->getContigRange() unless $options{nobadrange};
# subsequently we could use this interval to mask the regular mappings found
$DEBUG->info("checking bad mapping range") if $DEBUG;
$DEBUG->info($badmapping->writeToString('bad range')) if $DEBUG;
$DEBUG->info("bad contig range: @badmap") if $DEBUG;
    }

# the segment list now may on rare occasions (but in particular when
# there is a bad mapping range) contain overlapping segments where
# the position of overlap have conflicting boundaries, and therefore 
# have to be removed or pruned by adjusting the interval boundaries

# the folowing requires segment data sorted according to increasing X values

    foreach my $segment (@c2csegments) {
        my ($xs,$xf,$ys,$yf,$s) = @$segment;
        @$segment = ($xf,$xs,$yf,$ys,$s) if ($xs > $xf);
    }

    @c2csegments = sort {$a->[0] <=> $b->[0]} @c2csegments;

$DEBUG->info(scalar(@c2csegments)." segments; before pruning") if $DEBUG;

    my $j =1;
    while ($j < @c2csegments) {
        my $i = $j - 1;
        my $this = $c2csegments[$i];
        my $next = $c2csegments[$j];
# first remove segments which completely fall inside another
        if ($this->[0] <= $next->[0] && $this->[1] >= $next->[1]) {
# the next segment falls completely inside this segment; remove $next
            splice @c2csegments, $j, 1;
#            next;
        }
        elsif ($this->[0] >= $next->[0] && $this->[1] <= $next->[1]) {
# this segment falls completely inside the next segment; remove $this
            splice @c2csegments, $i, 1;
#            next;
        }
        elsif (@badmap && $next->[0] >= $badmap[0] && $next->[1] <= $badmap[1]) {
# the next segment falls completely inside the bad mapping range: remove $next
            splice @c2csegments, $j, 1;
        }
        else {
# this segment overlaps at the end with the beginning of the next segment: prune
            while ($alignment > 0 && $this->[1] >= $next->[0]) {
                $this->[1]--;
                $this->[3]--;
                $next->[0]++;
                $next->[2]++;
  	    }
# the counter-aligned case
            while ($alignment < 0 && $this->[1] >= $next->[0]) {
                $this->[1]--;
                $this->[3]++;
                $next->[0]++;
                $next->[2]--;
	    }
            $j++;
	}
    }

$DEBUG->info(scalar(@c2csegments)." segments after pruning") if $DEBUG;

# enter the segments to the mapping

    foreach my $segment (@c2csegments) {
$DEBUG->fine("segment after filter @$segment") if $DEBUG;
        next if ($segment->[1] < $segment->[0]); # segment pruned out of existence
        $mapping->putSegment(@$segment);
    }
# use the normalise method to handle possible single-base segments

    $mapping->normalise();

    if ($mapping->hasSegments()) {
# here, test if the mapping is valid, using the overall maping range
        my ($isValid,$msg) = &isValidMapping($this,$compare,$mapping,$overlapreads);
$DEBUG->info("\n isVALIDmapping $isValid\n$msg") if $DEBUG;
# here possible recovery based on analysis of continuity of mapping segments

# if still not valid, 
        if (!$isValid && !$options{forcelink}) {
$DEBUG->info("Spurious link detected to contig ".$compare->getContigName()) if $DEBUG;
            return 0, $overlapreads;
        }
# in case of split contig
        elsif ($isValid == 2) {
$DEBUG->info("(Possibly) split parent contig ".$compare->getContigName()) if $DEBUG;
            $deallocated = 0; # because we really don't know
        }
# for a regular link
        else {
            $deallocated = $compare->getNumberOfReads() - $overlapreads; 
        }
# store the Mapping as a contig-to-contig mapping (prevent duplicates)
        if ($this->hasContigToContigMappings()) {
            my $c2cmaps = $this->getContigToContigMappings();
            foreach my $c2cmap (@$c2cmaps) {
                my ($isEqual,@dummy) = $mapping->isEqual($c2cmap,silent=>1);
                next unless $isEqual;
                next if ($mapping->getSequenceID() != $c2cmap->getSequenceID());
                print STDERR "Duplicate mapping to parent " .
		             $compare->getContigName()." ignored\n";
if ($DEBUG) {
 $DEBUG->info("Duplicate mapping to parent ".$compare->getContigName()." ignored");
 $DEBUG->info("existing Mappings: @$c2cmaps ");
 $DEBUG->info("to be added Mapping: $mapping, tested against $c2cmap");
 $DEBUG->info("equal mappings: \n".$mapping->toString()."\n".$c2cmap->toString());
}
                return $mapping->hasSegments(),$deallocated;
            }
        }
        $this->addContigToContigMapping($mapping);
# what about the parent?
    }

# and return the number of segments, which could be 0

 $DEBUG->debug("EXIT");
    return $mapping->hasSegments(),$deallocated;

# if the mapping has no segments, no mapping range could be determined
# by the algorithm above. If the 'strong' mode was used, perhaps the
# method should be re-run in standard (strong=0) mode

}

sub isValidMapping {
# helper method for 'linkToContig': decide if a mapping is reasonable, based 
# on the mapped contig range and the sizes of the two contigs involved and the
# number of reads
    my $child = shift;
    my $parent = shift;
    my $mapping = shift;
    my $olreads = shift || return 0; # number of reads in overlapping area
    my %options = @_; # if any

    &verifyPrivate($child,'isValidMapping');

# a simple heuristic is used to decide if a parent-child link is wel
# established or may be spurious. It is based on the length of each contig, 
# the number of reads the size of the region of overlap. We derive the minimum 
# approximately expected number of reads in the overlap area. The observed
# number should be equal or larger than the minimum for both the contig and its
# parent; if it is smaller than either, the link is probably spurious

    my @range = $mapping->getContigRange(); 
    my $overlap = $range[1] - $range[0] + 1;

    my @thresholds;
    my @readsincontig;
    my @rfractions;
    my @lfractions;

    my @contigs = ($child,$parent);
    foreach my $contig (@contigs) {
        my $numberofreads = $contig->getNumberOfReads();
        push @readsincontig,$numberofreads;
# for the moment we use a sqrt function; could be something more sophysticated
        my $threshold = sqrt($numberofreads - 0.4) + 0.1;
        $threshold *= $options{spurious} if $options{spurious};
        $threshold = 1 if ($contig eq $parent && $numberofreads <= 2);
        push @thresholds, $threshold;
# get the length fraction in the overlapping area (for possible later usage)
        my $contiglength = $contig->getConsensusLength() || 1;
        my $lfraction = $overlap / $contiglength;
	push @lfractions,$lfraction;
# get the fraction of reads in the overlapping area 
        my $rfraction = $olreads/$numberofreads;
        push @rfractions,$rfraction;
    }

# compile a summary which we may want to use 

    my $report = "Contig overlap range @range ($overlap), $olreads reads\n\n";
    foreach my $i (0,1) {
        my $contig = $contigs[$i];
        $report .= $contig->getContigName();
        $report .= " (C) : " unless $i;
        $report .= " (P) : " if $i;
        $report .= "$readsincontig[$i] reads, threshold "
                .  sprintf("%6.1f",$thresholds[$i]) . " ($olreads)\n";
        $report .= "\tFraction overlap : length ("
                .  ($contig->getConsensusLength() || 1)
                .  ") ".sprintf("%6.3f",$lfractions[$i]) . ", reads "
                .  sprintf("%6.3f",$rfractions[$i]) . "\n";
    }

# return valid read if number of overlap reads equals number in either contig

    return 1,$report if ($olreads == $readsincontig[1]); # all parent reads in child
    return 1,$report if ($olreads == $readsincontig[0]); # all child reads in parent
#    return 1 if ($olreads == $readsincontig[0] && $olreads <= 2); # ? of child

# get threshold for spurious link to the parent

    my $threshold = $thresholds[1];

    return 0,$report if ($olreads < $threshold); # probably spurious link

# extra test for very small parents with incomplete overlaping reads: 
# require at least 50% overlap length

    if ($threshold <= 1) {
# this cuts out small parents of 2,3 reads with little overlap length)
        return 0,$report if ($lfractions[1] < 0.5); # bad/spurious link
    }

# get threshold for link to split contig

    $threshold = $thresholds[1];
    $threshold *= $options{splitparent} if $options{splitparent};

    return 2,$report if ($olreads < $readsincontig[1] - $threshold); #  split contig

# seems to be a regular link to parent contig

    return 1,$report;
}

sub cleanupsegmentlist {
# strictly private
    my $segmentlist = shift;
    my %options = @_;

    &verifyPrivate($segmentlist,'cleanupsegmentlist');

    @$segmentlist = sort {$a->[0] <=> $b->[0]} @$segmentlist;

    my $segmentstart = $segmentlist->[0]->[0];
    my $segmentfinis = $segmentlist->[0]->[1];

    return undef unless (defined($segmentstart));
    return undef unless (defined($segmentfinis));

    my $newsegmentlist = [];
    foreach my $interval (@$segmentlist) {
        my $intervalstart = $interval->[0];
        my $intervalfinis = $interval->[1];
        next unless defined($intervalstart);
        next unless defined($intervalfinis);
# break of coverage is indicated by begin of interval beyond end of previous
        if ($intervalstart > $segmentfinis) {
# add segmentstart - segmentfinis as mapping segment
            my @newsegment = ($segmentstart,$segmentfinis);
            push @$newsegmentlist,[@newsegment];
# initialize the new mapping interval
            $segmentstart = $intervalstart;
            $segmentfinis = $intervalfinis;
        }
        elsif ($intervalfinis > $segmentfinis) {
            $segmentfinis = $intervalfinis;
        }
    }
    my @newsegment = ($segmentstart,$segmentfinis);
    push @$newsegmentlist,[@newsegment];

# weedout small segments if there is a large one and disconnected small ones 

    if (@$newsegmentlist > 1) {
        my $length = 0;
        foreach my $segment (@$newsegmentlist) {
            my $size = $segment->[1] - $segment->[0] + 1;
            $length = $size if ($size > $length);
        } 
        my $threshold = $options{threshold} || 5;
        $threshold = $length/2 if ($threshold >= $length);
#$DEBUG->info("CM length $length  threshold $threshold\n";
        my $segmentlist = [];
        foreach my $segment (@$newsegmentlist) {
            my $size = $segment->[1] - $segment->[0] + 1;
#$DEBUG->info("CM size $size  threshold $threshold\n";
            push @$segmentlist,$segment if ($size > $threshold);
        }
        $newsegmentlist = $segmentlist;
    }

    return $newsegmentlist;
}

#------------------------------------------------------------------------------

sub propagateTagsToContig {
    my $class = shift;
# propagate tags FROM this (parent) TO the specified target contig
    my $parent = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($parent,'propagateTagsToContig 1-st parameter');

    &verifyParameter($contig,'propagateTagsToContig 2-nd parameter');

    my $logger = &verifyLogger('propagateTagsToContig PT');

# autoload tags unless tags are already defined

    $parent->getTags(1) unless $options{notagload};
#    $parent->getTags(load=>1) unless $options{notagload}; ?
#    $parent->getTags(sort=>1); ?

$logger->debug("ENTER");
$logger->debug("parent $parent (".$parent->getContigID()
        .")  target $contig (".$contig->getContigID().")");
my $tags = $parent->getTags() || []; 
$logger->debug("tags: ".scalar(@$tags));

    return 0 unless $parent->hasTags();

$logger->debug("parent $parent has tags ".scalar(@{$parent->getTags()}));

# check the parent-child relation: is there a mapping between them and
# is the ID of the one of the parents identical to to the input $parent?
# we do this by getting the parents on the $contig and compare with $parent

    my $mapping;

    my $parent_id = $parent->getContigID();

# define (delayed) autoload status: explicitly specify if not to be used 

    my $dl = $options{noparentload} ? 0 : 1; # default 1

    if ($contig->hasContigToContigMappings($dl)) {

# if parents are provided, then screen this ($parent) against them
# if this parent is not among the ones listed, ignored
# if no parents are provided, adopt this one

$logger->debug("Testing C2C mapping to find parent ".$parent->getSequenceID());
 
        my $cparents = $contig->getParentContigs($dl) || [];
        push @$cparents,$parent unless ($cparents && @$cparents);
# we scan the parent(s) provided, to ensure that $this parent is among them
        foreach my $cparent (@$cparents) {
	    if ($cparent->getContigID() == $parent_id) {
# yes, there is a parent child relation between the input Contigs
# find the corresponding mapping using contig and mapping names
                my $c2cmappings = $contig->getContigToContigMappings();
                foreach my $c2cmapping (@$c2cmappings) {
$logger->debug("Testing mapping $c2cmapping ".$c2cmapping->getSequenceID());
# we use the sequence IDs here, assuming the mappings come from the database
		    if ($c2cmapping->getSequenceID eq $parent->getSequenceID) {
                        $mapping = $c2cmapping;
                        last;
                    }
                }
	    }
	}
    }

$logger->debug("mapping selected: ".($mapping || 'not found'));

# if mapping is not defined here, we have to find it from scratch

    unless ($mapping) {
$logger->debug("Finding mappings from scratch");
        my ($nrofsegments,$deallocated) = $contig->linkToContig($parent);
$logger->debug("number of mapping segments : ".($nrofsegments || 0));
        return 0 unless $nrofsegments;
# identify the mapping using parent contig and mapping name
        my $c2cmappings = $contig->getContigToContigMappings();
        foreach my $c2cmapping (@$c2cmappings) {
#	    if ($c2cmapping->getSequenceID eq $parent->getSequenceID) {
	    if ($c2cmapping->getMappingName eq $parent->getContigName) {
                $mapping = $c2cmapping;
                last;
            }
        }
# protect against the mapping still not found, but this should not occur
$logger->debug("mapping identified: ".($mapping || 'not found'));
        return 0 unless $mapping;
    }
$logger->debug("\n".$mapping->assembledFromToString());

# check if the length of the target contig is defined

    my $tlength = $contig->getConsensusLength();
    unless ($tlength) {
        $contig->getStatistics(1); # no zeropoint shift; use contig as is
        $tlength = $contig->getConsensusLength();
        unless ($tlength) {
            $logger->warning("Undefined length in (child) contig");
            return 0;
        }
    }

$logger->debug("Target contig length : $tlength ");

# if the mapping comes from Arcturus we have to use its inverse

#    $mapping = $mapping->inverse() unless $options{noinverse};
    $mapping = $mapping->inverse();

# ok, propagate the tags from parent to target

    my $includetag = $options{includetag};
    my $excludetag = $options{excludetag};
    if ($options{includetag}) { # specified takes precedence
        $includetag = $options{includetag};
        $includetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
        $includetag =~ s/\W+/|/g; # put separators in include list
    }
    elsif ($options{excludetag}) {
        $excludetag = $options{excludetag};
        $excludetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
        $excludetag =~ s/\W+/|/g; # put separators in exclude list
    }

# get the tags in the parent (as they are, but sorted and unique)

    my $ptags = $parent->getTags(0,1);
    next unless ($ptags && @$ptags); # just in case, but should not occur

$logger->debug("parent contig $parent has tags: ".scalar(@$ptags));

# first attempt for ANNO tags (later to be used for others as well)

    my %annotagoptions = (break=>1);
    $annotagoptions{minimumsegmentsize} = $options{minimumsegmentsize} || 0;
    $annotagoptions{changestrand} = ($mapping->getAlignment() < 0) ? 1 : 0;

# activate speedup for mapping multiplication 

    if ($options{speedmode}) {
# will keep track of position in the mapping by defining nzt option as HASH
        $annotagoptions{nonzerostart} = {};
# but requires sorting according to tag position (REDUNDENT)
        @$ptags = sort {$a->getPositionLeft() <=> $b->getPositionLeft()} @$ptags;
    }

# apply filter, if any 

    my @rtags; # for (remapped) imported tags
    foreach my $ptag (@$ptags) {
        my $tagtype = $ptag->getType();
        next if ($excludetag && $tagtype =~ /\b$excludetag\b/i);
        next if ($includetag && $tagtype !~ /\b$includetag\b/i);
        next unless ($tagtype eq 'ANNO');
# remapping can be SLOW for large number of tags if not in speedmode
$logger->debug("CC Collecting ANNO tag for remapping ".$ptag->getPositionLeft());
        my $tptags = $ptag->remap($mapping,%annotagoptions);

        push @rtags,@$tptags if $tptags;
    }

$logger->debug("remapped ".scalar(@rtags)." from ".scalar(@$ptags)." input");# if annotation tags found, (try to) merge tag fragments

    if (@rtags) {
        my %moptions = (overlap => ($options{overlap} || 0));
$moptions{debug} = $logger;
        my $newtags = TagFactory->mergeTags(\@rtags,%moptions);

my $oldttags = $contig->getTags() || [];
$logger->debug(scalar(@$oldttags) . " existing tags on TARGET PT");
$logger->debug(scalar(@$newtags) . " added (merged) tags PT");

        $contig->addTag($newtags) if $newtags;

#        @tags = @$newtags if $newtags;
my $newttags = $contig->getTags() || [];
$logger->debug(scalar(@$newttags) . " updated tags on TARGET PT");
    }
else {
$logger->debug("NO REMAPPED ANNO TAGS FROM PARENT $parent_id");
}
#return 0;

# the remainder is for other tags using the old algorithm

    my $c2csegments = $mapping->getSegments();
    my $alignment = $mapping->getAlignment();

$logger->flush();
    foreach my $ptag (@$ptags) {
# apply include or exclude filter
        my $tagtype = $ptag->getType();
        next if ($excludetag && $tagtype =~ /\b$excludetag\b/i);
        next if ($includetag && $tagtype !~ /\b$includetag\b/i);
        next if ($tagtype eq 'ANNO');

#        my $tptags = $ptag->remap($mapping,break=>0); 
#        $contig->addTag($tptags) if $tptags;
$logger->debug("CC Collecting $tagtype tag for remapping ".$ptag->getPositionLeft());
# determine the segment(s) of the mapping with the tag's position
$logger->debug("processing tag $ptag (align $alignment)");

        undef my @offset;
        my @position = $ptag->getPosition();
$logger->debug("tag position (on parent) @position");
#$logger->flush();
        foreach my $segment (@$c2csegments) {
# for the correct segment, getXforY returns true
            for my $i (0,1) {
                if ($segment->getXforY($position[$i])) {
                    $offset[$i] = $segment->getOffset();
# ensure that both offsets are defined; this line ensures definition in
# case the counterpart falls outside any segment (i.e. outside the contig)
                    $offset[1-$i] = $offset[$i] unless defined $offset[1-$i];
                }
            }
        }
# accept the new tag only if the position offsets are defined
$logger->debug("offsets: @offset");
        next unless @offset;
$logger->flush();
$logger->setPrefix("Tag->transpose");
# create a new tag by spawning from the tag on the parent contig
        my $tptag = $ptag->transpose($alignment,\@offset,
                                   postwindowfinal=>$tlength);

$logger->setPrefix("CH->propagateTagsToContig");
        next unless $tptag; # remapped tag out of boundaries

if ($ptag eq $ptags->[0]) {
$logger->debug("tag on parent :". $ptag->dump);
$logger->debug("tag on child :". $tptag->dump);
}
$logger->flush();
$logger->debug("Test presence of transposed Tag against existing tags");

# test if the transposed tag is not already present in the child;
# if it is, inherit any properties from the transposed parent tag
# which are not defined in it (e.g. when ctag built from Caf file)


# should be done much more efficiently
        my $present = 0;
        my $ctags = $contig->getTags(0);
#$logger->debug("Testing new ($tptag) against existing (@$ctags) tags") if $ctags;
$logger->debug("Testing new ($tptag) against existing tags") if $ctags;
        foreach my $ctag (@$ctags) {
            my $debug = 0;
# test the transposed parent tag and port the tag_id / systematic ID
            if ($tptag->isEqual($ctag,inherit=>1,debug=>$debug)) {
                $present = 1;
                last;
	    }
        }
        next if $present;

# the (transposed) tag from parent is not in the current contig: add it

$logger->debug("new tag $tptag added to $contig");
        $contig->addTag($tptag);
#last;
    }
}

sub sortTags {
# sort and remove duplicate contig tags; re: Contig->getTags
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'sortTags');

#my $logger = verifyLogger('sortTags');
#$logger->debug("ENTER");

    my $tags = $contig->getTags(); # tags as is

    return unless ($tags && @$tags);

# sort the tags with increasing tag position

#$logger->debug('sorting');

    @$tags = sort {$a->getPositionLeft() <=> $b->getPositionLeft()} @$tags;

# remove duplicate tags

#$logger->debug('weeding out duplicates');
#$logger->debug("@$tags");

    my $n = 1;
    while ($n < scalar(@$tags)) {
        my $leadtag = $tags->[$n-1];
        my $nexttag = $tags->[$n];
# splice the nexttag out of the array if the tags are equal
        if ($leadtag->isEqual($nexttag)) {
#$logger->debug("n $n $leadtag equals $nexttag");
	    splice @$tags, $n, 1;
	}
        else {
	    $n++;
	}
    }    
#$logger->debug("@$tags");
#$logger->debug("EXIT",skip=>3);
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

        if (defined($prefix)) {

            $prefix = "ContigHelper->".$prefix unless ($prefix =~ /\-\>/); 

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

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $LOGGER undefined
}

#-----------------------------------------------------------------------------

1;
