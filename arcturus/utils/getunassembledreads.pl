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
my $outputFileName;
my $selectmethod;
my $aspedbefore;
my $aspedafter;
my $nosingleton;
my $blocksize = 10000;
my $mask;

my $number;

my $fasta;
my $addtag;

my $namelike;
my $namenotlike;
my $excludelist;

my $threshold;  # only with clipmethod
my $clipmethod;
my $minimumrange;

my $logfile;            # default STDERR
my $loglevel;           # default log warnings and errors only
my $debug;

my $validKeys  = "organism|instance|assembly|caf|aspedbefore|ab|aspedafter|aa|"
               . "nosingleton|ns|blocksize|bs|selectmethod|sm|namelike|nl|"
               . "namenotlike|nnl|excludelist|el|mask|tags|all|fasta|"
               . "clipmethod|cm|threshold|th|minimumqualityrange|mqr|"
               . "info|verbose|debug|log|help";


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

    $excludelist      = shift @ARGV  if ($nextword eq '-excludelist');
    $excludelist      = shift @ARGV  if ($nextword eq '-el');

    $selectmethod     = shift @ARGV  if ($nextword eq '-selectmethod');
    $selectmethod     = shift @ARGV  if ($nextword eq '-sm');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    if (defined($fasta) && ($nextword eq '-caf' || $nextword eq '-fasta')) {
        die "-caf and -fasta specification are mutually exclusive";
    }

    $outputFileName   = shift @ARGV  if ($nextword eq '-caf');
    $fasta            = 0            if ($nextword eq '-caf');
    $outputFileName   = shift @ARGV  if ($nextword eq '-fasta');
    $fasta            = 1            if ($nextword eq '-fasta');

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

    $addtag           = 1            if ($nextword eq '-tags');

    $loglevel         = 1            if ($nextword eq '-verbose'); 
    $loglevel         = 1            if ($nextword eq '-info'); 
    $loglevel         = 1            if ($nextword eq '-debug');

    $debug            = 1            if ($nextword eq '-debug'); 

    $number           = shift @ARGV  if ($nextword eq '-all');

    $logfile          = shift @ARGV  if ($nextword eq '-log');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging($logfile);

$logger->setStandardFilter($loglevel) if defined $loglevel; # reporting level

$logger->setBlock('debug',unblock=>1) if $debug;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing caf or fasta filename") unless defined $outputFileName;

my $adb = new ArcturusDatabase (-instance => $instance,
			        -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;

$adb->setLogger($logger);

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my ($CAF,$FAS,$QLT);

if ($fasta) {
# fasta output
    if ($outputFileName) {
        $outputFileName .= '.fas' unless ($outputFileName =~ /\.fas/);
        $logger->info("Opening fasta file $outputFileName for DNA output");
        $FAS = new FileHandle($outputFileName,"w");
    }
    $FAS = *STDOUT unless $FAS;
    if ($outputFileName) {
        $outputFileName =~ s/\.fas\w*/\.qlt/;
        $outputFileName .= '.qlt' unless ($outputFileName =~ /\.qlt/);
        $logger->info("Opening fasta file $outputFileName for Quality output");
        $QLT = new FileHandle($outputFileName,"w");
    }
    $QLT = *STDOUT unless $QLT;
}
else {
# caf output
    if ($outputFileName) {
        $outputFileName .= '.caf' unless ($outputFileName =~ /\.caf/);
        $logger->info("Opening CAF file $outputFileName for output");
        $CAF = new FileHandle($outputFileName,"w");
    }
    $CAF = *STDOUT unless $CAF;
}

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

my %excludehash;
if ($excludelist) {
    my $namelist = &getNamesFromFile($excludelist);
    foreach my $name (@$namelist) {
        $excludehash{$name}++;
    }
}

$logger->info("Getting read IDs for unassembled reads");

my $readids = [];

if ($number) {
# overrides all other qualifiers, export all reads up to read_id number
    if ($number =~ /^\d+$/) {
        my @readids = (1 .. $number);
        $readids = \@readids;
    }
    else {
	$logger->severe("invalid specification for '-all' option: integer expected");
    }
}
else {
# standard mode
    $readids = $adb->getIDsForUnassembledReads(%options);
}

$logger->info("Retrieving ".scalar(@$readids)." Reads");

my $discarded = 0;
my $excluded  = 0;

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

    $logger->info("Writing to output file $outputFileName");

    $threshold = 1 if (defined($threshold) && $threshold < 1);

    foreach my $read (@$reads) {
        my $readname = $read->getReadName();
        if ($excludelist && $excludehash{$readname}) {
            print STDERR "read $readname excluded\n";
            $excluded++;
            next;
        }
        if (defined($clipmethod) || defined($threshold) || $minimumrange) {
            $clipmethod = 0 unless defined($clipmethod);
            unless ($read->qualityClip(clipmethod=>$clipmethod,
                                       threshold=>$threshold,
				       minimum=>$minimumrange)) {
                print STDERR "read $readname discarded after clipping\n";
                $discarded++;
                next;
	    }
        }
        $read->writeToCaf($CAF,qualitymask=>$mask) unless $fasta;
        $read->writeToFasta($FAS,$QLT,qualitymask=>$mask) if $fasta;
    }
    undef @$reads;
}
    
print STDERR "$discarded reads ignored\n" if $discarded;
print STDERR "$excluded reads excluded\n" if $excluded;

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

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
    print STDOUT "MANDATORY EXCLUSIVE PARAMETER:\n";
    print STDOUT "\n";
    print STDOUT "-caf\t\tcaf file name for output (0 for STDOUT)\n";
    print STDOUT "-fasta\t\tfile name for output in fasta format\n";
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
    print STDOUT "-all\t\toverrides all other selection (except excludelist &\n";
    print STDOUT "\t\tstatus); exports reads 1 to number provided \n";
    print STDOUT "\n";
    print STDOUT "-excludelist\tfile of readnames to be excluded\n";
    print STDOUT "\n";
    print STDOUT "-blocksize\t(default 50000) for blocked execution\n";
# print STDOUT "-assembly\tassembly name\n";
    print STDOUT "\n";
    print STDOUT "-clipmethod\tOn the fly quality clipping using method specified\n";
    print STDOUT "-mask\t\tSymbol replacing low quality data (recommended: 'x')\n";
    print STDOUT "\t\t the masking includes screening for vector sequence\n";
    print STDOUT "-threshold\tQuality clipping threshold level\n";
    print STDOUT "-minimumqualityrange\tMinimum high quality length\n";
    print STDOUT "\n";
    print STDOUT "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";

    $code ? exit(1) : exit(0);
}