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

    my $self->{ADB} = shift;
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

    my ($S, $Q) = $ADB->getSequenceAndBaseQualityForRead (id=>$self->getReadID);

    $self->{Sequence}    = $S; # a string
    $self->{BaseQuality} = $Q; # reference to an array of integers
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
    $self->{BaseQuality} = shift;
}

sub getQuality {
# return the quality data (possibly) using lazy instatiation
    my $self = shift;
    $self->importSequence(@_) unless $self->{BaseQuality};
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
    $self->{Sequence} = shift;
}

sub getSequence {
# return the DNA (possibly) using lazy instatiation
    my $self = shift;
    $self->importSequence(@_) unless $self->{Sequence};
    return $self->{Sequence};
}

#-----------------

sub setSequenceLength {
    my $self = shift;
    $self->{data}->{slength} = shift;
}

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

sub writeReadToCaf {
# write this read in caf format (unpadded) to FILE handle
    my $self    = shift;
    my $FILE    = shift; # obligatory
    my $blocked = shift; # optional 

    my $data = $self->{data};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "\n\n";
    print $FILE "Sequence : $data->{readname}\n";
    print $FILE "Is_read\n";
    print $FILE "Unpadded\n";
    print $FILE "SCF_File $data->{readname}SCF\n";
    print $FILE "Template $data->{template}\n";
    print $FILE "Insert_size $data->{insertsize}\n";
    print $FILE "Ligation_no $data->{ligation}\n";
    print $FILE "Primer $data->{primer}\n";
    print $FILE "Strand $data->{strand}\n";
    print $FILE "Dye $data->{chemistry}\n";
    print $FILE "Clone $data->{clone}\n";
    print $FILE "ProcessStatus PASS\n";
    print $FILE "Asped $data->{date}\n";
    print $FILE "Base_caller $data->{basecaller}\n";
# add the alignment info (the padded maps)
#    $self->writeMapToCaf($FILE,1) if shift; # see below
# process read tags ?

    print $FILE "\nDNA : $data->{readname}\n";

    my $dna = $self->{Sequence};

    my $offset = 0;
    my $length = length($dna);
# replace by loop using substr
    while ($offset < $length) {    
        print $FILE substr($dna,$offset,60)."\n";
        $offset += 60;
    }

# the quality data

    print $FILE "\nBaseQuality : $data->{readname}\n";

    my $quality = $self->{BaseQuality} || [];

    my $line;
    my $next = 0;
    while (my $qvalue = shift @$quality) {
        $line .= sprintf "%3d", $qvalue;
        if ($blocked && (++$next%60)==0) {
            print $FILE $line."\n";
            $line = '';
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

1;
