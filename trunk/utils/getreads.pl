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
my $blocksize = 10000;
my $fasta;
my $namelike;
my $namenotlike;
my $tagtype;
my $tagname;
my $sequence = 1;
my $limit;


my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|aspedbefore|aspedafter|"
               . "namelike|tagtype|tagname|namenotlike|blocksize|nosequence|"
               . "limit|info|verbose|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $aspedbefore      = shift @ARGV  if ($nextword eq '-aspedbefore');

    $aspedafter       = shift @ARGV  if ($nextword eq '-aspedafter');

    $namelike         = shift @ARGV  if ($nextword eq '-namelike');

    $namenotlike      = shift @ARGV  if ($nextword eq '-namenotlike');

    $tagname          = shift @ARGV  if ($nextword eq '-tagname');

    $tagtype          = shift @ARGV  if ($nextword eq '-tagtype');

    $limit            = shift @ARGV  if ($nextword eq '-limit');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $blocksize        = shift @ARGV  if ($nextword eq '-blocksize');

    $sequence         = 0            if ($nextword eq '-nosequence');

    $fasta            = 1            if ($nextword eq '-fasta');

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

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
			        -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %options;
$options{aspedbefore} = $aspedbefore if $aspedbefore;
$options{aspedafter}  = $aspedafter  if $aspedafter;

if ($namelike) {
    $options{namelike}   = $namelike if ($namelike !~ /[^\w\.\%\_]/);
    $options{nameregexp} = $namelike if ($namelike =~ /[^\w\.\%\_]/);
}

if ($namenotlike) {
    $options{namenotlike}   = $namenotlike if ($namenotlike !~ /[^\w\.\%\_]/);
    $options{namenotregexp} = $namenotlike if ($namenotlike =~ /[^\w\.\%\_]/);
}

$options{tagname} = $tagname if $tagname;
$options{tagtype} = $tagtype if $tagtype;

$options{limit} = $limit if ($limit && $limit > 0);

$logger->info("Opening CAF file $cafFileName for output") if $cafFileName;

my $CAF;
$CAF = new FileHandle($cafFileName,"w") if $cafFileName;
$CAF = *STDOUT unless $CAF;

$logger->info("Retrieving Reads");

my $reads = $adb->getReads(%options);

print $adb->logQuery(1)."\n";

$adb->getTagsForReads($reads);

if ($sequence) {

    $logger->info("Adding sequence to ".scalar(@$reads)." reads");

    $adb->getSequenceForReads($reads);

    $logger->info("Writing to CAF file $cafFileName");

    foreach my $read (@$reads) {
        $read->writeToCaf($CAF) unless $fasta;
        $read->writeFasta($CAF) if $fasta;
    }
}
else {
    foreach my $read (@$reads) {
        my $readname = $read->getReadName();
        my $read_id  = $read->getReadID();
        my $seq_id   = $read->getSequenceID();
        my $version  = $read->getVersion();
        if ($read->hasTags()) {
	    print STDOUT "\n";
            my $tags = $read->getTags();
            foreach my $tag (@$tags) {
                my $tagtype = $tag->getType();
                my $tagname = $tag->getTagSequenceName() || 'none';
                my $comment = $tag->getTagComment();
                print STDOUT "$readname $read_id $seq_id $version $tagtype $tagname $comment\n";
            }
	}
        else {
	    print "NO tags\n";
            print STDOUT "$readname $read_id $seq_id $version \n";
        }
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
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\tcaf file name for output\n";
    print STDERR "-fasta\t\t(no value) write in fasta format (default CAF)\n";
    print STDERR "-blocksize\t(default 50000) for blocked execution\n";
    print STDERR "\n";
    print STDERR "-aspedafter\tdate lower bound (inclusive)\n";
    print STDERR "-aspedbefore\tdate upper bound (inclusive)\n";
    print STDERR "\n";
    print STDERR "-namelike\tName with wildcard or pattern\n";
    print STDERR "-namenotlike\tName with wildcard or pattern\n";
    print STDERR "\n";
#print STDERR "-assembly\tassembly name\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}


