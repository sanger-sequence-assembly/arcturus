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
        $this->{Tags} = [] unless defined $this->{Tags};
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
# lazy instantiation of DNA and quality data 
#-------------------------------------------------------------------

sub importSequence {
# private method
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

# try successively: sequence id, read id and readname, whichever comes first
   
    my ($sequence, $quality);

    if (my $seq_id = $this->getSequenceID()) {
       ($sequence, $quality) = $ADB->getSequenceForRead(
                                     seq_id => $seq_id);
    }
    elsif (my $read_id =  $this->getReadID()) {
       ($sequence, $quality) = $ADB->getSequenceForRead(
                                     read_id => $read_id,
                                     $this->getVersion());
    }
    elsif (my $readname =  $this->getReadName()) {
# print "using readname $readname\n";
       ($sequence, $quality) = $ADB->getSequenceForRead(
                                     readname => $readname,
                                     $this->getVersion());
    }
  
    $this->setSequence($sequence); # a string
    $this->setQuality($quality);   # reference to an array of integers
#    $this->setQuality([@$quality]); # alternative ? copy array, pass ref
}

#-------------------------------------------------------------------
# delayed loading of comment(s) (private)
#-------------------------------------------------------------------

sub importComment {
    my $this = shift;

    my $ADB = $this->{ADB} || return; # the parent database

    my $comments = $ADB->getCommentForRead(id => $this->getReadID);

    foreach my $comment (@$comments) {
        $this->addComment($comment);
    }
}

#-------------------------------------------------------------------    
# importing & exporting data and meta data
#-------------------------------------------------------------------    

sub addAlignToTrace {
    my $this = shift;
    my $value = shift; # array ref

    return unless defined($value);

    $this->{alignToTrace} = [] unless defined($this->{alignToTrace});

    my @array = @$value; # be sure it's an array ref 

    push @{$this->{alignToTrace}}, [@array];
}

sub getAlignToTrace {
    my $this = shift;
    return $this->{alignToTrace}; # array of arrays
}

#-----------------

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
    my $value = shift || return;

    return unless defined($value);

    $this->{data}->{cvector} = [] unless defined($this->{data}->{cvector});

    my @vector = @$value; # be sure input is array ref

    push @{$this->{data}->{cvector}}, [@vector];
}

sub getCloningVector {
    my $this = shift;
# returns an array of arrays
    return $this->{data}->{cvector};
}

#-----------------

sub addComment {
    my $this = shift;
# add comment as next array element 
    $this->{comment} = [] if !defined($this->{comment});
    push @{$this->{comment}}, shift; 
}

sub getComment {
    my $this = shift;
# returns an array of comments (or undef)
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
    $this->importSequence() unless defined($this->{BaseQuality});
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
    $this->importSequence() unless defined($this->{Sequence});
    return $this->{Sequence};
}


#-----------------

sub setSequenceID {
    my $this = shift;
    $this->{data}->{sequence_id} = shift;
}

sub getSequenceID {
    my $this = shift;
    return $this->{data}->{sequence_id};
}

#-----------------

sub getSequenceLength {
    my $this = shift;
    $this->importSequence() unless defined($this->{Sequence});
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
    my $value = shift || return;

    return unless defined($value);

    $this->{data}->{svector} = [] unless defined($this->{data}->{svector});

    my @vector = @$value; # be sure input is array ref

    push @{$this->{data}->{svector}}, [@vector];
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

#-----------------

sub setVersion {
    my $this = shift;
    $this->{data}->{version} = shift;
}

sub getVersion {
    my $this = shift;
    return $this->{data}->{version} || 0;
}

#----------------------------------------------------------------------
# comparing Read instances
#----------------------------------------------------------------------

sub compareSequence {
# compare sequence in input read against this
    my $this = shift;
    my $read = shift || return undef;

# test respectively, sequence length, DNA and quality; exit on first mismatch

    if (!defined($this->getSequenceLength())) {
# this Read instance has no sequence information
        return undef;
    }
    elsif (!defined($read->getSequenceLength())) {
# ibid
        return undef;
    }
    elsif ($this->getSequenceLength() != $read->getSequenceLength()) {
        return 1; # different lengths
    }

# alternative: test if an edit has been made by comparison of align-to-SCF

    elsif ($this->getSequence() ne $read->getSequence()) {
        return 2; # different DNA strings
    }

    my $thisBQD = $this->getQuality();
    my $readBQD = $read->getQuality();

    for (my $i=0 ; $i<@$thisBQD ; $i++) {
        return 3 if ($thisBQD->[$i] != $readBQD->[$i]);
    }

    return 0; # identical sequences 
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
    print $FILE "Insert_size @{$data->{insertsize}}\n"          if defined $data->{insertsize};
    print $FILE "Ligation_no $data->{ligation}\n"               if defined $data->{ligation};
    print $FILE "Primer ".ucfirst($data->{primer})."\n"         if defined $data->{primer};
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
            if (my $tags = $this->{Tags}) {
                foreach my $tag (@$tags) {
#?                    $tag->writeTagToCaf($FILE);
                }
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
# output in lines of 25 numbers
	my @bq = @{$quality};
	while (my $n = scalar(@bq)) {
            my $m = ($n > 24) ? 24 : $n-1;
	    print $FILE join(' ',@bq[0..$m]),"\n";
	    @bq = @bq[25..($n-1)];
	}
    }
}

##############################################################

sub dump {
    my $this = shift;

    foreach my $key (sort keys %{$this}) {
        my $item = $this->{$key};
        print STDERR "key $key -> $item\n";
        if (ref($item) eq 'HASH') {
            foreach my $key (sort keys %$item) {
                my $itemkey = $item->{$key};
                if (ref($itemkey) eq 'ARRAY' && @$itemkey) {
                    if (ref($itemkey->[0]) eq 'ARRAY') {
                        foreach my $item (@$itemkey) {
                            print STDERR "    $key -> @$item\n";
                        }
                    }
                    else {
                        print STDERR "    $key -> @{$itemkey}\n";
                    }
                }
                else {
                    print STDERR "    $key -> $itemkey\n";
                }
            }
        }
        elsif (ref($item) eq 'ARRAY') {
            if (@$item > 8) {
                print STDERR "    @$item\n";
            }
            elsif (@$item) {
                print STDERR "    ".join("\n    ",@$item)."\n";
            }
        }
    }
}

##############################################################

1;
