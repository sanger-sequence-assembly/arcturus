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
my $aspedbefore;
my $aspedafter;
my $nosingleton;
my $blocksize = 10000;


my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|aspedbefore|aspedafter|".
                 "nosingleton|blocksize|info|verbose|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $aspedbefore      = shift @ARGV  if ($nextword eq '-aspedbefore');

    $aspedafter       = shift @ARGV  if ($nextword eq '-aspedafter');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $blocksize        = shift @ARGV  if ($nextword eq '-blocksize');

    $nosingleton      = 1            if ($nextword eq '-nosingleton');

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

my $adb = new ArcturusDatabase (-instance => $instance,
			        -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;


#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# allocate basic objects

$logger->info("Getting read IDs for unassembled reads");


my %options;
$options{-nosingleton} = 1 if $nosingleton;
$options{-aspedbefore} = $aspedbefore if $aspedbefore;
$options{-aspedafter} = $aspedafter if $aspedafter;

my $readids = $adb->getUnassembledReads(%options);

$logger->info("Retrieving ".scalar(@$readids)." Reads");

$logger->info("Opening CAF file $cafFileName for output") if $cafFileName;

my $CAF;
$CAF = new FileHandle($cafFileName,"w") if $cafFileName;
$CAF = *STDOUT unless $CAF;

while (my $remainder = scalar(@$readids)) {

    $blocksize = $remainder if ($blocksize > $remainder);

    my @readblock = splice (@$readids,0,$blocksize);

    $logger->info("Processing next $blocksize reads");

    $logger->info("$readblock[0] $readblock[$#readblock] ".scalar(@readblock));

#undef @readblock; # testing
    my $reads = $adb->getReadsByReadID(\@readblock);

    $logger->info("Adding sequence");

    $adb->getSequenceForReads($reads);

    $logger->info("Writing to CAF file $cafFileName");

    foreach my $read (@$reads) {
        $read->writeToCaf($CAF);
    }
}

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
    print STDERR "-caf\t\tcaf file name for output\n";
    print STDERR "-aspedbefore\tdate\n";
    print STDERR "-aspedafter\tdate\n";
    print STDERR "-nosingleton\tdon't include reads from single-read".
                 " contigs (default include)\n";
    print STDERR "-blocksize\t(default 50000) for blocked execution\n";
    print STDERR "-instance\teither prod (default) or 'dev'\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}


