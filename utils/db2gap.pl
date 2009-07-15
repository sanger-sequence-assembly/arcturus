#!/usr/local/bin/perl

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
