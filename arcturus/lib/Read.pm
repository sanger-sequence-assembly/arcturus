package Read;

use strict;

use Mapping;

use Asp::PhredClip;

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

    $this->{padstatus} = 'Unpadded'; # default padstatus

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
    my $tag  = shift;

    die "Read->addTag expects a Tag instance as parameter" if (ref($tag) ne 'Tag');

    $this->{Tags} = [] unless defined $this->{Tags};

    $tag->setSequenceID($this->getSequenceID()); # transfer seq_id, if any

    push @{$this->{Tags}}, $tag;
}

sub getTags {
# export reference to the Tags array
    my $this = shift;
    return $this->{Tags};
}

sub hasTags {
# returns true if this Read has tags
    my $this = shift;
    return $this->getTags() ? 1 : 0;
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

sub getAlignToTraceMapping {
# export the trace-to-read mappings as a Mapping object
    my $this = shift;

    my $alignToTrace = $this->getAlignToTrace();

    my $mapping = new Mapping();

    if ($alignToTrace && @$alignToTrace) {
        foreach my $segment (@$alignToTrace) {
            $mapping->putSegment(@$segment);
	}
    }
    else {
        my $length = $this->getSequenceLength();
        $mapping->putSegment(1,$length,1,$length) if $length;
    }

    return $mapping;
}

sub isEdited {
    my $this = shift;
# return true if the number of alignments > 1, else false
    my $align = $this->getAlignToTrace();
    return ($align && scalar(@$align) > 1) ? 1 : 0;
}

#--------------------------------------------------
# alternative align-to-trace representation with mapping segments
#--------------------------------------------------

sub newaddAlignToTrace {
    my $this = shift;
    my $value = shift; # array reference

    return unless defined($value);

    unless (defined($this->{alignToTrace})) {
        $this->{alignToTrace} = new Mapping('align-to-trace');
    }

    my $mapping = $this->{alignToTrace};

    $mapping->addSegment(@$value);

    return $mapping;
}

sub newgetAlignToTrace {
# export the trace-to-read mappings as a Mapping object
    my $this = shift;

    my $mapping = $this->{alignToTrace};

    return $mapping if defined($mapping);
    
    my $length = $this->getSequenceLength();

    return undef unless $length;

    return $this->newaddAlignToTrace([(1,$length,1,$length)]);
}

sub newisEdited {
    my $this = shift;
# return true if the number of alignments > 1, else false
    my $mapping = newgetAlignToTrace();
    return ($mapping->hasSegments() > 1) ? 1 : 0;
}

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
    my %options = @_;

    $this->importSequence() unless defined($this->{Sequence});

    my $symbol = $options{qualitymask};

    return $this->{Sequence} unless $symbol;

# quality masking

    my $ql = $this->getLowQualityLeft();
    my $qr = $this->getLowQualityRight();
# what about masking sequencing and cloning vector?

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
# add the sequence ID to any tags
    if (my $tags = $this->getTags()) {
        foreach my $tag (@$tags) {
            $tag->setSequenceID($this->getSequenceID());
        }
    }
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

#print "Read.pm: Add sequencing vector @vector \n" if $this->isEdited; # test on input from CAF

    push @{$this->{data}->{svector}}, [@vector];
}

sub getSequencingVector {
    my $this = shift;

if (defined($this->{data}->{svector}->[0])) {
unless ($this->{data}->{svector}->[0]->[0]) {
print STDERR "Read.pm: Get sequencing vector : 'unknown' for read ".
              $this->getReadName."\n"; 
$this->{data}->{svector}->[0]->[0] = "unknown";
}}
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
# simple display format
#----------------------------------------------------------------------

sub toString {
    my $this = shift;
    return "Read(ID=" . $this->{data}->{read_id} .
	", name=" . $this->{readname} . ")";
}

#----------------------------------------------------------------------
# comparing Read instances
#----------------------------------------------------------------------

sub compareSequence {
# compare sequence in input read against this
    my $this = shift;
    my $read = shift || return undef;

# test respectively, sequence length, DNA and quality; exit on first mismatch

my $DEBUG = 0;
    if (!defined($this->getSequenceLength())) {
# this Read instance has no sequence information
        return undef;
    }
    elsif (!defined($read->getSequenceLength())) {
# read instance has no sequence information
        return undef;
    }
    elsif ($this->getSequenceLength() != $read->getSequenceLength()) {
# different lengths
        return 0;
    }

# test the DNA sequences; special provision for sequence with pads 

    my $thisDNA = $this->getSequence();
    my $readDNA = $read->getSequence();

    if ($thisDNA ne $readDNA) {
# try if it's a matter of case for 'N's appearing in the sequence
        if ($thisDNA =~ s/n/N/g || $readDNA =~ s/n/N/g) {
            return 1 if ($thisDNA eq $readDNA);
	}
# different DNA strings; we do extra test for sequences with pads
        return 0 unless ($thisDNA =~ /-/);
# compare individual alignment segments (separated by '-')
$DEBUG = 0;
print "testing ".$read->getReadName." version ".$read->getVersion.
" against ".$this->getReadName."\n" if $DEBUG;
        my @pad;
        my $pos = -1;
        my $thisBQD = $this->getBaseQuality();
        my $readBQD = $read->getBaseQuality();
        while (($pos = index($thisDNA,'-',$pos)) > -1) {
# alter 'this' quality data at the pad position to match the 'read' data
            $thisBQD->[$pos] = $readBQD->[$pos];
            push @pad, $pos++;
        }
        push @pad,length($thisDNA);

        my $start = 1;
        for (my $i = 0; $i < scalar(@pad); $i++) {
            my $length = $pad[$i] - $start;
print "i=$i  pad[i] $pad[$i]  start $start  length $length\n" if $DEBUG;
            if ($length > 0) {
                my $subthis = substr $thisDNA,$start,$length;
                my $subread = substr $readDNA,$start,$length;
# if the substrings differ we have different DNA strings
                return 0 unless ($subthis eq $subread);
            }
            $start = $pad[$i] + 1;
	}
    }

    my $thisBQD = $this->getBaseQuality();
    my $readBQD = $read->getBaseQuality();

    for (my $i=0 ; $i<@$thisBQD ; $i++) {
        return 0 if ($thisBQD->[$i] != $readBQD->[$i]);
    }

    return 1; # identical sequences 
}

#----------------------------------------------------------------------
# dumping data
#----------------------------------------------------------------------

sub writeToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $this = shift;
    my $FILE = shift; # obligatory output file handle
    my %option = @_;

# optionally takes 'qualitymask=>'N' to mask low quality data (transfer to writeDNA)

    die "Read->writeToCaf expect a FileHandle as parameter" unless $FILE;

    my $data = $this->{data};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "\n";
    print $FILE "Sequence : $this->{readname}\n";
    print $FILE "Is_read\n";
    print $FILE "$this->{padstatus}\n"; # Unpadded or Padded
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

# alternative using Mapping
#   my $alignToTtace = $this->getAlignToTraceMapping();
#   print $FILE $alignToTrace->writeToString("Align_to_SCF");

# sequencing vector

    if (my $seqvec = $this->getSequencingVector()) {
        foreach my $vector (@$seqvec) {
            my $name = $vector->[0] || "unknown";
            print $FILE "Seq_vec SVEC $vector->[1] $vector->[2] \"$name\"\n";
        }
    }

# cloning vector

    if (my $clonevec = $this->getCloningVector()) {
        foreach my $vector (@$clonevec) {
            my $name = $vector->[0] || "unknown";
            print $FILE "Clone_vec CVEC $vector->[1] $vector->[2] \"$name\"\n";
        }
    }

# tags

    if (my $tags = $this->getTags()) {
        foreach my $tag (@$tags) {
            $tag->writeToCaf($FILE);
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    $this->writeDNA($FILE,"DNA : ",@_); # specifying the CAF marker

    $this->writeBaseQuality($FILE,"BaseQuality : ");
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data
    my %option = @_;

# optionally takes 'qualitymask=>'N' to mask out low quality data

    $this->writeDNA($DFILE,">",@_);

    $this->writeBaseQuality($QFILE,">") if defined $QFILE;
}

# private methods

sub writeDNA {
# write DNA of this read in FASTA format to FILE handle
    my $this   = shift;
    my $FILE   = shift; # obligatory
    my $marker = shift;

# optionally takes 'qualitymask=>'N' to mask out low quality data

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

#----------------------------------------------------------------------
# alternative clipping
#----------------------------------------------------------------------

sub qualityClip {
    my $this = shift;
    my %options = @_;

# options: clipmethod to be used (phredclip, other)
#          threshold level (default 15)
#          minimum range (default 32)

    my $clipmethod =  $options{clipmethod} || 'phredclip';

    my ($QL,$QR);

    if ($clipmethod eq 'phredclip') {

# use standard clipping method from package PhredClip

       ($QL,$QR) = Asp::PhredClip->phred_clip($options{threshold} || 15,
                                              $this->getBaseQuality());
    }
    elsif ($clipmethod eq 'myphredclip') {
# use local test version
       ($QL,$QR) = &phred_clip($options{threshold} || 15,
                               $this->getBaseQuality());
    }
    elsif ($clipmethod eq 'someothermethodtobedeveloped') {
        return 0; # method to be defined 
    }
    else {
        return 0; # invalid method 
    }

# analyse returned range

    my $qualityrange = $QR - $QL + 1;
    my $minimumrange = $options{minimumrange} || 32;
        
    if ($qualityrange >= $minimumrange) {
        $this->setLowQualityLeft($QL);
        $this->setLowQualityRight($QR);
        return $qualityrange;
    }
    else {
        return 0; # failure
    }
}

# this method is taken from Paul Mooney's PhredClip

sub phred_clip {
# private method adapted from Paul Mooney's PhredClip module
    my $threshold = shift;
    my $avquality = shift; # array reference

    my $qualLen  = scalar(@{$avquality});
    my $lastQual = $qualLen - 1;
    my $i;
    my @q;

    for ($i = 0; $i < $qualLen; $i++) {
	$q[$i] = $avquality->[$i] - $threshold;
    }

    my @cleft;
    my @l;

    my $Left = 0;
    $cleft[0] = $q[0] > 0 ? $q[0] : 0;
    $l[0] = $Left;

    for ($i = 1; $i < $qualLen; $i++) {
	$cleft[$i] = $q[$i] + $cleft[$i - 1];

	if ($cleft[$i] <= 0) {
	    $cleft[$i] = 0;
	    $Left = $i;
	}

	$l[$i] = $Left;
    }

    my @cright;
    my @r;

    my $Right = $lastQual;
    $cright[$lastQual] = $q[$lastQual] > 0 ? $q[$lastQual] : 0;
    $r[$lastQual] = $Right;

    for ($i = $lastQual - 1; $i >= 0; $i--) {
	$cright[$i] = $q[$i] + $cright[$i + 1];

	if ($cright[$i] <= 0) {
	    $cright[$i] = 0;
	    $Right = $i;
	}

	$r[$i] = $Right;
    }

    my $best  = 0;
    my $coord = 0;

    for($i = 0; $i < $qualLen; $i++) {
	my $s = $cright[$i] + $cleft[$i];
	if ( $best < $s ) {
	    $best = $s;
	    $coord = $i;
	}
    }
    
    $Right = $r[$coord] + 1;
    $Left  = $l[$coord] + 1; # convert to coords starting at 1

    return ($Left, $Right);
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
