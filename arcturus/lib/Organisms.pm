package Organisms;

#########################################################################
#
# Operations on an individual project
#
#########################################################################

use strict;

use ArcturusTableRow;

use vars qw(@ISA); # our qw(@ISA);

@ISA = qw(ArcturusTableRow);

#########################################################################
# Class variables
#########################################################################

my %Organisms;

#########################################################################
# constructor new: create an Organisms instance
#########################################################################

sub new {
# all parameters obligatory
    my $prototype = shift;
    my $database  = shift; # (obligatory) arcturus database name
    my $ORGANISMS = shift; # (optional) handle to ORGANISMS table
 

    die "Missing database" unless $database;


# look in the inventory if the instance for this database already exists


    return $Organisms{$database} if $Organisms{$database};


# create an instance of the ArcturusTableRow super class 

    my $class = ref($prototype) || $prototype;

    if ($class eq ref($prototype) && !$ORGANISMS) {
# the new object is spawned from an existing instance of this class
        $ORGANISMS = $prototype->tableHandle;
    }

# here the ORGANISMS table must be defined

    die "Missing ORGANISMS table handle" unless $ORGANISMS;

    my $self = $class->SUPER::new($ORGANISMS,'arcturus');


# now fill the instance with data and add to inventory


    if ($self->loadRecord('dbasename',$database)) {

        my $contents = $self->{contents};
        $Organisms{$database} = $self;

    }

# test the existence of the organism; die if it doesn't

    if (my $status = $self->status(1)) {
        die "Failed to locate database $database: $status";
    }

    return $self;
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.9 ,
        updated =>    "16 Feb 2004",
        date    =>    "10 Feb 2004",
    };
}

#############################################################################

1;
