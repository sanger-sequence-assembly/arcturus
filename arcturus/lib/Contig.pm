package Contig;

use strict;

use Mapping;

use Clipping;

use TagFactory::ContigTagFactory;

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

my $tagfactory; # class variable

#-----------------------------------------------------------------------------

sub new {
    my $class      = shift;
    my $contigname = shift; # optional

    my $this = {};

    bless $this, $class;

    $this->{data} = {}; # meta data hash

    $this->setContigName($contigname) if $contigname;

    return $this;
}

#------------------------------------------------------------------- 
# parent database handle
#-------------------------------------------------------------------

sub setArcturusDatabase {
# import the parent Arcturus database handle
    my $this = shift;
    my $ADB  = shift;

    if (ref($ADB) eq 'ArcturusDatabase') {
        $this->{ADB} = $ADB;
    }
    else {
        die "Invalid object passed: $ADB";
    }
}

sub getOrganism {
# retrieve the organism 
    my $this = shift;

    my $ADB = $this->{ADB} || return 0; # the parent database

    return $ADB->getOrganism();
}

sub getInstance {
# retrieve the instance 
    my $this = shift;

    my $ADB = $this->{ADB} || return 0; # the parent database

    return $ADB->getInstance();
}

#-------------------------------------------------------------------
# delayed loading of DNA and quality data from database
#-------------------------------------------------------------------

sub importSequence {
# private method for delayed loading
    my $this = shift;

    my $ADB = $this->{ADB} || return 0; # the parent database

    my $cid = $this->getContigID() || return 0; 

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForContigID($cid);

    $this->setSequence($sequence); # a string
    $this->setBaseQuality($quality);   # reference to an array of integers

    return 1;
}

#-------------------------------------------------------------------    
# importing & exporting data and meta data
#-------------------------------------------------------------------    

sub setAverageCover {
    my $this = shift;
    $this->{data}->{averagecover} = shift;
}

sub getAverageCover {
    my $this = shift;
    return $this->{data}->{averagecover};
}

#-------------------------------------------------------------------   

sub getConsensusLength {
    my $this = shift;
    $this->importSequence() unless defined($this->{data}->{clength});
#    $this->getStatistics()  unless defined($this->{data}->{clength});
    return $this->{data}->{clength} || 0;
}

sub setConsensusLength {
    my $this = shift;
    $this->{data}->{clength} = shift;
}

#-------------------------------------------------------------------   

sub getContigID {
    my $this = shift;
    return $this->{data}->{contig_id} || 0;
}

sub getSequenceID {
    my $this = shift;
    return $this->getContigID();
}

sub setContigID {
    my $this = shift;
    my $cid  = shift;

    return if ($cid && $cid =~ /\D/); # if defined must be a number

    $this->{data}->{contig_id} = $cid;

# add the sequence ID to any tags

    if (my $tags = $this->getTags()) {
        foreach my $tag (@$tags) {
            $tag->setSequenceID($this->getSequenceID());
        }
    }
}

#-------------------------------------------------------------------   

sub getContigName {
    my $this = shift;

# in its absence generate a name based on the contig_id

    unless(defined($this->{contigname})) {
        my $cid = $this->getContigID() || 0;
        my $ins = $this->getInstance() || 0;
        my $org = $this->getOrganism() || 0;
        $this->setContigName($ins."_".$org."_contig_".sprintf("%08d",$cid));
    }
    return $this->{contigname};
}

sub setContigName {
    my $this = shift;
    $this->{contigname} = shift;
}

#------------------------------------------------------------------- 

sub setCreated {
    my $this = shift;
    $this->{created} = shift;
}

#------------------------------------------------------------------- 

sub setGap4Name {
    my $this = shift;
    $this->{gap4name} = shift;
}

sub getGap4Name {
    my $this = shift;
    $this->{gap4name} = $this->getReadOnLeft() unless $this->{gap4name};
    return $this->{gap4name} || 'unknown';
}

#------------------------------------------------------------------- 
  
sub getNumberOfParentContigs {
    my $this = shift;
# if number of contigs not defined get it from the Parent Contigs array
    if (!defined($this->{data}->{numberofparentcontigs})) {
        my $npc = $this->hasParentContigs();
        $this->{data}->{numberofparentcontigs} = $npc;
    }
    return $this->{data}->{numberofparentcontigs};
}

sub setNumberOfParentContigs {
    my $this = shift;
    $this->{data}->{numberofparentcontigs} = shift;   
}

#------------------------------------------------------------------- 
  
sub getNumberOfReads {
    my $this = shift;
# if number of reads not defined get it from the Read array
    if (!defined($this->{data}->{numberofreads}) && $this->hasReads()) {
        $this->{data}->{numberofreads} = scalar(@{$this->getReads});
    }
    return $this->{data}->{numberofreads} || 0;
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;   
}

#------------------------------------------------------------------- 
  
sub getNumberOfNewReads {
    my $this = shift;
    return $this->{data}->{numberofnewreads} || 0;  
}
  
sub setNumberOfNewReads {
    my $this = shift;
    $this->{data}->{numberofnewreads} = shift;   
}

#-------------------------------------------------------------------   

sub getOrigin {
    my $this = shift;
    return $this->{data}->{origin} || '';   
}

sub setOrigin {
    my $this = shift;
    $this->{data}->{origin} = shift;
}

#-------------------------------------------------------------------   

sub setBaseQuality {
# import base quality as an array with base quality values
    my $this    = shift;
    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$this->{BaseQuality} = $quality;
        return 1;
    }
    else {
        return undef;
    }
}

sub getBaseQuality {
# return the quality data (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{BaseQuality});
    return $this->{BaseQuality}; # an array reference (or undef)
}

#------------------------------------------------------------------- 

sub getProject {
    my $this = shift;
    return $this->{project};
}

sub setProject {
    my $this = shift;
    $this->{project} = shift;
}

#-------------------------------------------------------------------   

sub getReadOnLeft {
    my $this = shift;
    return $this->{data}->{readonleft};
}

sub setReadOnLeft {
# private method
    my $this = shift;
    $this->{data}->{readonleft} = shift;
}

#-------------------------------------------------------------------   

sub getReadOnRight {
    my $this = shift;
    return $this->{data}->{readonright};
}

sub setReadOnRight {
# private method
    my $this = shift;
    $this->{data}->{readonright} = shift;
}

#-------------------------------------------------------------------   

sub setSequence {
# import consensus sequence (string) and its length (derived)
    my $this     = shift;
    my $sequence = shift;

    if (defined($sequence)) {
	$this->{Sequence} = $sequence;
        $this->setConsensusLength(length($sequence));
    }
}

sub getSequence {
# return the DNA (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{Sequence});
    return $this->{Sequence};
}

#------------------------------------------------------------------- 

sub setUpdated {
    my $this = shift;
    $this->{updated} = shift;
}

#-------------------------------------------------------------------    
# importing/exporting Read(s), Mapping(s) & Tag(s) etcetera
#-------------------------------------------------------------------    

sub getReads {
# return a reference to the array of Read instances (can be empty)
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{Read} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getReadsForContig($this);
    }
    return $this->{Read};
}

sub addRead {
# add Read object or an array of Read objects to the internal buffer
    my $this = shift;
    my $Read = shift;

    $this->importer($Read,'Read');
}

sub hasReads {
# returns true if this Contig has reads
    my $this = shift;
    return $this->getReads() ? 1 : 0;
}

# read-to-contig mappings

sub getMappings {
# return a reference to the array of Mapping instances (can be empty)
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{Mapping} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getReadMappingsForContig($this);
    }
    return $this->{Mapping};
} 

sub addMapping {
# add (read) Mapping object (or an array) to the internal buffer
    my $this = shift;
    $this->importer(shift,'Mapping');
}

sub hasMappings {
# returns true if this Contig has (read-to-contig) mappings
    my $this = shift;
    return $this->getMappings(shift) ? 1 : 0;
}

# contig tags

sub getTags {
# return a reference to the array of Tag instances (can be empty)
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{Tag} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getTagsForContig($this);
    }
    return $this->{Tag};
}

sub addTag {
# add Tag object or an array of Tag objects to the internal buffer
    my $this = shift;
    my $ctag = shift;

    $this->importer($ctag,'Tag','Tag',$this->getSequenceID());
}

sub hasTags {
# returns true if this Contig has tags
    my $this = shift;
    return $this->getTags(shift) ? 1 : 0;
}

# contig-to-parent mappings

sub getContigToContigMappings {
# add (contig) Mapping object (or an array) to the internal buffer
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ContigMapping} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getContigMappingsForContig($this);
    }
    return $this->{ContigMapping};
}

sub addContigToContigMapping {
    my $this = shift;
    $this->importer(shift,'Mapping','ContigMapping');
}

sub hasContigToContigMappings {
# returns true if this Contig has contig-to-contig mappings
    return &getContigToContigMappings(@_) ? 1 : 0;
}

# parent contig instances

sub getParentContigs {
# returns array of parent Contig instances
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ParentContig} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getParentContigsForContig($this);
    }
    return $this->{ParentContig};
}

sub addParentContig {
# add parent Contig instance
    my $this = shift;
    $this->importer(shift,'Contig','ParentContig');
}

sub hasParentContigs {
# returns number of previous contigs
    my $this = shift;
    my $parents = $this->getParentContigs(shift);
    return $parents ? scalar(@$parents) : 0;
}

# child contig instances (re: tag propagation)

sub getChildContigs {
# returns array of child Contig instances
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ChildContig} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getChildContigsForContig($this);
    }
    return $this->{ChildContig};
}

sub addChildContig {
# add child Contig instance
    my $this = shift;
    $this->importer(shift,'Contig','ChildContig');
}

sub hasChildContigs {
# returns number of offspring contigs 
    my $this = shift;
    my $parents = $this->getChildContigs(shift);
    return $parents ? scalar(@$parents) : 0;
}

#-------------------------------------------------------------------    

sub importer {
# private generic method for importing objects into a Contig instance
    my $this = shift;
    my $Component = shift;
    my $class = shift; # (obligatory) class name of object to be stored
    my $buffername = shift; # (optional) internal name of buffer

    $buffername = $class unless defined($buffername);

    die "Contig->importer expects a component type" unless $class;

    if (ref($Component) eq 'ARRAY') {
# recursive use with scalar parameter
        while (scalar(@$Component)) {
            $this->importer(shift @$Component,$class,$buffername,@_);
        }
    }
    elsif ($Component) {
# test type of input object against specification
        my $instanceref = ref($Component);
        if ($class ne $instanceref) {
            die "Contig->importer expects a(n array of) $class instance(s) as input";
        }
        $this->{$buffername} = [] if !defined($this->{$buffername});
        push @{$this->{$buffername}}, $Component;
        return unless (my $sequence_id = shift);
        $Component->setSequenceID($sequence_id);
# shouldn't this be doen for ChildContigs and Mappings and Reads as well?
        $Component->setHost($this) if ($class eq 'Tag');
    }
    else {
# reset option
        undef $this->{$buffername};
    }
}

#-------------------------------------------------------------------    
# calculate consensus length, cover, etc
#-------------------------------------------------------------------

sub getStatistics {
# collect a number of contig statistics
    my $this = shift;
    my $pass = shift; # >= 2 allow adjustment of zeropoint, else not

    $pass = 1 unless defined($pass);
    $pass = 1 unless ($pass > 0);

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
        my $name = $this->getContigName() || 0;
        if (my $mappings = $this->getMappings()) {
            my $init = 0;
            $numberofnames = 0;
            $totalreadcover = 0;
            foreach my $mapping (@$mappings) {
                my $readname = $mapping->getMappingName();
# find begin/end of contig range cover by this mapping
                my ($cs, $cf) = $mapping->getContigRange();
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
                print STDERR "Contig $name requires shift by $shift\n";
                foreach my $mapping (@$mappings) {
                    $mapping->applyShiftToContigPosition($shift);
                }
# and apply shift to possible tags
                if ($this->hasTags()) {
                    $tagfactory = new ContigTagFactory() unless $tagfactory;
                    print STDERR "Adjusting tag positions (to be tested)\n";
                    my $tags = $this->getTags();
                    foreach my $tag (@$tags) {
                       $tagfactory->transpose($tag,1,[($shift,$shift)],$cfinal-$shift);
#                       $tag->shift($shift,1,$cfinal);
                    }
	        }
# and redo the loop (as $pass > 0)
                $isShifted = 1;
            }
            elsif ($isShifted) {
# this should never occur, indicative of corrupted data/code in Mapping/Segment
                print STDERR "Illegal condition in Contig->getStatistics\n";
                return 0;
            }
        }
        else {
            print STDERR "$name has no read-to-contig mappings\n";
            return 0;
        }
    }

# okay, now we can calculate/assign some overall properties

    my $clength = $cfinal-$cstart+1;
    $this->setConsensusLength($clength);
    my $averagecover = $totalreadcover/$clength; # ? clength - average readlength?
    $this->setAverageCover( sprintf("%.2f", $averagecover) );
    $this->setReadOnLeft($readonleft);
    $this->setReadOnRight($readonright);

# test number of reads

    if (my $nr = $this->getNumberOfReads()) {
        unless ($nr == $numberofnames) {
            print STDERR "Inconsistent read ($nr) and mapping ($numberofnames) "
                       . "count in contig ".$this->getContigName()."\n";
	}
    }
    else {
        $this->setNumberOfReads($numberofnames);
    }

    return 1; # register success
}

#-------------------------------------------------------------------    
# compare this Contig with another one using metadata and mappings
#-------------------------------------------------------------------

my $DEBUG;

sub isSameAs {
# compare the $compare and $this Contig instances
# return 0 if different; return +1 or -1 if identical, -1 if inverted
    my $this = shift;
    my $compare = shift;

    die "Contig->isSameAs takes a Contig instance" unless (ref($compare) eq 'Contig');

# ensure that the metadata are defined; do not allow zeropoint adjustments here

    $this->getStatistics(1)    unless $this->getReadOnLeft();
    $compare->getStatistics(1) unless $compare->getReadOnLeft();

# test the length

    return 0 unless ($this->getConsensusLength() == $compare->getConsensusLength());

# test the end reads (allow for inversion)

    my $align;
    if ($compare->getReadOnLeft()  eq $this->getReadOnLeft() && 
        $compare->getReadOnRight() eq $this->getReadOnRight()) {
# if the contigs are identical they are aligned
        $align = 1;
    } 
    elsif ($compare->getReadOnLeft() eq $this->getReadOnRight() && 
           $compare->getReadOnRight() eq $this->getReadOnLeft()) {
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
    if (my $mappings = $this->getMappings()) {
        $numberofmappings = scalar(@$mappings);
        foreach my $mapping (@$mappings) {
            my $key = $mapping->getSequenceID();
            $sequence->{$key} = $mapping if $key;
            $key =  $mapping->getMappingName();
            $sequence->{$key} = $mapping if $key;
        }
    }

    undef my $shift;
    if (my $mappings = $compare->getMappings()) {
# check number of mappings
        return 0 if ($numberofmappings != scalar(@$mappings));

        foreach my $mapping (@$mappings) {
# find the corresponding mapping in $this Contig instance
            my $key = $mapping->getSequenceID() || $mapping->getMappingName();
            return undef unless defined($key); # incomplete Mapping
            my $match = $sequence->{$key};
print STDERR "cannot find mapping for key $key \n" unless $match;
            return 0 unless defined($match); # there is no counterpart in $this
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
# returns undef if no or invalid mappings found in the $compare Contig instance
# returns false (but defined = 0) if any mismatch found between mappings

    return $align; # 1 for identical, -1 for identical but inverted
}   

sub linkToContig {
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
        $seq_id = $mapping->getMappingName();
        $readnamehash->{$seq_id} = $mapping if $seq_id;
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
            my $cpaligned = $cpmapping->getAlignment();

unless ($cpaligned || $compare->getNumberOfReads() > 1) {
    print STDERR "Non-overlapping read segments for single-read parent contig ".
                  $compare->getContigID()."\n";
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

            my $osegments = $cpmapping->getSegments() || next;

            foreach my $osegment (@$osegments) {
                my $offset = $osegment->getOffset();
                $offset = (-$offset+0); # conform to offset convention in this method
                my $hashkey = sprintf("%08d",$offset);
                $inventory->{$hashkey} = [] unless $inventory->{$hashkey};
                $osegment->normaliseOnX();# get in the correct order
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
print "offset $offset mapping @$mapping\n" if $DEBUG;
                my $position = 0.5 * ($mapping->[0] + $mapping->[1]);
                $sumpp += $position * $position;
                $sumop += $position * $offset;
                $sumoo += $offset * $offset;
            }
        }
# get the correlation coefficient
        my $threshold = $options{correlation} || 0.75;
        my $R = $sumop / sqrt($sumpp * $sumoo);
print "Correlation coefficient = $R\n\n" if $DEBUG;
        unless (abs($sumop / sqrt($sumpp * $sumoo)) >= $threshold) {
# relation offset-position looks messy: set up for offset masking
            my $partialsum = 0;
            foreach my $offset (@offsets) { 
                $partialsum += $accumulate->{$offset};
                next if ($partialsum < $weightedsum/2);
# the first offset here is the median
                $lower = $offset - $offsetwindow/2; 
                $upper = $offset + $offsetwindow/2;
print STDOUT "median: $offset ($lower $upper)\n" if $DEBUG;
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
print STDOUT "Testing offset $offset\n" if $DEBUG;
        if (($lower != $upper) && ($offset < $lower || $offset > $upper)) {
            $outofrange = 1; # outsize offset range, probably dodgy mapping
print STDOUT "offset out of range $offset\n" if $DEBUG;
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
print STDOUT "checking bad mapping range\n" if $DEBUG;
print STDOUT $badmapping->writeToString('bad range')."\n" if $DEBUG;
print STDOUT "bad contig range: @badmap\n" if $DEBUG;
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

print STDOUT scalar(@c2csegments)." segments; before pruning\n" if $DEBUG;

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

print STDOUT scalar(@c2csegments)." segments after pruning\n" if $DEBUG;

# enter the segments to the mapping

    foreach my $segment (@c2csegments) {
print "segment after filter @$segment \n" if $DEBUG;
        next if ($segment->[1] < $segment->[0]); # segment pruned out of existence
        $mapping->putSegment(@$segment);
    }
# use the analyse method to handle possible single-base segments
    $mapping->analyseSegments();

    if ($mapping->hasSegments()) {
# here, test if the mapping is valid, using the overall maping range
        my ($isValid,$msg) = &isValidMapping($this,$compare,$mapping,$overlapreads);
print STDOUT "\n isVALIDmapping $isValid\n$msg\n" if $DEBUG;
# here possible recovery based on analysis of continuity of mapping segments

# if still not valid, 
        if (!$isValid && !$options{forcelink}) {
print STDOUT "Spurious link detected to contig ".
$compare->getContigName()."\n" if $DEBUG;
            return 0, $overlapreads;
        }
# in case of split contig
        elsif ($isValid == 2) {
print STDOUT "(Possibly) split parent contig ".
$compare->getContigName()."\n" if $DEBUG;
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
 print STDOUT "Duplicate mapping to parent " .
	       $compare->getContigName()." ignored\n";
 print STDOUT "existing Mappings: @$c2cmaps \n";
 print STDOUT "to be added Mapping: $mapping, tested against $c2cmap\n";
 print STDOUT "equal mappings: \n".$mapping->toString()."\n".$c2cmap->toString();
}
                return $mapping->hasSegments(),$deallocated;
            }
        }
        $this->addContigToContigMapping($mapping);
# what about the parent?
    }

# and return the number of segments, which could be 0

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

#-------------------------------------------------------------------    
# Tags
#-------------------------------------------------------------------    

sub inheritTags {
# inherit tags from this contig's parents
    my $this = shift;
    my $depth = shift;
# what about selected tags only?
#    my %options = @_;

#    $options{depth} = 1 unless defined($options{depth});
#    $options{depth} -= 1;

    $depth = 1 unless defined($depth);

# get the parents; if none present, (try to) get them from the database

    my $parents = $this->getParentContigs(1);

    return unless ($parents && @$parents);

    foreach my $parent (@$parents) {
# if this parent does not have tags, test its parent(s)
        if ($depth > 0 && !$parent->hasTags(1)) {
            $parent->inheritTags($depth-1);
#        if ($options{depth} > 0 && !$parent->hasTags(1)) {
#            $parent->inheritTags(%options);
        }
# get the tags from the parent into this contig
        next unless $parent->hasTags();
        $parent->propagateTagsToContig($this);
#        $parent->propagateTagsToContig($this,%options);
    }

    $depth-- if $depth;
}

sub propagateTags {
# propagate the tags from this contig to its child(ren)
    my $this = shift;

# get the child(ren); if none present, (try to) get them from the database

    my $children = $this->getChildContigs(1);

    foreach my $child (@$children) {
        $this->propagateTagsToContig($child,@_);
    }
}

sub propagateTagsToContig {
# propagate tags FROM this (parent) TO the specified target contig
    my $parent = shift;
    my $target = shift;
    my %options = @_;

    return 0 unless $parent->hasTags(1);

$DEBUG->info("ENTER propagateTagsToContig ".
"parent $parent (".$parent->getContigID().")  target $target ("
.$target->getContigID().")") if $DEBUG;

# check the parent-child relation: is there a mapping between them and
# is the ID of the one of the parents identical to to the input $parent?
# we do this by getting the parents on the $target and compare with $parent

    my $mapping;

    my $parent_id = $parent->getContigID();

    my $dl = $options{delayedloading};
    $dl = 1 unless defined ($dl);

    if ($target->hasContigToContigMappings($dl)) {

# if parents are provided, then screen this ($parent) against them
# if this parent is not among the ones listed, ignored
# if no parents are provided, adopt this one
 
        my $cparents = $target->getParentContigs($dl) || [];
        push @$cparents,$parent unless ($cparents && @$cparents);
# we scan the parent(s) provided, to ensure that $this parent is among them
        foreach my $cparent (@$cparents) {
	    if ($cparent->getContigID() == $parent_id) {
# yes, there is a parent child relation between the input Contigs
# find the corresponding mapping using contig and mapping names
                my $c2cmappings = $target->getContigToContigMappings();
                foreach my $c2cmapping (@$c2cmappings) {
$DEBUG->info("Testing mapping ".$parent->getSequenceID()) if $DEBUG;
# we use the sequence IDs here, assuming the mappings come from the database
		    if ($c2cmapping->getSequenceID eq $parent->getSequenceID) {
                        $mapping = $c2cmapping;
                        last;
                    }
                }
	    }
	}
    }

$DEBUG->info("mapping: ".($mapping || 'not found')) if $DEBUG;

# if mapping is not defined here, we have to find it from scratch

    unless ($mapping) {
$DEBUG->info("Finding mappings from scratch") if $DEBUG;
        my ($nrofsegments,$deallocated) = $target->linkToContig($parent);
$DEBUG->info("number of mapping segments : ".($nrofsegments || 0)) if $DEBUG;
        return 0 unless $nrofsegments;
# identify the mapping using parent contig and mapping name
        my $c2cmappings = $target->getContigToContigMappings();
        foreach my $c2cmapping (@$c2cmappings) {
#	    if ($c2cmapping->getSequenceID eq $parent->getSequenceID) {
	    if ($c2cmapping->getMappingName eq $parent->getContigName) {
                $mapping = $c2cmapping;
                last;
            }
        }
# protect against the mapping still not found, but this should not occur
$DEBUG->info("mapping identified: ".($mapping || 'not found')) if $DEBUG;
        return 0 unless $mapping;
    }
$DEBUG->warning($mapping->assembledFromToString()) if $DEBUG;

# check if the length of the target contig is defined

    my $tlength = $target->getConsensusLength();
    unless ($tlength) {
        $target->getStatistics(1); # no zeropoint shift; use contig as is
        $tlength = $target->getConsensusLength();
        unless ($tlength) {
            $DEBUG->warning("Undefined length in (child) contig");
            return 0;
        }
    }
$DEBUG->warning("Target contig length : $tlength ") if $DEBUG;

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

# get the tags in the parent

    my @tags;
    my $ptags = $parent->getTags(1);

# get a handle to the tag factory, if not do earlier

    $tagfactory = new ContigTagFactory() unless $tagfactory;

# first attempt for ANNO tags (later to be used for others as well)

#FROM HERE could be a function of the tag factory
    my %annotagoptions = (break=>1, debug=>$DEBUG);
    $annotagoptions{minimumsegmentsize} = $options{minimumsegmentsize} || 0;
    $annotagoptions{changestrand} = ($mapping->getAlignment() < 0) ? 1 : 0;
# activate speedup for mapping multiplication by defining nzt option as hash
    $annotagoptions{nonzerostart} = {} if $options{speedmode};
$annotagoptions{timer} = $options{timer};

    my %moptions = (overlap => $options{overlap});

    foreach my $ptag (@$ptags) {
        my $tagtype = $ptag->getType();
        next unless ($tagtype eq 'ANNO');
# remapping is SLOW for large number of tags
$DEBUG->warning("Processing ANNO tag for remapping ".$ptag->getPositionLeft()) if $DEBUG;
        my $tptags = $tagfactory->remap($ptag,$mapping,%annotagoptions);
        push @tags,@$tptags if $tptags;
    }
# if annotation tags found, sort according to start position
    if (@tags) {
$DEBUG->warning("Processing ".scalar(@tags)." ANNO tags for merge") if $DEBUG;
        @tags = sort {$a->getPositionLeft <=> $b->getPositionLeft()} @tags;
# test if some tags can be merged
        my ($i,$j) = (0,1);
        while ($i < scalar(@tags) && $j < scalar(@tags)) {
# test for possible merger of tags i and j
            if (my $newtag = $tagfactory->merge($tags[$i],$tags[$j],%moptions)) {
# the tags are merged: replace tags i and j by the new one
                splice @tags, $i, 2, $newtag;
# keep the same values of i and j
	    }
            else {
# tags cannot be merged: increase both i and j
                $i++;
		$j++;
            }
        }
        $target->addTag([@tags]) if @tags;
$DEBUG->warning("DONE") if $DEBUG;
    }
#TO HERE

# the remainder is for other tags using the old algorithm

    my $c2csegments = $mapping->getSegments();
    my $alignment = $mapping->getAlignment();

    foreach my $ptag (@$ptags) {
# apply include or exclude filter
        my $tagtype = $ptag->getType();
        next if ($tagtype eq 'ANNO');

#        next if ($exclude && $tagtype =~ /\b$exclude\b/i);
#        next if ($include && $tagtype !~ /\b$include\b/i);
#        my $tptags = $ptag->remap($mapping,break=>0); 
#        push @tags,@$tptags if $tptags; 

# determine the segment(s) of the mapping with the tag's position
$DEBUG->warning("processing tag $ptag (align $alignment)") if $DEBUG;

        undef my @offset;
        my @position = $ptag->getPosition();
$DEBUG->warning("tag position (on parent) @position") if $DEBUG;
        foreach my $segment (@$c2csegments) {
# for the correct segment, getXforY returns true
            for my $i (0,1) {
$DEBUG->warning("testing position $position[$i]") if $DEBUG;
                if ($segment->getXforY($position[$i])) {
                    $offset[$i] = $segment->getOffset();
$DEBUG->warning("offset to be applied : $offset[$i]") if $DEBUG;
# ensure that both offsets are defined; this line ensures definition in
# case the counterpart falls outside any segment (i.e. outside the contig)
                    $offset[1-$i] = $offset[$i] unless defined $offset[1-$i];
                }
            }
        }
# accept the new tag only if the position offsets are defined
$DEBUG->warning("offsets: @offset") if $DEBUG;
        next unless @offset;
# create a new tag by spawning from the tag on the parent contig
     my $tptag = $ptag->transpose($alignment,\@offset,$tlength); # to be replaced
#        my $tptag = $tagfactory->transpose($ptag,$alignment,\@offset,$tlength);
        next unless $tptag; # remapped tag out of boundaries

if ($DEBUG) {
$DEBUG->warning("tag on parent :". $ptag->dump);
$DEBUG->warning("tag on target :". $tptag->dump);
}

# test if the transposed tag is not already present in the child;
# if it is, inherit any properties from the transposed parent tag
# which are not defined in it (e.g. when ctag built from Caf file) 

        my $present = 0;
        my $ctags = $target->getTags(0);
        foreach my $ctag (@$ctags) {
# test the transposed parent tag and port the tag_id / systematic ID
            if ($tptag->isEqual($ctag,inherit=>1,debug=>$DEBUG)) {
                $present = 1;
                last;
	    }
        }
        next if $present;

# the (transposed) tag from parent is not in the current contig: add it

$DEBUG->warning("new tag added") if $DEBUG;
        $target->addTag($tptag);
    }
}

#-------------------------------------------------------------------    
# exporting to CAF (standard Arcturus)
#-------------------------------------------------------------------    

sub writeToCaf {
# write reads and contig to CAF (unpadded)
    my $this = shift;
    my $FILE = shift; # obligatory file handle
    my %options = @_;

    return "Missing file handle for Caf output" unless $FILE;

    my $contigname = $this->getContigName();

# dump all reads

    unless ($options{noreads}) {
        my $reads = $this->getReads(1);
        foreach my $read (@$reads) {
            $read->writeToCaf($FILE,%options); # transfer options, if any
        }
    }

# write the overall maps for for the contig ("assembled from")

    print $FILE "\nSequence : $contigname\nIs_contig\nUnpadded\n";

    my $mappings = $this->getMappings(1);
    foreach my $mapping (@$mappings) {
        print $FILE $mapping->assembledFromToString();
    }

# write tags, if any are loaded (if no tags, use delayed loading)

    if (!$options{notags} && $this->hasTags(1)) {
        my $tags = $this->getTags();
# decide on which tags to export; default no annotation (assembly export)
        my $includetag;
        my $excludetag = 'ANNO';
        if ($options{alltags}) {
            undef $excludetag;
        }
        elsif ($options{includetag}) { # specified takes precedence
            $includetag = $options{includetag};
            $includetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $includetag =~ s/\W+/|/g; # put separators in include list
	}
        elsif ($options{excludetag}) {
            $excludetag = $options{excludetag};
            $excludetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $excludetag =~ s/\W+/|/g; # put separators in exclude list
	}
# export the tags which pass the possible tag type filter               
        foreach my $tag (@$tags) {
            my $tagtype = $tag->getType();
            next if ($includetag && $tagtype !~ /$includetag/);
            next if ($excludetag && $tagtype =~ /$excludetag/); 
            $tag->writeToCaf($FILE,annotag=>1);
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    my $errors = $this->writeDNA($FILE,marker => "\nDNA : "); # CAF marker

    $errors += $this->writeBaseQuality($FILE,marker => "\nBaseQuality : ");

    print $FILE "\n";

    return $errors;
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data
    my %options = @_; 

    return "Missing file handle for Fasta output" unless $DFILE;

    if ($options{readsonly}) {
# 'reads' switch dumps reads only; its absence dumps contigs 
        my $reads = $this->getReads(1);
        foreach my $read (@$reads) {
            $read->writeToFasta($DFILE,$QFILE,%options); # transfer options
        }
        return undef;
    }

# apply end-region masking

    if ($options{endregiononly}) {
        if (my $sequence = &endregionmask($this->getSequence(),%options)) {
            $this->setSequence($sequence);
        }
    }

# apply quality clipping

    if ($options{qualityclip}) {
# get a clipped version of the current consensus
        my ($sequence,$quality,$map) = &qualityclip($this->getSequence(),
                                                    $this->getBaseQuality(),
			  		            %options);
        if ($sequence && $quality) {
            $this->setSequence($sequence);
            $this->setBaseQuality($quality);
	}
    }

    my $errors = $this->writeDNA($DFILE,%options);

    $errors += $this->writeBaseQuality($QFILE,%options) if $QFILE;

    return $errors;
}

# private methods

sub writeDNA {
# write consensus sequence DNA to DFILE handle
    my $this    = shift;
    my $DFILE   = shift; # obligatory
    my %options = @_;

    my $marker = $options{marker} || '>'; # default FASTA format

    my $identifier = $this->getContigName();
# optionally add gap4name 
    $identifier .= " - ".$this->getGap4Name() if $options{gap4name};

    if (!$DFILE) {
       print STDERR "Missing file handle for DNA sequence\n";
       return 1; # error status
    }
    elsif (my $dna = $this->getSequence()) {
# output in blocks of 60 characters
	print $DFILE "$marker$identifier\n";
	my $offset = 0;
	my $length = length($dna);
	while ($offset < $length) {    
	    print $DFILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }
    else {
        print STDERR "Missing DNA data for contig $identifier\n";
        return 1; # error status
    }
       
    return 0; # no errors
}

sub writeBaseQuality {
# write consensus Quality Data to QFILE handle
    my $this   = shift;
    my $QFILE  = shift; # obligatory
    my %options = @_;

    my $marker = $options{marker} || '>'; # default FASTA format

    my $identifier = $this->getContigName();
# optionally add gap4name 
    $identifier .= " - ".$this->getGap4Name() if $options{gap4name};

    if (!$QFILE) {
        priont STDERR "Missing file handle for Quality Data\n";
        return 1; # error status
    }
    elsif (my $quality = $this->getBaseQuality()) {
# output in lines of 25 numbers
	print $QFILE "$marker$identifier\n";
	my $n = scalar(@$quality) - 1;
        for (my $i = 0; $i <= $n; $i += 25) {
            my $m = $i + 24;
            $m = $n if ($m > $n);
	    print $QFILE join(' ',@$quality[$i..$m]),"\n";
	}
    }
    else {
        print STDERR "Missing BaseQuality data for contig $identifier\n";
        return 1; # error status
    }

    return 0; # no errors
}

sub metaDataToString {
# list the contig meta data
    my $this = shift;
    my $full = shift;

    $this->getMappings(1) if $full; # load the read-to-contig maps

    if (!$this->getReadOnLeft() && $this->hasMappings()) {
        $this->getStatistics(1);
    }

    my $name     = $this->getContigName()            || "undefined";
    my $gap4name = $this->getGap4Name();
    my $created  = $this->{created}                  || "not known";
    my $updated  = $this->{updated}                  || "not known";
    my $project  = $this->{project}                  ||           0;
    my $length   = $this->getConsensusLength()       ||   "unknown";
    my $cover    = $this->getAverageCover()          ||   "unknown";
    my $rleft    = $this->getReadOnLeft()            ||   "unknown";
    my $right    = $this->getReadOnRight()           ||   "unknown";
    my $nreads   = $this->getNumberOfReads()         || "undefined";
    my $nwread   = $this->getNumberOfNewReads()      ||           0;
    my $pcntgs   = $this->getNumberOfParentContigs() ||           0;

# if the contig has parents, get their names by testing/loading the mappings

    my $parentlist = '';
    my @assembledfrom;
    if ($pcntgs && (my $mappings = $this->getContigToContigMappings(1))) {
        my @parents;
        foreach my $mapping (@$mappings) {
            push @parents, $mapping->getMappingName();
            push @assembledfrom, $mapping->assembledFromToString(1);
        }
        $parentlist = "(".join(',',sort @parents).")" if @parents;
    }

    my $string = "Contig name     = $name\n"
               . "Gap4 name       = $gap4name\n"
               . "Created         : $created\n"
               . "Last update     : $updated\n"
               . "Project ID      = $project\n"
               . "Number of reads = $nreads  (newly assembled : $nwread)\n"
               . "Parent contigs  = $pcntgs $parentlist\n"
               . "Consensuslength = $length\n"
               . "Average cover   = $cover\n"   
               . "End reads       : (L) $rleft   (R) $right\n\n";
    foreach my $assembled (sort @assembledfrom) {
        $string   .= $assembled;
    }

    return $string;
}

sub toString {
# very brief summary
    my $this = shift;

    my $name     = $this->getContigName()            || "undefined";
    my $gap4name = $this->getGap4Name();
    my $nreads   = $this->getNumberOfReads()         || "undefined";
    my $length   = $this->getConsensusLength()       ||   "unknown";
    my $cover    = $this->getAverageCover()          ||   "unknown";
    my $created  = $this->{created}                  || "undefined";
    my $project  = $this->{project}                  || 0;

    return sprintf 
     ("%-14s = %-20s r:%-7d l:%-8d c:%4.2f %-19s %3d",
      $name,$gap4name,$nreads,$length,$cover,$created,$project);
}

#-------------------------------------------------------------------    
# non-standard output (e.g. for interaction with Phusion and Gap4)
#-------------------------------------------------------------------    

sub writeToMaf {
# write the "reads.placed" read-contig mappings in Mullikin format
    my $this = shift;
    my $DFILE = shift; # obligatory file handle for DNA
    my $QFILE = shift; # obligatory file handle for QualityData
    my $RFILE = shift; # obligatory file handle for Placed Reads
    my %options = @_;

    my $report = '';

    unless ($DFILE && $QFILE && $RFILE) {
	$report .= "Missing file handle for Maf output of ";
	$report .= "DNA Bases\n" unless $DFILE;
	$report .= "Quality Data\n" unless $QFILE;
	$report .= "Placed Reads\n" unless $RFILE;
	return 0,$report;
    }

# preset error reporting

    my $success = 1;

# first handle the fasta output of the consensus sequence DNA and Quality

    my $minNX = $options{minNX};
    $minNX = 3 unless defined($minNX);

    if (my $sequence = $this->getSequence()) {

        if (my $newsequence = &replaceNbyX($sequence,$minNX)) {
            $this->setSequence($newsequence);
	}

# replace current consensus by the substituted string 

        $this->writeToFasta($DFILE,$QFILE);
    }
    else {
        return 0,"Missing sequence for contig ".$this->getContigName();
    }

# extra outside info to be passed as parameters: supercontig name &
# approximate start of contig on supercontig

    my $contigname = $this->getContigName();
    my $supercontigname = $options{supercontigname} || $contigname;
    my $contigzeropoint = $options{contigzeropoint} || 0;

# get the reads and build a hash list for identification

    my %reads;
    my $reads = $this->getReads(1);
    foreach my $read (@$reads) {
        $reads{$read->getReadName()} = $read;
    }

# write the individual read info

    my $mappings = $this->getMappings(1);
    foreach my $mapping (@$mappings) {
        my @range = $mapping->getContigRange();
        my $readname = $mapping->getMappingName();
        unless ($readname) {
            $report .= "Missing readname in mapping "
                    .   $mapping->getMappingID()."\n";
            $success = 0;
            next;
        }
        my $read = $reads{$readname};
        unless ($read) {
	    $report .= "Missing read $readname\n";
            $success = 0;
	    next;
	}
        my $lqleft = $read->getLowQualityLeft();
        my $length = $read->getLowQualityRight() - $lqleft + 1;
        my $alignment = ($mapping->getAlignment() > 0) ? 0 : 1;
        my $supercontigstart  = $contigzeropoint + $range[0];
        print $RFILE "* $readname $lqleft $length $alignment " .
                     "$contigname $supercontigname $range[0] " .
                     "$supercontigstart\n"; 
    }

# returns 1 for success or 0 and report for errors

    return $success,$report;
}

sub writeToEMBL {
# write contig info in (minimal) EMBL format (TO BE TESTED)
    my $this = shift;
    my $DFILE = shift; # obligatory file handle for DNA output
    my $QFILE = shift; # optional file handle for quality data
    my %options = @_;

    my $identifier = $this->getContigName();

    if (!$DFILE) {
        print STDERR "Missing file handle for DNA sequence\n";
        return 1;
    }
    elsif (my $dna = $this->getSequence()) {

# collect length and print header record

	my $length = length($dna);
	print $DFILE "ID   $identifier  standard; Genomic DNA; CON; "
                   . "$length BP\n";
        print $DFILE "XX\n";
        print $DFILE "AC   unknown;\n";
        print $DFILE "XX\n";

# the tag section (if any)

        if ($this->hasTags(1)) { # force delayed loading
# determine which tags to export
            $options{includetag} = 'ANNO' unless $options{includetag};
            my $includetag = $options{includetag};
            $includetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $includetag =~ s/\W+/|/g; # put separators in include list

            my $tags = $this->getTags();
# test if there are tags with identical systematic ID; collect groups, if any
            my @newtags;
            my $joinhash = {};
            foreach my $tag (@$tags) {
                my $tagtype     = $tag->getType();
                next if (!$includetag || $tagtype !~ /$includetag/);
                my $strand      = lc($tag->getStrand());
                my $sysID       = $tag->getSystematicID();
# if the tag is not an annotation tag, just add to local list
                unless (defined($sysID)) {
		    push @newtags,$tag;
                    next;
		}
# the tag is annotation, build the join hash
                $joinhash->{$sysID} = {} unless $joinhash->{$sysID};
                unless ($joinhash->{$sysID}->{$strand}) {
                    $joinhash->{$sysID}->{$strand} = [];
                }
		my $joinset = $joinhash->{$sysID}->{$strand};
                push @$joinset, $tag;
            }

# if there are groups of tags or tag fragments, generate joins

            foreach my $sysID (sort keys %$joinhash) {
                my $strandhash = $joinhash->{$sysID};
                foreach my $strand (keys %$strandhash) {
                    my $joinset = $strandhash->{$strand};
                    $tagfactory = new ContigTagFactory() unless $tagfactory;
                    my $newtag = $tagfactory->makeCompositeTag($joinset);
                    push @newtags,$newtag if $newtag;
	        }
	    }

# export the tags

            my $feature;
            foreach my $tag (@newtags) {
                my $tagtype = $tag->getType();
                next if (!$includetag || $tagtype !~ /$includetag/);
                unless ($feature) {
                    print $DFILE "FH   Key             Location/Qualifiers\n";
                    print $DFILE "FH\n";
                }
                $feature++;

                print $DFILE $tag->writeToEMBL(0,tagkey=>'TAG');
            }
            print $DFILE "XX\n" if $feature;
        }
	else {
            print $DFILE "FH   Key             Location/Qualifiers\n";
            print $DFILE "FH\n";
	}
return if $options{tagsonly}; # debug option
  
# the DNA section, count the base composition

        my %base;
        while ($dna =~ /(.)/g) {
            $base{uc($1)}++; # count on upper case
        }
# count other than ACTG
        my $other = $length;
        foreach my $key ('A','C','G','T') {
            $other -= $base{$key};
        }
        print $DFILE  "SQ   Sequence $length BP; "
                    . "$base{A} A;  $base{C} C; $base{G} G; $base{T} T; "
			. "$other  other;\n";

# output in blocks of 60 characters

	my $offset = 0;
	while ($offset < $length) {    
	    my $line = substr($dna,$offset,60);
            $line =~ tr/A-Z/a-z/; # lower case
	    $offset += 60;
            if ($offset > $length) {
# append the missing blanks to the line
                my $gap = $offset - $length;
                while ($gap--) {
                    $line .= " ";
                }
                $offset = $length;
	    }
            $line =~ s/(.{1,10})/$1 /g; # insert single space
            print $DFILE "     ". $line . sprintf('%9d',$offset) . "\n"; # 80 
	}
        print $DFILE "//\n";
    }
    else {
        print STDERR "Missing DNA data for contig $identifier\n";
        return 1;
    }

    return 0 unless $QFILE;

# Quality printout to be completed
}

#-------------------------------------------------------------------    

sub replaceNbyX {
# private, substitute strings of 'N's in the consensus sequence by (MAF) 'X' 
    my $sequence = shift;
    my $min      = shift; # minimum length of the string;

# first replace all Ns by X

    if ($min && $sequence =~ s/[N\?]/X/ig) {

# then change contiguous runs of X smaller than $min back to N

        my $X = 'X';
        my $N = 'N';
        my $i = 1;

        while ($i++ < $min) {
            $sequence =~ s/([ACTG\?])($X)(?=[ACTG\?])/$1$N/ig;
            $X .= 'X';
            $N .= 'N';
        }

        return $sequence;
    }

    return 0;
}

#---------------------------
# Pad status TO BE DEVELOPED
#---------------------------

sub isPadded {
# return 0 for unpadded (default) or true for padded
    my $this = shift;

    return $this->{ispadded} || 0;
}

sub toPadded {
    my $this = shift;

    return 0; # failed
#    die "Contig->toPadded is not yet implemented";
}

sub toUnPadded {
    my $this = shift;

    return 0; # failed
#    die "Contig->toUnPadded is not yet implemented";
}

use PaddedRead;

sub writeToCafPadded {
# TO BE REPLACED by internal state (padded unpaaded) and tranform function
# write reads and contig to CAF (padded but leaving consensus unchanged)
# this is an ad hoc method to make Arcturus conversant with GAP4
# it uses the PaddedRead class for conversion of read mappings

    my $this = shift;
    my $FILE = shift; # obligatory file handle

    my $contigname = $this->getContigName();

# get a read name hash and copy the (unpadded) reads into a PaddedRead

    my $readnamehash = {};
    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        my $readname = $read->getReadName();
        my $paddedread = new PaddedRead($read);
        $readnamehash->{$readname} = $paddedread;
    }

# find the corresponding mappings and pad each read  

    my @assembledfrommap;
    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        my $readname = $mapping->getMappingName();
        my $paddedread = $readnamehash->{$readname};
        unless ($paddedread) {
            $DEBUG->warning("Missing padded read $readname");
            next; 
        }
        my $afm = $paddedread->toPadded($mapping); # out: one segment mapping
        $paddedread->writeToCaf($FILE); # write the read to file
        push @assembledfrommap, $afm;
    }

# write the overall mappings to the contig ("assembled from")

    print $FILE "\nSequence : $contigname\nIs_contig\nPadded\n";

    foreach my $mapping (@assembledfrommap) {
        print $FILE $mapping->assembledFromToString();
    }

# write tags, if any (consensus has not changed)

    if ($this->hasTags) {
        my $tags = $this->getTags();
        foreach my $tag (@$tags) {
            $tag->writeToCaf($FILE);
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"\nDNA : "); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"\nBaseQuality : ");

    print $FILE "\n";
}

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

sub setDEBUG {shift;$DEBUG = shift;} # pass the logger module
sub setNoDEBUG {$DEBUG = 0;}

1;
