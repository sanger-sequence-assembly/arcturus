package Contig;



sub new {
    my $class      = shift;
    my $contigname = shift; # optional

    my $this = {};

    bless $this, $class;

    $self->{contigname} = $contigname;
    $self->{data}      = {}; # meta data hash
    $self->{Reads}     = []; # array of Read instances
    $self->{Mappingss} = []; # array of Mappings

    return $this;
}

#------------------------------------------------------------------- 
# parent database handle
#-------------------------------------------------------------------

sub setArcturusDatabase {
# import the parent Arcturus database handle
    my $self = shift;

    $self->{ADB} = shift;
}

sub getArcturusDatabase {
# export the parent Arcturus database handle
    my $self = shift;

    return $self->{ADB};
}

#-------------------------------------------------------------------
# delayed loading of DNA and quality data
#-------------------------------------------------------------------

sub importSequence {
    my $self = shift;

    my $ADB = $self->{ADB} || return; # the parent database

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForContig(id => $self->getContigID());

    $self->setSequence($sequence); # a string
    $self->setQuality($quality);   # reference to an array of integers
}

#-------------------------------------------------------------------    
# importing & exporting data and meta data
#-------------------------------------------------------------------    

sub importData {
# input of meta data into this instance with a hash
    my $self = shift;
    my $hash = shift;

# copy the input hash elements (disconnect from outside interference)

    my $copied = 0;
    if (ref($hash) eq 'HASH') {
        my $data = $self->{data};
        foreach my $key (%$hash) {
            if ($key eq 'contigname') {
                $self->{$key} = $hash->{$key};
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

sub setQuality {
# import the reference to an array with base qualities
    my $self = shift;

    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$self->{BaseQuality} = $quality;
    }
}

sub getQuality {
# return the quality data (possibly) using lazy instatiation
    my $self = shift;
    $self->importSequence(@_) unless defined($self->{BaseQuality});
    return $self->{BaseQuality}; # returns an array reference
}

#-------------------------------------------------------------------   

sub setSequence {
    my $self = shift;

    my $sequence = shift;

    if (defined($sequence)) {
	$self->{Sequence} = $sequence;
	$self->{data}->{slength} = length($sequence);
    }
}

sub getSequence {
# return the DNA (possibly) using lazy instatiation
    my $self = shift;
    $self->importSequence(@_) unless defined($self->{Sequence});
    return $self->{Sequence};
}

#-------------------------------------------------------------------    
# getting Contigs from database
#-------------------------------------------------------------------    

sub importReads {
# import the reads for this contig as an array
    my $this  = shift;

    my $this->{Reads} = shift;
}


sub importMappings {
# import the reads for this contig as an array
    my $this  = shift;

    my $this->{Mappings} = shift;
}


#-------------------------------------------------------------------    

#-------------------------------------------------------------------    
















