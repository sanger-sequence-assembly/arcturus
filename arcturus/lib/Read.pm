package Read;

use strict;

#-------------------------------------------------------------------
# Constructor new
#-------------------------------------------------------------------

sub new {

    my $prototype  = shift;
    my $identifier = shift; # optional

    my $class = ref($prototype) || $prototype;

    my $self = {};

    bless $self, $class;

    $self->{identifier} = $identifier;
    $self->{data}       = {}; # metadata hash
    $self->{sequence}   = '';
    $self->{quality}    = '';
    $self->{ADB}        = '';

    return $self;
}

#-------------------------------------------------------------------
# parent data base handle
#-------------------------------------------------------------------

sub setDataBaseHandle {
# import the parent Arcturus database handle
    my $self = shift;

    my $self->{ADB} = shift;
}

#-------------------------------------------------------------------
# lazy instantiation of DNA and quality data
#-------------------------------------------------------------------

sub fetchSequence {
# private method; will bum out when called from outside
    my $lock = shift && die "fetchSequence is a private method";
    my $self = shift;

    my $ADB = $self->{ADB}; # the parent database

    $ADB->fetchSequence($self) if $ADB;
}

#-------------------------------------------------------------------    
# importing data and meta data
#-------------------------------------------------------------------    

sub importData {
# input of meta data into this instance with a hash
    my $self = shift;
    my $hash = shift;

# copy the input hash elements (disconnect outside interference)

    my $copied = 0;
    if (ref($hash) eq 'HASH') {
        my $data = $self->{data};
        foreach my $key (%$hash) {
            $data->{$key} = $hash->{$key};
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

sub setChemistry {

    my $self = shift;

    $self->{data}->{chemistry} = shift;
}

sub setClone {

    my $self = shift;

    $self->{data}->{clone} = shift;
}

sub setCloningVector {

    my $self = shift;

    $self->{data}->{cvector} = shift;
}

sub setComment {

    my $self = shift;

    $self->{data}->{comment} = shift;
}

sub setCVleft {

    my $self = shift;

    $self->{data}->{cvleft} = shift;
}

sub setCVright {

    my $self = shift;

    $self->{data}->{cvright} = shift;
}

sub setDate {

    my $self = shift;

    $self->{data}->{date} = shift;
}

sub setDirection {

    my $self = shift;

    $self->{data}->{direction} = shift;
}

sub setInsertSize {

    my $self = shift;

    $self->{data}->{insertsize} = shift;
}

sub setLigation {

    my $self = shift;

    $self->{data}->{ligation} = shift;
}

sub setLowQualityLeft {

    my $self = shift;

    $self->{data}->{lqleft} = shift;
}

sub setLowQualityRight {

    my $self = shift;

    $self->{data}->{lqright} = shift;
}

sub setPrimer {

    my $self = shift;

    $self->{data}->{primer} = shift;
}

sub setQuality {

    my $self = shift;

    $self->{quality} = shift;
}

sub setReadID {

    my $self = shift;

    $self->{data}->{read_id} = shift;
}

sub setReadName {

    my $self = shift;

    $self->{data}->{readname} = shift;
}

sub setSequenceLength {

    my $self = shift;

    $self->{data}->{slength} = shift;
}

sub setSequence {

    my $self = shift;

    $self->{sequence} = shift;
}

sub setStrand {

    my $self = shift;

    $self->{data}->{strand} = shift;
}

sub setSVsite {

    my $self = shift;

    $self->{data}->{svcsite} = shift;
}

sub setSequencingVector {

    my $self = shift;

    $self->{data}->{svector} = shift;
}

sub setSVleft {

    my $self = shift;

    $self->{data}->{svleft} = shift;
}

sub setSVright {

    my $self = shift;

    $self->{data}->{svright} = shift;
}

sub setTemplate {

    my $self = shift;

    $self->{data}->{template} = shift;
}

#----------------------------------------------------------------------
# exporting data
#----------------------------------------------------------------------

sub getReadItem {

    my $self = shift;
    my $item = shift;

    return $self->{data}->{$item};
}

#----------------------------------------------------------------------

sub getBaseCaller {

    my $self = shift;

    return $self->{data}->{basecaller};
}

sub getChemistry {

    my $self = shift;

    return $self->{data}->{chemistry};
}

sub getClone {

    my $self = shift;

    return $self->{data}->{clone};
}

sub getCloningVector {

    my $self = shift;

    return $self->{data}->{cvector};
}

sub getComment {

    my $self = shift;

    return $self->{data}->{comment};
}

sub getCVleft {

    my $self = shift;

    return $self->{data}->{cvleft};
}

sub getCVright {

    my $self = shift;

    return $self->{data}->{cvright};
}

sub getDate {

    my $self = shift;

    return $self->{data}->{date};
}

sub getDirection {

    my $self = shift;

    return $self->{data}->{direction};
}

sub getInsertSize {

    my $self = shift;

    return $self->{data}->{insertsize};
}

sub getLigation {

    my $self = shift;

    return $self->{data}->{ligation};
}

sub getLowQualityLeft {

    my $self = shift;

    return $self->{data}->{lqleft};
}

sub getLowQualityRight {

    my $self = shift;

    return $self->{data}->{lqright};
}

sub getPrimer {

    my $self = shift;

    return $self->{data}->{primer};
}

sub getQuality {
# return the quality data (possibly) using lazy instatiation
    my $self = shift;

    &fetchSequence(0,$self) unless $self->{quality};

    return $self->{quality};
}


sub getReadID {

    my $self = shift;

    return $self->{data}->{read_id};
}

sub getReadName {

    my $self = shift;

    return $self->{data}->{readname};
}

sub getSequenceLength {

    my $self = shift;

    return $self->{data}->{slength};
}

sub getSequence {
# return the DNA (possibly) using lazy instatiation
    my $self = shift;

    &fetchSequence(0,$self) unless $self->{DNA};

    return $self->{DNA};
}

sub getStrand {

    my $self = shift;

    return $self->{data}->{strand};
}

sub getSVsite {

    my $self = shift;

    return $self->{data}->{svcsite};
}

sub getSequencingVector {
}
    my $self = shift;

    return $self->{data}->{svector};


sub getSVleft {

    my $self = shift;

    return $self->{data}->{svleft};
}

sub getSVright {

    my $self = shift;

    return $self->{data}->{svright};
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
    print $FILE "Is_read\nUnpadded\nSCF_File $data->{readname}SCF\n";
    print $FILE "Template $data->{template}\n";
    print $FILE "Insert_size $data->{insertsize}\n";
    print $FILE "Ligation_no $data->{ligation}\n";
    print $FILE "Primer $data->{primer}\n";
    print $FILE "Strand $data->{strand}\n";
    print $FILE "Dye $data->{chemistry}\n";
    print $FILE "Clone $data->{clone}\n";
    print $FILE "ProcessStatus PASS\nAsped $data->{date}\n";
    print $FILE "Base_caller $data->{basecaller}\n";
# add the alignment info (the padded maps)
#    $self->writeMapToCaf($FILE,1) if shift; # see below
# process read tags ?

    my $sstring = $self->{sequence};
# replace by loop using substr
    $sstring =~ s/(.{60})/$1\n/g;
    print $FILE "\nDNA : $data->{readname}\n$sstring\n";

# the quality data

    my $qstring = $self->{quality};
    if ($blocked) {
# prepare the string for printout as a block: each number on I3 field
        $qstring =~ s/\b(\d)\b/0$1/g;
        $qstring =~ s/^\s+//; # remove leading blanks
        $qstring =~ s/(.{90})/$1\n/g;
    }
    print $FILE "\nBaseQuality : $data->{readname}\n$qstring\n";

#    my $status = $self->{status};
#    return $status->{errors};
}

#######################
# more methods:
#
# export as flat file (experiment file format, requires translation of keys)
#
#
# plus:
# a section dealing with padded mappings (import / export 'writeMapToCaf')
#
#######################
















