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
#my $ignoreblocked = 0;
my $fofn;
my $caf;
my $fasta;
my $quality;
my $metadataonly = 1;

my $validKeys  = "organism|instance|contig|fofn|ignoreblocked|full|"
               . "caf|fasta|quality|padded|batch|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                          
    $instance   = shift @ARGV  if ($nextword eq '-instance');
      
    $organism   = shift @ARGV  if ($nextword eq '-organism');

    $contig     = shift @ARGV  if ($nextword eq '-contig'); # ID or name

    $fofn       = shift @ARGV  if ($nextword eq '-fofn');

    $caf        = shift @ARGV  if ($nextword eq '-caf');

    $fasta      = shift @ARGV  if ($nextword eq '-fasta');

    $quality    = shift @ARGV  if ($nextword eq '-quality');

    $verbose    = 1            if ($nextword eq '-verbose');

    $verbose    = 2            if ($nextword eq '-debug');

    $padded     = 1            if ($nextword eq '-padded');

    $metadataonly = 0          if ($nextword eq '-full');

#    $ignblocked = 1            if ($nextword eq '-ignoreblocked');

    $batch      = 1            if ($nextword eq '-batch');

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

unless (defined($caf) || defined($fasta)) {
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

if (defined($caf)) {
    $caf = new FileHandle($caf,"w") if $caf;
    $caf = *STDOUT unless $caf;
}

if (defined($fasta)) {
    $fasta = new FileHandle($fasta,"w") if $fasta;
    $fasta = *STDOUT unless $fasta;
    if ($quality) {
        $quality = new FileHandle($quality,"w");
    }
}


my @contigs;

push @contigs, $contig if $contig;
 
if ($fofn) {
    foreach my $contig (@$fofn) {
        push @contigs, $contig if $contig;
    }
}

foreach my $identifier (@contigs) {

    unless ($identifier) {
        print STDERR "Invalid or missing contig identifier\n";
        next;
    }

    undef my %options;
    $options{metaDataOnly} = $metadataonly;
    $options{withRead}  = $identifier if ($identifier =~ /\D/);
    $options{contig_id} = $identifier if ($identifier !~ /\D/);
#    $options{ignoreblocked} = 1;

    my $contig = $adb->getContig(%options) || 0;

    $logger->info("Contig returned: $contig");

    next if (!$contig && $batch); # re: contig-padded-tester

    $logger->warning ("Blocked or unknown contig $identifier") unless $contig;

    next unless $contig;

    $contig->setContigName($identifier) if ($identifier =~ /\D/);

    $contig->writeToCaf($caf) unless ($padded || $fasta);

    $contig->writeToFasta($fasta) if $fasta;
    print $fasta "\n" if $fasta;

    $contig->writeToCafPadded($caf) if $padded;
}

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
    print STDERR "-fofn \t\tname of file with list of Contig IDs\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\toutput file name (default STDOUT)\n";
    print STDERR "-padded\t\t(no value) export contig in padded format\n";
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
