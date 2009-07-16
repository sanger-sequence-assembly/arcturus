#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use FileHandle;
use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $username;
my $password;

my $contig;
my $parent;
my $offspring;
my $fofn;
my $cleanup = 0;
my $srparents;
my $mincid;
my $maxcid;
my $limit;
my $force;

my $cproject;
my $pproject;
my $assembly;

my $verbose;
my $confirm;

my $validKeys  = "help|organism|instance|username|password|contig|fofn|focn|"
               . "singlereadparents|srp|srplinked|srpunlinked|srpunlinkedall|mincid|"
               . "maxcid|project|childproject|cp|parentproject|pp|library|assembly|"
               . "offspring|limit|cleanup|parent|force|confirm|verbose";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
    if ($nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism = shift @ARGV;
    }

    if ($nextword eq '-username') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define username" if $username;
        $username = shift @ARGV;
    }

    $password     = shift @ARGV  if ($nextword eq '-password');

    $contig       = shift @ARGV  if ($nextword eq '-contig');
    $contig       = shift @ARGV  if ($nextword eq '-library');
    $parent       = shift @ARGV  if ($nextword eq '-parent');
    $parent       = $contig      if ($nextword eq '-library');

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');
    $fofn         = shift @ARGV  if ($nextword eq '-focn'); # alias

    $srparents    = 1            if ($nextword eq '-singlereadparents');
    $srparents    = 1            if ($nextword eq '-srp');         # all parents
    $srparents    = 2            if ($nextword eq '-srplinked');   # linked only
    $srparents    = 3            if ($nextword eq '-srpunlinked'); # unlinked only
    $srparents    = 4            if ($nextword eq '-srpunlinkedall'); # allow s-r children

    $mincid       = shift @ARGV  if ($nextword eq '-mincid');
    $maxcid       = shift @ARGV  if ($nextword eq '-maxcid');
    $limit        = shift @ARGV  if ($nextword eq '-limit');

    $force        = 1            if ($nextword eq '-force');

    $cproject     = shift @ARGV  if ($nextword eq '-project');
    $cproject     = shift @ARGV  if ($nextword eq '-childproject');
    $cproject     = shift @ARGV  if ($nextword eq '-cp');
    $pproject     = shift @ARGV  if ($nextword eq '-parentproject');
    $pproject     = shift @ARGV  if ($nextword eq '-pp');
    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $offspring    = 1            if ($nextword eq '-offspring');

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

&showUsage("Missing contig ID or fofn") unless (defined($contig) || $fofn || $srparents);

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
# MAIN
#----------------------------------------------------------------

my ($cpid,$ppid); # project IDs

if ($cproject) {
    my $cProject = &getProjectInstance($cproject,$assembly,$adb);
    &showUsage("Unknown project '$cproject'") unless $cProject;
    $cpid = $cProject->getProjectID();
}
 
if ($pproject) {
    my $pProject = &getProjectInstance($pproject,$assembly,$adb);
    &showUsage("Unknown project '$pproject'") unless $pProject;
    $ppid = $pProject->getProjectID();
} 

my @contigs;

my %options;

if ($srparents && $srparents > 0) {
# signal redundent input parameters
    if ($fofn) {
        $logger->warning("You cannot specify '-fofn' together "
                       . "with the '-singlereadparents' option");
        $logger->warning("'confirm' option reset to 'preview'") if $confirm;
        $confirm = 0;
    }
# obtain a list of single-read parents
    my %getoptions;
    $getoptions{linktype} = $srparents - 1;

    $getoptions{parent} = $parent if ($parent && $parent !~ /\D/);
    $getoptions{contig} = $contig if ($contig && $contig !~ /\D/);
    $getoptions{parentname} = $parent if ($parent && $parent =~ /\D/); 
    $getoptions{contigname} = $contig if ($contig && $contig =~ /\D/); 

    $getoptions{mincid} = $mincid if $mincid;
    $getoptions{maxcid} = $maxcid if $maxcid;
    $getoptions{project} = $cpid if $cpid; # child's project
    $getoptions{parentproject} = $ppid if $ppid;

    my $pids = $adb->getSingleReadParentIDs(%getoptions);

    $logger->warning(scalar(@$pids)." single read parents found");

    foreach my $contig (@$pids) {
        push @contigs, $contig;
    }
    $options{treatassinglereadparent} = 1;
    $options{forcedelete} = 1 if $force;
}
else {

#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------

    if ($fofn) {
# read list from file and add to @contigs
        $fofn = &getNamesFromFile($fofn);
        foreach my $contig (@$fofn) {
            push @contigs, $contig;
        }
    }

#----------------------------------------------------------------
# and/or collect contig IDs
#----------------------------------------------------------------

    if ($contig && $contig =~ /\,/) {
        @contigs = split /\,/,$contig;
    }
    elsif ($contig) {
        push @contigs, $contig;
    }
# possibly here range specifier?
}

# convert contig names into IDs (if names are provided)

foreach my $identifier (@contigs) {
    next if ($identifier !~ /\D/); # not a name, (possibly) a number
    my @readnames = ($identifier);
    my $list = $adb->getContigIDsForReadNames([@readnames]);
    unless ($list->[0]->[0] > 0) {
        $logger->warning("Contig $identifier not found; entry disabled");
        $identifier = 0;
	next;
    }
    $identifier = $list->[0]->[0];
}

# if offspring has to be removed: replace current contig_ids by offspring

if ($offspring) {
    my %offspring;
    $logger->info("Getting descendents for @contigs");
    foreach my $cid (@contigs) {
#        my $connected = $adb->getFamilyIDsForContigID($cid,descendants=>1);
        my $connected = $adb->getAncestorIDsForContigID($cid,descendants=>1);
        foreach my $contig_id (@$connected) {
            next if ($contig_id <= $cid);
            $logger->warning("offspring found of $cid : $contig_id");
            $offspring{$contig_id}++;
        }
    }
    @contigs = sort {$b <=> $a} keys %offspring;
}
    
$options{confirm} = 1 if $confirm;

# reverse sort for current contigs, query returns increasing order for single-read parents

@contigs = sort {$b <=> $a} @contigs unless $srparents;

my $delete = 0;
foreach my $contig_id (@contigs) {
    next unless ($contig_id > 0);
    $logger->warning("Contig $contig_id is to be deleted");
    my ($success,$msg) = $adb->deleteContig($contig_id,%options);
    if ($confirm) {
        $logger->severe("FAILED to remove contig $contig_id") unless $success;
        $logger->warning("Contig $contig_id is deleted") if $success;
        $delete++ if $success;
    }
    $logger->warning($msg);
    last if ($limit && $limit > 0 && $delete >= $limit);
}

$logger->warning("$delete contigs were removed from the database");
 
if ($confirm && $cleanup) {
    my $fullscan = $srparents;
    $fullscan = 1 unless @contigs; # run full scan when specified '-contig 0'
    $logger->warning("Cleaning up ... be patient");
    my $msg = $adb->cleanupMappings(confirm=>1,fullscan=>$fullscan);
    $logger->warning($msg);
}

elsif ($cleanup) { # not confirmed
    my $fullscan = $srparents;
    $fullscan = 1 unless @contigs; # run full scan when specified '-contig 0'
    my $msg = $adb->cleanupMappings(fullscan=>$fullscan);
    $logger->warning($msg); # print a preview
    $logger->warning("To do the deletes with cleanup: repeat and specify -confirm");
}

elsif (!$confirm) {  
    $logger->warning("Deletes to be made without cleanup; otherwise use -cleanup");
    $logger->warning("To do the delete: repeat and specify -confirm");
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
# identify project
#------------------------------------------------------------------------

sub getProjectInstance {
# returns Project given project ID or name and (optionally) assembly
# (also in case of project ID we consult the database to check its existence)
    my $identifier = shift;  # ID or name
    my $assembly = shift; # ID or name
    my $adb = shift;

    return undef unless defined($identifier);

# get project info by getting a Project instance

    my %projectoptions;
    $projectoptions{project_id}  = $identifier if ($identifier !~ /\D/);
    $projectoptions{projectname} = $identifier if ($identifier =~ /\D/);
    if (defined($assembly)) {
        $projectoptions{assembly_id}   = $assembly if ($assembly !~ /\D/);
        $projectoptions{assemblyname}  = $assembly if ($assembly =~ /\D/);
    }

# find the project and test if it is unique

    my ($Project,$log) = $adb->getProject(%projectoptions);
# test if any found
    unless ($Project && @$Project) {
        my $message = "No project $identifier found";
        $message .= " in assembly $assembly" if $projectoptions{assemblyname};
        $logger->warning("$message: $log");
        return undef;
    }
# test if project is unique; if not return undef
    if ($Project && @$Project > 1) {
        my $list = '';
        foreach my $project (@$Project) {
            $list .= $project->getProjectName()." ("
                   . $project->getAssemblyID().") ";
        }
        $logger->warning("More than one project found: $list");
        $logger->warning("Are you sure you do not need to specify assembly?")
            unless defined($assembly);
        return undef;
    }

    return $Project->[0] if $Project;

    return undef;
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
    print STDERR "-organism\tArcturus organism database\n" unless $organism;
    print STDERR "-instance\tArcturus database instance\n" unless $instance;
    print STDERR "-username\tArcturus user with delete privilege\n" unless $username;
    print STDERR "-password\tpassword of Arcturur DBA with delete privilege\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tContig ID or comma-separated list of \n";
    print STDERR "-fofn\t\tfilename with list of contig IDs to be deleted\n";
    print STDERR "-offspring\tremove descendants of the input contigs\n";
    print STDERR "\n";
    print STDERR "-srp\t\tdelete single-read parent contigs\n";
    print STDERR "-srplinked\tsame, excluding parents with missing links\n";
    print STDERR "-srpunlinked\tsame, including parents with links\n";
    print STDERR "-srpunlinkedall\tsame, include single-read children\n";
    print STDERR "-mincid\t\tminumum (child) contig ID\n";
    print STDERR "-maxcid\t\tmaxumum (child) contig ID\n";
    print STDERR "-childproject\tproject name or ID for child contigs\n";
    print STDERR "-parentproject\tproject name or ID for parent contigs\n";
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

