package Contig;

use strict;

use Mapping;

# ----------------------------------------------------------------------------
# constructor and initialisation
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

    if (ref($ADB) =~ /^ADB(Contig|Assembly)$/) {
        $this->{ADB} = $ADB;
    }
    else {
        die "Invalid object passed: $ADB";
    }
}

#-------------------------------------------------------------------
# delayed loading of DNA and quality data from database
#-------------------------------------------------------------------

sub importSequence {
    my $this = shift;

    my $ADB = $this->{ADB} || return 0; # the parent database

    my $cid = $this->getContigID() || return 0; 

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForContigID($cid);

    $this->setSequence($sequence); # a string
    $this->setQuality($quality);   # reference to an array of integers

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

sub setContigID {
    my $this = shift;
    my $cid  = shift;

    return if ($cid =~ /\D/); # must be a number

    $this->{data}->{contig_id} = $cid;
}

#-------------------------------------------------------------------   

sub getContigName {
    my $this = shift;

# in its absence generate a name based on the contig_id

    if (!defined($this->{contigname}) && $this->getContigID()) {
        $this->setContigName(sprintf("contig%08d",$this->getContigID()));
    }
    return $this->{contigname};
}

sub setContigName {
    my $this = shift;
    $this->{contigname} = shift;
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

sub setQuality {
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

sub getQuality {
# return the quality data (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{BaseQuality});
    return $this->{BaseQuality}; # an array reference (or undef)
}

#-------------------------------------------------------------------   

sub getReadOnLeft {
    my $this = shift;
    return $this->{data}->{readonleft};
}

sub setReadOnLeft {
    my $this = shift;
    $this->{data}->{readonleft} = shift;
}

#-------------------------------------------------------------------   

sub getReadOnRight {
    my $this = shift;
    return $this->{data}->{readonright};
}

sub setReadOnRight {
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
# importing/exporting Read(s), Mapping(s) & Tag(s) etcetera
#-------------------------------------------------------------------    

sub getReads {
# return a reference to the array of Read instances (can be empty)
    my $this = shift;
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
#    my $Mapping = shift;
    $this->importer(shift,'Mapping');
}

sub hasMappings {
# returns true if this Contig has (read-to-contig) mappings
    my $this = shift;
    return $this->getMappings() ? 1 : 0;
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
    $this->importer(shift,'Tag');
}

sub hasTags {
# returns true if this Contig has tags
    my $this = shift;
    return $this->getTags() ? 1 : 0;
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
    return &getContigToContigMappings(shift) ? 1 : 0;
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
    my $parents = $this->getParentContigs();
    return $parents ? scalar(@$parents) : 0;
}

#-------------------------------------------------------------------    

sub importer {
# private generic method for importing objects into a Contig instance
    my $this = shift;
    my $Component = shift;
    my $class = shift; # (obligatory) class of object to be stored
    my $buffername = shift; # (optional) internal name of buffer

    $buffername = $class unless defined($buffername);

    die "Contig->importer expects a component type" unless $class;

    if (ref($Component) eq 'ARRAY') {
# recursive use with scalar parameter
        while (scalar(@$Component)) {
            $this->importer(shift @$Component,$class,$buffername);
        }
    }
    else {
# test type of input object against specification
        my $instanceref = ref($Component);
        if ($class ne $instanceref) {
            die "Contig->importer expects a(n array of) $class instance(s) as input";
        }
        $this->{$buffername} = [] if !defined($this->{$buffername});
        push @{$this->{$buffername}}, $Component;
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
    my $isShifted = 0;

    while ($pass) {
# go through the mappings to find begin, end of contig
# and to determine the reads at either end
        my ($minspanonleft, $minspanonright);
        my $name = $this->getContigName();
        if (my $mappings = $this->getMappings()) {
            my $init = 0;
            $totalreadcover = 0;
            foreach my $mapping (@$mappings) {
                my $readname = $mapping->getMappingName();
# find begin/end of contig range cover by this mapping
                my ($cs, $cf) = $mapping->getContigRange();
# total read cover = sum of contigspan length
                my $contigspan = $cf - $cs + 1;
                $totalreadcover += $contigspan;

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
    my $averagecover = $totalreadcover/$clength;
    $this->setAverageCover( sprintf("%.2f", $averagecover) );
    $this->setReadOnLeft($readonleft);
    $this->setReadOnRight($readonright);

    return 1; # register success
}

#-------------------------------------------------------------------    
# compare this Contig with another one using metadata and mappings
#-------------------------------------------------------------------

sub isSameAs {
# compare the $compare and $this Contig instances
# return 0 if different; return +1 or -1 if identical, -1 if inverted
    my $this = shift;
    my $compare = shift;

    die "Contig->compare takes a Contig instance" unless (ref($compare) eq 'Contig');

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
            my ($identical,$aligned,$offset) = $match->compare($mapping);
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
    my $relaxed = shift; # set True for relaxed comparison of mappings

    die "$this takes a Contig instance" unless (ref($compare) eq 'Contig');

    return undef unless $this->hasMappings();
    return undef unless $compare->hasMappings();

# make the comparison using sequence ID; start by getting an inventory of $this

    my $sequence = {};
    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        my $key = $mapping->getSequenceID();
        $sequence->{$key} = $mapping if $key;
    }

# make an inventory hash of (identical) alignments from $compare to $this

    my $alignment;
    my $inventory = {};
    my $deallocated = 0;
    $mappings = $compare->getMappings();
    foreach my $mapping (@$mappings) {
        my $key = $mapping->getSequenceID();
print "Incomplete Mapping ".$mapping->getMappingName."\n" unless defined($key);
        return undef unless defined($key); # incomplete Mapping
        my $match = $sequence->{$key};
        unless (defined($match)) {
            $deallocated++;
            next;
        }
# this mapping/sequence in $compare also figures in the current Contig
        my ($identical,$aligned,$offset) = $match->compare($mapping,$relaxed);
# keep the first encountered (contig-to-contig) alignment value != 0 
        $alignment = $aligned unless $alignment;
        next unless ($identical && $aligned == $alignment);
# the mappings are identical (alignment and, if !relaxed, segment size)
        my @segment = $mapping->getContigRange();
# in relaxed mode we have (possibly) to prune the boundaries of the interval
        if ($relaxed) {
            my @match = $match->getContigRange();
# transform the range to this contig
            $match[0] = $alignment * $match[0] - $offset;
            $match[1] = $alignment * $match[1] - $offset;
            @match = sort { $a <=> $b} @match;
# and determine the minimum overlapping range 
            $segment[0] = $match[0] if ($match[0] > $segment[0]);
            $segment[1] = $match[1] if ($match[1] < $segment[1]);
            next unless ($match[0] < $match[1]);
        }
# build a hash key based on offset and alignment direction and add segment
        my $hashkey = sprintf("%08d",$offset);
        $inventory->{$hashkey} = [] unless defined $inventory->{$hashkey};
        push @{$inventory->{$hashkey}},[@segment];
    }

# OK, here we have an inventory: the number of keys equals the number of 
# different alignments between $this and $compare. On each key we have an
# array of arrays with the individual mappings data. For each alignment we
# determine if the covered interval is contiguous. For each such interval
# we add a (contig) Segment alignment to the output mapping
# NOTE: the table can be empty, which occurs if all reads in the current Contig
# have their mappings changed compared with the previous contig 

    my $mapping = new Mapping($compare->getContigName());
    $mapping->setSequenceID($compare->getContigID());
# accept only alignments with a minimum number of reads 
    my $guillotine = 1 + log(scalar(@$mappings));

    foreach my $offset (sort keys %$inventory) {
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
                if ($nreads > $guillotine) {
                    my $start = ($segmentstart + $offset) * $alignment;
                    my $finis = ($segmentfinis + $offset) * $alignment;
                    $mapping->addAssembledFrom($start,$finis,$segmentstart,
                                                            $segmentfinis);
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
        }
# add segmentstart - segmentfinis as (last) mapping segment
        next unless ($nreads > $guillotine);
        my $start = ($segmentstart + $offset) * $alignment;
        my $finis = ($segmentfinis + $offset) * $alignment;
        $mapping->addAssembledFrom($start,$finis,$segmentstart,$segmentfinis);
    }

# if mapping has segments, or if a finescan has been done, return 

    if ($mapping->hasSegments() || $relaxed) {
# store the Mapping as a contig-to-contig mapping
        $this->addContigToContigMapping($mapping);
# and return the number of segments, which could be 0
        return $mapping->hasSegments(),$deallocated;
    }

# the mapping has no segments: no mapping range(s) could be determined
# by the algorithm above. A more refined analysis is required based
# on analysis of the individual segments: try again with 'relaxed' on

    return $this->linkToContig($compare,1);
}

#-------------------------------------------------------------------    
# exporting to CAF
#-------------------------------------------------------------------    

sub writeToCaf {
# write reads and contig to CAF
    my $this = shift;
    my $FILE = shift; # obligatory file handle

    my $contigname = $this->getContigName();

# dump all reads

    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        $read->writeToCafForAssembly($FILE); 
    }

# write the overall maps for for the contig ("assembled from")

    print $FILE "\nSequence : $contigname\nIs_contig\nUnpadded\n";

    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        print $FILE $mapping->assembledFromToString();
    }

# write tags, if any

    if ($this->hasTags) {
        my $tags = $this->getTags();
        foreach my $tag (@$tags) {
# $tag->toString ?
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"DNA : "); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"BaseQuality : ");

    print $FILE "\n\n";
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        $read->writeToFasta($DFILE,$QFILE);
    }

    $this->writeDNA($DFILE);

    $this->writeBaseQuality($QFILE) if defined $QFILE;
}

# private methods

sub writeDNA {
# write DNA of this read in FASTA format to FILE handle
    my $this   = shift;
    my $FILE   = shift; # obligatory
    my $marker = shift;

    $marker = '>' unless defined($marker); # default FASTA format

    my $identifier = $this->getContigName();

    if (my $dna = $this->getSequence()) {
# output in blocks of 60 characters
	print $FILE "\n$marker$identifier\n";
	my $offset = 0;
	my $length = length($dna);
	while ($offset < $length) {    
	    print $FILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }
    else {
        print STDERR "Missing DNA data for contig $identifier\n";
    }
}

sub writeBaseQuality {
# write Quality data of this read in FASTA format to FILE handle
    my $this   = shift;
    my $FILE   = shift; # obligatory
    my $marker = shift;

    $marker = '>' unless defined($marker); # default FASTA format

    my $identifier = $this->getContigName();

    if (my $quality = $this->getQuality()) {
# output in lines of 25 numbers
	print $FILE "\n$marker$identifier\n";
	my $n = scalar(@$quality) - 1;
        for (my $i = 0; $i <= $n; $i += 25) {
            my $m = $i + 24;
            $m = $n if ($m > $n);
	    print $FILE join(' ',@$quality[$i..$m]),"\n";
	}
    }
    else {
        print STDERR "Missing BaseQuality data for contig $identifier\n";
    }
}

sub metaDataToString {
# list the contig meta data
    my $this = shift;
    my $full = shift;

    $this->getMappings(1) if $full; # load the read-to-contig maps

    if (!$this->getReadOnLeft() && $this->hasMappings()) {
        $this->getStatistics(1);
    }

    my $name   = $this->getContigName()            || "undefined";
    my $length = $this->getConsensusLength()       ||   "unknown";
    my $cover  = $this->getAverageCover()          ||   "unknown";
    my $rleft  = $this->getReadOnLeft()            ||   "unknown";
    my $right  = $this->getReadOnRight()           ||   "unknown";
    my $nreads = $this->getNumberOfReads()         || "undefined";
    my $nwread = $this->getNumberOfNewReads()      ||           0;
    my $pcntgs = $this->getNumberOfParentContigs() ||           0;

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

    my $string = "Contig name     = $name\n" .
                 "Number of reads = $nreads  (new reads = $nwread)\n" .
                 "Parent contigs  = $pcntgs $parentlist\n" .
                 "Consensuslength = $length\n" .
                 "Average cover   = $cover\n" .   
                 "End reads       : left $rleft  right $right\n\n";
    foreach my $assembled (sort @assembledfrom) {
        $string   .= $assembled;
    }

    return $string;
}

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

1;
