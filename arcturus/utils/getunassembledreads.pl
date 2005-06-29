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
my $selectmethod;
my $aspedbefore;
my $aspedafter;
my $nosingleton;
my $blocksize = 10000;
my $mask;

my $fasta;
my $addtag;

my $namelike;
my $namenotlike;

my $threshold;  # only with clipmethod
my $clipmethod;
my $minimumrange = 32;

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only
my $debug;

my $validKeys  = "organism|instance|assembly|caf|aspedbefore|ab|aspedafter|aa|"
               . "nosingleton|ns|blocksize|bs|selectmethod|sm|namelike|nl|"
               . "namenotlike|nnl|mask|tags|"
               . "clipmethod|cm|threshold|th|minimumqualityrange|mqr|"
               . "info|verbose|debug|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $aspedbefore      = shift @ARGV  if ($nextword eq '-aspedbefore');
    $aspedbefore      = shift @ARGV  if ($nextword eq '-ab');
 
    $aspedafter       = shift @ARGV  if ($nextword eq '-aspedafter');
    $aspedafter       = shift @ARGV  if ($nextword eq '-aa');

    $namelike         = shift @ARGV  if ($nextword eq '-namelike');
    $namelike         = shift @ARGV  if ($nextword eq '-nl');

    $namenotlike      = shift @ARGV  if ($nextword eq '-namenotlike');
    $namenotlike      = shift @ARGV  if ($nextword eq '-nnl');

    $selectmethod     = shift @ARGV  if ($nextword eq '-selectmethod');
    $selectmethod     = shift @ARGV  if ($nextword eq '-sm');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $blocksize        = shift @ARGV  if ($nextword eq '-blocksize');
    $blocksize        = shift @ARGV  if ($nextword eq '-bs');

    $clipmethod       = shift @ARGV  if ($nextword eq '-clipmethod');
    $clipmethod       = shift @ARGV  if ($nextword eq '-cm');

    $mask             = shift @ARGV  if ($nextword eq '-mask');

    $threshold        = shift @ARGV  if ($nextword eq '-threshold');
    $threshold        = shift @ARGV  if ($nextword eq '-th');

    $minimumrange     = shift @ARGV  if ($nextword eq '-minimumqualityrange');
    $minimumrange     = shift @ARGV  if ($nextword eq '-mqr');

    $nosingleton      = 1            if ($nextword eq '-nosingleton');
    $nosingleton      = 1            if ($nextword eq '-ns');

    $fasta            = 1            if ($nextword eq '-fasta');

    $addtag           = 1            if ($nextword eq '-tags');

    $logLevel         = 1            if ($nextword eq '-verbose'); 
    $logLevel         = 1            if ($nextword eq '-info'); 
    $logLevel         = 1            if ($nextword eq '-debug');

    $debug            = 1            if ($nextword eq '-debug'); 

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

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
			        -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;


#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

$logger->info("Opening CAF file $cafFileName for output") if $cafFileName;

my $CAF;
$CAF = new FileHandle($cafFileName,"w") if $cafFileName;
$CAF = *STDOUT unless $CAF;

my %options;
$options{nosingleton} = 1 if $nosingleton;
$options{aspedbefore} = $aspedbefore if $aspedbefore;
$options{aspedafter}  = $aspedafter  if $aspedafter;

if (defined($selectmethod)) {
    $options{method} = $selectmethod;
    $options{method} = 'usetemporarytables' if ($selectmethod >= 2);
    $options{method} = 'usesubselect'       if ($selectmethod == 1);
}

if ($namelike) {
    $options{namelike}   = $namelike if ($namelike !~ /[^\w\.\%\_]/);
    $options{nameregexp} = $namelike if ($namelike =~ /[^\w\.\%\_]/);
}

if ($namenotlike) {
    $options{namenotlike}   = $namenotlike if ($namenotlike !~ /[^\w\.\%\_]/);
    $options{namenotregexp} = $namenotlike if ($namenotlike =~ /[^\w\.\%\_]/);
}

$logger->info("Getting read IDs for unassembled reads");

my $readids = $adb->getIDsForUnassembledReads(%options);

$logger->info("Retrieving ".scalar(@$readids)." Reads");

while (my $remainder = scalar(@$readids)) {

    $blocksize = $remainder if ($blocksize > $remainder);

    my @readblock = splice (@$readids,0,$blocksize);

    $logger->info("Processing next $blocksize reads");

    $logger->info("$readblock[0] $readblock[$#readblock] ".scalar(@readblock));

    next if $debug;

    my $reads = $adb->getReadsByReadID(\@readblock);

    $logger->info("Adding sequence");

    $adb->getSequenceForReads($reads);

    if ($addtag) {
        $logger->info("Adding tags");
        $adb->getTagsForReads($reads);
    }

    $logger->info("Writing to CAF file $cafFileName");

    foreach my $read (@$reads) {
        if (defined($clipmethod) || $threshold || $minimumrange) {
            $clipmethod = 0 unless defined($clipmethod);
            unless ($read->qualityClip(clipmethod=>$clipmethod,
                                       threshold=>$threshold,
				       minimum=>$minimumrange)) {
                print STDERR "read ".$read->getReadName().
		             " discarded after clipping\n";
                next;
	    }
        }

        $read->writeToCaf($CAF,qualitymask=>$mask) unless $fasta;
        $read->writeFasta($CAF,qualitymask=>$mask) if $fasta;
    }
    undef @$reads;
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

    print STDOUT "\nParameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";
    print STDOUT "MANDATORY PARAMETERS:\n";
    print STDOUT "\n";
    print STDOUT "-organism\tArcturus database name\n";
    print STDOUT "-instance\teither 'prod' or 'dev'\n";
    print STDOUT "\n";
    print STDOUT "OPTIONAL PARAMETERS:\n";
    print STDOUT "\n";
    print STDOUT "-selectmethod\t1: for using sub queries\n"
               . "\t\t2: for using temporary tables\n"
               . "\t\t0: for a blocked search\n"
               . "\t\tdefault selection of either method 1 or 2\n";
    print STDOUT "-nosingleton\tdon't include reads from single-read".
                 " contigs (default include)\n";
    print STDOUT "\n";
    print STDOUT "-aspedafter\tAsped date lower bound (inclusive)\n";
    print STDOUT "-aspedbefore\tAsped date upper bound (inclusive)\n";
    print STDOUT "-namelike\t(include) readname with wildcard or a pattern\n";
    print STDOUT "-namenotlike\t(exclude) readname with wildcard or a pattern\n";
    print STDOUT "\n";
    print STDOUT "-caf\t\tcaf file name for output\n";
    print STDOUT "-fasta\t\t(no value) write in fasta format (default CAF)\n";
    print STDOUT "-blocksize\t(default 50000) for blocked execution\n";
# print STDOUT "-assembly\tassembly name\n";
    print STDOUT "\n";
    print STDOUT "-clipmethod\tOn the fly quality clipping using method specified\n";
    print STDOUT "-threshold\tQuality clipping threshold level\n";
    print STDOUT "-minimumqualityrange\tMinimum high quality length\n";
    print STDOUT "\n";
    print STDOUT "-info\t\t(no value) for some progress info\n";
    print STDOUT "\n";

    $code ? exit(1) : exit(0);
}




