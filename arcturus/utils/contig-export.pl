#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $contig; # = 20884;
my $batch;
my $padded;
my $noread;
#my $ignoreblocked = 0;
my $fofn;
my $caffile;
my $fastafile;
my $qualityfile;
my $masking;
my $metadataonly = 1;

my $validKeys  = "organism|instance|contig|contigs|fofn|ignoreblocked|full|"
               . "caf|fasta|quality|padded|mask|noread|batch|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                          
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig       = shift @ARGV  if ($nextword eq '-contig'); # ID or name

    $contig       = shift @ARGV  if ($nextword eq '-contigs'); # ID or name

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');

    $caffile      = shift @ARGV  if ($nextword eq '-caf');

    $fastafile    = shift @ARGV  if ($nextword eq '-fasta');

    $qualityfile  = shift @ARGV  if ($nextword eq '-quality');

    $masking      = shift @ARGV  if ($nextword eq '-mask');

    $verbose      = 1            if ($nextword eq '-verbose');

    $padded       = 1            if ($nextword eq '-padded');

    $noread       = 1            if ($nextword eq '-noread');

    $metadataonly = 0            if ($nextword eq '-full');

#    $ignblocked   = 1            if ($nextword eq '-ignoreblocked');

    $batch        = 1            if ($nextword eq '-batch');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

unless (defined($caffile) || defined($fastafile)) {
    &showUsage("Missing caf or fasta file specification");
}

&showUsage("Missing contig name or ID") unless ($contig || $fofn);

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");
 
#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------
 
$fofn = &getNamesFromFile($fofn) if $fofn;
 
#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

if ($padded && defined($fastafile)) {
    $logger->warning("Redundant '-padded' key ignored");
    undef $padded;
}

if ($noread && defined($caffile)) {
    $logger->warning("Redundant '-noread' key ignored");
    undef $noread;
}

# get file handles

my ($fhDNA, $fhQTY);

if (defined($caffile) && $caffile) {
    $caffile .= '.caf' unless ($caffile =~ /\.caf$|null/);
    unless ($fhDNA = new FileHandle($caffile, "w")) {
        &showUsage("Failed to create CAF output file \"$caffile\"");
    }
}
elsif (defined($caffile)) {
    $fhDNA = *STDOUT;
}

if (defined($fastafile) && $fastafile) {
    $fastafile .= '.fas' unless ($fastafile =~ /\.fas$|null/);
    unless ($fhDNA = new FileHandle($fastafile, "w")) {
        &showUsage("Failed to create FASTA sequence output file \"$fastafile\"");
    }
    if (defined($qualityfile)) {
        unless ($fhQTY = new FileHandle($qualityfile, "w")) {
	    &showUsage("Failed to create FASTA quality output file \"$qualityfile\"");
        }
    }
    elsif ($fastafile eq '/dev/null') {
        $fhQTY = $fhDNA;
    }
}
elsif (defined($fastafile)) {
    $fhDNA = *STDOUT;
}

my @contigs;

push @contigs, split(/,/, $contig) if $contig;
 
if ($fofn) {
    foreach my $contig (@$fofn) {
        push @contigs, $contig if $contig;
    }
}

# get the write options

    my %woptions;
    $woptions{noreads} = 1 if $noread; # fasta only
    $woptions{qualitymask} = $masking if defined($masking);
    $woptions{padded} = 1 if $padded;

my $errorcount = 0;

foreach my $identifier (@contigs) {

    unless ($identifier) {
        print STDERR "Invalid or missing contig identifier\n";
        next;
    }

# get the contig select options

    undef my %coptions;
    $coptions{metaDataOnly} = $metadataonly;
    $coptions{withRead}  = $identifier if ($identifier =~ /\D/);
    $coptions{contig_id} = $identifier if ($identifier !~ /\D/);
# $options{ignoreblocked} = 1;

    my $contig = $adb->getContig(%coptions) || 0;

    $logger->info("Contig returned: $contig");

    next if (!$contig && $batch); # re: contig-padded-tester

    $logger->warning ("Blocked or unknown contig $identifier") unless $contig;

    next unless $contig;

    $contig->setContigName($identifier) if ($identifier =~ /\D/);

    $contig->writeToCaf($fhDNA,%woptions) unless ($padded || defined($fastafile));

    $contig->writeToFasta($fhDNA,$fhQTY,%woptions) if defined($fastafile);

    $contig->writeToCafPadded($fhDNA,%woptions) if $padded; # later to option of writeToCaf
}

$fhDNA->close() if $fhDNA;

$fhQTY->close() if $fhQTY;

$adb->disconnect();

# TO BE DONE: message and error testing
#$logger->warning("There were no errors") unless $errorcount;
#$logger->warning("$errorcount Errors found") if $errorcount;

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n\nExport contig(s) by ID or using a fofn with IDs\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n\n";
    print STDERR "OPTIONAL EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-contig\t\tContig name or ID\n";
    print STDERR "-contigs\tComma-separated list of ontig names or IDs\n";
    print STDERR "-fofn \t\tname of file with list of Contig IDs\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\toutput file name (default STDOUT)\n";
    print STDERR "-padded\t\t(no value) export contig in padded format (caf only)\n";
#    print STDERR "-ignoreblock\t\t(no value) include contigs from blocked projects\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
 
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
