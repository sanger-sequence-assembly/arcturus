#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $username;
my $password;
my $contig_id;
my $verbose;
my $confirm;
my $cleanup = 0;
my $fofn;

my $validKeys  = "organism|instance|username|password|contig|fofn|cleanup|"
               . "verbose|confirm|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $username     = shift @ARGV  if ($nextword eq '-username');

    $password     = shift @ARGV  if ($nextword eq '-password');

    $contig_id    = shift @ARGV  if ($nextword eq '-contig');

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');

    $cleanup      = 1            if ($nextword eq '-cleanup');

    $confirm      = 1            if ($nextword eq '-confirm');

    $verbose      = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig ID or fofn") unless ($contig_id || $fofn);

&showUsage("Missing arcturus username") unless $username;

&showUsage("Missing arcturus password") unless $password;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism,
                                -username => $username,
                                -password => $password);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Unknown organism '$organism' on server '$instance', "
              ."or invalid username and password");
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

my @contigs;

if ($contig_id && $contig_id =~ /\,/) {
    @contigs = split /\,/,$contig_id;
}
elsif ($contig_id) {
    push @contigs, $contig_id;
}

if ($fofn) {
    foreach my $contig_id (@$fofn) {
        push @contigs, $contig_id;
    }
}

my $isName = 0;
foreach my $identifier (@contigs) {
    $isName = 1 if ($identifier =~ /\D/);
}


foreach my $contig_id (@contigs) {
    my %options;
    $options{confirm} = 1 if $confirm;
    $logger->warning("Contig $contig_id is to be deleted");
    my ($success,$msg) = $adb->deleteContig($contig_id,%options);
    if ($confirm) {
        $logger->severe("FAILED to remove contig $contig_id") unless $success;
        $logger->warning("Contig $contig_id is deleted") if $success;
    }
    $logger->warning($msg);
}

if ($confirm) {
    $logger->warning("Cleaning up") if $cleanup;
    $adb->cleanupMappings() if $cleanup;
}
else {    
    $logger->warning("Deletes to be made without cleanup; otherwise use -cleanup") unless $cleanup;
    $logger->warning("Repeat and specify -confirm");
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $record = <$FILE>)) {
        next unless ($record =~ /\S/);
        if ($record =~ s/^\s*(\S+)\s*$//) {
            push @list, $1;
        }
        elsif ($record =~ /^\s*from\s+(\d+)\s+to\s+(\d+)\s*$/i) {
            my $start = $1;
            my $final = $2;
            for my $i ($start .. $final) {
                push @list, $i;
            }
        }
        else {
            print STDERR "Invalid input on fofn: $record\n";
        }
    }
    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "Delete a contig or contigs\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tContig ID\n";
    print STDERR "-fofn\t\tfilename with list of contig IDs to be delete\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) to actually do the delete\n";
    print STDERR "-cleanup\t(no value) to cleanup after each deleted contig\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

