package Mapping;

use strict;

#-------------------------------------------------------------------
# Constructor new
#-------------------------------------------------------------------

sub new {
    my $class    = shift;

    my $self = {};

    bless $self, $class;

    $self->{MappingSegments} = [];

    return $self;
}

#-------------------------------------------------------------------
# inventory of instances of this class (methods for quick look-up)
#-------------------------------------------------------------------

my %Mappings;

sub addToInventory {
# add this read to the inventory keyed on either read_id (default) or readname
    my $self = shift;
    my $item = shift || 'read_id';

    return undef unless ($item eq 'read_id' || $item eq 'readname');

    my $key = $self->{data}->{$item} || return undef;

    $Mappings{$key} = $self;
}

sub findReadInInventory {
# return the instance if present in the inventory
    my $self = shift;
    my $item = shift;

    return $Mappings{$item};
}

sub getInventoryKeys {
# return inventory list

    my @keys = sort keys %Mappings;

    return \@keys;
}

#-------------------------------------------------------------------
# parent data base handle
#-------------------------------------------------------------------

sub setArcturusDatabase {
# import the parent Arcturus database handle
    my $self = shift;

    $self->{ADB} = shift;
}

sub getArcturusDatabase {
# export the parent Arcturus database handle
    my $self = shift;

    return $self->{ADB};
}

#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

1;
