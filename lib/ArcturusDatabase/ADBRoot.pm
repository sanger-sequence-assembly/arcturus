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

# substitute placeholders '?' by values

    my $length = scalar(@_);

    while ($length-- > 0) {
        my $datum = shift || 'null';
        $datum = "'$datum'" if ($datum =~ /\D/);
        $query =~ s/\?/$datum/;
    }

# and break up into seperate lines to make long queries more readable 

    $query =~ s/(\s+(where|from|and|order|group|union))/\n$1/gi;

    print STDERR "FAILED query:\n$query\n\n";

    print STDERR "MySQL error: $DBI::err ($DBI::errstr)\n\n" if ($DBI::err);

    return 0;
}

#------------------------------------------------------------------------------

1;



