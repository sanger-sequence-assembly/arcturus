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
my $tmpdir;
my $keepfiles = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $tmpdir = shift @ARGV if ($nextword eq '-tmpdir');

    $keepfiles = 1 if ($nextword eq '-keepfiles');
}

unless (defined($instance) && defined($organism) && defined($contigids)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

$tmpdir ="/tmp/contigs2gap.$$" unless defined($tmpdir);

if (! -d $tmpdir) {
    die "Unable to create directory $tmpdir" unless mkdir($tmpdir);
}

chdir($tmpdir);

print STDERR "Using $tmpdir as temporary directory\n";

&execute("export-assembly.pl -instance $instance -organism $organism -contigs $contigids -caf input_depad.caf", "input_depad.caf");

&execute("caf_pad < input_depad.caf > input_pad.caf", "input_pad.caf");

&execute("caf2gap -ace input_pad.caf -project $organism", "$organism.0.aux");

&execute("gap4 $organism.0");

&execute("gap2caf -project $organism -ace output_pad.caf", "output_pad.caf");

&execute("caf_depad < output_pad.caf > output_depad.caf", "output_depad.caf");

&execute("contig-loader.pl -instance $instance -organism $organism -caf output_depad.caf");

&execute("calculateconsensus -instance cn=$instance,cn=jdbc -organism cn=$organism");

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-contigs\tComma-separated list of contig IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-tmpdir\t\tName of directory for temporary files\n";
    print STDERR "-keepfiles\tKeep all temporary files\n";
}
