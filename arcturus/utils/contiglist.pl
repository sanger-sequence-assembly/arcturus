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
my $contig_id;
my $caf;
my $fasta;
my $fofn;
my $html;
my $verbose;

my $validKeys  = "organism|instance|contig|fofn|html|caf|fasta|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $contig_id = shift @ARGV  if ($nextword eq '-contig');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    $html      = 1            if ($nextword eq '-html');

    $fasta     = 1            if ($nextword eq '-fasta');

    $caf       = 1            if ($nextword eq '-caf');

    $verbose   = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging(*STDERR);
 
$logger->setFilter(0) if $verbose; # set reporting level

my $break = $html ? "<br>" : "\n";
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

if ($adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
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


if ($fofn) {
    foreach my $name (@$fofn) {
        my $contig = $adb->getContig(id=>$name);
        push @contigs, $contig if $contig;
    }
}

$logger->info("Contig $contig_id to be processed");
if ($contig_id) {
#test mode construction to be changed
    my $contig = $adb->getContig(id=>$contig_id);
$logger->info("Contig $contig constructed");
    push @contigs, $contig if $contig;
}

foreach my $contig (@contigs) {
    $contig->writeToCaf(*STDOUT); 
}


#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub readNamesFromFile {
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

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' (default) or 'dev'\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-fofn\t\tfilename with list of readnames to be included\n";
    print STDERR "-filter\t\tprocess only those readnames matching pattern or substring\n";
    print STDERR "-readnamelike\t  idem\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}



