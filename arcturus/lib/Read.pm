package Read;

use strict;

#-------------------------------------------------------------------
# Constructor new (instantiation with readname is optional)
#-------------------------------------------------------------------

sub new {
    my $class    = shift;
    my $readname = shift; # optional

    my $this = {};

    bless $this, $class;

    $this->{readname} = $readname;
    $this->{data}     = {}; # metadata hash

    $this->addToInventory('readname') if $readname;

    return $this;
}

#-------------------------------------------------------------------
# inventory of instances of this class (methods for quick look-up)
#-------------------------------------------------------------------

my %Reads;

sub addToInventory {
# add this instance to the inventory keyed on either read_id (default) or readname
    my $this = shift;
    my $item = shift || 'read_id';

    return undef unless ($item eq 'read_id' || $item eq 'readname');

    my $key = $this->{data}->{$item} || return undef;

    $Reads{$key} = $this;
}

sub fingerRead {
# return the instance if present in the inventory
    my $this = shift;
    my $item = shift;

    return $Reads{$item};
}

sub getInventory {
# return reference to inventory list
    return \%Reads;
}

sub clearInventory {
# delete the current inventory
    undef %Reads;
}

#-------------------------------------------------------------------
# import of handles to related objects
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

sub setMapping {
# import the Mapping instance for this Read
    my $this    = shift;
    my $Mapping = shift;

    if (ref($Mapping) ne 'Mapping') {
        die "Invalid object passed: $Mapping";
    }
# test consistent read_id values
    elsif ($Mapping->getReadID == $this->getReadID) {
        $this->{Mapping} = $Mapping;
        return 1;
    }
    else {
        return 0;
    }
}    

#-------------------------------------------------------------------
# lazy instantiation of DNA and quality data
#-------------------------------------------------------------------

sub importSequence {
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

    my ($sequence, $quality) = $ADB->getSequenceAndBaseQualityForRead(id => $this->getReadID());

    $this->setSequence($sequence); # a string
    $this->setQuality($quality);   # reference to an array of integers
}

#-------------------------------------------------------------------
# delayed loading of comment(s)
#-------------------------------------------------------------------

sub importComment {
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

    my $comment = $ADB->getCommentForRead(id => $this->getReadID()) || '';

    if (ref($comment) eq 'ARRAY') {
        $this->{comment} = join "\n",@$comment;
    }
    elsif ($comment) {
        $this->{comment} = $comment;
    }
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
            if ($key eq 'readname') {
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
# export of meta data of this instance with a hash
    my $this = shift;

    my %export;
    my $data = $this->{data};

    $export{readname} = $this->{readname} if $this->{readname};

    foreach my $key (%$data) {
        $export{$key} = $data->{$key} if defined $data->{$key};
    }

    return \%export;
}

#-------------------------------------------------------------------    

sub setBaseCaller {
    my $this = shift;
    $this->{data}->{basecaller} = shift;
}

sub getBaseCaller {
    my $this = shift;
    return $this->{data}->{basecaller};
}

#-----------------

sub setChemistry {
    my $this = shift;
    $this->{data}->{chemistry} = shift;
}

sub getChemistry {
    my $this = shift;
    return $this->{data}->{chemistry};
}

#-----------------

sub setClone {
    my $this = shift;
    $this->{data}->{clone} = shift;
}

sub getClone {
    my $this = shift;
    return $this->{data}->{clone};
}

#-----------------

sub setCloningVector {
    my $this = shift;
    $this->{data}->{cvector} = shift;
}

sub getCloningVector {
    my $this = shift;
    return $this->{data}->{cvector};
}

#-----------------

sub setCloningVectorLeft {
    my $this = shift;
    $this->{data}->{cvleft} = shift;
}

sub getCloningVectorLeft {
    my $this = shift;
    return $this->{data}->{cvleft};
}

#-----------------

sub setCloningVectorRight {
    my $this = shift;
    $this->{data}->{cvright} = shift;
}

sub getCloningVectorRight {
    my $this = shift;
    return $this->{data}->{cvright};
}

#-----------------

sub setComment {
    my $this = shift;
    $this->{comment} = shift;
}

sub getComment {
    my $this = shift;
    $this->importComment unless defined($this->{comment});
    return $this->{comment};
}

#-----------------

sub setDate {
    my $this = shift;
    $this->{data}->{date} = shift;
}

sub getDate {
    my $this = shift;
    return $this->{data}->{date};
}

#-----------------

sub setDirection {
    my $this = shift;
    $this->{data}->{direction} = shift;
}

sub getDirection {
    my $this = shift;
    return $this->{data}->{direction};
}

#-----------------

sub setInsertSize {
    my $this = shift;
    $this->{data}->{insertsize} = shift;
}

sub getInsertSize {
    my $this = shift;
    return $this->{data}->{insertsize};
}

#-----------------

sub setLigation {
    my $this = shift;
    $this->{data}->{ligation} = shift;
}

sub getLigation {
    my $this = shift;
    return $this->{data}->{ligation};
}

#-----------------

sub setLowQualityLeft {
    my $this = shift;
    $this->{data}->{lqleft} = shift;
}

sub getLowQualityLeft {
    my $this = shift;
    return $this->{data}->{lqleft};
}

#-----------------

sub setLowQualityRight {
    my $this = shift;
    $this->{data}->{lqright} = shift;
}

sub getLowQualityRight {
    my $this = shift;
    return $this->{data}->{lqright};
}

#-----------------

sub setPrimer {
    my $this = shift;
    $this->{data}->{primer} = shift;
}

sub getPrimer {
    my $this = shift;
    return $this->{data}->{primer};
}

#-----------------

sub setQuality {
# import the reference to an array with base qualities
    my $this = shift;

    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$this->{BaseQuality} = $quality;
    }
}

sub getQuality {
# return the quality data (possibly) using lazy instatiation
    my $this = shift;
    $this->importSequence(@_) unless defined($this->{BaseQuality});
    return $this->{BaseQuality}; # returns an array reference
}

#-----------------

sub setReadID {
    my $this = shift;
    $this->{data}->{read_id} = shift;
}

sub getReadID {
    my $this = shift;
    return $this->{data}->{read_id};
}

#-----------------

sub setReadName {
    my $this = shift;
    $this->{readname} = shift;
}

sub getReadName {
    my $this = shift;
    return $this->{readname};
}

#-----------------

sub setSequence {
    my $this = shift;

    my $sequence = shift;

    if (defined($sequence)) {
	$this->{Sequence} = $sequence;
	$this->{data}->{slength} = length($sequence);
    }
}

sub getSequence {
# return the DNA (possibly) using lazy instatiation
    my $this = shift;
    $this->importSequence(@_) unless defined($this->{Sequence});
    return $this->{Sequence};
}

#-----------------

sub getSequenceLength {
    my $this = shift;
    return $this->{data}->{slength};
}

#-----------------

sub setStrand {
    my $this = shift;
    $this->{data}->{strand} = shift;
}

sub getStrand {
    my $this = shift;
    return $this->{data}->{strand};
}

#-----------------

sub setSequenceVectorSite {
    my $this = shift;
    $this->{data}->{svcsite} = shift;
}

sub getSequenceVectorSite {
    my $this = shift;
    return $this->{data}->{svcsite};
}

#-----------------

sub setSequencingVector {
    my $this = shift;
    $this->{data}->{svector} = shift;
}

sub getSequencingVector {
    my $this = shift;
    return $this->{data}->{svector};
}

#-----------------

sub setSequenceVectorLeft {
    my $this = shift;
    $this->{data}->{svleft} = shift;
}

sub getSequenceVectorLeft {
    my $this = shift;
    return $this->{data}->{svleft};
}

#-----------------

sub setSequenceVectorRight {
    my $this = shift;
    $this->{data}->{svright} = shift;
}

sub getSequenceVectorRight {
    my $this = shift;
    return $this->{data}->{svright};
}

#-----------------

sub setTemplate {
    my $this = shift;
    $this->{data}->{template} = shift;
}

sub getTemplate {
    my $this = shift;
    return $this->{data}->{template};
}

#----------------------------------------------------------------------
# dumping data
#----------------------------------------------------------------------

sub importMapping {
# link this Read with a Mapping object
    my $this = shift;
    
    $this->{Mapping} = shift;
}

sub writeToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $this    = shift;
    my $FILE    = shift; # obligatory

    my $data = $this->{data};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "Sequence : $this->{readname}\n";
    print $FILE "Is_read\n";
    print $FILE "Unpadded\n";
    print $FILE "SCF_File $this->{readname}SCF\n";
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

    my $Mapping = $this->{Mapping};
    $Mapping->writeMapToCaf($FILE,1) if $Mapping;

# process read tags ?

    my $Tags = $this->{Tags};

# process read tags ? 

    my $dna = $this->getSequence();

    if (defined($dna)) {
	print $FILE "\nDNA : $this->{readname}\n";
# output in blocks of 60 characters
	my $offset = 0;
	my $length = length($dna);
	while ($offset < $length) {    
	    print $FILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }

# the quality data

    my $quality = $this->getQuality();

    if (defined($quality)) {
	print $FILE "\nBaseQuality : $this->{readname}\n";
	my $line;
	my $next = 0;
# output in lines of 24 numbers
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
    my $this = shift;

    foreach my $key (sort keys %{$this}) {
        my $item = $this->{$key};
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




