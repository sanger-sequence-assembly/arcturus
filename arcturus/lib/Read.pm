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

    die "Read->addTag expects a Tag instance as parameter" if (ref($Tag) ne 'Tag');

    $this->{Tags} = [] unless defined $this->{Tags};

    push @{$this->{Tags}}, $Tag;
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
    $this->setBaseQuality($quality);   # reference to an array of integers
#    $this->setBaseQuality([@$quality]); # alternative ? copy array, pass ref
    return 1;
}

sub hasSequence {
# return true if both DNA and BaseQuality are defined
    my $this = shift;
    return ($this->{Sequence} && $this->{BaseQuality});
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
    return $this->{alignToTrace}; # undef or array of arrays
}

sub isEdited {
    my $this = shift;
# return true if the number of alignments > 1, else false
    my $align = $this->getAlignToTrace();
    return ($align && scalar(@$align) > 1) ? 1 : 0;
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

sub setBaseQuality {
# import the reference to an array with base qualities
    my $this = shift;

    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$this->{BaseQuality} = $quality;
    }
}

sub getBaseQuality {
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

    my $symbol;
# test for extra input; only accept qualityMask=>'symbol'
    while (my $nextword = shift) {
        if ($nextword eq 'qualitymask') {
            $symbol = shift;
        }
    }

    return $this->{Sequence} unless $symbol;

# quality masking 

    my $ql = $this->getLowQualityLeft();
    my $qr = $this->getLowQualityRight();

    return $this->{Sequence} unless (defined($ql) && defined($qr));

    return &maskDNA($this->{Sequence},$ql,$qr,substr($symbol,0,1));
}

sub maskDNA {
# private function: mask DNA with some symbol outside the quality range
    my $dna = shift; # input DNA sequence
    my $ql  = shift; # low quality left
    my $qr  = shift; # low quality right
    my $sym = shift; # replacement symbol

    my ($part1, $part2, $part3);

    $part1 = substr($dna,0,$ql);
    $part2 = substr($dna,$ql,$qr-$ql-1);
    $part3 = substr($dna,$qr-1);

    $part1 =~ s/./$sym/g;
    $part3 =~ s/./$sym/g;

    return $part1.$part2.$part3;
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
        return 0; # different lengths
    }

# alternative: test if an edit has been made by comparison of align-to-SCF

    elsif ($this->getSequence() ne $read->getSequence()) {
        return 0; # different DNA strings
    }

    my $thisBQD = $this->getBaseQuality();
    my $readBQD = $read->getBaseQuality();

    for (my $i=0 ; $i<@$thisBQD ; $i++) {
        return 0 if ($thisBQD->[$i] != $readBQD->[$i]);
    }
#print "Identical sequences\n";

    return 1; # identical sequences 
}

#----------------------------------------------------------------------
# dumping data
#----------------------------------------------------------------------

sub writeToCafForAssembly {
# write this read in caf format (unpadded)
# include align-to-trace file information and possible tags
    &writeToCaf(shift,shift,1);
}

sub writeToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $this = shift;
    my $FILE = shift;        # obligatory output file handle

    die "Read->writeToCaf expect a FileHandle as parameter" unless $FILE;

    my $data = $this->{data};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "\nSequence : $this->{readname}\n";
    print $FILE "Is_read\n";
    print $FILE "Unpadded\n";
    print $FILE "SCF_File $this->{readname}SCF\n";
    print $FILE "Template $data->{template}\n"          if defined $data->{template};
    print $FILE "Insert_size @{$data->{insertsize}}\n"  if defined $data->{insertsize};
    print $FILE "Ligation_no $data->{ligation}\n"       if defined $data->{ligation};
    print $FILE "Primer ".ucfirst($data->{primer})."\n" if defined $data->{primer};
    print $FILE "Strand $data->{strand}\n"              if defined $data->{strand};
    print $FILE "Dye $data->{chemistry}\n"              if defined $data->{chemistry};
    print $FILE "Clone $data->{clone}\n"                if defined $data->{clone};
    print $FILE "ProcessStatus PASS\n";
    print $FILE "Asped $data->{asped}\n"                if defined $data->{asped} ;
    print $FILE "Base_caller $data->{basecaller}\n"     if defined $data->{basecaller};

# quality clipping

    if (defined($data->{lqleft}) && defined($data->{lqright})) {
        print $FILE "Clipping QUAL $data->{lqleft} $data->{lqright}\n";
    }

# align to trace

    if (my $alignToTrace = $this->getAlignToTrace()) {
        foreach my $alignment (@$alignToTrace) {
            print $FILE "Align_to_SCF @$alignment\n";
        }
    }
    else {
        my $length = $this->getSequenceLength();
        print $FILE "Align_to_SCF 1 $length  1 $length\n";  
    }

# sequencing vector

    if (my $seqvec = $this->getSequencingVector()) {
        foreach my $vector (@$seqvec) {
            my $name = $vector->[0];
            print $FILE "Seq_vec SVEC $vector->[1] $vector->[2] \"$name\"";
        }
    }

# cloning vector

    if (my $clonevec = $this->getCloningVector()) {
        foreach my $vector (@$clonevec) {
            my $name = $vector->[0];
            print $FILE "Clone_vec CVEC $vector->[1] $vector->[2] \"$name\"";
        }
    }

# tags

    if (my $tags = $this->getTags()) {
        foreach my $tag (@$tags) {
#?          $tag->writeTagToCaf($FILE);
        }
    }

    # The CAF format requires a blank line between sections
    print $FILE "\n";

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"DNA : ",@_); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"BaseQuality : ");
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

    $this->writeDNA($DFILE,">",@_);

    $this->writeBaseQuality($QFILE,">") if defined $QFILE;
}

# private methods

sub writeDNA {
# write DNA of this read in FASTA format to FILE handle
    my $this   = shift;
    my $FILE   = shift; # obligatory
    my $marker = shift;

    $marker = ">" unless defined($marker); # default FASTA format

    if (my $dna = $this->getSequence(@_)) {
# output in blocks of 60 characters
	print $FILE "\n$marker$this->{readname}\n";
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

    if (my $quality = $this->getBaseQuality()) {
# output in lines of 25 numbers
	print $FILE "\n$marker$this->{readname}\n";
	my $n = scalar(@$quality) - 1;
        for (my $i = 0; $i <= $n; $i += 25) {
            my $m = $i + 24;
            $m = $n if ($m > $n);
	    print $FILE join(' ',@$quality[$i..$m]),"\n";
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
