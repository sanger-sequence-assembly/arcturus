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
my $readname;
my $tagname;
my $fasta;
my $fofn;
my $verbose;
my $metadataonly = 0;

my $validKeys  = "organism|instance|contig|fofn|read|tag|short|".
                 "fasta|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig_id    = shift @ARGV  if ($nextword eq '-contig');

    $readname     = shift @ARGV  if ($nextword eq '-read');

    $tagname      = shift @ARGV  if ($nextword eq '-tag');

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');

    $fasta        = 1            if ($nextword eq '-fasta');

    $verbose      = 1            if ($nextword eq '-verbose');

    $metadataonly = 1            if ($nextword eq '-short');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging(*STDERR);
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'dev' unless defined($instance);

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

if ($contig_id) {
    $logger->info("Contig $contig_id to be processed");
    my $contig = $adb->getContig(contig_id=>$contig_id,
                                 metaDataOnly=>$metadataonly);
    $logger->info("Contig $contig constructed");
    push @contigs, $contig if $contig;
}

if ($readname) {
    $logger->info("Contig with read $readname to be processed");
    my $contig = $adb->getContig(withRead=>$readname,
                                 metaDataOnly=>$metadataonly);
    $logger->info("Contig $contig constructed");
    push @contigs, $contig if $contig;
}

if ($tagname) {
    $logger->info("Contig with tag $tagname to be processed");
    my $contig = $adb->getContig(withTag=>$tagname,
                       metaDataOnly=>$metadataonly);
    $logger->info("Contig $contig constructed");
    push @contigs, $contig if $contig;
}

if ($fofn) {
    foreach my $contig_id (@$fofn) {
        my $contig = $adb->getContig(id=>$contig_id,
                                     metaDataOnly=>$metadataonly);
        push @contigs, $contig if $contig;
    }
}

foreach my $contig (@contigs) {
    if ($metadataonly) {
        print STDOUT "\n";
        print STDOUT "Contig name = ".$contig->getContigName.
	             " (".$contig->getContigID.")\n";
        print STDOUT "Number of reads = ".$contig->getNumberOfReads.
                     " (new reads = ".$contig->getNumberOfNewReads.")\n";
        print STDOUT "Number of contigs = ".$contig->getNumberOfContigs."\n";
        print STDOUT "Consensus length = ".$contig->getConsensusLength."\n";
        print STDOUT "Average cover = ".$contig->getAverageCover."\n";
        print STDOUT "Origin = ".$contig->getOrigin."\n";
        if (my $pc = $contig->hasPreviousContigs) {
	    my $cs = $contig->getPreviousContigs;
            print STDOUT "Previous Contigs : ",$pc, " (@$cs)\n";
        }
        print STDOUT "\n";
    }
    elsif ($fasta) {
        $contig->writeToFasta(*STDOUT,*STDOUT);
    } 
    else {
        $contig->writeToCaf(*STDOUT); 
    }
}


#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

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
    print STDERR "-instance\teither 'prod' or 'dev' (default)\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-contig\t\tContig ID\n";
    print STDERR "-fofn\t\tfilename with list of contig IDs to be included\n";
    print STDERR "-fasta\t\tOutput in fasta format\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
