package ArcturusDatabase::ADBRoot;

use strict;

use DBI;

use Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(queryFailed); # export to remote sub-classes

# ----------------------------------------------------------------------------
# constructor
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = {};
    bless $this, $class;

    return $this;
}

#------------------------------------------------------------------------------

sub queryFailed {
    my $query = shift;

    $query =~ s/\s+/ /g; # remove redundent white space

    print STDERR "FAILED query: $query\n";

    print STDERR "MySQL error: $DBI::err ($DBI::errstr)\n\n" if ($DBI::err);

    return 0;
}

#------------------------------------------------------------------------------

1;
