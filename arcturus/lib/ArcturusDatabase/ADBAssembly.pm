package ArcturusDatabase::ADBAssembly;

use strict;

use ArcturusDatabase::ADBProject;

our @ISA = qw(ArcturusDatabase::ADBProject);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#------------------------------------------------------------------------------
# methods dealing with Projects
#------------------------------------------------------------------------------

sub aborttest {

    &queryFailed("TEST ABORT on ArcturusDatabase");
    exit;

}

#------------------------------------------------------------------------------

1;
