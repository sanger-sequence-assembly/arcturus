package Draco;

# GeneDB interface to Arcturus database

use strict;

use Bootean;

use vars qw($VERSION @ISA); #our ($VERSION, @ISA);

@ISA = qw(Bootean);

#############################################################################
# ALPHA DRACONIANS
#
# Reptilian beings who are said to have established colonies in Alpha Draconis. 
# Like all reptilians, these claim to have originated on Terra thousands of 
# years ago, a fact that they use to 'justify' their attempt to re-take the 
# Earth for their own. They are apparently a major part of a planned 'invasion'
# which is eventually turning from covert infiltration mode to overt invasion 
# mode as the "window of opportunity" (the time span before International human 
# society becomes an interplanetary and interstellar power) slowly begins to 
# close. They are attempting to keep the "window" open by suppressing advanced 
# technology from the masses, which would lead to eventual Terran colonization 
# of other planets by Earth and an eventual solution to the population, pollution,
# food and other environmental problems. Being that Terrans have an inbred 
# "warrior" instinct the Draconians DO NOT want them/us to attain interstellar 
# capabilities and therefore become a threat to their imperialistic agendas.
#
# 'Men in Black' Collectables Presents: The Alien Encyclopedia
#############################################################################
my $DEBUG = 1;
#############################################################################

sub new {
# constructor invoking the constructor of the Bootean class
    my $caller   = shift;
    my $database = shift;
    my $options  = shift;

# import options specified in $options hash

    undef my %options;
    $options = \%options if (!$options || ref($options) ne 'HASH');
    $options->{writeAccess} = 'GENE2CONTIG' if $options->{writeAccess};

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = $class->SUPER::new($database,$options) || return 0;

print "Draco: $self \n" if $DEBUG;

    $self->{G2C} = $self->{mother}->spawn('GENE2CONTIG',$database,0,0);

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 new (constructor)

=head2 Synopsis

=head2 Parameters:

=cut

#############################################################################
# GeneDB Interface; functions require access privilege to GENE2CONTIGS table
#############################################################################

sub query {
# query on GENES2CONTIG table (read only)
    my $self  = shift;
    my $what  = shift;
    my $where = shift;

    $self->dropDead("Table GENE2CONTIG not accessible") if !$self->{G2C};

    my $query = "select $what from <self> ";
    $query .= "where $where" if $where;

    my $output = $self->{G2C}->query($query,{returnArray => 1});

    $output; 
}

#############################################################################


sub put {
# enter a GeneDB tag into the GENE2CONTIGS table
    my $self = shift;
    my $data = shift; # hash with gene data

    my $G2C = $self->{G2C} || $self->dropDead("Table GENE2CONTIG not accessible");

    my $success = 0;
    if (ref($data) ne 'HASH') {
        $self->{error} = "invalid input for Draco->put: missing data hash";
    }
    elsif ($self->allowTableAccess('GENE2CONTIG')) {
# enter as arrays and test presence of all items
	undef my @items;
        undef my @value;
        my $parity = 0;
        foreach my $item (keys %$data) {
            push @items, $item;
            push @value, $data->{$item};
            $parity++ if ($item =~ /\btagname|contig_id|tcp_start|tcp_final|orientation\b/);   
        }
        if ($parity == 5) {
            $success = $G2C->newrow(\@items,\@value);
        }
        else {
            $self->{error} = "incomplete gene descriptors for Draco->put";
        }
    }

print $self->error  if !$success;
    return $success;
}

#############################################################################

sub update {
# update any field(s) for a particular GeneDB tag
    my $self = shift;
    my $data = shift;

    my $G2C = $self->{G2C} || $self->dropDead("Table GENE2CONTIG not accessible");

    if ($self->allowTableAccess('GENE2CONTIG')) {
# to be developed

    }
    else {
        print "$self->errors\n";
        return 0;
    }
}

#############################################################################

#############################################################################

sub get {
# get all data for a given GeneDB tag
    my $self = shift;
    my $name = shift; # the tag name

    my $G2C = $self->{G2C} || $self->dropDead("Table GENE2CONTIG not accessible");

    my $hash = $G2C->associate('hashref',$name,'tagname');

    return $hash;
}

#############################################################################
# 
#############################################################################

sub geneGetContig {
# get the contig id and name on which a given GeneDB tag resides
    my $self = shift;

    my $G2C = $self->{G2C} || $self->dropDead("Table GENE2CONTIG not accessible");
}

#--------------------------- documentation --------------------------
=pod

=head1 method g

=head2 Synopsis

=head2 Parameters

=over 4

=item name

=item value

=cut
#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.9 ,
        date    =>    "17 Jan 2003",
        updated =>    "17 Jan 2003",
    };
}

#############################################################################

1;
