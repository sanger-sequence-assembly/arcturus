package Contig;

use strict;

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
    return $this->{data}->{clength};
}

sub setConsensusLength {
    my $this = shift;
    $this->{data}->{clength} = shift;
}

#-------------------------------------------------------------------   

sub getContigID {
    my $this = shift;
    return $this->{data}->{contig_id};
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
  
sub getNumberOfReads {
    my $this = shift;
    return $this->{data}->{numberofreads};   
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;   
}

#------------------------------------------------------------------- 
  
sub hasNumberOfNewReads {
    my $this = shift;
    return $this->{data}->{numberofnewreads};   
}
  
sub setNumberOfNewReads {
    my $this = shift;
    $this->{data}->{numberofnewreads} = shift;   
}

#-------------------------------------------------------------------   

sub hasPreviousContigs {
    my $this = shift;
    return $this->{data}->{previouscontigs};   
}

sub setPreviousContigs {
    my $this = shift;
    $this->{data}->{previouscontigs} = shift;   
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

sub getReadNameHash {
    my $this = shift;
    return $this->{data}->{readnamehash};
}

sub setReadNameHash {
    my $this = shift;
    $this->{data}->{readnamehash} = shift;
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

sub getRead {
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
    return $this->getRead() ? 1 : 0;
}

sub getMapping {
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
    return $this->getMapping() ? 1 : 0;
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
# exporting to CAF
#-------------------------------------------------------------------    

sub writeToCaf {
# write reads and contig to CAF
    my $this = shift;
    my $FILE = shift; # obligatory file handle

    my $contigname = $this->getContigName();

# dump all reads

print STDERR "Dumping Reads\n"; my $nr = 0;

    my $reads = $this->getRead();
    foreach my $read (@$reads) {
        $read->writeToCafForAssembly($FILE);
print STDERR " Read ".$read->getSequenceID()." ($nr) done\n" if ((++$nr)%1000 == 0); 
    }

# write the overall maps for for the contig ("assembled from")


print STDERR "Dumping Contig\n";
    print $FILE "\nSequence : $contigname\nIs_contig\nUnpadded\n";

print STDERR "Dumping Mappings\n"; my $mr = 0;
    my $mappings = $this->getMapping();
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

    my $reads = $this->getRead();
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

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

1;
