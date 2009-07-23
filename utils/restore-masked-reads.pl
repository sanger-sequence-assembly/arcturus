#!/usr/local/bin/perl -w

#----------------------------------------------------------------
# 
#----------------------------------------------------------------

use strict; # Constraint variables declaration before using them

use ContigFactory::ContigFactory;

use ArcturusDatabase;

use FileHandle;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

# the data source

my $caffilename;            # must be specified

# filter for mixed assembly capilary reads

my $manglereadname = '\.[pq][12]k\.[\w\-]+';

# output

my $progress = 1;

my $loglevel;             
my $logfile;

my $debug = 0;

#------------------------------------------------------------------------------

my $validkeys  = "organism|o|instance|i|caf|"
               . "log|verbose|info|debug|noprogress|help|h";

#------------------------------------------------------------------------------
# parse the command line input; options overwrite eachother; order is important
#------------------------------------------------------------------------------

while (my $nextword = shift @ARGV) {

    $nextword = lc($nextword);

    if ($nextword !~ /\-($validkeys)\b/) {
        &showUsage("Invalid keyword '$nextword' \n($validkeys)");
    }

    if ($nextword eq '-i' || $nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    elsif ($nextword eq '-o' || $nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }

# input specification

    if ($nextword eq '-caf') {
        $caffilename  = shift @ARGV; # specify input file
    }

# reporting

    $progress         = 0  if ($nextword eq '-noprogress');

    $loglevel         = 0  if ($nextword eq '-verbose'); # info, fine, finest
    $loglevel         = 2  if ($nextword eq '-info');    # info
    $debug            = 1  if ($nextword eq '-debug');   # info, fine
    $logfile          = shift @ARGV  if ($nextword eq '-log');

    &showUsage(0) if ($nextword eq '-h' || $nextword eq '-help');
}

#----------------------------------------------------------------
# test the CAF file name
#----------------------------------------------------------------
        
&showUsage("Missing CAF file name") unless defined($caffilename);

# test existence of the caf file

&showUsage("CAF file $caffilename does not exist") unless (-f $caffilename);

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardStream($logfile,append=>1) if $logfile; # default STDOUT

$logger->setStandardFilter($loglevel) if defined $loglevel; # reporting level

if ($debug) {
    $logger->stderr2stdout();
    $logger->setBlock('debug',unblock=>1);
}

$logger->listStreams() if defined $loglevel; # test

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism eq 'default' || $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection

unless ($adb->verifyArcturusUser(list=>1)) { # error message to STDERR
    $adb->disconnect();
    exit 1;
}

$adb->setLogger($logger);

ContigFactory->setLogger($logger);

Contig->setLogger($logger);

#------------------------------------------------------------------------------
# scan the file and make an inventory of objects
#------------------------------------------------------------------------------
    
my %options = (progress=>$progress);

my $inventory = ContigFactory->cafFileInventory($caffilename,%options);
unless ($inventory) {
    $logger->severe("Could not make an inventory of $caffilename");
    exit 0;
}
my $nrofobjects = scalar(keys %$inventory) - 1;
$logger->info("$nrofobjects objects found on file $caffilename ");

# get contig names, count reads 

my @readnames;

my @contignames;
    
my @inventory = sort keys %$inventory; # better: sort on position in file
    
foreach my $objectname (@inventory) { 
# ignore non-objects
    my $objectdata = $inventory->{$objectname};
# Read and Contig objects have data store as a hash; if no hash, ignore 
    next unless (ref($objectdata) eq 'HASH');

    my $objecttype = $objectdata->{Is};

    if ($objecttype =~ /contig/) {
        push @contignames,$objectname;
    }
    elsif ($objecttype =~ /read/) {
# filter readnames to avoid loading unwanted reads into arcturus
        if ($manglereadname && $objectname =~ /$manglereadname/) {
            $logger->severe("The assembly contains reads mangled by the Newbler asssembler");
            $logger->severe("Processing is aborted");
  	    $adb->disconnect();
            exit 1;
        }
        push @readnames,$objectname;
    }
    elsif ($objecttype =~ /assembly/) {
# here potential to process assembly information
        next;
    }
    else {
        $logger->error("Invalid object type $objecttype for $objectname");
        next;
    }
}

$logger->info(scalar(@contignames)." contigs, " . scalar(@readnames) . " reads");

unless (@readnames) {
    $logger->warning("CAF file $caffilename has no reads");
}

$logger->flush();

# use standard pattern to catch all tag types
    
# my $rtagtypeaccept = '\w{3,4}';

my %poptions;

$poptions{consensus} = 1;

foreach my $contigname (@contignames) {

    my @contigname = ($contigname);

    $logger->error("next contig ($contigname) to be extracted",ss=>1);

    my $object = ContigFactory->contigExtractor(\@contigname, 0, %poptions);

    my $contig = $object->[0];

    $contig->setArcturusDatabase($adb);

    my $restored = $contig->restoreMaskedReads();

    $logger->error("restored reads : $restored");

    $contig->writeToCaf(*STDOUT);
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "restore quality-masked reads in an assembly caf file; ";
    print STDERR "output on STDOUT\n";
    print STDERR "\n";

    unless ($organism && $instance && $caffilename) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus organism database\n" unless $organism;
        print STDERR "-instance\tArcturus database instance\n" unless $instance;
        print STDERR "-caf\t\tfile name with assembly in UN-padded format\n" unless $caffilename;
        print STDERR "\n";
    }
 
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-noprogress\tsuppress reporting by caf file parser\n";
    print STDERR "\n";
    print STDERR "-info\n-verbose\n-debug\n";
    print STDERR "-log\t\twrite some output to specified log file\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
