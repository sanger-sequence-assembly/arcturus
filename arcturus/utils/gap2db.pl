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
my $project;
my $version = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $project = shift @ARGV if ($nextword eq '-project');
    $version = shift @ARGV if ($nextword eq '-version');
}

unless (defined($instance) && defined($organism)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $tmpfile1 = "/tmp/gap2db.$$.pad.caf";
my $tmpfile2 = "/tmp/gap2db.$$.depad.caf";

$project = $organism unless defined($project);

&execute("gap2caf -project $project -ace $tmpfile1", $tmpfile1);

&execute("caf_depad < $tmpfile1 > $tmpfile2", $tmpfile2);

&execute("contig-loader.pl -instance $instance -organism $organism -caf $tmpfile2");

&execute("calculateconsensus -instance cn=$instance,cn=jdbc -organism cn=$organism");

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-project\tName of Gap4 project [default: same as organism]\n";
    print STDERR "-version\tVersion for Gap4 project [default: 0]\n";
}
