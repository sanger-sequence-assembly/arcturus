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
# importing/exporting Read(s), Mapping(s) & Tag(s)
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

    $this->importComponent($Read,'Read');
}

sub getMapping {
# return a reference to the array of Mapping instances (can be empty)
    my $this = shift;

    return $this->{Mapping};
} 

sub addMapping {
# add Mapping object or an array of Mapping objects to the internal buffer
    my $this = shift;
    my $Mapping = shift;

    $this->importComponent($Mapping,'Mapping');
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

    $this->importComponent($Tag,'Tag');
}

#-------------------------------------------------------------------    

sub importComponent {
# private generic method
    my $this = shift;
    my $Component = shift;
    my $type = shift;

    if (ref($Component) eq 'ARRAY') {
# recursive use with scalar parameter
        foreach my $component (@$Component) {
            $this->importComponent($component,$type);
        }
    }
    else {
# test type of input object against specification
        my $inputtype = ref($Component);
        if ($type ne $inputtype) {
            die "Contig->import$type expects a $type instance or array of $type instances as input";
        }
        push @{$this->{$type}}, $Component;
    }
}

#-------------------------------------------------------------------    
# 
#-------------------------------------------------------------------    

1;
