package Mapping;

use strict;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
    my $class   = shift;
    my $mapping = shift; # mapping number, optional

    my $this = {};

    bless $this, $class;

    $this->{MappingSegments} = [];
    $this->{assembledFrom} = [];

    $this->{mapping} = $mapping if defined($mapping);

    return $this;
}

#-------------------------------------------------------------------
# import handle to related objects
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

sub setRead {
# import the handle to the Read instance for this mapping
    my $this = shift;
    my $Read = shift;

    if (ref($Read) eq 'Read') {
        $this->{Read} = $Read;
    }
    else {
        die "Invalid object passed: $Read";
    } 
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub getReadID {
    my $this = shift;

    return $this->{data}->{read_id};
}

sub setReadID {
    my $this = shift;

    $this->{data}->{read_id} = shift;
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub addAlignToCaf {
    my $this = shift;
    my $map  = shift;

#print "addAlignToCaf: @$map\n";    
}

sub addAssembledFrom {
    my $this = shift;
    my $map  = shift;

#print "assembledFrom: @$map\n";

    my $assembledFrom = $this->{assembledFrom};

    my @Map = @$map; # copy the array to local


    push @$assembledFrom, \@Map; # add to array of maps (to be improved)

    return scalar @$assembledFrom;  
}

1;



