package Consensus;

#########################################################################
#
# Operations on an individual assembly
#
#########################################################################

use strict;

use ArcturusTableRow;

use Compress;

use vars qw(@ISA); # our qw(@ISA);

@ISA = qw(ArcturusTableRow);

#########################################################################
# Class variables
#########################################################################

my %Consensus;

my $Compress;  # handle to Compress module

# my $break = $ENV{REQUEST_METHOD} ? "<br>" : "\n";

#########################################################################
# constructor new: create an Consensus instance
#########################################################################

sub new {
# create a new instance for the named or numbered assembly
    my $prototype = shift;
    my $contig_id = shift;
    my $CONSENSUS = shift; # handle to the CONSENSUS database table 

    return $Consensus{$contig_id} if $Consensus{$contig_id};

    my $class = ref($prototype) || $prototype;

    if ($class eq ref($prototype) && !$CONSENSUS) {
# the new object is spawned from an existing instance of this class
        $CONSENSUS  = $prototype->tableHandle;
    }

# test the database table handle

    die "Missing CONSENSUS table handle" unless $CONSENSUS;

# okay, we seem to have everything to build a new Consensus instance

    my $self = $class->SUPER::new($CONSENSUS);

# load the data

    $self->loadRecord('contig_id',$contig_id);

# signal that the data is compressed (Note: decompress only when data are needed)

    $self->{compress} = 1; 

# placeholder for contig name

    $self->{contigname} = '';

# add instance to the inventory list

    $Consensus{$contig_id} = $self;
    
    return $self;
}

#############################################################################

sub putContigName {

    my $self = shift;
    my $name = shift;

    $self->{contigname} = $name;
}

#############################################################################

sub testContigName {
# test definitio of contigname
    my $self = shift;

    my $name = $self->{contigname} || 0;

    $self->putErrorStatus(1,"Undefined contig name") unless $name;

    return $name;
}

#############################################################################

sub decompress {
# decompress the data if not yet done
    my $self = shift;
    my $fail = shift; # optional, true to signal failure on length mismatch

    my $status = $self->clearErrorStatus;

    return 1 unless $self->{compress};

# create an instance of the Compress module (if it doesn't exist yet)

    $Compress = new Compress() unless $Compress; # needs to be done only once

# decompress sequence

    my $data = $self->data; # the data hash

    my ($scount, $sstring) = $Compress->sequenceDecoder($data->{sequence},99);

    my ($qcount, $qstring) = $Compress->qualityDecoder ($data->{quality} ,99);

    my $length = $data->{length} || 0;

# compare the size of the sequence and quality data; should all be identical

    if ($scount != $length || $qcount != $length || $length == 0) {

        my $text = "Consensus sequence $data->{contig_id} length mismatch : ";
        $text   .= "DNA=$scount Quality=$qcount length=$length";

        if (!$scount || !$qcount || $fail) {
# forces exit with status 0
            $self->putErrorStatus(1,$text);
            return 0;
        }

        $self->putErrorStatus(0,$text); # warning only
    }

# replace the compressed data by de decompressed data

    $data->{sequence} = $sstring;

    $data->{quality}  = $qstring;

    $self->{compress} = 0;

    return 1;
}

#############################################################################

sub writeToCaf {
# write the DNA and Quality data to a file handle in caf format
    my $self = shift;
    my $FILE = shift; # file handle

# decompress the data, if not done earlier

    return 0 unless $self->decompress; # abort if decompress fails

    my $name = $self->{contigName};

    return 0 if $self->status; # abort if some other error status exists

# all seems to be fine

    my $data = $self->data;

    my $sequence = $data->{sequence};

    $sequence =~ s/(.{60})/$1\n/g; # split in lines of 60

    print $FILE "DNA : $name\n$sequence\n";    

    print $FILE "BaseQuality : $name\n$data->{quality}\n";

    return 1;
}

#############################################################################
#############################################################################

sub DESTROY {
# remove object from inventory list to remove reference to it
    my $self = shift;

    my $cid = $self->get('contig_id');

    delete $Consensus{$cid};
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.1 ,
        updated =>    "19 Feb 2004",
        date    =>    "19 Feb 2004",
    };
}

#############################################################################

1;


