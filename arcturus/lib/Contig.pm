package Contig;

use strict;

use Digest::MD5 qw(md5 md5_hex md5_base64);

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

    $this->{ADB} = shift;
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
  
sub getNumberOfContigs {
    my $this = shift;
# if number of contigs not defined get it from the Read array
    if (!defined($this->{data}->{numberofcontigs})) {
        my $npc = $this->hasPreviousContigs();
        $this->{data}->{numberofcontigs} = $npc;
    }
    return $this->{data}->{numberofcontigs};
}

sub setNumberOfContigs {
    my $this = shift;
    $this->{data}->{numberofcontigs} = shift;   
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

sub getPreviousContigs {
# returns array of previous contigs
    my $this = shift;
    return $this->{previouscontigs};   
}

sub setPreviousContigs {
# add previous contig (ID or object or whatever) to array
    my $this = shift;
    $this->{previouscontigs} = [] unless $this->{previouscontigs};
    push @{$this->{previouscontigs}}, shift;   
}

sub hasPreviousContigs {
# returns number of previous contigs
    my $this = shift;
    my $cpre = $this->getPreviousContigs();
    return $cpre ? scalar(@$cpre) : 0;
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
# importing/exporting Read(s), Mapping(s) & Tag(s) (or others)
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
# returns true if the contig has reads
    my $this = shift;
    return $this->getReads() ? 1 : 0;
}

sub getMappings {
# return a reference to the array of Mapping instances (can be empty)
    my $this = shift;
    return $this->{Mapping};
} 

sub addMapping {
# add (read) Mapping object (or an array) to the internal buffer
    my $this = shift;
    my $Mapping = shift;

    $this->importer($Mapping,'Mapping');
}

sub hasMappings {
# returns true if the contig has mappings
    my $this = shift;
    return $this->getMappings() ? 1 : 0;
}

sub getTag {
# return a reference to the array of Tag instances (can be empty)
    my $this = shift;
    return $this->{Tag};
} 

sub addTag {
# add Tag object or an array of Tag objects to the internal buffer
    my $this = shift;
    my $Tag  = shift;

    $this->importer($Tag,'Tag');
}

sub hasTags {
# returns true if the contig has tags
    my $this = shift;
    return $this->getTag() ? 1 : 0;
}

sub getContigToContigMapping {
# add (contig) Mapping object (or an array) to the internal buffer
    my $this = shift;
    return $this->{ContigMapping};
}

sub addContigToContigMapping {
    my $this = shift;
    my $ContigMapping = shift;

    $this->importer($ContigMapping,'ContigMapping');
    my $pc = scalar(@{$this->getContigMapping});
    $this->setPreviousContigs($pc);
}

#-------------------------------------------------------------------    

sub importer {
# private generic method for importing objects into a Contig instance
    my $this = shift;
    my $Component = shift;
    my $type = shift;

    die "Contig->importer expects a component type" unless $type;

    if (ref($Component) eq 'ARRAY') {
# recursive use with scalar parameter
        while (scalar(@$Component)) {
            $this->importer(shift @$Component,$type);
        }
    }
    else {
# test type of input object against specification
        my $inputtype = ref($Component);
        if ($type ne $inputtype) {
            die "Contig->importer expects a(n array of) $type instance(s) as input";
        }
        $this->{$type} = [] if !defined($this->{$type});
        push @{$this->{$type}}, $Component;
    }
}

#-------------------------------------------------------------------    
# calculate consensus length, cover, etc
#-------------------------------------------------------------------

sub getStatistics {
# collect a number of contig statistics
    my $this = shift;

# determine the range on the contig and the first and last read


    my $cstart = 0;
    my $cfinal = 0;
    my ($readonleft, $readonright);
    my $totalreadcover = 0;

    my $repeat = 2;
    while ($repeat) {
# go through the mappings to find begin, end of contig
# and to determine the reads at either end
        my ($minspanonleft, $minspanonright);
        my $name = $this->getContigName();
        if (my $mappings = $this->getMappings()) {
            my $init = 0;
            $totalreadcover = 0;
            foreach my $mapping (@$mappings) {
                my $readname = $mapping->getReadName();
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
                $repeat = 0;
            }
            elsif (--$repeat) {
# cstart != 1: this is an unusual lower boundary, apply shift to the 
# Mappings (and Segments) to get the contig starting at position 1
                my $shift = 1 - $cstart;
                print STDERR "Contig $name requires shift by $shift\n";
                foreach my $mapping (@$mappings) {
                    $mapping->applyShiftToContigPosition($shift);
                }
# and redo the loop (as $repeat > 0)
            }
            else {
# this should never occur, indicative of corrupted data/code in Mapping/Segment
                print STDERR "Illegal condition in Contig->getStatistics\n";
                return 0;
            }
        }
        else {
            print STDERR "Contig $name has no mappings\n";
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
# compare Contigs on metadata and mappings
#-------------------------------------------------------------------

sub isSameAs {
# compare the $compare and $this Contig instances
    my $this = shift;
    my $compare = shift || return 0;

    die "Contig->compare takes a Contig instance" unless (ref($compare) eq 'Contig');

# compare some of the metadata

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
# the countigs are different
        return 0;
    }

# compare the mappings one by one
# mappings are identified using their sequence IDs or their readnames
# this assumes that both sets of mappings have the same type of data

#print "getting inventory for mappings\n";
    my $sequence = {};
    my $numberofmappings = 0;
    if (my $mappings = $this->getMappings()) {
        $numberofmappings = scalar(@$mappings);
        foreach my $mapping (@$mappings) {
            my $key = $mapping->getSequenceID();
            $sequence->{$key} = $mapping if $key;
            $key =  $mapping->getReadName();
            $sequence->{$key} = $mapping if $key;
        }
    }
print "number of mappings $numberofmappings\n";

    undef my $shift;
    if (my $mappings = $compare->getMappings()) {
# check number of mappings
        return 0 if ($numberofmappings != scalar(@$mappings));

        foreach my $mapping (@$mappings) {
# find the corresponding mapping in $this Contig instance
            my $key = $mapping->getSequenceID() || $mapping->getReadName();
            return undef unless defined($key); # incomplete Mapping
            my $match = $sequence->{$key};
print "cannot find mapping for key $key \n" unless $match;
            return 0 unless defined($match); # there is no counterpart in $this
# compare the two maps
            my ($identical,$aligned,$offset) = $match->compare($mapping);
# print "mapping comparison: $identical,$aligned,$offset \n";
print "match   : ".$match->assembledFromToString unless $identical;
print "mapping : ".$mapping->assembledFromToString unless $identical;
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

print "Contig ".$this->getContigName()." isSameAs ($align) ".
                $compare->getContigName()."\n";
    return $align; # 1 for identical, -1 for identical but inverted
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

print STDERR "Dumping Reads\n"; my $nr = 0;

    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        $read->writeToCafForAssembly($FILE);
print STDERR " Read ".$read->getSequenceID()." ($nr) done\n" if ((++$nr)%1000 == 0); 
    }

# write the overall maps for for the contig ("assembled from")


print STDERR "Dumping Contig\n";
    print $FILE "\nSequence : $contigname\nIs_contig\nUnpadded\n";

print STDERR "Dumping Mappings\n"; my $mr = 0;
    my $mappings = $this->getMappings();
    foreach my $mapping (@$mappings) {
        print $FILE $mapping->assembledFromToString();
print STDERR " Map ".$mapping->getSequenceID()." ($mr) done\n" if ((++$mr)%1000 == 0);    
    }

# write tags, if any

    if ($this->hasTags) {
        my $tags = $this->getTags();
        foreach my $tag (@$tags) {
# $tag->toString ?
        }
    }

# to write the DNA and BaseQuality we use the two private methods

print STDERR "Dumping DNA\n";

    $this->writeDNA($FILE,"DNA : "); # specifying the CAF marker

print STDERR "Dumping BaseQuality\n";

    $this->writeBaseQuality($FILE,"BaseQuality : ");

    print $FILE "\n\n";
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

print STDERR "Dumping Reads\n"; my $nr = 0;

    my $reads = $this->getReads();
    foreach my $read (@$reads) {
        $read->writeToFasta($DFILE,$QFILE);
print STDERR " Read ".$read->getSequenceID()." ($nr) done\n" if ((++$nr)%1000 == 0); 
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

    my $string = "Statistics for contig ".$this->getContigName."\n";
    $string .= "Consensuslength ".$this->getConsensusLength."\n";
    $string .= "Average cover ".$this->getAverageCover."\n";   
    $string .=  "End reads : left ".$this->getReadOnLeft.
                          " right ".$this->getReadOnRight."\n";
    return $string;
}

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

1;
