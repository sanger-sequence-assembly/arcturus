package ContigHelper;

use strict;

use Contig;

use Mapping;

use TagFactory::TagFactory;

use Alignment;

use Clipping;

use Logging;

#-----------------------------------------------------------------------------
# testing
#-----------------------------------------------------------------------------

sub testContig {
# use via ForExport and ForImport aliases ?
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,"testContig");

    my $logger = &verifyLogger('testContig');

    my $contigstatus = '';

    if ($options{metadata}) {
# test the meta data
        if ($contig->getNumberOfReads() <= 0 || $contig->getProject() <= 0) {
# indicative of problems during --previous-- loading session
            $contigstatus = "invalid metadata for contig " . $contig->getContigName()
                          . " (project ID = " . $contig->getProject()
                          . " number of reads = " . $contig->getNumberOfReads()
                          . " created " . $contig->getCreated()
                          . ")";
            $contig->{status} = $contigstatus;
            return 0;
	}
        return 1;
    }

# write out the current status of mapping and reads

    if ($options{diagnose}) {
        my $load = $options{diagnose} > 1 ? 1 : 0; 
        my $reads = $contig->getReads($load);
        my (@readids,@rseqids);
        my $readnamehash = {};
        foreach my $read (@$reads) {
            my $read_id = $read->getReadID();
            my $rseq_id = $read->getSequenceID();
	    my $version = $read->getVersion();
            push @readids,$read_id;
            push @rseqids,$rseq_id;
            my $readname = $read->getReadName();
            $readnamehash->{$readname} = $rseq_id;
            $logger->warning("$readname i:$read_id  s:$rseq_id  v:$version");
        }
        my $mappings = $contig->getMappings();
        my @mseqids;
        foreach my $mapping (@$mappings) {
            my $readname = $mapping->getMappingName() || 'undef';
            my $mseq_id = $mapping->getSequenceID()   || 'undef';
            $logger->warning("mapping:$readname  s:$mseq_id");
            push @mseqids,$mseq_id;
            next unless $readnamehash->{$readname};
            next if ($readnamehash->{$readname} eq $mseq_id);
            $logger->severe("sequence ID missmatch for read $readname");            
        }
	return 1 unless ($options{diagnose} > 1);
        @rseqids = sort {$a <=> $b} @rseqids;
        $logger->warning("sequences in reads:\n@rseqids");
        @mseqids = sort {$a <=> $b} @mseqids;
        $logger->warning("sequences in mappings:\n@mseqids");
        return 1;
    }

# test the components

# level 0 for export, test number of reads against mappings and metadata    
# for export: test reads against mappings using the sequence ID
# for import: test reads against mappings using the readname
# in either case, the reads and mappings must correspond 1 to 1

    my $level = $options{forimport} || 0;
    my $noreadsequencetest = $options{noreadsequencetest};

    my %identifier; # hash for IDs

# test contents of the contig's Read instances; we log errors on reads or
# mappings; we record error status on contig separately

    my $ID;
    if ($contig->hasReads()) {
        my $success = 1;
        my $reads = $contig->getReads();
        foreach my $read (@$reads) {
# test identifier: for export sequence ID; for import readname (or both? for both)
            $ID = $read->getReadName()   if  $level; # import
	    $ID = $read->getSequenceID() if !$level;
            if (!defined($ID)) {
                $logger->severe("Missing identifier in Read ".$read->getReadName);
                $success = 0;
            }
            $identifier{$ID} = $read;
# test presence of sequence and quality data
            if (!$level || $read->isEdited()) { 
                if (!$noreadsequencetest && !$read->hasSequence()) {
                    unless ($read->getSequenceID()) {
                        $logger->severe("Missing DNA or BaseQuality in Read "
                                        .$read->getReadName);
$logger->severe("ex/import-level=$level  isEdited=".$read->isEdited());
#$logger->severe($read->writeToCaf(*STDOUT));
                        $success = 0 unless ($read->getReadName() =~ /con/);
		    }
                }
	    }
            $contig->{status} = "Invalid or incomplete Read(s)" unless $success;
        }
        return 0 unless $success;       
    }
    else {
        $contigstatus .= "Contig ".$contig->getContigName." has no Reads\n";
    }

# test contents of the contig's Mapping instances and against the Reads

    if ($contig->hasMappings()) {
        my $success = 1;
	my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
# get the identifier: for export sequence ID; for import readname
            if ($mapping->hasSegments) {
                $ID = $mapping->getMappingName() if $level;
	        $ID = $mapping->getSequenceID() unless $level;
# is ID among the identifiers? if so delete the key from the has
                if (!defined($ID) || !$identifier{$ID}) {
		    $ID = 'undefined' unless defined($ID);
                    $logger->severe("Missing Read for Mapping ".
                                 $mapping->getMappingName." ($ID)");
                    $success = 0;
                }
                delete $identifier{$ID}; # delete the key
            }
	    else {
                $logger->severe("Mapping ".$mapping->getMappingName().
                            " for Contig ".$contig->getContigName().
                            " has no Segments");
                $success = 0;
            }
            $contig->{status} = "Invalid or incomplete Mapping(s)" unless $success;
        }
        return 0 unless $success;
    } 
    else {
        $contigstatus .= "Contig ".$contig->getContigName." has no Mappings\n";
        $contig->{status} = $contigstatus;
        return 0;
    }
# now there should be no keys left (when Reads and Mappings correspond 1-1)
    if (scalar(keys %identifier)) {
        foreach my $ID (keys %identifier) {
            my $read = $identifier{$ID};
            $contigstatus .= "Missing Mapping for Read "
                          .   $read->getReadName." ($ID)\n";
        }
    }

# test the Mappings for continuous cover

    my $mappings = $contig->getMappings();
    @$mappings = sort { $a->getContigStart() <=> $b->getContigStart() } @$mappings;

    my ($dummy,$farend);
   ($dummy,$farend) = $mappings->[0]->getContigRange() if $mappings->[0];
    for (my $i = 1 ; $i < scalar(@$mappings) ; $i++) {
        my @current = $mappings->[$i]->getContigRange();
        unless ($current[0] <= $farend) { # i.e. if there is overlap
            my $pmap = $mappings->[$i-1]->getMappingName();
            my $cmap = $mappings->[$i]->getMappingName();
            my @previous = $mappings->[$i-1]->getContigRange();
            $contigstatus .= "Discontinuity at mapping $i: no overlap between "
                          .  "$pmap (@previous) and $cmap (@current)\n";
	}
        $farend = $current[1] if ($current[1] > $farend);
    }

# test the number of Reads against the contig meta data (info only; non-fatal)

    if (my $numberOfReads = $contig->getNumberOfReads()) {
        my $reads = $contig->getReads() || [];
        my $nreads =  scalar(@$reads);
        if ($nreads != $numberOfReads) {
            $logger->warning("Read count error for contig ".$contig->getContigName
                            . " (actual $nreads, metadata $numberOfReads)");
        }
    }
    elsif (!$level) {
        $logger->warning("Missing metadata for ".contig->getContigName());
    }

    return 1 unless $contigstatus; # no errors

    $contig->{status} = $contigstatus;

    return 0;
}

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
        if ($contig->hasMappings()) {
            my $init = 0;
            $numberofnames = 0;
            $totalreadcover = 0;
            my $mappings = $contig->getMappings();
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
                $logger->info("zero point shift by $shift applied to contig $name");
                foreach my $mapping (@$mappings) {
                    $mapping->applyShiftToContigPosition($shift);
                }
# and apply shift to possible tags
                if ($contig->hasTags()) {
                    $logger->fine("adjusting tag positions (to be tested)");
                    my %options = (nonew => 1,postwindowfinal => $cfinal);
                    my $tags = $contig->getTags(); # as is
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
                $logger = &verifyLogger("statistics");
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

    my $newcontigname = $contig->getContigName()."-reversecomplemented";

    $contig->setContigName($newcontigname);

    my $length = $contig->getConsensusLength();

    my $complete = $options{nocomplete} ? 0 : 1;

# the read mappings

    if ($contig->getMappings($complete)) {
        $logger->debug("inverting read-to-contig mappings");
        my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
# and sort the mappings according to increasing contig position
        @$mappings = sort {$a->getContigStart <=> $b->getContigStart} @$mappings;
    }

# possible parent contig mappings

    if ($contig->getContigToContigMappings($complete)) {
        $logger->debug("inverting contig-to-contig mappings");
        my $mappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
    }

# tags

    my $tags = $contig->getTags($complete);
    $logger->debug("inverting tags") if $tags;
    foreach my $tag (@$tags) {
        $tag->mirror($length+1,nonew=>1); # don't create a new tag
    }

# replace the consensus sequence with the inverse complement

    if (my $consensus = $contig->getSequence()) {
        $logger->info("inverting sequence");
        my $newsensus = reverse($consensus);
        $newsensus =~ tr/ACGTacgt/TGCAtgca/;
	$contig->setSequence($newsensus);
    }
    else {
        $logger->info("missing consensus sequence in contig ".$contig->getContigName());
    }

    if (my $quality = $contig->getBaseQuality()) {
# invert the base quality array
        $logger->info("inverting base quality array");
        @$quality = reverse(@$quality);
#        for (my $i = 0 ; $i < $length ; $i++) {
#            my $j = $length - $i - 1;
#            last unless ($i < $j);
#            my $swap = $quality->[$i];
#            $quality->[$i] = $quality->[$j];
#            $quality->[$j] = $swap;
#        }
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

# step 1: analyse DNA and Quality data to determine the clipping points
    
    my $contigname = $contig->getContigName();

    my $flq = &findlowquality($contig->getSequence(),
                              $contig->getBaseQuality(),
                              $options{symbols},   # default 'ACGTN'
                              $options{threshold}, # default 20
                              $options{minimum},   # default 0,15
                              $options{hqpm},      # default 0,30
                              $options{window});   # default 9

    unless ($flq) {
# bad things have happened
        $logger->warning("Missing or invalid base quality data in $contigname");
        $logger->severe("missing DNA or quality data") unless $contig->hasSequence();
        return $contig, 0;
    }

    my ($pads,$mask) = @$flq;

    unless ($pads && @$pads) {
        $logger->special("No low quality data found in $contigname");
        $logger->debug("No low quality data found in $contigname");
        return $contig, 1; # no low quality stuff found
    }

# step 2: remove low quality pads from the sequence & quality;

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);

$logger->debug("ContigFactory->deleteLowQualityBases  sl:".length($sequence)."  ql:".scalar(@$quality));

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

#    $contig = $contig->copy(%coptions) unless $options{nonew}; # ??
    my $clippedcontig = new Contig();

# add descriptors and sequence

    $clippedcontig->setContigName($contig->getContigName);
                
    $clippedcontig->setGap4Name($contig->getGap4Name);
                
    $clippedcontig->setSequence($sequence);
                
    $clippedcontig->setBaseQuality($quality);

    $clippedcontig->addContigNote("low_quality_removed:$mask");

    $clippedcontig->setContigID( 1000000 + $contig->getContigID() ); # to give it an ID

    $ori2new->setHostSequenceID( $contig->getContigID() ); # X domain original contig

    $ori2new->setSequenceID( $clippedcontig->getContigID() ); # Y domain clipped contig

$logger->debug("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED'));

    $clippedcontig->addContigToContigMapping($ori2new);

# either treat the new contig as a child of the input contig

    if ($options{exportaschild}) {
        $clippedcontig->addParentContig($contig);
        $contig->addChildContig($clippedcontig);
    }
    elsif ($options{exportasparent}) {
        $clippedcontig->addChildContig($contig);
        $contig->addParentContig($clippedcontig);
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

    my $logger = &verifyLogger('replaceLowQualityBases');

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

    my $flq = &findlowquality($contig->getSequence(),
                              $quality,
                              $options{symbols},   # default 'ACGTN'
                              $options{threshold}, # default 20
                              $options{minimum},   # default 0,15
                              $options{hqpm},      # default 0,30
                              $options{window});   # default 9

    unless ($flq) {
# bad things have happened
        $logger->warning("Missing or invalid base quality data in $contigname");
        $logger->severe("missing DNA or quality data") unless $contig->hasSequence();
        return 0;
    }

    my ($pads,$mask) = @$flq;

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

sub removeInvalidReadNames {
# remove reads with name matching input filter pattern 
# default: capillary readnames mangled by Newbler assembler
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'removeInvalidReadNames');

    my $reads = $contig->getReads(1);

    my @reads_to_be_removed;

    unless (defined $options{exclude_filter}) {
        $options{exclude_filter} = '\.[pq][12]k\.[\w\-]+'; # default
    }
    my $exclude_filter = $options{exclude_filter};

    foreach my $read (@$reads) {
        my $readname = $read->getReadName();
        next unless ($readname =~ /$exclude_filter/);
	push @reads_to_be_removed,$readname;
    }

my $logger = &verifyLogger('removeInvalidReadNames');
$logger->debug("ENTER");
$logger->warning("readnames to be removed:\n@reads_to_be_removed");

    return $contig,"No reads removed" unless @reads_to_be_removed; # none found

    delete $options{exclude_filter};

    return $contig->removeNamedReads(\@reads_to_be_removed,%options);
}

sub removeNamedReads {
# remove a list of readnames from a contig
    my $class  = shift;
    my $contig = shift;
    my $readnames = shift;
    my %options = @_;

    &verifyParameter($contig,'removeNamedReads');

# test for a read name/id or an array

    &verifyParameter($readnames,'removeNamedReads','ARRAY') if ref($readnames);

my $logger = &verifyLogger('removeNamedReads');
$logger->debug("ENTER");

    $contig = $contig->copy() if $options{new};

    my ($count,$parity,$total) = &removereads($contig,$readnames);

    unless ($total) {
        return undef,"No reads to be deleted specified";
    }

# parity and count must be 0 and a multiple of 3 respectively

    my $status = "p:$parity c:$count t:$total";

    if ($parity || $count%3) {
        return undef,"Badly configured input contig or returned contig ($status)";
    }
    
# test actual count against input read specification
    
    unless ($count > 0 && $count == 3*$total) {
        return undef,"No reads deleted from input contig ($status)" unless $count;
        return undef,"Not all reads deleted from input contig ($status)";
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

# step 1: analyse DNA and Quality data to determine the clipping points

    my $flq = &findlowquality($contig->getSequence(),
                              $contig->getBaseQuality(),
                              $options{symbols},   # default 'ACGTN'
                              $options{threshold}, # default 20
                              $options{minimum},   # default 0,15
                              $options{hqpm},      # default 0,30
                              $options{window});   # default 9

    unless ($flq) {
# bad things have happened
        $logger->warning("Missing or invalid base quality data in ".$contig->getContigName());
        $logger->severe("missing DNA or quality data") unless $contig->hasSequence();
        return 0;
    }

    my ($pads,$mask) = @$flq;

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

sub restoreMaskedReads {
# ad hoc method to restore the masked parts of sequence and quality of reads
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'restoreMaskedReads');

    my $logger = &verifyLogger('restoreMaskedReads');

    my $reads = $contig->getReads(1);

    my $adb = $contig->getArcturusDatabase() || return 0; # no database handle

    my $restored = 0;
    foreach my $read (@$reads) {

        my $readdna = $read->getSequence() || next;

        my $read_left = 0;
	my $read_right = length($readdna) + 1;

        if ($readdna =~ /^([xn]+)/i) {
            $read_left  += length($1); # last masked position left
        }
        if ($readdna =~ /([xn]+)$/i) {
            $read_right -= length($1); # first masked position right
        }

        next unless ($read_left > 0 || $read_right < length($readdna) + 1);

        my $base = $adb->getRead(readname => $read->getReadName(), version => 0);

        unless ($base) {
            $logger->sever("Unable to retrieve original read; no databse connection?");
            last;
	}

        my $readqlt = $read->getBaseQuality() || [];
        my @readqlt = @$readqlt; # make local copy

# now use the sequence of the original read to repair the current version 

        my $basedna = $base->getSequence();
        my $baseqlt = $base->getBaseQuality();
        my @baseqlt = @$baseqlt; # make local copy

# find the boundaries as found in the read in the version 0 dna

        my ($base_left,$base_right);

        my $marker = substr $readdna,$read_left,4; # first on the left
        foreach my $shift (2, 1, -2, -1, 0) {
            my $motif = substr $basedna,($read_left + $shift), 4;
            $base_left = $read_left + $shift if ($motif eq $marker);
        }

        $marker = substr $readdna,($read_right - 5),4; # then on the right
        foreach my $shift (-2, -1, 2, 1, 0) {
            my $motif = substr $basedna,($read_right - 5 + $shift), 4;
            $base_right = $read_right + $shift if ($motif eq $marker);
        }

        my $rlength = $read_right - $read_left - 1; # the length of the unmasked part of read
        my $replacement = substr $readdna, $read_left, $rlength;
        my @cenquality  = splice @readqlt, $read_left, $rlength;

        unless (defined($base_left) && defined($base_right)) {
$logger->info("procesing read $read");
# one or both boundaries could not be determined
$logger->error("cannot determine boundaries on version 0"); 
$logger->info("restoring read ".$read->getReadName());
$logger->info("cannot determine boundaries on version 0");
$logger->info("read left $read_left , read right $read_right, rlength $rlength");
$logger->fine("read DNA\n$readdna\nbaseDNA\n$basedna"); 
$logger->flush();
            my $change = length($basedna) - length($readdna); 
$logger->info("change = $change");
            if (defined($base_left)) {
                $base_right = $read_right + $change;
	    }
            elsif (defined($base_left)) {
                $base_left  = $read_left  - $change;
	    }
# infer from difference in read length, assuming the same start point 
            else {
                $base_left = $read_left;
                $base_right = $read_right + $change;
            }
$logger->info("base left $base_left , base right $base_right");
	}

        my $blength = $base_right - $base_left - 1; # the length of the unmasked part of version 0

        substr $basedna,$base_left,$blength,$replacement;
        splice @baseqlt,$base_left,$blength,@cenquality;

        $read->setSequence($basedna);
        $read->setBaseQuality([@baseqlt]);

        $restored++;
    }

    return $restored;
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

    my $logger = &verifyLogger('extractEndRegion');

    my $sq = &endregiononly($contig->getSequence(),
                            $contig->getBaseQuality(),
                            $options{endregionsize} || 100, # extracted length at either end
                            $options{sfill}         || 'X', # replacement symbol for central part
                            $options{lfill}         || 0,   # replace centre with string of this length
                            $options{qfill})        || 1;   # quality value to be used in centre
# create a new output contig

    my $newcontig = new Contig();
    $newcontig->setContigName($contig->getContigName);
    $newcontig->setSequence($sq->[0]);
    $newcontig->setBaseQuality($sq->[1]);
    $newcontig->addContigNote("endregiononly");
    $newcontig->setGap4Name($contig->getGap4Name);

    return $newcontig;
}

sub endregiononly {
# helper method, private: generate masked sequence and quality data
    my $sequence = shift;
    my $quality  = shift;
# options
    my $ersize = shift; # extracted length at either end
    my $symbol = shift; # replacement symbol for central part
    my $centre = shift; # replace centre with string of this length
    my $qfill  = shift; # quality value to be used in centre

    &verifyPrivate($sequence,'endregiononly');

# apply lower limit, if shrink option active

    $centre = $ersize if ($centre < $ersize);

    my $length = length($sequence);

    if ($ersize > 0 && $symbol && $length > 2*$ersize) {

        my $begin  = substr $sequence,0,$ersize;
        my $center = substr $sequence,$ersize,$length-2*$ersize;
        my $end = substr $sequence,$length-$ersize,$ersize;

# adjust the center, if shrink option

        if ($centre && $length-2*$ersize >= $centre) {
            $center = '';
            while ($centre--) {
                $center .= $symbol;
            }
        }
	else {
            $center =~ s/./$symbol/g;
	}

        $sequence = $begin.$center.$end;

# assemble new quality array, if an input was defined

        if ($quality) {

            my @newquality = @$quality[0 .. $ersize-1];
            my $length = length($center);
            while ($length--) {
		push @newquality, $qfill;
	    }
            push @newquality, @$quality[$length-$ersize .. $length-1];

            $quality = \@newquality;
	}
    }

    return [($sequence,$quality)];
}

#-----------------------------------------------------------------------------

sub endRegionTrim {
# trim low quality data from the end of the contig
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'endRegionTrim');

    my $logger = &verifyLogger('endRegionTrim');

$logger->error("ENTER: @_");

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
$logger->error("mask mapping ".$mask->writeToString());

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
$logger->error("mapping to be deleted: ".$mapping->writeToString());
            push @deletereads,$mapping->getMappingName();
        }
# what about the reads to be deleted?

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

    $trimmedcontig->setContigNote("clipped range @crange ($clength)");

    return $trimmedcontig;
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
 
    my $symbols               = shift || 'ACGTN';
    my $threshold             = shift;
    my $minimum               = shift;
    my $highqualitypadminimum = shift;
    my $fwindow               = shift || 9;

# put defaults if undef

    $threshold             = 20 unless defined($threshold);
    unless (defined($minimum) || defined($highqualitypadminimum)) {
# if both undefined default to Gap4 clipping
        $minimum = 0; $highqualitypadminimum = 0;
    }
# else if one defined, use default for other
    $minimum               = 15 unless defined($minimum);
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

    my $mask = "$fwindow:$highqualitypadminimum:$minimum:$threshold:$symbols";

    return [($pads,$mask)]; # array reference
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
        $filter[$i] = 1.0;
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

#------------------------------------------------------------------------------

sub remapcontigcomponents {
# take components from oldcontig, remap using ori2new, put into newcontig
    my $oldcontig = shift; # original contig
    my $ori2new   = shift; # mapping original to new
    my $newcontig = shift; 
    my %options = @_; # mergetaglist, tracksegments

    &verifyPrivate($oldcontig,'remapcontigcomponents');

    my $logger = &verifyLogger('remapcontigcomponents');

# add and transform the mappings; keep track of the corresponding reads

    my %moptions;
    $moptions{tracksegments} = $options{tracksegments} || 0;

    my $readnamehash = {};
    my $mappings = $oldcontig->getMappings();
    foreach my $mapping (@$mappings) {
        my $newmapping = $mapping->multiply($ori2new,%moptions); # before/after
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
#$logger->monitor("Tag remapping start",timing=>1);

        $moptions{tracksegments} = 2; # default
        my $tags = $oldcontig->getTags();

        my $breaktags = $options{breaktags} || 'ANNO';
        $breaktags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $breaktags =~ s/\W+/|/g; # prepare for use in regexp

        my @newtags;
        foreach my $tag (@$tags) {
            my $tagtype = $tag->getType();
            if ($tagtype =~ /$breaktags/) {
                my $newtags = $tag->remap($ori2new,split=>1,%moptions);
                push @newtags, @$newtags if $newtags;
for my $ntag (@$newtags) {print STDOUT "split tag ".$ntag->writeToCaf();}
            }
            else {
                my $newtags = $tag->remap($ori2new,nosplit=>1,%moptions);
                push @newtags, @$newtags if $newtags;
	    }
	}

# test if some tags can be merged (using the Tag factory)

        my $nomerge = $options{nomergetaglist};
        $nomerge = 'ANNO' unless defined $nomerge;

        my @tags = TagFactory->mergeTags([@newtags],nomergetaglist=>$nomerge);

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
	$logger->info(scalar(keys %$readidhash)." reads to be removed");
    }
    else {
        $readidhash->{$readrf}++;
    }
    
# run through the reads and mappings and remove the ones that match

    my $parity = 0;
    my $splicecount = 0;
    my $total = scalar(keys %$readidhash);

    my $reads = $contig->getReads(1);

    my $n = 0;
    my $readsqhash = {};
    while ($n < scalar(@$reads)) {
        unless ($readidhash->{$reads->[$n]->getReadName()}
	    or  $readidhash->{$reads->[$n]->getReadID()}) {
            $n++;
            next;
	}
        $readsqhash->{$reads->[$n]->getSequenceID()}++;  # register sequence ID
        my $removed = splice @$reads,$n,1;
        $logger->info("read ".$removed->getReadName()." ($n) removed");
        $contig->setNumberOfReads(scalar(@$reads));
        $splicecount += 2;
        $parity++;
    }
            
    my $mapps = $contig->getMappings(1);

    my $i = 0;
    while ($i < scalar(@$mapps)) {
        unless ($readidhash->{$mapps->[$i]->getMappingName()}
	    or  $readsqhash->{$mapps->[$i]->getSequenceID()}) {
	    $i++;
	    next;
	}
        my $removed = splice @$mapps,$i,1;
        $logger->info("mapping ".$removed->getMappingName()." ($i) removed");
        $splicecount++;
        $parity--;
        next unless $logger;
    }

    return $splicecount,$parity,$total;
}

sub break {
# split a contig into new contigs on areas of no coverage
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,"break");

    my $logger = &verifyLogger("break",1);

# first determine if there are breaking points

    my $mappings = $contig->getMappings();
    return undef unless @$mappings;

    @$mappings = sort { $a->getContigStart() <=> $b->getContigStart() } @$mappings;

    my @break = (0);
    my $nm = scalar(@$mappings);
    my ($dummy,$farend) = $mappings->[0]->getContigRange();
    for (my $i = 1 ; $i < $nm ; $i++) {
        my @current = $mappings->[$i]->getContigRange();
        unless ($current[0] <= $farend) { # i.e. if there is overlap
            my $pmap = $mappings->[$i-1]->getMappingName();
            my $cmap = $mappings->[$i]->getMappingName();
            my @previous = $mappings->[$i-1]->getContigRange();
            $logger->info("Discontinuity! $i: consecutive mappings $pmap ".
                         "(@previous) and $cmap (@current) do not overlap");
            push @break, $i;
	}
        $farend = $current[1] if ($current[1] > $farend);
    }
    push @break, $nm;

    $logger->severe("breaking points @break");

    return 0 unless @break > 2;

# a more general approach: get a record of cover by sampling mapping boundaries

    my %boundaries;
    foreach my $mapping (@$mappings) {
        my @range =  $mapping->getContigRange();
        $boundaries{$range[0]}++;
        $boundaries{$range[1]}++;
    }

    my @boundaries = sort {$a <=> $b} keys %boundaries; 

# count number of reads straddling each interval

    for (my $i = 1 ; $i < scalar(@boundaries) ; $i++) {
# to be completed
    }

# collect the new contigs:

    my %readnamehash;
    my $reads = $contig->getReads();
    foreach my $read (@$reads) {
        $readnamehash{$read->getReadName()} = $read;
    }

    my $contigbasename = $contig->getContigName();

    my @contigs;
    for (my $i = 1 ; $i < scalar(@break) ; $i++) {
        my $contig = new Contig($contigbasename."-$i");
        foreach my $map ( $break[$i-1] .. $break[$i]-1 ) {
            my $mapping = $mappings->[$map];
            my $readname = $mapping->getMappingName();
            $contig->addMapping($mapping);
            my $read = $readnamehash{$readname};
            $contig->addRead($read);
	}
        $contig->getStatistics();
        $logger->warning($contig->toString());
	push @contigs,$contig;
    }
    return [@contigs];
}

sub disassemble {
# public, partly dis-assemble contig by removing reads in selected intervals
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,"disAssembleContig");

# read intervals are marked by special tags on reads

    my $reads = $contig->getReads(1);
    my $mapps = $contig->getMappings(1);

# build cross reference hash

    my $mappingnames = {};
    foreach my $mapping (@$mapps) {
	$mappingnames->{$mapping->getMappingName} = $mapping;
    }

# intervals are marked by reads with tags

    my %readtagstart;
    my %readtagfinal;
    $options{tagstart} = 'BRKS' unless defined $options{tagstart};
    $options{tagfinal} = 'BRKF' unless defined $options{tagfinal};

# TO BE DEVELOPED

    foreach my $read (@$reads) {
        my $tags = $read->getTags();
        foreach my $tag (@$tags) {
            my $tagtype = $tag->getType();
#           $readtagstart->{$read} = $read if ($tagtype eq $options{tagstart});
	}
    }

# identify reads to be removed
# remove using removereads method above

# run contig through break method; return resulting array of smaller contigs

#    return $class->break($contig); # ? or list of contig, list of reads?
}

#-----------------------------------------------------------------------------
# Padding
#-----------------------------------------------------------------------------

sub pad {
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'pad');

    my $logger = &verifyLogger('pad');

    $logger->error("not yet operational");
}

sub depad {
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'depad');

    my $logger = &verifyLogger('depad');

    $logger->error("not yet operational");
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

    my $logger = &verifyLogger('isEqual',1);

# if the comparison is to be made with sequence only

    if ($options{sequenceonly}) {
        my $mastersequence = lc($master->getSequence()) || return undef;
        my $contigsequence = lc($contig->getSequence()) || return undef;
        return  1 if ($mastersequence eq $contigsequence);
        $contigsequence = reverse($contigsequence);
        $contigsequence =~ tr/acgt/tgca/; # reverse complement
        return -1 if ($mastersequence eq $contigsequence);
        return  0;
    }

# ensure that read mappings are defined, use delayed loading if required (and possible)

    unless ($master->hasMappings(1) && $contig->hasMappings(1)) {
        $logger->debug("Missing mappings in one or both contig(s)");
# if mappings are missing, try the sequence (if recovery is enabled)
        return undef unless $options{recoverenabled};
        return $class->isEqual($master,$contig,sequenceonly=>1);
    }

# ensure that the metadata are defined; do not allow zeropoint adjustments here

    $master->getStatistics(1) unless $master->getReadOnLeft();
    $contig->getStatistics(1) unless $contig->getReadOnLeft();

# test again if mappings available 

    unless ($contig->getReadOnLeft() && $master->getReadOnLeft()) {
        $logger->debug("Missing mappings in one or both contig(s)");
	return undef; # should not occur, bad things have happened
    }

# test the consensus length

    unless ($master->getConsensusLength() == $contig->getConsensusLength()) {
	$logger->debug("consensus length mismatch");
	return 0;
    }

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
	$logger->debug("end reads mismatch 1");
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

    my $logger = &verifyLogger('crossmatch',1);

# test the presence of read-to-contig mappings in both contigs

    my $cthism = $cthis->hasMappings();
    my $cthatm = $cthat->hasMappings();

    if ($cthism && $cthatm && !$options{sequenceonly}) {
# find the alignment from the read-to-contig mappings
# option strong       : set True for comparison at read mapping level
# option noguillotine : if NOT set, require a minumum number of reads in C2C segment
      
        return &linkToContig($cthis,$cthat,%options) if $options{useold};
 
        return &linkcontigs($cthis,$cthat,%options); 
    }
    elsif ($options{sequenceonly}) {
# try the alignment of the consensus sequence
        $options{banded} = 1 unless defined $options{banded};
# banded search with default parameters; if set to 0 search is between offset windows
        my %searchoptions = (lqsymbol => 0, minimumsegmentsize => 50,
                             iterate => 1, minimum => 3, diagnose => 1);
        $searchoptions{banded} = $options{banded};

        my $mapping = Alignment->correlate(uc($cthis->getSequence()),undef,
                                           uc($cthat->getSequence()),undef,
                                           %searchoptions);
# test mapping for length and orientation
        return undef,0  unless $mapping;

# here completion of mapping ; see line 2191 

        $mapping->setMappingName($cthat->getContigName());
        $mapping->setHostSequenceID($cthis->getContigName()); # this contig
        $mapping->setSequenceID($cthat->getContigName()); # the linked contig

$logger->info($mapping->toString());

        $cthis->addContigToContigMapping($mapping);

        return $mapping->hasSegments(),0;
    }
    else {
# if any of the two contigs does not have mappings, no comparison can be made
        $logger->debug("Contig ".$cthis->getContigName()." has no mappings") unless $cthism;
        $logger->debug("Contig ".$cthat->getContigName()." has no mappings") unless $cthatm;
        return undef,0;
    }
}

sub linkcontigs {
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# returns the number of mapped segments; returns undef if failed. e.g. 
# because of incomplete Contig instances or missing sequence IDs in mappings
    my $thiscontig = shift;
    my $thatcontig = shift; # Contig instance to be compared to $thiscontig
    my %options = @_;

# option strong       : set True for comparison at read mapping level
# option readclipping : if set, require a minimum number of reads in C2C segment

    &verifyPrivate($thiscontig,"linkcontigs");

    my $logger = &verifyLogger('linkcontigs');

#$logger->debug("ENTER");
#$logger->info("using new linkcontigs");

# test completeness

    return undef unless $thiscontig->hasMappings(); 
    return undef unless $thatcontig->hasMappings();

# make the comparison using sequence ID; start by getting an inventory of $thiscontig
# we build a hash on sequence ID values & one for back up on mapping(read)name

    my $sequencehash = {};
    my $readnamehash = {};
    my $lmappings = $thiscontig->getMappings();
    foreach my $mapping (@$lmappings) {
        my $seq_id = $mapping->getSequenceID();
        $sequencehash->{$seq_id} = $mapping if $seq_id;
        my $m_name = $mapping->getMappingName();
        $readnamehash->{$m_name} = $mapping if $m_name;
    }

# make an inventory hash of (identical) alignments from $thatcontig to $thiscontig

    my $alignment = 0;
    my $inventory = {};
    my $accumulate = {};
    my $deallocated = 0;
    my $overlapreads = 0;
    my $cmappings = $thatcontig->getMappings();
    foreach my $mapping (@$cmappings) {
        my $readname = $mapping->getMappingName();
        my $oseq_id = $mapping->getSequenceID();
        unless (defined($oseq_id)) {
            $logger->error("Incomplete Mapping for $readname");
            return undef; # abort: incomplete Mapping; should never occur!
        }
        my $complement = $sequencehash->{$oseq_id};
        unless (defined($complement)) {
# the read in the parent is not identified in this contig; this can be due
# to several causes: the most likely ones are: 1) the read is deallocated
# from the previous assembly, or 2) the read sequence was edited and hence
# its seq_id has been changed and thus is not recognized in the parent; 
# we can decide between these cases by looking at the readnamehash
            $complement  = $readnamehash->{$readname};
            unless (defined($complement)) {
# it's a de-allocated read, except possibly in the case of a split parent
                $deallocated++; 
                next;
	    }
# ok, the readnames match, but the sequences not: its a (new) edited sequence
# we now use the align-to-trace mapping between the sequences and the original
# trace file in order to find the contig-to-contig alignment defined by this read
# in order to do this we have to retrieve both the original and the edited read
            my $eseq_id = $complement->getSequenceID(); # (newly) edited sequence
# check the existence of the database handle in order to get at the read versions
            my $ADB = $thiscontig->getArcturusDatabase();
            $ADB = $thatcontig->getArcturusDatabase() unless $ADB;
            unless ($ADB) {
		$logger->error("Unable to recover C2C link for read $readname "
                             . ": missing database handle");
		next;
            }
# get the versions of this read in a hash keyed on sequence IDs
            my $reads = $ADB->getAllVersionsOfRead(readname=>$readname);
# test if both reads are found, just to be sure
            unless ($reads->{$oseq_id} && $reads->{$eseq_id}) {
		$logger->error("Cannot recover sequence $oseq_id or $eseq_id "
                             . "for read $readname");
		next;
	    }
# pull out the align-to-SCF as mappings
            my $omapping = $reads->{$oseq_id}->getAlignToTraceMapping(); # original
            my $emapping = $reads->{$eseq_id}->getAlignToTraceMapping(); # edited
# find the proper chain of multiplication to get the new mapping 

#**** under development begin
$logger->info("Missing match for sequence ID $oseq_id"); 
$logger->info("But the readnames do match : $readname");
$logger->info("sequences: parent $oseq_id   child (edited) $eseq_id");
$logger->info("original Align-to-SCF:".$omapping->toString());
$logger->info("edited   Align-to-SCF:".$emapping->toString());
$logger->info("Recovering link for read $readname (seqs:$oseq_id, $eseq_id)");
$logger->info("complement:".$complement->toString(),ss=>2);
            $complement = $complement->multiply($emapping);
$logger->info("remapped Mro I:".$complement->toString());
            my $oinverse = $omapping->inverse();
$logger->info("o inverse:".$oinverse->toString());
            $complement = $complement->multiply($oinverse,repair=>3);
$logger->info("remapped Mro II:".$complement->toString());
#**** under development end

        }
# count the number of reads in the overlapping area
        $overlapreads++;

# this mapping/sequence in $thatcontig also figures in the current Contig

        if ($options{strong}) {
# strong comparison: test for identical mappings (apart from shift)
            my ($identical,$aligned,$offset) = $complement->isEqual($mapping);
            $logger->info("not identical $readname $identical,$aligned,$offset") unless $identical;

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
            my $cpmapping = $complement->compare($mapping,silent=>1);
            unless ($cpmapping && $cpmapping->hasSegments()) {
# empty cross mapping

                if ($thatcontig->getNumberOfReads() > 1) {
                    $logger->special("Non-overlapping read segments for read $readname");
		}
		else {
                    $logger->special("Non-overlapping read segments for single-read "
                                    ."parent contig ".$thatcontig->getContigID());
		}
                $logger->special("parent mapping:".$mapping->toString());
                $logger->special("contig mapping:".$complement->toString());
                $logger->special("c-to-p mapping:".$cpmapping->toString()) if $cpmapping;
#		$complement->compare($mapping,list=>1); exit;

		next; 
            }

# keep the first encountered (contig-to-contig) alignment value != 0

            my $cpaligned = $cpmapping->getAlignment();
$logger->fine($mapping->getMappingName()." : alignment $cpaligned");

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
# different alignments between $thiscontig and $thatcontig. On each key we have an
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
$logger->debug("CM offset $offset  segmentlist before ".scalar(@$segmentlist));
            $segmentlist = &cleanupsegmentlist($segmentlist,);
$logger->debug("CM offset $offset  segmentlist  after ".scalar(@$segmentlist));
            unless ($segmentlist && @$segmentlist) {
   	        print STDERR "unexpectedly NO SEGMENTLIST for offset $offset\n";
                next;
	    }
            my $psum = 0; # re: average position
            foreach my $mapping (@$segmentlist) {
$logger->debug("CM offset $offset cleaned mapping @$mapping");
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
$logger->debug("Inversion detected $ph[0] $ph[1] $ph[2]");
                $penalty++;
	    }
        }
# get the correlation coefficient
        my $threshold = $options{correlation} || 0.75;
        my $R = $sumop / sqrt($sumpp * $sumoo);
$logger->debug("Correlation coefficient = $R  penalty $penalty");
# if CC too small, apply lower and upper boundary to offset
        unless (abs($R) >= $threshold) {
# relation offset-position looks messy
            $logger->special("Suspect correlation coefficient = $R : target "
                            .$thatcontig->getContigName()
                            ." (inversion penalty = $penalty)");
# accept the alignment if no penalties are incurred (monotonous alignment)
            if ($penalty > $defects) {
# set up for offset masking
$logger->debug("Suspect correlation coefficient = $R : target "
              .$thatcontig->getContigName()." (penalty = $penalty)");
$logger->debug("Offset masking activated");
                my $partialsum = 0;
                foreach my $offset (@offsets) { 
                    $partialsum += $accumulate->{$offset};
                    next if ($partialsum < $weightedsum/2);
# the first offset here is the median
                    $lower = $offset - $offsetwindow/2; 
                    $upper = $offset + $offsetwindow/2;
$logger->debug("median: $offset ($lower $upper)");
                    $minimumsize = $options{segmentsize} || 2;
                    last;
		}
	    }
        }
    }

# determine guillotine; accept only alignments with a minimum number of reads 

    my $guillotine = 0;
    if ($options{readclipping}) { # perhaps drop altogether ??
        my $thiscount = scalar(@$lmappings);
        my $thatcount = scalar(@$cmappings);
        my $readcount = ($thiscount <= $thatcount ? $thiscount : $thatcount);
        $guillotine = 1 + int(log($readcount));
# adjust for small numbers (2 and 3)
        $guillotine -= 1 if ($guillotine > $readcount - 1);
        $guillotine =  1 if ($guillotine < 1); # minimum required
        $guillotine = $readcount if ($guillotine > $readcount);
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
$logger->info("Testing offsets");
$logger->fine(" @offsets");
    foreach my $offset (@offsets) {
# apply filter if boundaries are defined
        my $outofrange = 0;
        if (($lower != $upper) && ($offset < $lower || $offset > $upper)) {
            $outofrange = 1; # outsize offset range, probably dodgy mapping
$logger->info("offset $offset out of range $lower $upper");
        }
# sort mappings according to increasing contig start position
        my @mappings = sort { $a->[0] <=> $b->[0] } @{$inventory->{$offset}};
$logger->info("intervals ".scalar(@mappings));
        my $nreads = 0; # counter of reads in current segment
        my $segmentstart = $mappings[0]->[0];
        my $segmentfinis = $mappings[0]->[1];
$logger->info("segmentstart $segmentstart  segmentfinis $segmentfinis");
        foreach my $interval (@mappings) {
            my $intervalstart = $interval->[0];
            my $intervalfinis = $interval->[1];
            next unless defined($intervalstart);
            next unless defined($segmentfinis);
$logger->info("intervalstart $intervalstart  intervalfinis $intervalfinis");
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
$logger->debug("checking bad mapping range");
$logger->debug($poormapping->writeToString('bad range'));
$logger->debug("bad contig range: @badmap");
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

$logger->info(scalar(@c2csegments)." segments; before pruning");

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

$logger->info(scalar(@c2csegments)." segments after pruning");

# create an output Mapping enter the segments

    my $mapping = new Mapping($thatcontig->getContigName());
    $mapping->setSequenceID($thatcontig->getContigID());

    foreach my $segment (@c2csegments) {
        next if ($segment->[1] < $segment->[0]); # segment pruned out of existence
$logger->info("segment after filter @$segment");
        $mapping->putSegment(@$segment);
    }

# use the normalise method to handle possible single-base segments

    $mapping->normalise(mute=>1); # short messsage for alignment problem

    if ($mapping->hasSegments()) {
# here, test if the mapping is valid, using the overall maping range
        my ($isValid,$msg) = &isValidMapping($thiscontig,$thatcontig,$mapping,$overlapreads);
$logger->info("isVALIDmapping $isValid\n$msg",ss=>1);

# here possible recovery based on analysis of continuity of mapping segments

# if still not valid, 
        if (!$isValid && !$options{forcelink}) {
#$logger->debug("Spurious link detected to contig ".$thatcontig->getContigName());
            return 0, $overlapreads;
        }
# in case of split contig
        elsif ($isValid == 2) {
$logger->debug("(Possibly) split parent contig ".$thatcontig->getContigName());
            $deallocated = 0; # because we really don't know
        }
# for a regular link
        else {
            $deallocated = $thatcontig->getNumberOfReads() - $overlapreads; 
        }
# store the Mapping as a contig-to-contig mapping (prevent duplicates)
        if ($thiscontig->hasContigToContigMappings()) {
            my $c2cmaps = $thiscontig->getContigToContigMappings();
            foreach my $c2cmap (@$c2cmaps) {
                my ($isEqual,@dummy) = $mapping->isEqual($c2cmap,silent=>1);
                next unless $isEqual;
                next if ($mapping->getSequenceID() != $c2cmap->getSequenceID());
                $logger->error("Duplicate mapping to parent "
		              .$thatcontig->getContigName()." ignored");

$logger->debug("Duplicate mapping to parent ".$thatcontig->getContigName()." ignored");
$logger->debug("existing Mappings: @$c2cmaps");
$logger->debug("to be added Mapping: $mapping, tested against $c2cmap");
$logger->debug("equal mappings: \n".$mapping->toString()."\n".$c2cmap->toString());

                return $mapping->hasSegments(),$deallocated;
            }
        }
        $thiscontig->addContigToContigMapping($mapping);
    }
# single-read parent without valid link : add empty link
    elsif ($thatcontig->getNumberOfReads() == 1) {
        $thiscontig->addContigToContigMapping($mapping);
    }

# and return the number of segments, which could be 0

$logger->debug("EXIT");
   return $mapping->hasSegments(),$deallocated;

# if the mapping has no segments, no mapping range could be determined
# by the algorithm above. If the 'strong' mode was used, perhaps the
# method should be re-run in standard (strong=0) mode

}

##### TO BE DEPRECATED after linkcontigs has been tested 

sub linkToContig { # will be REDUNDENT to be DEPRECATED
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# if any, mapping from $compare to $this contig
# returns the number of mapped segments (usually 1); returns undef if 
# incomplete Contig instances or missing sequence IDs in mappings
    my $this = shift;
    my $compare = shift; # Contig instance to be compared to $this
    my %options = @_;

# option strong       : set True for comparison at read mapping level
# option readclipping : if set, require a minumum number of reads in C2C segment

    die "$this takes a Contig instance" unless (ref($compare) eq 'Contig');

my $DEBUG = &verifyLogger('linkToContig',1);

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
#            $logger->severe("Incomplete Mapping ".$mapping->getMappingName());
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
            my $ADB = $this->getArcturusDatabase() || $compare->getArcturusDatabase(); # get database handle
            unless ($ADB) {
		print STDERR "Unable to recover C2C link for read $readname "
                           . ": missing database handle\n";
		next;
            }
# get the versions of this read in a hash keyed on sequence IDs
            my $reads = $ADB->getAllVersionsOfRead(readname=>$readname);
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

    $mapping->normalise(mute=>1);

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

###### TO HERE

sub linkContigToParents {
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'linkContigToParents');

    return undef unless $contig->hasParentContigs();

    my $parents = $contig->getParentContigs();

#my $logger = &verifyLogger('linkContigToParents');
#$logger->info("linkContigToParents: parents : @$parents");

    my $report = '';
    foreach my $parent (@$parents) {
        $parent->getMappings(1); # delayed loading if no mappings
        my ($linked,$deallocated) = $contig->linkToContig($parent,%options);
            
        my $parentname = $parent->getContigName();

        unless ($linked) {
	    $report .= "; " if $report;
            $report .= "empty link detected to $parentname";
        }
        if ($deallocated) {
	    $report .= "; " if $report;
            $report .= "$deallocated reads deallocated from $parentname";
	}
    }
#$logger->info("link-contig-to-parents report : $report");
    return $report;
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

        my $segmentlist = [];
        foreach my $segment (@$newsegmentlist) {
            my $size = $segment->[1] - $segment->[0] + 1;
            push @$segmentlist,$segment if ($size > $threshold);
        }
        $newsegmentlist = $segmentlist;
    }

    return $newsegmentlist;
}

#------------------------------------------------------------------------------
# remapping tags
#------------------------------------------------------------------------------

sub propagateTagsToContig {
    my $class = shift;
# propagate tags FROM parent TO the specified target contig
return $class->newpropagateTagsToContig(@_);
    my $parent = shift;
    my $target = shift;
    my %options = @_;

    &verifyParameter($parent,'propagateTagsToContig 1-st parameter');

    &verifyParameter($target,'propagateTagsToContig 2-nd parameter');

# options, delayed loading of data
#          asis       : default 0, if no mapping/tags on target, get by delayed loading (if any)
# options, mapping selection
#          unique     : default 0, insist on 1 valid mapping between parent and target
#          norerun    : default 0, do not, if no mapping found, determine from scratch
# options, tagselection and marking
#          annotation : comma-separated list of selected annotation tag types (def: FCDS,CDS)
#          finishing  : comma-separated list of selected finishing tag types (def: REPT,RP20) 
#          markftags  : comma-separated list of finishing tag types, which are marked 
#                                       if frame shifts or truncations are are detected

# autoload tags unless tags are already defined or notagload specified

    $parent->getTags(($options{asis} ? 0 : 1),sort=>'full',merge=>1);

    return 0 unless $parent->hasTags();

    my $logger = &verifyLogger('propagateTagsToContig',1);

# use (delayed) autoloading to probe for c2cmapping on target; specify asis=>1 if not to be used 
# for new contigs built from a CAF source this will have no effect as contig_id is not defined

    $target->hasContigToContigMappings(1) unless $options{asis};

# get the mapping from parent to target

    my $unique = $options{unique} || 0; # default accept all matching mappings

    my @mapping = &getMappingFromParentToContig($parent,$target,unique=>$unique);

    unless (@mapping) {
        $logger->info("Finding mapping from scratch");
        return 0 if $options{norerun}; # prevent endless loop
        my %loptions; # to be refined (e.g. banded?)
        my ($nrofsegments,$deallocated) = $target->linkToContig($parent,%loptions);
        unless ($nrofsegments) {
	    $logger->info("Failed to determine parent to target mapping");
            return 0;
	}
# now that we have a mapping use recursion
        return $class->propagateTagsToContig($parent,$target,norerun=>1,%options);
    }

#--------------------------- test the mapping ---------------------------

    my @p2tmapping;
    foreach my $p2tmapping (@mapping) {     
        unless ($p2tmapping->isRegularMapping()) {
            my $name = $p2tmapping->getMappingName();
	    $logger->warning($name." is not a regular mapping");
            next;
# or try a split ?
        }
	push @p2tmapping,$p2tmapping;
    }

    unless (@p2tmapping) {
        my $pname = $parent->getContigName();
        my $tname = $target->getContigName();
        $logger->warning("NO valid mapping found between $pname and $tname");
        return 0;
    }

# propagate the tags from parent to target; define tag selection

# get the tags on the parent (as they are, but sorted and unique)

    my $ptags = $parent->getTags(0,sort=>'full',merge=>1);

    $logger->info("parent contig $parent has tags: ".scalar(@$ptags),skip=>1);

    foreach my $tag (@$ptags) {
        $logger->fine($tag->writeToCaf()); # test
    }

# define annotation tags explicitly or use defaults

    $options{annotation} = 'CDS|FCDS' unless defined $options{annotation}; # default
    my $annotation = $options{annotation};
# all other tags are considered as finishing tags, unless explicitly specified
    my $finishing  = $options{finishing};

    my @rtags; # remapped tags
    if ($annotation) {
        my %aoptions = (tagfilter => $annotation);     
        my $atags = &remapAnnotationTags($ptags,\@p2tmapping,%aoptions);
        $logger->info(scalar(@$atags)." remapped annotation tags added",skip=>1) if $atags;
        $target->addTag($atags);
    }

# now the finishing tags which cannot be split

    unless (defined($finishing) && !$finishing) { # i.e. unless finishing set to '0'   
        my %foptions;
        if ($finishing) {
            $foptions{tagfilter} = $finishing; # explicitly defined
            $foptions{tagscreen} = 1; # to include
        }
        else {
# default all tag typs not listed as annotation are considered as finishing tags
            $foptions{tagfilter} = $annotation;
            $foptions{tagfilter} = 'CDS|FCDS' unless $annotation; # default
            $foptions{tagfilter} .= '|ASIT'; # add Arcturus annotation to exclude
            $foptions{tagscreen} = 0; # to exclude
	}
        $foptions{markftags} = 'REPT|RP20' unless defined $options{markftags}; # default
        $foptions{markftags} = $options{markftags} if defined $options{markftags};
        my $ftags = &oldremapFinishingTags($ptags,\@p2tmapping,%foptions);
        $logger->info(scalar(@$ftags)." remapped finishing tags added",skip=>1) if $ftags;
        $target->addTag($ftags);
    }

# finally, remove possible duplicates on the target

    $target->getTags(0,sort=>'full',merge=>1);

    return;
}
#***

sub newpropagateTagsToContig {
    my $class = shift;
# propagate tags FROM parent TO the specified target contig
    my $parent = shift;
    my $target = shift;
    my %options = @_;

    &verifyParameter($parent,'propagateTagsToContig 1-st parameter');

    &verifyParameter($target,'propagateTagsToContig 2-nd parameter');

# options, delayed loading of data
#          asis       : default 0, if no mapping/tags on target, get by delayed loading (if any)
# options, mapping selection
#          unique     : default 0, insist on 1 valid mapping between parent and target
#          norerun    : default 0, do not, if no mapping found, determine from scratch
# options, tagselection and marking
#          annotation : comma-separated list of selected annotation tag types (def: FCDS,CDS)
#          finishing  : comma-separated list of selected finishing tag types (def: REPT,RP20) 
#          markftags  : comma-separated list of finishing tag types, which are marked 
#                                       if frame shifts or truncations are are detected
#          internal   : tag type used by Arcturus as internal tag

# autoload tags unless tags are already defined or notagload specified

    $parent->getTags(($options{asis} ? 0 : 1),sort=>'full',merge=>1);

    return 0 unless $parent->hasTags();

    my $logger = &verifyLogger('propagateTagsToContig',1);

# use (delayed) autoloading to probe for c2cmapping on target; specify asis=>1 if not to be used 
# for new contigs built from a CAF source this will have no effect as contig_id is not defined

    $target->hasContigToContigMappings(1) unless $options{asis};

# get the mapping from parent to target

    my $unique = $options{unique} || 0; # default accept all matching mappings

    my @mapping = &getMappingFromParentToContig($parent,$target,unique=>$unique);

    unless (@mapping) {
        $logger->info("Finding mapping from scratch");
        return 0 if $options{norerun}; # prevent endless loop
        my %loptions; # to be refined (e.g. banded?)
        my ($nrofsegments,$deallocated) = $target->linkToContig($parent,%loptions);
        unless ($nrofsegments) {
	    $logger->info("Failed to determine parent to target mapping");
            return 0;
	}
# now that we have a mapping use recursion
        return $class->propagateTagsToContig($parent,$target,norerun=>1,%options);
    }

#--------------------------- test the mapping ---------------------------

    my @p2tmapping;
    foreach my $p2tmapping (@mapping) {     
        unless ($p2tmapping->isRegularMapping()) {
            my $name = $p2tmapping->getMappingName();
	    $logger->warning($name." is not a regular mapping");
            next;
# or try a split ?
        }
	push @p2tmapping,$p2tmapping;
    }

    unless (@p2tmapping) {
        my $pname = $parent->getContigName();
        my $tname = $target->getContigName();
        $logger->warning("NO valid mapping found between $pname and $tname");
        return 0;
    }

#-------------------------------------------------------------------------
# propagate the tags from parent to target; define tag selection
#-------------------------------------------------------------------------

# get the tags on the parent (as they are, but sorted and unique)

    my $ptags = $parent->getTags(0,sort=>'full',merge=>1);

    $logger->info("parent contig $parent has tags: ".scalar(@$ptags),skip=>1);

foreach my $tag (@$ptags) {
    $logger->fine($tag->writeToCaf()); # test
}

# get the tags on the target (if any, as they are, but sorted and unique)

    my $ttags = $target->getTags(0,sort=>'full',merge=>1) || [];

    $logger->info("target contig $target has tags: ".scalar(@$ttags),skip=>1);

foreach my $tag (@$ttags) {
    $logger->fine($tag->writeToCaf()); # test
}

# define annotation tags explicitly or use defaults

    $options{annotation} = 'CDS|FCDS' unless defined $options{annotation}; # default

    my $annotation = &cleanTagList($options{annotation});
# all other tags are considered as finishing tags, unless explicitly specified
    my $finishing  = &cleanTagList($options{finishing});

# remap the annotation tags, if any, which are split under frameshifts

    if ($annotation) {
        my %aoptions = (tagfilter => $annotation);     
        my $atags = &remapAnnotationTags($ptags,\@p2tmapping,%aoptions);
        $logger->info(scalar(@$atags)." remapped annotation tags added",skip=>1) if $atags;
        $target->addTag($atags);
    }

# now the finishing tags (which are not to be split)

    unless (defined($finishing) && !$finishing) { # i.e. unless finishing set to '0'
        $options{internal} = 'ASIT' unless defined $options{internal};
        my $internaltag = $options{internal}; # can be 0
        my %foptions;
        if ($finishing) { # tags are explicitly defined
            $foptions{tagfilter} = $finishing;
            $foptions{tagscreen} = 1; # to include
        }
        else { # all tag types NOT listed as annotation are considered as finishing tags
            $foptions{tagscreen} = 0; # to exclude
            $foptions{tagfilter} = $annotation;
            $foptions{tagfilter} = "CDS|FCDS" unless $annotation; # default, if annotation defined 0
            $foptions{tagfilter} .= "|$internaltag" if $internaltag; # do not remap internal tag type
	}
        my $ftags = &remapFinishingTags($ptags,\@p2tmapping,%foptions);
# get the tags in the parent (as they are, but sorted and unique)
        if ($ftags && @$ftags) {
            $logger->info(scalar(@$ftags)." finishing tags remapped from parent",skip=>1);
# now (try to) match inherited (f)tags with the (t)tags on target
            TagFactory->sortTags($ftags,sort=>'full',merge=>1);
            &linkRemappedFinishingTags($ftags,$ttags); # to transfer parent_tag IDs 
# finally test for frame shifts and rename selected tags
            $options{markftags} = 'REPT|RP20' unless defined $options{markftags}; # can be 0
            my $markftags = &cleanTagList($options{markftags});
            $ftags = &filterRemappedFinishingTags($ftags,$markftags,$internaltag) if $markftags;
	    
            $logger->info(scalar(@$ftags)." remapped finishing tags added",skip=>1) if $ftags;
            $target->addTag($ftags);
	}
    }

# finally, remove possible duplicates on the target

    $target->getTags(0,sort=>'full',merge=>1);

    return;
}

sub cleanTagList {
# helper routine with propagateTagsToContig
    my $list = shift;
    return $list unless $list; # can be undef or 0
    $list =~ s/^\s+|\s+$//g; # leading/trailing blanks
    $list =~ s/\W+/|/g; # put separators in include list
    return $list;
}

sub oldremapFinishingTags {
# private, remap input tags without splitting (marking frameshifts/truncations) 
    my $tags = shift;
    my $maps = shift;
    my %options = @_;

    &verifyPrivate ($tags,'remapFinishingTags');

    my $logger = &verifyLogger('remapFinishingTags',1);

# options

# tagfilter : comma-separated list of selected tagtypes (def: FCDS,CDS)
# tagscreen : default 0, exclude (only) the tags in tagfilter; set 1 to include
# markftags : if set, rename the remapped tags to a type used internally by
#             Arcturus, but ONLY if frame shifts or truncations are are detected

    my $includetag; # default include all
    my $excludetag; # default exclude none

    my $tagfilter = $options{tagfilter};
    $tagfilter = 'FCDS|CDS' unless defined $tagfilter; # default annotation tags

    if ($tagfilter) { # can be defined and 0
        $tagfilter =~ s/^\s+|\s+$//g; # leading/trailing blanks
        $tagfilter =~ s/\W+/|/g; # put separators in include list
        my $screen = $options{tagscreen}; # 1 include; 0 exclude
        $screen = 0 unless defined $screen; # default exclude
        $excludetag = $tagfilter unless $screen;
        $includetag = $tagfilter if $screen;
    }
# specific tags can have their type changed on output to flag frame shifts or truncations
    my $markftags = $options{markftags};
    if ($markftags) {
        $markftags =~ s/^\s+|\s+$//g; # leading/trailing blanks
        $markftags =~ s/\W+/|/g; # put separators in include list
    }

#------------------------------------------------------------------------------
# remap tags which may not be split and can have frameshifts after remapping
#------------------------------------------------------------------------------

    my @rtags; # for (remapped) tags
    my $remapped = 0;
    foreach my $ptag (@$tags) {
# apply include or exclude filter
        my $tagtype = $ptag->getType() || '';
        next if ($excludetag && $tagtype =~ /\b$excludetag\b/i);
        next if ($includetag && $tagtype !~ /\b$includetag\b/i);

        my @newtags;
        foreach my $p2tmapping (@$maps) {
            my $tptags = $ptag->remap($p2tmapping,nosplit=>'collapse',tracksegments=>3);
            next unless ($tptags && @$tptags);
            push @newtags, $tptags->[0]; 
	}
        unless (@newtags) {
    	    $logger->info("tag $tagtype could not be re-mapped (1)");
	    next;
	}

# if the remapped tag has frameshifts or is truncated & the tagtype is among
# the keys of the hash list $newtypetag the tagtype is to be renamed  

        foreach my $tptag (@newtags) {
            my $tagtype = $tptag->getType();
            $tptag->setParentTagID($ptag->getID());
            unless ($markftags && $tagtype =~ /$markftags/) {
                push @rtags,$tptag;
   	        $remapped++;
		next;
	    }
# rename the tag and mark with a comment about about frame shifts or truncations, if present
	    next unless ($tptag->getFrameShiftStatus() || $tptag->getTruncationStatus());
            my $comment = $tptag->getComment();
            my $tagcomment = $tptag->getTagComment();
            my $newcomment = "Alteration detected of previous version of tag "
                           . "at this position\\n\\$tagcomment\\n\\$comment";
# rename the tag type and amend the comment
            $tptag->setType('ASIT');
            $tptag->setTagComment($newcomment);
            $tptag->setDNA(); # remove any sequence info
            $tptag->setTagSequenceID();
            $logger->info($tptag->writeToCaf()); # test
            push @rtags,$tptag;
	    $remapped++;
        }
    }

    $logger->info("$remapped tags remapped (no-split) ",skip=>1) if $remapped;

# finally, remove duplicates on the target

    return [@rtags];
}

sub remapFinishingTags {
# private, remap input tags without splitting (marking frameshifts/truncations) 
    my $tags = shift;
    my $maps = shift;
    my %options = @_;

    &verifyPrivate ($tags,'remapFinishingTags');

    my $logger = &verifyLogger('remapFinishingTags',1);

# tagfilter : comma-separated list of selected tagtypes (def: FCDS,CDS)
# tagscreen : default 0, exclude (only) the tags in tagfilter; set 1 to include

    my $includetag; # default include all
    my $excludetag; # default exclude none

    my $tagfilter = $options{tagfilter};

    if ($tagfilter) { # can be defined and 0
        my $screen = $options{tagscreen}; # 1 include; 0 exclude
        $screen = 0 unless defined $screen; # default exclude
        $excludetag = $tagfilter unless $screen;
        $includetag = $tagfilter if $screen;
    }

#------------------------------------------------------------------------------
# remap tags which may not be split and can have frameshifts after remapping
#------------------------------------------------------------------------------

    my @rtags; # for (remapped) tags
    my $remapped = 0;
    foreach my $ptag (@$tags) {
# apply include or exclude filter
        my $tagtype = $ptag->getType() || '';
        next if ($excludetag && $tagtype =~ /\b$excludetag\b/i);
        next if ($includetag && $tagtype !~ /\b$includetag\b/i);

        my $id = $ptag->getID();

        my $newtag;
        foreach my $p2tmapping (@$maps) {
            my $tptags = $ptag->remap($p2tmapping,nosplit=>'collapse',tracksegments=>3);
            next unless ($tptags && @$tptags);
            foreach my $tptag (@$tptags) {
                $tptag->setParentTagID($id);
                push @rtags, $tptag;
                $newtag++;
	    }
	}
# check result
        unless ($newtag) {
    	    $logger->info("tag $tagtype (ID $id) could not be re-mapped");
	    next;
	}
        unless ($newtag == 1) {
            $logger->info("tag $tagtype (ID $id) was unexpectedly split"); 
	}
	$remapped++;
    }

    $logger->info("$remapped tags remapped (no-split) ",skip=>1) if $remapped;

    return [@rtags];
}

sub linkRemappedFinishingTags {
# compare a list of new tags ttags with a list of inherited tags ftags
    my $ftags = shift; # from parent
    my $ttags = shift; # from data source, e.g. CAF file

    my ($i,$j) = (0,0);
    while ($i < scalar(@$ftags) && $j < scalar(@$ttags)) {
        my $ftag = $ftags->[$i];
        my $ttag = $ttags->[$j];
        if ($ftag->getPositionLeft() < $ttag->getPositionLeft()) {
	    $i++;
	}
	elsif ($ftag->getPositionLeft() > $ttag->getPositionLeft()) {
            $j++;
	}
        elsif ($ftag->isEqual($ttag)) {
            $ftag->setParentTagID($ttag->getParentTagID());
            $i++;
	}
	elsif ($ftag->isEqual($ttag,contains=>1)) {
            $ftag->setParentTagID($ttag->getParentTagID());
            $i++;
	}
	elsif ($ftag->isEqual($ttag,overlaps=>1)) {
            $ftag->setParentTagID($ttag->getParentTagID());
            $i++;
	}
	else{
	    $j++;
	}
    }
}

sub filterRemappedFinishingTags {
# filter tags of given tag type 
    my $tags = shift; # remapped tags
    my $type = shift; # tag types to be filtered (undef or 0 for all)
    my $tnew = shift || 'ASIT'; # replacement tagtype for selected tags

# type : if set, rename the remapped tags of type to new tnew used internally
#        by Arcturus, but ONLY if frame shifts or truncations are are detected;
#        tags of type without frameshifts are removed from the list

    &verifyPrivate ($tags,'filterRemappedFinishingTags');

    my $logger = &verifyLogger('filterRemappedFinishingTags',1);

# identify the counterpart of the inherited tags among the new tags and transfer
# the parent tag id; if frameshifts found replace the inherited tag by ASIT tag 

    $logger->info("filtering for type $type");

    my @ftags;
    foreach my $tag (@$tags) {
# the filter selects tags for further analysis
        my $tagtype = $tag->getType();
        unless ($type && $tagtype =~ /\b$type\b/i) {
            push @ftags, $tag; # accept tag type not matching filter as is
            next;
	}

# rename the tag and mark with a comment about frame shifts or truncations, if present
	    
        next unless $tnew; # has the effect of ignoring tag types matching the filter

        next unless ($tag->getFrameShiftStatus() || $tag->getTruncationStatus()); # ignore tag

# replace the "damaged" tag by an internal tag to record the frame shift

        my $comment = $tag->getComment();
        my $tagcomment = $tag->getTagComment();
        my $newcomment = "Alteration detected of previous version of tag "
                       . "at this position\\n\\$tagcomment\\n\\$comment";
# rename the tag type and amend the comment
        $tag->setType($tnew);
        $tag->setTagComment($newcomment);
        $tag->setDNA(); # remove any sequence info
        $tag->setTagSequenceID();
        push @ftags,$tag;
        $logger->info($tag->writeToCaf()); # test
    }

    return [@ftags];
}

sub remapAnnotationTags {
# private, remap input tags with split allowed 
    my $tags = shift;
    my $maps = shift;
    my %options = @_;

    &verifyPrivate ($tags,'remapAnnotationTags');

    my $logger = &verifyLogger('remapAnnotationTags',1);

# options

# tagfilter : comma-separated list of selected tagtypes (def: FCDS,CDS)
# tagscreen : default 1, include (only) the tags in tagfilter; set 0 to exclude 

    my $includetag; # default include all
    my $excludetag; # default exclude none
    my $tagfilter = $options{tagfilter};
    $tagfilter = 'FCDS|CDS' unless defined $tagfilter; # default annotation tags
    if ($tagfilter) { # can be 0
        my $screen = $options{tagscreen}; # 1 include; 0 exclude
        $screen = 1 unless defined $screen; # default include
        $excludetag = $tagfilter unless $screen;
        $includetag = $tagfilter if $screen;
    }

#-----------------------------------------------------------------------------------
# deal with the tags that may be split when remapped
#-----------------------------------------------------------------------------------

    my %splittagoptions = (split => 1, tracksegments => 3);

    my @rtags; # for (remapped) tags
    my $remapped = 0;
    foreach my $ptag (@$tags) {
        my $tagtype = $ptag->getType();
        next if ($excludetag && $tagtype =~ /\b$excludetag\b/i);
        next if ($includetag && $tagtype !~ /\b$includetag\b/i);
# remap 
        foreach my $p2tmapping (@$maps) {
            $splittagoptions{changestrand} = ($p2tmapping->getAlignment() < 0) ? 1 : 0;
            my $tptags = $ptag->remap($p2tmapping,%splittagoptions);
            next unless $tptags;
            $remapped++;
            foreach my $tag (@$tptags) {
                $tag->setParentTagID($ptag->getID());
                $logger->fine($tag->writeToCaf()); # test
                push @rtags, $tag;
	    }
        }
    }

# if remapped annotation tags found, (try to) merge tag fragments

    my $atags = [];

    if (@rtags) {
        $logger->info("remapped (split allowed) ".scalar(@rtags)
                     ." tags from $remapped input");
        my %moptions = (overlap => ($options{overlap} || 0));
        $atags = TagFactory->mergeTags(\@rtags,%moptions);

        $logger->info(scalar(@$atags)." tags after merge") if ($atags && @$atags);

    }

    return $atags;
}

sub getMappingFromParentToContig {
# private: take input contig and return the mapping from contig to it's parent
    my $parent = shift;
    my $target = shift;
    my %options = @_;

# option : unique  to require one single mapping; reject multiple mappings

    my $logger = &verifyLogger('getMappingFromParentToContig');

#----------------------------------------------------------------------------
# check/get the parent-child mapping: is there a mapping between them and
# is the ID of the one of the parents identical to the input $parent?
# we do this by getting the parents on the $target and compare with $parent
#----------------------------------------------------------------------------

    my $parent_id = $parent->getContigID() || 0;

    my $target_id = $target->getContigID() || 0;

# if parents are specified on the $target then test if $parent is among them
# if no parents specified on $target then accept the the current $parent

    if ($target->hasParentContigs()) {
# the input $parent must be among the list of parents on the target 
        my $verifyparent = 0;
        my $tparents = $target->getParentContigs();
        foreach my $tparent (@$tparents) {
            my $tparent_id = $tparent->getContigID();
	    next unless ($tparent_id && $tparent_id == $parent_id);
            $verifyparent = 1;
            $logger->info("$parent_id is accepted as a parent of $target_id");
            last;
	}
        unless ($verifyparent) {
            $logger->info("no valid parent ($parent_id) provided for contig ($target_id)");
            return (); # empty array
        }
    }

# ok, $parent is accepted as a parent of $target; now find the mapping to be used

    my @c2cmappings;
    foreach my $contig ($target,$parent) { # look in both contigs
        my $cmappings = $contig->getContigToContigMappings();
        next unless ($cmappings && @$cmappings);
        push @c2cmappings, @$cmappings;
    }

    $logger->info(scalar(@c2cmappings)." mappings to be tested");

# the tags are on the parent, therefore we look for a mapping with the parent as
# xdomainsequence (see Mapping) (and the target as ydomainsequence, if defined) 

    my @mapping;
    my @reserve;
# collect the possible matching mapping(s) or inverse by matching the parent_id then target_id 
    $logger->info("parent ID $parent_id   target ID $target_id");
    foreach my $mapping (@c2cmappings) {
        my $xdomainseq_id = $mapping->getSequenceID('x') || 0;
        my $ydomainseq_id = $mapping->getSequenceID('y') || 0;
        $logger->info("mapping $mapping xsid $xdomainseq_id  ysid $ydomainseq_id");
# collect mapping(s), or their inverse(s), which match the parent in the x-domain
        if ($xdomainseq_id && $xdomainseq_id == $parent_id) {
            next if ( $target_id && $ydomainseq_id && $target_id != $ydomainseq_id);
            next if (!$target_id && $ydomainseq_id); 
            $logger->info("mapping $mapping accepted");
            push @mapping,$mapping;
        }
        elsif ($ydomainseq_id && $ydomainseq_id == $parent_id) {
# the inverse mapping matches the parent domain
            next if ( $target_id && $xdomainseq_id && $target_id != $xdomainseq_id);
            next if (!$target_id && $xdomainseq_id);
            $logger->info("inverse of mapping $mapping accepted");
            push @mapping,$mapping->inverse();
        }
    }
# if no mapping was found (e.g. parent id is undefined (taken to be 0), use target_id on its own
    if (!@mapping && $target_id) {
        foreach my $mapping (@c2cmappings) {
            my $xdomainseq_id = $mapping->getSequenceID('x') || 0;
            my $ydomainseq_id = $mapping->getSequenceID('y') || 0;
            push @reserve,$mapping            if ($target_id == $ydomainseq_id && !$xdomainseq_id);
            push @reserve,$mapping->inverse() if ($target_id == $xdomainseq_id && !$ydomainseq_id);
        }
    }
# if still no mapping identified, then no sequence id info may be available to identify a mapping
# in this case we assume that any (single) mapping on the parent or on the target is the one to use
    unless (@mapping || @reserve) {
        foreach my $contig ($target,$parent) { # look in both contigs
            my $cmappings = $contig->getContigToContigMappings();
            next unless ($cmappings && @$cmappings == 1);
            next if $contig->getContigID(); # was picked up earlier and rejected
            push @reserve,$cmappings->[0]->inverse() if ($contig eq $target);
            push @mapping,$cmappings->[0] if ($contig eq $parent);
        }
    }

    $logger->warning("mapping @reserve taken as backup") if @reserve;

# ok, decide on which mapping to use (allow more than one mapping per link)

    if (scalar(@mapping) == 1) {
	$logger->fine("only 1 mapping matches");
    }
    elsif (@mapping) {
# test for duplicate mappings, sort mappings ?        
        while (@mapping > 1) {
# exit loop on first mismatch (implies at least 2 different ones)
            last unless ($mapping[0]->isEqual($mapping[1]));
            shift @mapping;
        }
        if (@mapping > 1 && $options{unique}) {
  	    $logger->warning("ambiguous parent-to-contig mapping: several (reserve) matches");
            return 0; # this case is unrecoverable
	}
    }
    elsif (scalar(@reserve) == 1) {
	$logger->info("using backup mapping option");
        push @mapping, @reserve;
    }
# the next branches do not return but proceed with an attempt to determine mapping from scratch
    elsif (@reserve) {
	$logger->warning("ambiguous contig-to-parent mapping: several matches");
    }
    else {
	$logger->warning("no (valid) parent-to-contig mapping found (p:$parent_id c:$target_id)");
    }

    return @mapping;
}

sub sortContigTags {
# sort and remove duplicate contig tags; re: Contig->getTags
    my $class = shift;
    my $contig = shift;
    my %options = @_; # sort=> (position, full), merge=>

    &verifyParameter($contig,'sortContigTags');

    my $logger = verifyLogger('sortContigTags');

    my $tags = $contig->getTags(); # tags as is

    return unless ($tags && @$tags);

# sort the tags with increasing tag position

    return TagFactory->sortTags($tags,@_);
}

#-----------------------------------------------------------------------------
# project inheritance
#-----------------------------------------------------------------------------

sub inheritProject {
# inherit a project from a contig's parents, if any ; puts project_id and returns either
# a Project instance, or undef for not possible (no parents), or 0 and comment for a fail
    my $class = shift;
    my $contig = shift;
    my %options = @_; # delayed , measure or score

    &verifyParameter($contig,'inheritProject');

# get the parent contigs, as is; if none, and if specified, use delayed loading

    my $delayedload = $options{delayed} || 0;
    unless ($contig->hasParentContigs($delayedload)) {
        return undef; # act upon in calling model
    }

# test the input inheritance model

    my $score = $options{score} || $options{measure} || 1; # default readcount
    my %inherit = ('readcount'    ,1,  # nr of reads in all contigs for project
                   'contiglength' ,2,  # total consensus length of contigs
                   'contigcount'  ,3,  # number of contigs in project
                   'largestcontig',4,  # length of largest contig in project
                   'averagesize'  ,5); # average size of contigs in project
    my $inheritmodel = $inherit{$score} || $score; # replace by 1,2 or 3
    if ($inheritmodel < 1 || $inheritmodel > 5) {
        return (0,"invalid inheritance model: $score");
    }

# collect the parent information, hash various measures

    my %sumreadsinparent;   # total nr of reads for projects of parent contigs
    my %sumconsensussize;   # total consensus length for projects of parent contigs
    my %projectcontigcount; # number of parent contigs per project
    my %consensussize;      # largest contig size per project of parent contigs

    my $parents = $contig->getParentContigs();

    my %parentforproject;
    foreach my $parent (@$parents) {
        my $pid = $parent->getProject() || next; # skip if undefined or 0
        my $cid = $parent->getContigID();
        $sumreadsinparent{$pid} += $parent->getNumberOfReads();
	$sumconsensussize{$pid} += $parent->getConsensusLength();
        $projectcontigcount{$pid}++;
        $parentforproject{$pid} = $parent unless defined $parentforproject{$pid};
        my $length = $parent->getConsensusLength();
        $consensussize{$pid} = $length unless defined $consensussize{$pid};
        $consensussize{$pid} = $length if ($length > $consensussize{$pid});
    }

# determine a parent contig of which the project is to be used

    my $project_id;
    my $maxscore;
    my @inheritmodelscores;
    foreach my $pid (keys %projectcontigcount) {
        $inheritmodelscores[0] = $sumreadsinparent{$pid};   # model 1 (total nr of reads) 
        $inheritmodelscores[1] = $sumconsensussize{$pid};   # model 2 (total consensus length)
        $inheritmodelscores[2] = $projectcontigcount{$pid}; # model 3 (number of contigs)     
        $inheritmodelscores[3] = $consensussize{$pid};      # model 4 (length largest contig)
        $inheritmodelscores[4] = int($consensussize{$pid}/$projectcontigcount{$pid} + 0.5); # m 5
        my $score = $inheritmodelscores[$inheritmodel-1];

# assign on first encounter and if score > maxscore

        unless (defined $maxscore && $score < $maxscore) {      
            $maxscore = $score;
            $project_id = $pid;
	    next;
	}
# if the scores are equal, then enlist one of the alternatives
        if ($score == $maxscore) {
            my $select = 0;
            if ($inheritmodel != 3) {
# use smallest number of contigs as alternative
                $select = 1 if ($projectcontigcount{$pid} < $projectcontigcount{$project_id});
                if ($projectcontigcount{$pid} == $projectcontigcount{$project_id}) {
# and if still no decision try the size of the largest contig
                    $select = 1 if ($consensussize{$pid} > $consensussize{$project_id});
	        }
	    }
            else {
# use size of largest contig
                $select = 1 if ($consensussize{$pid} > $consensussize{$project_id});
                if ($consensussize{$pid} == $consensussize{$project_id}) {
                    $select = 1 if ($projectcontigcount{$pid} < $projectcontigcount{$project_id});
		}
	    }
            next unless $select;
            $maxscore = $score;
            $project_id = $pid;
        }
    }
    
    return undef unless $project_id;

    $contig->setProject($project_id); # sets the project ID in contig

# get a Project instance via a parent contig (where data SOURCE is defined)
        
    my $parent = $parentforproject{$project_id};
    return $parent->getProject(instance=>1);
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
    print STDOUT "instead of $object\n" if $object;
    exit 1;
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return unless ($caller && ($caller  eq 'ContigHelper' ||
                           ref($caller) eq 'ContigHelper'));
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

        $LOGGER->debug('ENTER') if shift;

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

    &verifyLogger(); # creates a default if $LOGGER undefined

    Alignment->setLogger($logger);
}

#-----------------------------------------------------------------------------

1;
