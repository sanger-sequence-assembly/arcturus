package Serpens;

# Happy Map interface to Arcturus database

use strict;

use Bootean;

use vars qw($VERSION @ISA); #our ($VERSION, @ISA);

@ISA = qw(Bootean);

#############################################################################
#
# 'Men in Black': The Alien Encyclopedia
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
    $options->{writeAccess} = 'HAPPYTAGS' if $options->{writeAccess};

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = $class->SUPER::new($database,$options) || return 0;

print "SERPENS: $self \n" if $DEBUG;

    $self->{TAGS} = $self->{mother}->spawn('HAPPYTAGS',$database,0,0);

    $self->dropDead("Table HAPPYTAGS not accessible") if !$self->{MAP};

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
# query on HAPPYTAGS table (read only)
    my $self  = shift;
    my $what  = shift;
    my $where = shift;

    my $query = "select $what from <self> ";
    $query .= "where $where" if $where;

    my $output = $self->{TAGS}->query($query,{returnScalar => 0});

    $output; 
}

#############################################################################

sub put {
# enter 
    my $self = shift;
    my $data = shift; # hash with ?? data

    my $success = 0;
    if (ref($data) ne 'HASH') {
        $self->{error} = "invalid input for Draco->put: missing data hash";
    }
    elsif ($self->allowTableAccess('HAPPYTAGS')) {
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
            $success = $self->{MAP}->newrow(\@items,\@value);
        }
        else {
            $self->{error} = "incomplete ?? descriptors for Draco->put";
        }
    }

print $self->error  if !$success;
    return $success;
}

#############################################################################

sub update {
# update any field(s) for a particular happy tag
    my $self = shift;
    my $data = shift;

    if ($self->allowTableAccess('HAPPYTAGS')) {
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
# get all data for a given tag
    my $self = shift;
    my $name = shift; # the tag name

    my $hash = $self->{TAGS}->associate('hashref',$name,'tagname');

    return $hash;
}

#############################################################################
# 
#############################################################################

sub tagGetContig {
# get the contig id and name on which a give tag resides
    my $self = shift;
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
        updated =>    "04 Sep 2003",
    };
}

#############################################################################

1;
