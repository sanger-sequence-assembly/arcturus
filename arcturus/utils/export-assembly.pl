#!/usr/local/bin/perl -w

use strict; # Constraint variables declaration before using them

use ArcturusDatabase::ADBContig;

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

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|verbose|info|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $logLevel         = 0            if ($nextword eq '-verbose'); 

    $logLevel         = 2            if ($nextword eq '-info'); 

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging($outputFile);

$logger->setFilter($logLevel) if defined $logLevel; # set reporting level

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

my $adb = new ADBContig (-instance => $instance,
			 -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;


#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $CAF;
$CAF = new FileHandle($cafFileName,"w") if $cafFileName;
$CAF = *STDOUT unless $CAF;

# allocate basic objects

$logger->info("Getting contig IDs for generation 0");

my $contigids = $adb->getCurrentContigs(); # exclude singleton

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

    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither prod (default) or 'dev'\n";
    print STDERR "-caf\t\tcaf file name for output\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}


