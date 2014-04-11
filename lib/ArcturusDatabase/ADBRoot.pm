package ArcturusDatabase::ADBRoot;

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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



