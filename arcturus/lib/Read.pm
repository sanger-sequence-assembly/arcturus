package Read;

use strict;

#-------------------------------------------------------------------
# Constructor new
#-------------------------------------------------------------------

sub new {
    my $class    = shift;
    my $readname = shift; # optional

    my $self = {};

    bless $self, $class;

    $self->{readname} = $readname;
    $self->{data}     = {}; # metadata hash

    return $self;
}

#-------------------------------------------------------------------
# parent data base handle
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
# lazy instantiation of DNA and quality data
#-------------------------------------------------------------------

sub importSequence {
    my $self = shift;

    my $ADB = $self->{ADB} || return; # the parent database

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForRead(id => $self->getReadID());

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
            if ($key eq 'readname') {
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
# export of meta data of this instance with a hash
    my $self = shift;

    my %export;
    my $data = $self->{data};

    $export{readname} = $self->{readname} if $self->{readname};

    foreach my $key (%$data) {
        $export{$key} = $data->{$key} if defined $data->{$key};
    }

    return \%export;
}

#-------------------------------------------------------------------    

sub setBaseCaller {
    my $self = shift;
    $self->{data}->{basecaller} = shift;
}

sub getBaseCaller {
    my $self = shift;
    return $self->{data}->{basecaller};
}

#-----------------

sub setChemistry {
    my $self = shift;
    $self->{data}->{chemistry} = shift;
}

sub getChemistry {
    my $self = shift;
    return $self->{data}->{chemistry};
}

#-----------------

sub setClone {
    my $self = shift;
    $self->{data}->{clone} = shift;
}

sub getClone {
    my $self = shift;
    return $self->{data}->{clone};
}

#-----------------

sub setCloningVector {
    my $self = shift;
    $self->{data}->{cvector} = shift;
}

sub getCloningVector {
    my $self = shift;
    return $self->{data}->{cvector};
}

#-----------------

sub setComment {
    my $self = shift;
    $self->{data}->{comment} = shift;
}

sub getComment {
    my $self = shift;
    return $self->{data}->{comment};
}

#-----------------

sub setCloningVectorLeft {
    my $self = shift;
    $self->{data}->{cvleft} = shift;
}

sub getCloningVectorLeft {
    my $self = shift;
    return $self->{data}->{cvleft};
}

#-----------------

sub setCloningVectorRight {
    my $self = shift;
    $self->{data}->{cvright} = shift;
}

sub getCloningVectorRight {
    my $self = shift;
    return $self->{data}->{cvright};
}

#-----------------

sub setDate {
    my $self = shift;
    $self->{data}->{date} = shift;
}

sub getDate {
    my $self = shift;
    return $self->{data}->{date};
}

#-----------------

sub setDirection {
    my $self = shift;
    $self->{data}->{direction} = shift;
}

sub getDirection {
    my $self = shift;
    return $self->{data}->{direction};
}

#-----------------

sub setInsertSize {
    my $self = shift;
    $self->{data}->{insertsize} = shift;
}

sub getInsertSize {
    my $self = shift;
    return $self->{data}->{insertsize};
}

#-----------------

sub setLigation {
    my $self = shift;
    $self->{data}->{ligation} = shift;
}

sub getLigation {
    my $self = shift;
    return $self->{data}->{ligation};
}

#-----------------

sub setLowQualityLeft {
    my $self = shift;
    $self->{data}->{lqleft} = shift;
}

sub getLowQualityLeft {
    my $self = shift;
    return $self->{data}->{lqleft};
}

#-----------------

sub setLowQualityRight {
    my $self = shift;
    $self->{data}->{lqright} = shift;
}

sub getLowQualityRight {
    my $self = shift;
    return $self->{data}->{lqright};
}

#-----------------

sub setPrimer {
    my $self = shift;
    $self->{data}->{primer} = shift;
}

sub getPrimer {
    my $self = shift;
    return $self->{data}->{primer};
}

#-----------------

sub setQuality {
# import the reference to an array with base qualities
    my $self = shift;

    my $quality = shift;

    if (defined($quality)) {
	$self->{BaseQuality} = $quality;
    }
}

sub getQuality {
# return the quality data (possibly) using lazy instatiation
    my $self = shift;
    $self->importSequence(@_) unless defined($self->{BaseQuality});
    return $self->{BaseQuality}; # returns an array reference
}

#-----------------

sub setReadID {
    my $self = shift;
    $self->{data}->{read_id} = shift;
}

sub getReadID {
    my $self = shift;
    return $self->{data}->{read_id};
}

#-----------------

sub setReadName {
    my $self = shift;
    $self->{readname} = shift;
}

sub getReadName {
    my $self = shift;
    return $self->{readname};
}

#-----------------

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

#-----------------

sub getSequenceLength {
    my $self = shift;
    return $self->{data}->{slength};
}

#-----------------

sub setStrand {
    my $self = shift;
    $self->{data}->{strand} = shift;
}

sub getStrand {
    my $self = shift;
    return $self->{data}->{strand};
}

#-----------------

sub setSequenceVectorSite {
    my $self = shift;
    $self->{data}->{svcsite} = shift;
}

sub getSequenceVectorSite {
    my $self = shift;
    return $self->{data}->{svcsite};
}

#-----------------

sub setSequencingVector {
    my $self = shift;
    $self->{data}->{svector} = shift;
}

sub getSequencingVector {
    my $self = shift;
    return $self->{data}->{svector};
}

#-----------------

sub setSequenceVectorLeft {
    my $self = shift;
    $self->{data}->{svleft} = shift;
}

sub getSequenceVectorLeft {
    my $self = shift;
    return $self->{data}->{svleft};
}

#-----------------

sub setSequenceVectorRight {
    my $self = shift;
    $self->{data}->{svright} = shift;
}

sub getSequenceVectorRight {
    my $self = shift;
    return $self->{data}->{svright};
}

#-----------------

sub setTemplate {
    my $self = shift;
    $self->{data}->{template} = shift;
}

sub getTemplate {
    my $self = shift;
    return $self->{data}->{template};
}

#----------------------------------------------------------------------
# dumping data
#----------------------------------------------------------------------

sub writeToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $self    = shift;
    my $FILE    = shift; # obligatory

    my $data = $self->{data};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "Sequence : $self->{readname}\n";
    print $FILE "Is_read\n";
    print $FILE "Unpadded\n";
    print $FILE "SCF_File $self->{readname}SCF\n";
    print $FILE "Template $data->{template}\n"                  if defined $data->{template};
    print $FILE "Insert_size $data->{insertsize}\n"             if defined $data->{insertsize};
    print $FILE "Ligation_no $data->{ligation}\n"               if defined $data->{ligation};
    print $FILE "Primer ".ucfirst($data->{primer})."_primer\n"  if defined $data->{primer};
    print $FILE "Strand $data->{strand}\n"                      if defined $data->{strand};
    print $FILE "Dye Dye_$data->{chemistry}\n"                  if defined $data->{chemistry};
    print $FILE "Clone $data->{clone}\n"                        if defined $data->{clone};
    print $FILE "ProcessStatus PASS\n";
    print $FILE "Asped $data->{date}\n"                         if defined $data->{date} ;
    print $FILE "Base_caller $data->{basecaller}\n"             if defined $data->{basecaller};
# add the alignment info (the padded maps)
#    $self->writeMapToCaf($FILE,1) if shift; # see below
# process read tags ?


    my $dna = $self->getSequence();

    if (defined($dna)) {
	print $FILE "\nDNA : $self->{readname}\n";

	my $offset = 0;
	my $length = length($dna);
# replace by loop using substr
	while ($offset < $length) {    
	    print $FILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }

# the quality data

    my $quality = $self->getQuality();

    if (defined($quality)) {
	print $FILE "\nBaseQuality : $self->{readname}\n";
	my $line;
	my $next = 0;

	my @bq = @{$quality};

	while (my $n = scalar(@bq)) {
	    print $FILE join(' ',@bq[0..24]),"\n";
	    @bq = @bq[25..$n];
	}
    }
}

#######################
# more methods:
#
# export as flat file (experiment file format, requires translation of keys, NO should be script)
#
#
# plus:
# a section dealing with padded mappings (import / export 'writeMapToCaf')
#
#######################

sub dump {
    my $self = shift;

    foreach my $key (sort keys %{$self}) {
        my $item = $self->{$key};
        print STDERR "self key $key -> $item\n";
        if (ref($item) eq 'HASH') {
            foreach my $key (sort keys %$item) {
                print STDERR "    $key -> $item->{$key}\n";
            }
        }
        elsif (ref($item) eq 'ARRAY') {
            print STDERR "    @$item\n";
        }
    }
}


1;




