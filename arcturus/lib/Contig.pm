package Contig;

use strict;

use Mapping;

use PaddedRead;

my $DEBUG = 0;

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

    if (ref($ADB) eq 'ArcturusDatabase') {
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

    return if ($cid =~ /\D/); # must be a number

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
#    my $Mapping = shift;
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

    $this->importer($ctag,'Tag');

    $ctag->setSequenceID($this->getSequenceID());
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
# returns array of parent Contig instances
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ChildContig} && $load && (my $ADB = $this->{ADB})) {
        $ADB->getChildContigsForContig($this);
    }
    return $this->{ChildContig};
}

sub addChildContig {
# add parent Contig instance
    my $this = shift;
    $this->importer(shift,'Contig','ChildContig');
}

sub hasChildContigs {
# returns number of previous contigs
    my $this = shift;
    my $parents = $this->getChildContigs(shift);
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

    die "$this takes a Contig instance" unless (ref($compare) eq 'Contig');

# decode control input

    my $DEBUG = 0;

    my $strong = 0; # set True for comparison at read mapping level
    my $guillotine = 0;
    while (my $nextword = shift) {

        if ($nextword eq 'strong') {
            $strong = shift || 0;
        }
        elsif ($nextword eq 'readclipping') {
            $guillotine = shift || 0;
        }
        elsif ($nextword eq 'debug') {
            $DEBUG = shift || 0;
	}
        else {
            print STDERR "Invalid keyword $nextword in 'linkToContig'\n";
        }
    }

# test completeness

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

    my $alignment = 0;
    my $inventory = {};
    my $deallocated = 0;
    $mappings = $compare->getMappings();
    foreach my $mapping (@$mappings) {
        my $key = $mapping->getSequenceID();
        unless (defined($key)) {
            print STDERR "Incomplete Mapping ".$mapping->getMappingName."\n";
            return undef; # abort: incomplete Mapping; should never occur
        }
        my $match = $sequence->{$key};
        unless (defined($match)) {
            $deallocated++;
            next;
        }

# this mapping/sequence in $compare also figures in the current Contig

        if ($strong) {
# test alignment of complete mapping
            my ($identical,$aligned,$offset) = $match->isEqual($mapping);

            print STDERR "\nmapping: id=$identical  align=".($aligned||' ').
            "  offset=".($offset||' ')."  ".$mapping->getMappingName if $DEBUG;
 
# keep the first encountered (contig-to-contig) alignment value != 0 
            $alignment = $aligned unless $alignment;
            next unless ($identical && $aligned == $alignment);
# the mappings are identical (alignment and segment sizes)
            my @segment = $mapping->getContigRange();
# build a hash key based on offset and alignment direction and add segment
            my $hashkey = sprintf("%08d",$offset);
            $inventory->{$hashkey} = [] unless defined $inventory->{$hashkey};
            push @{$inventory->{$hashkey}},[@segment];
            print STDERR " contig segment @segment " if $DEBUG;
        }

# otherwise do a segment-by-segment comparison and find ranges of identical mapping

        else {
            my $debug = $DEBUG;
            if ($DEBUG) {
                my ($identical,$al,$of) = $match->isEqual($mapping);
                $debug = 0 if $identical;
            }

            my ($aligned,$osegments) = $match->compare($mapping,$debug);
# keep the first encountered (contig-to-contig) alignment value != 0 
            $alignment = $aligned unless $alignment;

            print STDERR "Fine comparison of segments for mapping: align=".
             ($aligned||' ')."  ".$mapping->getMappingName."\n" if $DEBUG;

            next unless ($alignment && $aligned == $alignment);
# add the mapping range(s) returned in the list to the inventory 
            foreach my $osegment (@$osegments) {
                my $offset = shift @$osegment;
                my $hashkey = sprintf("%08d",$offset);
                $inventory->{$hashkey} = [] unless defined $inventory->{$hashkey};
                my @segment = @$osegment; # copy
                push @{$inventory->{$hashkey}},[@segment];
                print STDERR " contig segment @segment \n" if $DEBUG;
	    }
	}
    }
    print "\n" if $DEBUG;

# OK, here we have an inventory: the number of keys equals the number of 
# different alignments between $this and $compare. On each key we have an
# array of arrays with the individual mappings data. For each alignment we
# determine if the covered interval is contiguous. For each such interval
# we add a (contig) Segment alignment to the output mapping
# NOTE: the table can be empty, which occurs if all reads in the current Contig
# have their mappings changed compared with the previous contig 

    my $mapping = new Mapping($compare->getContigName());
    $mapping->setSequenceID($compare->getContigID());

# determine guillotine; accept only alignments with a minimum number of reads 

    if ($guillotine) {
        $guillotine = 1 + log(scalar(@$mappings)); 
# adjust for small numbers (2 and 3)
        $guillotine -= 1 if ($guillotine > scalar(@$mappings) - 1);
        $guillotine = 2  if ($guillotine < 2); # minimum required
        print STDERR "guillotine: $guillotine \n" if $DEBUG;
    }


    my @c2csegments;
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
                if ($nreads >= $guillotine) {
                    my $start = ($segmentstart + $offset) * $alignment;
                    my $finis = ($segmentfinis + $offset) * $alignment;
		    my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
                    push @c2csegments,[@segment];
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
        next unless ($nreads >= $guillotine);
        my $start = ($segmentstart + $offset) * $alignment;
        my $finis = ($segmentfinis + $offset) * $alignment;
        my @segment = ($start,$finis,$segmentstart,$segmentfinis,$offset);
        push @c2csegments,[@segment];
    }

# the segment list now may on rare occasions contain overlapping segments
# the position of overlap have conflicting offsets, and therefore have to
# be removed by adjusting the intervals

    @c2csegments = sort {$a->[0] <=> $b->[0]} @c2csegments;

    for (my $i = 1 ; $i < @c2csegments ; $i++) {
        my $this = $c2csegments[$i-1];
        my $next = $c2csegments[$i];
# the aligned case
        while ($alignment > 0 && $this->[1] >= $next->[0]) {
            $this->[1]--;
            $this->[3]--;
            $next->[0]++;
            $next->[2]++;
	}
# the counter-aligned case
        while ($alignment < 0 && $this->[0] >= $next->[1]) {
            $this->[0]--;
            $this->[2]++;
            $next->[1]++;
            $next->[3]--;
	}
    }

# enter the segments to the mapping

    foreach my $segment (@c2csegments) {
	print "segment @$segment \n" if $DEBUG;
        next if ($segment->[3] < $segment->[2]); # in case the boundaries have changed
        $mapping->addAssembledFrom(@$segment);
    }

    if ($mapping->hasSegments()) {
# store the Mapping as a contig-to-contig mapping
        $this->addContigToContigMapping($mapping);
    }

# and return the number of segments, which could be 0
        
    return $mapping->hasSegments(),$deallocated;

# if the mapping has no segments, no mapping range could be determined
# by the algorithm above. If the 'strong' mode was used, perhaps the
# method should be re-run in standard (strong=0) mode

}

sub reverse {
# inverts all read alignments
    my $this = shift;

    my $length = $this->getContigLength();
 
    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        $mapping->applyMirrorTransform($length+1);
    }
# and sort the mappings according to increasing contig position
    @$mappings = sort {$a->getContigStart <=> $b->getContigStart} @$mappings;
}

sub findMapping {
    my $this = shift;
    my $readname = shift;

    return undef unless $this->hasMappings();

    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        return $mapping if ($mapping->getMappingName() eq '$readname');
    }

    return undef;
}

#-------------------------------------------------------------------    
# Tags
#-------------------------------------------------------------------    

sub inheritTags {
# inherit tags from this contig's parents
    my $this = shift;
    my $depth = shift;

    $depth = 1 unless defined($depth);

# get the parents

    my $parents = $this->getParentContigs(1);

    return unless ($parents && @$parents);

    foreach my $parent (@$parents) {
# if this parent does not have tags, test its parent(s)
        if ($depth > 0 && !$parent->hasTags(1)) {
            $parent->inheritTags($depth-1);
        }
# get the tags from the parent into this contig
        next unless $parent->hasTags();
        $parent->propagateTagsToContig($this);
    }

    $depth-- if $depth;
}

sub propagateTags {
# propagate the tags from this contig to its child(ren)
    my $this = shift;

# get the child(ren) of this contig

    my $children = $this->getChildContigs(1);

    foreach my $child (@$children) {
        $this->propagateTagsToContig($child);
    }
}

sub propagateTagsToContig {
# propagate tags from this (parent) to target contig
    my $parent = shift;
    my $target = shift;

    return 0 unless $parent->hasTags(1);
print "propagateTagsToContig ".
      "parent $parent (".$parent->getContigID().")  target $target ("
                        .$target->getContigID().")\n" if $DEBUG;

# check the parent-child relation: is there a mapping between them and
# is the ID of the one of the parents identical to to the input $parent?
# we do this by getting the parents on the $target and compare with $parent

    my $mapping;

    my $cparents = $target->getParentContigs(1);

    my $parent_id = $parent->getContigID();


    if ($cparents && @$cparents && $target->hasContigToContigMappings(1)) {
# there are mappings: hence the child is taken from the database (and has parents)
        foreach my $cparent (@$cparents) {
print "comparing IDs : ".$cparent->getContigID()." ($parent_id)\n" if $DEBUG;
	    if ($cparent->getContigID() == $parent_id) {
# yes, there is a parent child relation between the input Contigs
# find the corresponding mapping using contig and mapping names
                my $c2cmappings = $target->getContigToContigMappings();
                foreach my $c2cmapping (@$c2cmappings) {
		    if ($c2cmapping->getMappingName eq $parent->getContigName) {
                        $mapping = $c2cmapping;
                        last;
                    }
                }
	    }
	}
    }

print "mapping found: ".($mapping || 'not found')."\n" if $DEBUG;

# if mapping is not defined here, we have to find it from scratch

    unless ($mapping) {
print "Finding mappings from scratch \n";
        my ($nrofsegments,$deallocated) = $target->linkToContig($parent);
print "number of mapping segments : ",($nrofsegments || 0)."\n" if $DEBUG;
        return 0 unless $nrofsegments;
# identify the mapping using contig and mapping names
        my $c2cmappings = $target->getContigToContigMappings();
        foreach my $c2cmapping (@$c2cmappings) {
	    if ($c2cmapping->getMappingName eq $parent->getContigName) {
                $mapping = $c2cmapping;
                last;
            }
        }
# protect against the mapping still not found, but this should not occur
print "mapping identified: ".($mapping || 'not found')."\n" if $DEBUG;
        return 0 unless $mapping;
    }
print $mapping->assembledFromToString() if $DEBUG;

# check if the length of the target contig is defined

    my $tlength = $target->getConsensusLength();
    unless ($tlength) {
        $target->getStatistics(1); # no zeropoint shift; use contig as is
        $tlength = $target->getConsensusLength();
        unless ($tlength) {
            print STDERR "Undefined length in (child) contig\n";
            return 0;
        }
    }
print "Target contig length : $tlength \n" if $DEBUG;

# ok, propagate the tags from parent to target

    my $c2csegments = $mapping->getSegments();
    my $alignment = $mapping->getAlignment();

    my @tags;
    my $ptags = $parent->getTags(1); # tags in parent
    foreach my $ptag (@$ptags) {

# determine the segment(s) of the mapping with the tag's position
print "processing tag $ptag (align $alignment) \n" if $DEBUG;

        undef my @offset;
        my @position = $ptag->getPosition();
print "tag position (on parent) @position \n" if $DEBUG;
        foreach my $segment (@$c2csegments) {
# for the correct segment, getXforY returns true
            for my $i (0,1) {
print "testing position $position[$i] \n" if $DEBUG;
                if ($segment->getXforY($position[$i])) {
                    $offset[$i] = $segment->getOffset();
print "offset to be applied : $offset[$i] \n" if $DEBUG;
# ensure that both offsets are defined; this line ensures definition in
# case the counterpart falls outside any segment (i.e. outside the contig)
                    $offset[1-$i] = $offset[$i] unless defined $offset[1-$i];
                }
            }
        }
# accept the new tag only if the position offsets are defined
print "offsets: @offset \n" if $DEBUG;
        next unless @offset;
# create a new tag by spawning from the old tag
        my $newtag = $ptag->transpose($alignment,\@offset,$tlength);

if ($DEBUG) {
print "tag on parent : "; $ptag->writeToCaf(*STDOUT);
print "tag on target : "; $newtag->writeToCaf(*STDOUT);
}

# test if the new tag is not already present in the child

        my $present = 0;
        my $ctags = $target->getTags(0);
        foreach my $ctag (@$ctags) {
            if ($newtag->isEqual($ctag)) {
                $present = 1;
                last;
	    }
        }
        next if $present;

# it's a new tag       

print "new tag added\n" if $DEBUG;
        $target->addTag($newtag);
    }
}

#-------------------------------------------------------------------    
# exporting to CAF (standard Arcturus)
#-------------------------------------------------------------------    

sub writeToCaf {
# write reads and contig to CAF (unpadded)
    my $this = shift;
    my $FILE = shift; # obligatory file handle

    my $contigname = $this->getContigName();

# dump all reads

    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        $read->writeToCaf($FILE);
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
            $tag->writeToCaf($FILE);
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"\nDNA : "); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"\nBaseQuality : ");

    print $FILE "\n";
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

    unless (shift) {
# suppress dumping read data with extra paramater 
        my $reads = $this->getReads();
        foreach my $read (@$reads) {
            $read->writeToFasta($DFILE,$QFILE);
        }
    }

    $this->writeDNA($DFILE);

    $this->writeBaseQuality($QFILE) if defined $QFILE;
}

# private methods

sub writeDNA {
# write consensus sequence DNA in FASTA format to FILE handle
    my $this   = shift;
    my $DFILE  = shift; # obligatory
    my $marker = shift;

    $marker = '>' unless defined($marker); # default FASTA format

    my $identifier = $this->getContigName();

    if (!$DFILE) {
        print STDERR "Missing file handle for DNA\n";
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
    }
}

sub writeBaseQuality {
# write consensus Quality Data in FASTA format to FILE handle
    my $this   = shift;
    my $QFILE  = shift; # obligatory
    my $marker = shift;

    $marker = '>' unless defined($marker); # default FASTA format

    my $identifier = $this->getContigName();

    if (!$QFILE) {
        print STDERR "Missing file handle for Quality Data\n";
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

sub toString {
# very brief summary
    my $this = shift;

    my $name   = $this->getContigName()            || "undefined";
    my $nreads = $this->getNumberOfReads()         || "undefined";
    my $length = $this->getConsensusLength()       ||   "unknown";
    my $cover  = $this->getAverageCover()          ||   "unknown";

    return sprintf ("%16s   reads:%-7d   length:%-8d   cover:%4.2f", 
                    $name,$nreads,$length,$cover);
}

#-------------------------------------------------------------------    
# non-standard output for interaction with Phusion and Gap4
#-------------------------------------------------------------------    

sub writeToMaf {
# write the "reads.placed" read-contig mappings in Mullikin format
    my $this = shift;
    my $DFILE = shift; # obligatory file handle for DNA
    my $QFILE = shift; # obligatory file handle for QualityData
    my $RFILE = shift; # obligatory file handle for Placed Reads
    my $options = shift; # hash ref for options

    unless ($DFILE && $QFILE && $RFILE) {
	print STDERR "Missing file handle for Bases\n" unless ($DFILE);
	print STDERR "Missing file handle for Quality\n" unless ($QFILE);
	print STDERR "Missing file handle for Placed Reads\n" unless ($RFILE);
	return undef;
    }

# preset error reporting

    my $success = 1;
    my $report = '';

# first handle the fasta output of the consensus sequence DNA and Quality

    my $minNX = $options->{minNX};
    $minNX = 3 unless defined($minNX);

    $this->replaceNbyX($minNX) if ($minNX);
    $this->writeToFasta($DFILE,$QFILE,1); # no reads

# extra outside info to be passed as parameters: supercontig name &
# approximate start of contig on supercontig

    my $contigname = $this->getContigName();
    my $supercontigname = $options->{supercontigname} || $contigname;
    my $contigzeropoint = $options->{contigzeropoint} || 0;

# get the reads and build a hash list for identification

    my %reads;
    my $reads = $this->getReads(1); # ? (1)
    foreach my $read (@$reads) {
        $reads{$read->getReadName()} = $read;
    }

# write the individual read info

    my $mappings = $this->getMappings(1); # ? (1)
    foreach my $mapping (@$mappings) {
        my @range = $mapping->getContigRange();
        my $readname = $mapping->getMappingName();
        unless ($readname) {
            $report .= "Missing readname in mapping ".$mapping->getMappingID()."\n";
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

    return $success,$report;
}

sub replaceNbyX {
# substitute strings of (CAF) 'N's in the consensus sequence by (MAF) 'X' 
    my $this = shift;
    my $min = shift || 0; # minimum length of the string

    my $sequence = $this->getSequence();

# first replace all Ns by X

    $sequence =~ s/N/X/ig;

# then change contiguous runs of X smaller than $min back to N

    my $X = 'X';
    my $N = 'n';
    my $i = 1;

    while ($i++ < $min) {
        $sequence =~ s/([ACTG\?])($X)(?=[ACTG\?])/$1$N/ig;
        $X .= 'X';
        $N .= 'N';
    }

# replace current consensus by the substituted string 

    $this->setSequence($sequence);
}

sub writeToCafPadded {
# TO BE REPLACED
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
            print STDERR "Missing padded read $readname\n";
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

1;
