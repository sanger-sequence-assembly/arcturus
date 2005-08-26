package ArcturusDatabase::ADBRoot;

use strict;

use DBI;

use Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(queryFailed userRoles); # export to remote sub-classes

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

    my $length = length(@_);

    while ($length-- > 0) {
        my $datum = shift || 'null';
        $datum = "'$datum'" if ($datum =~ /\D/);
        $query =~ s/\?/$datum/;
    }

# and break up into seperate lines to make long queries more readable 

    $query =~ s/(\s*(where|from|and|order|group|union))/\n$1\t/gi;

    print STDERR "FAILED query:\n$query\n";

    print STDERR "MySQL error: $DBI::err ($DBI::errstr)\n\n" if ($DBI::err);

    return 0;
}

#------------------------------------------------------------------------------

my $USERROLEHASH; # class variable

sub userRoles {
# experimental routine for user roles
    my $boss = shift;
    my $user = shift;

# idea: load on first call a table with user roles
# use that list to decide whether $boss is $user's boss

    unless (defined($USERROLEHASH)) {
# load stuff
    }

# THIS IS AD HOC for exploratory purposes

    return 1 if ($boss eq $user || $boss eq 'ejz' || $boss eq 'adh');

    return 0;
}

#------------------------------------------------------------------------------

1;


