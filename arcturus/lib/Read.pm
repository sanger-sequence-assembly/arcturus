package Read;

use strict;

#-------------------------------------------------------------------
# Constructor (optional instantiation with readname as identifier)
#-------------------------------------------------------------------

sub new {
    my $class    = shift;
    my $readname = shift; # optional

    my $this = {};

    bless $this, $class;

    $this->{data} = {}; # metadata hash

    $this->{Tags} = []; # array of read tags
 
    $this->setReadName($readname) if defined($readname);

    return $this;
}

#-------------------------------------------------------------------
# import/export of handles to related objects
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

sub addTag {
# import a Tag instance and add to the Tag list
    my $this = shift;
    my $Tag  = shift;

    if (ref($Tag) eq 'Tag') {
        push @{$this->{Tags}}, $Tag;
    }
    else {
        die "Invalid object passed: $Tag";
    }
}

sub getTags {
# export reference to the Tags array
    my $this = shift;

    return $this->{Tags};
}

#-------------------------------------------------------------------
# lazy instantiation of DNA and quality data (private)
#-------------------------------------------------------------------

sub importSequence {
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

    my ($sequence, $quality) = $ADB->getSequenceForRead(id => $this->getReadID());

    $this->setSequence($sequence); # a string
    $this->setQuality($quality);   # reference to an array of integers
}

#-------------------------------------------------------------------
# delayed loading of comment(s) (private)
#-------------------------------------------------------------------

sub importComment {
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

    my $comment = $ADB->getCommentForRead(id => $this->getReadID);

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

sub setAspedDate {
    my $this = shift;
    $this->{data}->{asped} = shift;
}

sub getAspedDate {
    my $this = shift;
    return $this->{data}->{asped};
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

sub addCloningVector {
    my $this = shift;

    my $value = shift;

    return unless defined($value);

    $this->{data}->{cvector} = [] unless defined($this->{data}->{cvector});

    push @{$this->{data}->{cvector}}, $value;
}

sub getCloningVector {
    my $this = shift;
    return $this->{data}->{cvector};
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

sub setProcessStatus {
    my $this = shift;
    $this->{data}->{pstatus} = shift;
}

sub getProcessStatus {
    my $this = shift;
    return $this->{data}->{pstatus};
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

sub setSequenceVectorCloningSite {
    my $this = shift;
    $this->{data}->{svcsite} = shift;
}

sub getSequenceVectorCloningSite {
    my $this = shift;
    return $this->{data}->{svcsite};
}

#-----------------

sub setSequenceVectorPrimerSite {
    my $this = shift;
    $this->{data}->{svpsite} = shift;
}

sub getSequenceVectorPrimerSite {
    my $this = shift;
    return $this->{data}->{svpsite};
}

#-----------------

sub addSequencingVector {
    my $this = shift;

    my $value = shift;

    return unless defined($value);

    $this->{data}->{svector} = [] unless defined($this->{data}->{svector});

    push @{$this->{data}->{svector}}, $value;
}

sub getSequencingVector {
    my $this = shift;
    return $this->{data}->{svector};
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

#-----------------

sub setTraceArchiveIdentifier {
    my $this = shift;
    $this->{TAI} = shift;
}

sub getTraceArchiveIdentifier {
    my $this = shift;

    if (!$this->{TAI}) {
        my $ADB = $this->{ADB} || return undef;
        $this->{TAI} = $ADB->getTraceArchiveIdentifier(id=>$this->getReadID);
    }
    return $this->{TAI};
}

#----------------------------------------------------------------------
# check for completeness
#----------------------------------------------------------------------

sub checkReadForCompleteness {
    my $this = shift;
    my $options = shift;

    my $skipAspedCheck = 0;

    if (defined($options) && ref($options) && ref($options) eq 'HASH') {
	$skipAspedCheck = $options->{skipaspedcheck} || 0;
    }

    return (0, "undefined asped-date")
	unless (defined($this->getAspedDate()) || $skipAspedCheck);

    return (0, "undefined base-quality")
	unless defined($this->getQuality());

    return (0, "undefined chemistry")
	unless defined($this->getChemistry());

    return (0, "undefined insert-size")
	unless defined($this->getInsertSize());

    return (0, "undefined ligation")
	unless defined($this->getLigation());

    return (0, "undefined low-quality-left")
	unless defined($this->getLowQualityLeft());

    return (0, "undefined low-quality-right")
	unless defined($this->getLowQualityRight());

    return (0, "undefined primer")
	unless defined($this->getPrimer());

    return (0, "undefined readname")
	unless defined($this->getReadName());

    return (0, "undefined sequence")
	unless defined($this->getSequence());

    return (0, "undefined strand")
	unless defined($this->getStrand());

    return (0, "undefined template")
	unless defined($this->getTemplate());

    return (1, "OK");
}

#----------------------------------------------------------------------
# dumping data
#----------------------------------------------------------------------

sub writeToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $this    = shift;
    my $FILE    = shift; # obligatory
    my $Mapping = shift; # optional

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

# if a Mapping is provided, add the alignment info (the padded maps)

    if ($Mapping) {
# test validity; fail most likely due to programming error, hence die
        if (ref($Mapping) ne 'Mapping') {
            die "Invalid object passed as Mapping in writeToCaf: $Mapping";
        }
# test consistent read_id values
        elsif ($Mapping->getReadID != $this->getReadID) {
            die "Inconsistent read IDs in writeToCaf";
        }
# write out the mapping and possible Tag info
        else {
            $Mapping->writeMapToCaf($FILE);
# process read tags 
            foreach my $Tag (@{$this->{Tags}}) {
#?                $Tag->writeTagToCaf($FILE);
            }
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"DNA : "); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"BaseQuality : ");
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

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

    my $dna = $this->getSequence();

    if (defined($dna)) {
	print $FILE "\n$marker$this->{readname}\n";
# output in blocks of 60 characters
	my $offset = 0;
	my $length = length($dna);
	while ($offset < $length) {    
	    print $FILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }
}

sub writeBaseQuality {
# write Quality data of this read in FASTA format to FILE handle
    my $this   = shift;
    my $FILE   = shift; # obligatory
    my $marker = shift;

    $marker = '>' unless defined($marker); # default FASTA format

# the quality data go into a separt

    my $quality = $this->getQuality();

    if (defined($quality)) {
	print $FILE "\n$marker$this->{readname}\n";
# output in lines of 24 numbers
	my @bq = @{$quality};
	while (my $n = scalar(@bq)) {
	    print $FILE join(' ',@bq[0..24]),"\n";
	    @bq = @bq[25..$n];
	}
    }
}

##############################################################

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

##############################################################

1;
