package ClonesReader;

# read Ligation data from Oracle database


use strict;
use vars qw($VERSION);

use Tracking;

my $tracking;

###################################################################

sub new {
   my $prototype = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $tracking = Tracking->new();

   bless ($self, $class);
   return $self;
}


####################################################################

sub get {
# retrieve data for a named clone 
    my $self      = shift;
    my $clonename = shift;

    my $cloneinfo = $tracking->get_clone_info($clonename);

    my $count = keys %$cloneinfo;
    print "$count clone items found<br>";

    return $count;
}

####################################################################

1;













