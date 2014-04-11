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
use Compress::Zlib;

require "exectools.pl";

use strict;

my $nextword;
my $instance;
my $organism;
my $contigids;
my $project;
my $version = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigids = shift @ARGV if ($nextword eq '-contigs');
    $project = shift @ARGV if ($nextword eq '-project');
    $version = shift @ARGV if ($nextword eq '-version');
}

unless (defined($instance) && defined($organism)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $tmpfile1 = "/tmp/db2gap.$$.depad.caf";
my $tmpfile2 = "/tmp/db2gap.$$.pad.caf";

my $contigs = defined($contigids) ? "-contigs $contigids" : "";

$project = $organism unless defined($project);

&execute("export-assembly.pl -instance $instance -organism $organism $contigs -caf $tmpfile1", $tmpfile1);

&execute("caf_pad < $tmpfile1 > $tmpfile2", $tmpfile2);

my $auxfile = "$organism.$version.aux";

&execute("caf2gap -ace $tmpfile2 -project $project -version $version", $auxfile);

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contigs\tComma-separated list of contig IDs\n";
    print STDERR "-project\tName of Gap4 project [default: same as organism]\n";
    print STDERR "-version\tVersion for Gap4 project [default: 0]\n";
}
