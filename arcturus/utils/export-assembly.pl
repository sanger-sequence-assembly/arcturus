#!/usr/local/bin/perl -w

use strict; # Constraint variables declaration before using them

use ArcturusDatabase;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;
my $assembly;
my $cafFileName ='';
my $contiglist;

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|contigs|verbose|info|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage();
	exit(1);
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $contiglist       = shift @ARGV  if ($nextword eq '-contigs');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $logLevel         = 0            if ($nextword eq '-verbose'); 

    $logLevel         = 2            if ($nextword eq '-info'); 

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    print STDERR "Both instance and organism must be defined.\n\n";
    &showUsage(0);
    exit(1);
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging($outputFile);

$logger->setFilter($logLevel) if defined $logLevel; # set reporting level

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
			        -organism => $organism);

die "Failed to create ArcturusDatabase(-instance => $instance, -organism => $organism)" unless $adb;


#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $CAF;
$CAF = new FileHandle($cafFileName,"w") if $cafFileName;
$CAF = *STDOUT unless $CAF;

# allocate basic objects
my $contigids;

if (defined($contiglist)) {
    my @ctgs = split(',',$contiglist);
    $contigids = \@ctgs;
} else {
    $logger->info("Getting contig IDs for generation 0");

    $contigids = $adb->getCurrentContigIDs(); # exclude singleton
}

$logger->info("Retrieving ".scalar(@$contigids)." Contigs");

foreach my $contigid (@$contigids) {
    my $contig = $adb->getContig(ID=>$contigid);
    $logger->severe("Failed to retrieve contig $contigid") unless $contig;
    next unless $contig;
    my $contigname = $contig->getContigName();
    $logger->info("Writing $contigname to CAF file $cafFileName");
    $contig->writeToCaf($CAF);
}

$logger->info("Disconnecting");

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------


#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tArcturus instance\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\tCAF file name for output\n";
    print STDERR "-contigs\tComma-separated list of contig IDs\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-info\t\tDisplay progress info [boolean]\n";
    print STDERR "\n";
}


