package RepositoryManager;

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

use Carp;

use OORepository;

sub new {
    my $class = shift;

    my $this = {};

    bless $this, $class;

    $this->{'OORepository'} = new OORepository();

    return $this;
}

sub getOnlinePath {
    my $this = shift;

    my $alias = shift;

    $this->{'OORepository'}->get_online_path_from_project($alias);

    return $this->{'OORepository'}->{online_path};
}

sub convertMetaDirectoryToAbsolutePath {
    my $this = shift;

    my $metadir = shift;

    my %opts = @_;

    if ($metadir =~ /^:([\w\-]+):/) {
	my $name = $1;

	my $alias = $opts{$name} || $opts{lc($name)} || $name;

	my $location = $this->getOnlinePath($alias);

	croak "Could not find location for $alias" unless defined($location);

	$metadir =~ s/^:$name:/$location/;
    }

    return $metadir;
}

sub convertAbsolutePathToMetaDirectory {
    my $this = shift;

    my $abspath = shift;

    my %opts = @_;

    my $assembly = $opts{'assembly'} || $opts{'ASSEMBLY'};

    if (defined($assembly)) {
	my $location = $this->getOnlinePath($assembly);

	if (defined($location) && $abspath =~ /^$location/) {
	    $abspath =~ s/^$location/:ASSEMBLY:/;
	    return $abspath;
	}
    }

    my $project = $opts{'project'} || $opts{'PROJECT'};

    if (defined($project)) {
	my $location = $this->getOnlinePath($project);

	if (defined($location) && $abspath =~ /^$location/) {
	    $abspath =~ s/^$location/:PROJECT:/;
	    return $abspath;
	}
    }

    return $abspath;
}

1;
