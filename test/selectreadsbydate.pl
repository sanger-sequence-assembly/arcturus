#!/usr/local/bin/perl

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


use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance = 'dev';
my $organism;
my $aspedbefore;
my $aspedafter;
my $qualitymask;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $aspedbefore = shift @ARGV if ($nextword eq '-aspedbefore');
    $aspedafter = shift @ARGV if ($nextword eq '-aspedafter');
    $qualitymask = 1 if ($nextword eq '-qualitymask');
}

die "No organism specified" unless defined($organism);
die "No cutoff date specified" unless (defined($aspedbefore) ||
				       defined($aspedafter));

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $reads;

my @params;


push @params, '-aspedbefore', $aspedbefore if defined($aspedbefore);
push @params, '-aspedafter', $aspedafter if defined($aspedafter);

$reads = $adb->getReadsByAspedDate(@params);

if (defined($reads)) {
    print STDERR "There are ",scalar(@{$reads})," reads\n";
}

my $stdout = new FileHandle('>&STDOUT');

my @params = ();

push @params, "qualitymask", "X" if $qualitymask;

foreach my $read (@{$reads}) {
    $read->writeToCaf($stdout, @params);
}

exit(0);
