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

    $this->{contigname} = $contigname;
    $this->{data}       = {}; # meta data hash
    $this->{Reads}      = []; # array of Read instances
    $this->{Mappings}   = []; # array of Mappings
    $this->{Tags}       = []; # array of Tag instances

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

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForContig(id => $cid);

    $this->setSequence($sequence); # a string

    $this->setQuality($quality);   # reference to an array of integers

    return 1;
}

#-------------------------------------------------------------------    
# importing & exporting data and meta data
#-------------------------------------------------------------------    

sub importData {
# input of meta data into this instance with a hash
    my $this = shift;
    my $hash = shift;

# copy the input hash elements (disconnect from outside interference)

    my $copied = 0;
    if (ref($hash) eq 'HASH') {
        my $data = $this->{data};
        foreach my $key (%$hash) {
            if ($key eq 'contigname') {
                $this->{$key} = $hash->{$key};
            } 
            else {
		$data->{$key} = $hash->{$key};
            }
            $copied++;      
        }
    }

    return $copied;
}

sub exportData {
# export of meta data of this instance in a hash
    my $this = shift;

    my %export;
    my $data = $this->{data};

    $export{contigname} = $this->{contigname} if $this->{contigname};

    foreach my $key (%$data) {
        $export{$key} = $data->{$key} if defined $data->{$key};
    }

    return \%export;
}

#-------------------------------------------------------------------   

sub getContigID {

    my $this = shift;

    return $this->{data}->{contig_id};
}

sub setContigID {

    my $this = shift;

    my $cid  = shift;

    return unless ($cid =~ /\D/); # must be a number

    $this->{data}->{contig_id} = $cid;
}
#-------------------------------------------------------------------   

sub getContigName {
    my $this = shift;
    return $this->{data}->{contigname};
}

sub setContigName {
    my $this = shift;
    $this->{data}->{contigname} = shift;
}

#-------------------------------------------------------------------   

sub setQuality {
# import base quality as an array with base quality values
    my $this    = shift;
    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$this->{BaseQuality} = $quality;
    }
}

sub getQuality {
# return the quality data (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{BaseQuality});
    return $this->{BaseQuality}; # returns an array reference
}

#-------------------------------------------------------------------   

sub setSequence {
# import consensus sequence (string) and its length (derived)
    my $this     = shift;
    my $sequence = shift;

    if (defined($sequence)) {
	$this->{Sequence} = $sequence;
	$this->{data}->{slength} = length($sequence);
    }
}

sub getSequence {
# return the DNA (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{Sequence});
    return $this->{Sequence};
}

#-------------------------------------------------------------------    
# importing Contig components
#-------------------------------------------------------------------    

sub importReads {
# import the reads for this contig as an array of Read instances
    my $this  = shift;

    my $this->{Reads} = shift;
}

sub importMappings {
# import the r-to-c mappings for this contig as an array of Mapping instances
    my $this  = shift;

    my $this->{Mappings} = shift;
}

sub importTags {
# import the tags for this contig as an array of Tag instances
    my $this  = shift;

    my $this->{Tags} = shift;
}

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

1;















