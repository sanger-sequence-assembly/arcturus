package ReadFactory;

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

sub new {

    my $class = shift;

    my $this = {};

    bless $this, $class;

    return $this;
}

#----------------------------------------------------------------
# handling (error) logging
#----------------------------------------------------------------

sub setLogging {
# takes an instance of the Logging class
    my $this = shift;
    my $Logging = shift;

    if (ref($Logging) ne 'Logging') {
        print STDERR "setLogging expects an instance of the Logging class\n";
        return undef;
    }

    $this->{Logging} = $Logging;

    return 1;
}

sub logerror {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->severe($text);
}

sub logwarning {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->warning($text);
}

sub loginfo {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->info($text);
}

# Sub-classes MUST override this method

sub getReadNamesToLoad {
    die "Sub-class did not override getReadNamesToLoad";
}

# Sub-classes MUST override this method

sub getReadByName {
    die "Sub-class did not overrdide getReadByName";
}

1;
