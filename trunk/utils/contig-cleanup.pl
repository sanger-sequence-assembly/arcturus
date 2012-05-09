#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use FileHandle;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $verbose;
my $debug;
my $commit;
my $focn;
my $caf;
my $group;
my $minimum = 2;
my $readid;
my $asped;
my $limit = 1;

my $contamination;

my $validKeys  = "organism|o|instance|i|contig|focn|fofn|current|cc|"
               . "lowqualityreads|lqr|shortreads|sr|minimum|deletereads|dr|aspedbefore|ab|"
#               . "username|password|"
               . "contamination|status|caf|"
               . "limit|commit|info|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
# the next die statement prevents redefinition when used with e.g. a wrapper script

    if ($nextword eq '-i' || $nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-o' || $nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism  = shift @ARGV;
    }

    $contig       = shift @ARGV  if ($nextword eq '-contig');
    $contig       = 'current'    if ($nextword eq '-current');
    $contig       = 'current'    if ($nextword eq '-cc');

    $focn         = shift @ARGV  if ($nextword eq '-focn');
    $focn         = shift @ARGV  if ($nextword eq '-fofn');

    $caf          = shift @ARGV  if ($nextword eq '-caf');

    if ($nextword eq '-sr'  || $nextword eq '-shortreads') {
        $group    = 1;
    }
    if ($nextword eq '-lqr' || $nextword eq '-lowqualityreads') {
        $group    = 2;
    }
    if ($nextword eq '-dr'  || $nextword eq '-deletereads') {
        $readid   = shift @ARGV;
        $group    = 3;
    }
    if ($nextword eq '-ab'  || $nextword eq '-aspedbefore') {
        $asped    = shift @ARGV;
        $group    = 4;
    }


    if ($nextword eq '-status'  || $nextword eq '-contamination') {
        $contamination = 1            if ($nextword eq '-contamination');
        $contamination = shift @ARGV  if ($nextword eq '-status');
        $group    = 5;
    }

    $limit         = shift @ARGV  if ($nextword eq '-limit');

    $minimum       = shift @ARGV  if ($nextword eq '-minimum');

    $verbose       = 1            if ($nextword eq '-verbose');

    $verbose       = 2            if ($nextword eq '-info');

    $debug         = 1            if ($nextword eq '-debug');

    $commit        = 1            if ($nextword eq '-commit');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter($verbose) if $verbose; # set reporting level

$logger->setBlock('debug',unblock=>1) if $debug;

$logger->setSpecialStream('problemcontigs.lis',list=>1);

Contig->setLogger($logger);
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing contig identifier or focn") unless ($contig || $focn);

&showUsage("Missing read group specification") unless $group;

if ($organism && $organism eq 'default' ||
    $instance && $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
                                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message

    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Organism '$organism' not found on server '$instance'");
}

$adb->setLogger($logger);
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get the contig(s)
#----------------------------------------------------------------

my $cids;

if ($contig && $contig eq 'current') {
    $cids = $adb->getCurrentContigIDs();
}
else {
    $cids = &getContigIdentifiers($contig,$focn,$adb);
}

&showUsage("No valid contig identifier provided") unless @$cids;


my $CAF;
if ($caf) {
    $CAF = new FileHandle($caf,'w');
    unless ($CAF) {
	$logger->severe("Failed to open caf file $caf");
        exit 1;
    }
}

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %loadoptions = (noload=>1,setprojectby=>'readcount');

$loadoptions{noload} = 0 if $commit;

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
        $contig = $contig->removeShortReads(%option);
    }
    elsif ($group == 2) {
        $contig = $contig->removeLowQualityReads();
    }
    elsif ($group == 3) {
        my @reads = split /\,/,$readid;
        $logger->info("reads to be removed: @reads");       
       ($contig,$msg) = $contig->removeNamedReads([@reads]);
        $logger->info("contig status returned: $msg");
    }
    elsif ($group == 4) {
       ($contig,$msg) = &removeaspedbeforereads($contig,$asped);
    }
    elsif ($group == 5) {
       ($contig,$msg) = &removefailedreads($contig,$contamination);
    }
    elsif ($group == 6) {
        $contig = $contig->undoReadEdits();
    }

    unless ($contig) {
        $msg = 'no further info available';
        $logger->severe("No valid contig returned for $identifier: $msg");
        next;
    }

# present the contig to the database

    $logger->info("Testing/loading contig $contig");

    unless ($contig->isValid(forimport=>1)) {
        $logger->special($contig->getContigID());
        $logger->warning("bad contig $contig after processing :");
        $logger->warning($contig->{status});
        $contig->writeToCaf($CAF) if $CAF;
        last unless --$limit;
	next;
    }

   (my $added,$msg) = $adb->putContig($contig, $projects->[0], %loadoptions);

    if ($added) {
        if ($loadoptions{noload}) {
   	    $logger->warning("Contig tested but not added : $msg");
	}
	else {
   	    $logger->warning("Contig added $added : $msg");
	}
    }
    elsif ($loadoptions{noload}) {
	$logger->warning("Contig tested but not added : $msg");
        $logger->warning("To load this contig: repeat with '-commit'");
    }
    else {
        $logger->severe("Failed to add contig : $msg");
# record empty contigs: they should be deleted or moved?
    }

    last unless --$limit;
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub removeaspedbeforereads {
    my $contig = shift;
    my $asped = shift;

    $logger->warning( "removing asped before $asped reads "
                    . $contig->getContigName() . " with " 
                    . $contig->getNumberOfReads() . " reads");

    $asped =~ s/\D//g;

    my $reads = $contig->getReads(1);
    my @toberemoved;
    foreach my $read (@$reads) {
        my $aspdate = $read->getAspedDate() || 0; # or on special log?
        $aspdate =~ s/\D//g;
        next unless ($aspdate && $aspdate < $asped);
        $logger->warning( "remove ".$read->getReadName()." $aspdate  ($asped)" );
        push @toberemoved,$read->getReadName();        
    }

#    return 0,"no reads were removed" unless @toberemoved;
    return $contig,"no reads were removed" unless @toberemoved;

    my ($status,$msg) = $contig->removeNamedReads([@toberemoved]); # force?
    $logger->warning("contig status returned: $msg");
    return $status,$msg; # undef for failure
}

sub removefailedreads {
    my $contig = shift;
    my $status = shift;

    $logger->warning( "removing reads with status >= $status "
                    . $contig->getContigName() . " with " 
                    . $contig->getNumberOfReads() . " reads");

    my %statushash = (PASS => 1            , QUAL => 2,
                      SVEC => 3            , CONT => 4,
                      'CONT BIG1' => 5     , 'CONT BIG1 QUAL' => 6,
                      'CONT BIG1 SVEC' => 7, 'CONT BIG1' => 8); 

    my $reads = $contig->getReads(1);
    my @toberemoved;
    foreach my $read (@$reads) {
        my $processstatus = $read->getProcessStatus() || 0;
        my $readstatus = $statushash{$processstatus} || $processstatus;
        next unless ($readstatus && $readstatus >= $status);

        $logger->warning( "remove ".$read->getReadName()." '$processstatus',$readstatus  ($status)" );
        push @toberemoved,$read->getReadName();        
    }

    return $contig,"no reads were removed" unless @toberemoved;

    my ($returncontig,$msg) = $contig->removeNamedReads([@toberemoved]); # force?
    $logger->warning("contig status returned: $msg");
    return $returncontig,$msg; # undef for failure
}

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
    print STDERR "-ab\t\t(asped before) reads asped before a certain date\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\tfile for output of problem contigs (split)\n";
    print STDERR "-limit\t\tnumber of contigs to process from input list\n";
    print STDERR "\n";
    print STDERR "-minimum\tminimum short read length required (with shortreads)\n";
    print STDERR "\n";
    print STDERR "-commit\t\t(no value) \n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

