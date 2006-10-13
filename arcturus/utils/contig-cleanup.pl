#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use ContigFactory::ContigFactory;

use FileHandle;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $verbose;
my $confirm;
my $focn;
my $group;
my $minimum = 2;
my $readid;
my $force = 0;

my $validKeys  = "organism|instance|contig|focn|fofn|current|cc|"
               . "lowqualityreads|lqr|shortreads|sr|minimum|deletereads|dr|"
#               . "username|password|"
               . "force|confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
# the next die statement prevents redefinition when used with e.g. a wrapper script

    die "You can't re-define instance" if ($instance && $nextword eq '-instance');
 
    $instance     = shift @ARGV  if ($nextword eq '-instance');

    die "You can't re-define organism" if ($organism && $nextword eq '-organism');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig       = shift @ARGV  if ($nextword eq '-contig');
    $contig       = 'current'    if ($nextword eq '-current');
    $contig       = 'current'    if ($nextword eq '-cc');

    $focn         = shift @ARGV  if ($nextword eq '-focn');
    $focn         = shift @ARGV  if ($nextword eq '-fofn');

    if ($nextword eq '-shortreads' || $nextword eq '-sr') {
        $group    = 1;
    }
    if ($nextword eq '-lowqualityreads' || $nextword eq '-lqr') {
        $group    = 2;
    }
    if ($nextword eq '-deletereads' || $nextword eq '-dr') {
        $readid   = shift @ARGV;
        $group    = 3;
    }

    $minimum      = shift @ARGV  if ($nextword eq '-minimum');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm');

    $force        = 1            if ($nextword eq '-force');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level

ContigFactory->logger($logger);
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig identifier or focn") unless ($contig || $focn);

&showUsage("Missing read group specification") unless $group;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get the contig(s)
#----------------------------------------------------------------

my $cids;

if ($contig eq 'current') {
    $cids = $adb->getCurrentContigIDs();
}
else {
    $cids = &getContigIdentifiers($contig,$focn,$adb);
}

&showUsage("No valid contig identifier provided") unless @$cids;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %options;

$options{confirm} = 1 if $confirm;

my %loadoptions = (noload=>1,setprojectby=>'readcount');
$loadoptions{noload} = 0 if $confirm;

foreach my $identifier (@$cids) {

    $logger->warning("Processing contig $identifier");

# identifer can be a number or the name of a read in it

    if ($identifier =~ /\D/) {
        $contig = $adb->getContig(withRead=>$identifier,metadataonly=>1);
    }
    else {
        $contig = $adb->getContig(contig_id=>$identifier,metadataonly=>1);
    }

# test existence

    unless ($contig) {
	$logger->severe("Contig $identifier not found");
	next;
    }

# test if current generation

    my $contig_id = $contig->getContigID();

    unless ($adb->isCurrentContigID($contig_id)){
	$logger->severe("Contig $identifier ($contig_id) is not a current contig");
        next;
    }

    my $project_id = $contig->getProject(); 
    my ($projects,$status) = $adb->getProject(project_id=>$project_id);
    if ($projects->[0] && $status eq 'OK') {
        my $projectname = $projects->[0]->getProjectName();
        $logger->warning("Project $projectname found for ID $project_id");
    }
    else {
       ($projects,$status) = $adb->getProject(projectname=>'BIN');
    }
    
    $logger->info("Checking mappings");

    $contig->getMappings(1); # delayed loading

    $logger->info("Checking reads");

    $contig->getReads(1); # delayed loading

    my $msg = '';
    if ($group == 1) {
        my %option = (threshold => $minimum-1);
	$logger->info("Removing short reads (length < $minimum)");
        $contig = ContigFactory->removeShortReads($contig,%option);
    }
    elsif ($group == 2) {
        $contig = ContigFactory->removeLowQualityReads($contig);
    }
    elsif ($group == 3) {
        my %option = (force => $force);
        my @reads = split /\D/,$readid;        
       ($contig,$msg) = ContigFactory->deleteReads($contig,[@reads],%option);
        $logger->info("contig status returned: $msg");
    }

    unless ($contig) {
        $logger->severe("No valid contig returned for $identifier: $msg");
        next;
    }

# present the contig to the database

    $logger->info("Testing/loading contig $contig");

   (my $added,$msg) = $adb->putContig($contig, $projects->[0], %loadoptions);

    if ($added) {
	$logger->warning("Contig added $added : $msg");
    }
    elsif ($loadoptions{noload}) {
	$logger->warning("Contig tested but not added : $msg");
        $logger->warning("To load this contig: repeat with '-confirm'");
    }
    else {
        $logger->severe("Failed to add contig : $msg");
    }
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
            print STDERR "Invalid input on focn: $record\n";
        }
    }
    return [@list];
}

#------------------------------------------------------------------------

sub getContigIdentifiers {
# ad hoc routine, returns contig IDs specified with $contig, $focn or both
    my $contig = shift; # contig ID, name or comma-separated list of these
    my $focn = shift; # filename
    my $adb = shift; # database handle

    my @contigs;

    if ($contig || $focn) {
# get contig identifiers in array
        if ($contig && $contig =~ /\,/) {
            @contigs = split /\,/,$contig;
        }
        elsif ($contig) {
            push @contigs,$contig;
        }
# add possible info from file with names
        if ($focn) {
            $focn = &getNamesFromFile($focn);
            push @contigs,@$focn;
        }
    }

# translate (possible) contig names into contig IDs

    my @cids;

    foreach my $contig (@contigs) {

        next unless $contig;

# identify the contig if a name is provided

        if ($contig =~ /\D/) {
# get contig ID from contig name
            my $contig_id = $adb->hasContig(withRead=>$contig);
# test its existence
            unless ($contig_id) {
                $logger->warning("contig with read $contig not found");
                next;
            }
            $contig = $contig_id;
        }
        push @cids,$contig;
    }
    return [@cids];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "Mothball (retire) a contig or contigs\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tarcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
        print STDERR "\n";
    }
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID or name of a read occurring in it\n";
    print STDERR "-focn\t\tfilename with list of contig IDs or read names\n";
    print STDERR "-current\t(cc) all current contigs\n";
    print STDERR "\n";
    print STDERR "-deletereads\t(dr) remove read or comma-separated list of reads\n";
    print STDERR "-shortreads\t(sr) remove reads with short mapping length\n";
    print STDERR "-lqr\t\t(lowqualityreads) as it says \n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-minimum\tminimum short read length required (with shortreads)\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

