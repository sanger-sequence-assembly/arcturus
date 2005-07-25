#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;


#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $verbose;
my $project;
my $assembly;
my $forced;
my $confirm;
my $fofn;

my $validKeys = "organism|instance|contig|fofn|project|assembly|"
              . "verbose|debug|confirm|force|preview|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig       = shift @ARGV  if ($nextword eq '-contig');

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $verbose      = 1            if ($nextword eq '-verbose');

    $verbose      = 2            if ($nextword eq '-debug');

    $confirm      = 1            if ($nextword eq '-confirm' && !defined($confirm));

    $forced       = 1            if ($nextword eq '-force');

    $confirm      = 0            if ($nextword eq '-preview');

    &showUsage(0,1) if ($nextword eq '-help'); # long write up
}

&showUsage("Missing contig ID, contigname or fofn") unless ($contig || $fofn);

&showUsage("Missing project ID or projectname") unless $project;
 
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

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
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

$logger->warning("Are you sure you do not need to specify assembly?") unless defined($assembly);

# get the contig (by ID or readname)

my @contigids;

if (defined($contig)) {

    if ($contig =~ /\,/) {
        push @contigids, split /\,/,$contig;
    }
    else {
        push @contigids, $contig;
    }
}

if ($fofn) {
    foreach my $contig (@$fofn) {
	next unless $contig;
        push @contigids, $contig;
    }
}

# determine selection by ID or by readname

my @contigs;
my $report = '';
foreach my $contigid (@contigids) {
    my $contig;
    next unless defined($contigid);
    if ($contigid =~ /\D/) {
	$contig = $adb->getContig(withRead=>$contigid,metaDataOnly=>1);
    }
    else {
	$contig = $adb->getContig(contig_id=>$contigid,metaDataOnly=>1);
    }
    $report .= "unidentified contig: $contigid\n" unless $contig;
    push @contigs,$contig if $contig;
    $logger->warning($adb->logQuery(1)) if ($verbose && $verbose > 1);
}

# get the project and assembly information (ID or name for both)

my %projectoptions;
$projectoptions{project_id}  = $project if ($project !~ /\D/);
$projectoptions{projectname} = $project if ($project =~ /\D/);
if (defined($assembly)) {
    $projectoptions{assembly_id}   = $assembly if ($assembly !~ /\D/);
    $projectoptions{assemblyname}  = $assembly if ($assembly =~ /\D/);
}

my ($Project,$log) = $adb->getProject(%projectoptions);
# test if any found
unless ($Project && @$Project) {
    my $message = "No project $project found";
    $message .= " in assembly $assembly" if $projectoptions{assemblyname};
    $logger->warning("$message: $log");
    $adb->disconnect();
    exit 0;
}
# test if not too many found
if (@$Project > 1) {
    my $list = '';
    foreach my $project (@$Project) {
	$list .= $project->getProjectName()." (".$project->getAssemblyID().") ";
    }
    &showUsage("More than one project found: $list");
}
    
$project = $Project->[0];

# execute if confirm switch set, else list 
  
if ($confirm) {

    my ($status,$message) = $adb->assignContigsToProject([@contigs],$project,$forced);
    $logger->warning("status $status:");
    $logger->warning($message);
}
else {
    $logger->warning("to be allocated to project "
                    .$project->getProjectName()
                    ." in assembly ".$project->getAssemblyID());
    foreach my $contig (@contigs) {
	$logger->warning($contig->toString());
    }
}
  
$adb->disconnect();

exit 0;

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
        next unless ($name =~ /\S/);
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;
    my $long = shift || 0;

    if ($long) {
     print STDERR "\n";
     print STDERR "Allocate contig(s) to a specified project, optionally in a\n";
     print STDERR "specified assembly\n\n";
     print STDERR "A contig can be specified on the command line by a number (ID)\n";
     print STDERR "or by the name of a read occurring in it; a list of contigs can\n";
     print STDERR "be presented in a file using the '-fofn' option\n\n";
     print STDERR "Both project and assembly can be specified with \n";
     print STDERR "a number (ID) or a name (i.e. not a number)\n\n";
     print STDERR "The allocation process tests the project locking status:\n";
     print STDERR "Contigs will only be (re-)allocated from their current\n";
     print STDERR "project (if any) to the new one specified, if BOTH the\n";
     print STDERR "current project AND the target project are not locked by\n";
     print STDERR "another user. Carefully check the results log!\n";
     print STDERR "\n";
     print STDERR "In default mode this script lists the contigs that it will\n";
     print STDERR "(try to) re-allocate. In order to actually make the change,\n";
     print STDERR "the '-confirm' switch must be used\n";
     print STDERR "\n";
     print STDERR "A special case is when a contig is already in a project\n"; 
     print STDERR "(possibly owned by another user) but not locked.\n";
     print STDERR "In default mode such contigs are NOT re-allocated (as a\n";
     print STDERR "protective measure) even if owned by yourself. In order to\n";
     print STDERR "reassign those contig(s), the '-force' switch must be used.\n";
     print STDERR "\n";
    }
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "-project\tproject ID or projectname\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID or contigname\n";
    print STDERR "-fofn\t\tfilename with list of contig IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or assemblyname\n";
    print STDERR "-confirm\t(no value) to execute on the database\n";
    print STDERR "-preview\t(no value) produce default listing (negates 'confirm')\n";
    print STDERR "-force\t\t(no value) to process contigs allocated to other users\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

