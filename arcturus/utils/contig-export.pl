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
my $contig_id; # = 20884;
my $batch;
my $padded;
my $fofn;

my $validKeys  = "organism|instance|contig_id|fofn|padded|batch|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $contig_id = shift @ARGV  if ($nextword eq '-contig_id');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-debug');

    $padded    = 1            if ($nextword eq '-padded');

    $batch     = 1            if ($nextword eq '-batch');

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

$instance = 'prod' unless defined($instance);

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing contig ID") unless ($contig_id || $fofn);

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

my @contigids;

push @contigids, $contig_id if $contig_id;
 
if ($fofn) {
    foreach my $contig_id (@$fofn) {
        push @contigids, $contig_id if $contig_id;
    }
}

foreach my $contig_id (@contigids) {

    my $contig = $adb->getContig(contig_id=>$contig_id) || 0;

    $logger->info("Contig returned: $contig");

    next if (!$contig && $batch); # re: contig-padded-tester

    $logger->warning ("Unknown contig $contig_id") unless $contig;

    next unless $contig;

    $contig->writeToCaf(*STDOUT)   unless $padded;

    $contig->writeToCafPadded(*STDOUT) if $padded;
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
    print STDERR "-organism\tArcturus database name\n\n";
    print STDERR "either -contig_id or -fofn :\n\n";
    print STDERR "-contig_id\tContig ID\n";
    print STDERR "-fofn \t\tname of file with list of Contig IDs\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' (default) or 'dev'\n";
    print STDERR "-padded\t\t(no value) export contig in padded format\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
 
sub getNamesFromFile {
    my $file = shift; # file name
                                                                                
    &showUsage(0,"File $file does not exist") unless (-e $file);
 
    my $FILE = new FileHandle($file,"r");
 
    &showUsage(0,"Can't access $file for reading") unless $FILE;
 
    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }
 
    return [@list];
}
