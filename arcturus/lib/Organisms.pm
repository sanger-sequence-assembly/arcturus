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
    my $ORGANISMS = shift; # handle to ORGANISMS table
    my $database  = shift; # arcturus database name
 
print "Organisms.pm new for database  $database<br>\n";
    die "Missing ORGANISMS table handle" unless $ORGANISMS;
    die "Missing database"               unless $database;

    return $Organisms{$database} if $Organisms{$database};

    my $class = ref($prototype) || $prototype;

    my $self = $class->SUPER::new($ORGANISMS,'arcturus');

# now fill the instance with data

    if ($self->loadRecord('dbasename',$database)) {
# add this project to inventory
        my $contents = $self->{contents};
        $Organisms{$contents->{dbasename}} = $self;
     }

    return $self; # possible error status to be tested
}


#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.9 ,
        updated =>    "13 Feb 2004",
        date    =>    "10 Feb 2004",
    };
}

#############################################################################

1;
