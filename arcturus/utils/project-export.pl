#!/usr/local/bin/perl -w

use strict;

use FileHandle;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $project;
my $batch;
my $lock;
my $padded;
my $output;
my $fofn;
my $caffile;
my $fastafile;
my $qualityfile;

my $validKeys  = "organism|instance|project|fofn|padded|fasta|"
               . "caf|quality|lock|batch|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance    = shift @ARGV  if ($nextword eq '-instance');
      
    $organism    = shift @ARGV  if ($nextword eq '-organism');

    $project     = shift @ARGV  if ($nextword eq '-project');

    $fofn        = shift @ARGV  if ($nextword eq '-fofn');

    $verbose     = 1            if ($nextword eq '-verbose');

    $verbose     = 2            if ($nextword eq '-debug');

    $padded      = 1            if ($nextword eq '-padded');

    $fastafile   = shift @ARGV  if ($nextword eq '-fasta');
    $caffile     = shift @ARGV  if ($nextword eq '-caf');

    $qualityfile = shift @ARGV  if ($nextword eq '-quality');

    $lock        = 1            if ($nextword eq '-lock');

    $batch       = 1            if ($nextword eq '-batch');

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

&showUsage("Missing server instance") unless $instance;

&showUsage("Missing CAF or FASTA output file name") unless (defined($fastafile) || defined($caffile));

&showUsage("Missing project ID or name") unless (defined($project) || $fofn);

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

$logger->warning("Redundant '-padded' key ignored") if $padded;

# get file handles

my $fhCAF;
my $fhFASTA;
my $fhQuality;

if (defined($caffile)) {
    $fhCAF = new FileHandle($caffile, "w");
    &showUsage("Failed to create CAF output file \"$caffile\"") unless $fhCAF;
}

if (defined($fastafile)) {
    $fhFASTA = new FileHandle($fastafile, "w");
    &showUsage("Failed to create FASTA sequence output file \"$fastafile\"") unless $fhFASTA;

    if (defined($qualityfile)) {
	$fhQuality = new FileHandle($qualityfile, "w");
	&showUsage("Failed to create FASTA quality output file \"$qualityfile\"") unless $fhQuality;
    }
}

# get project(s) to be exported

my @projects;

$project = 0 if (defined($project) && $project eq 'BIN');

push @projects, $project if defined($project);
 
if ($fofn) {
    foreach my $project (@$fofn) {
        push @projects, $project if $project;
    }
}

my %exportoptions;
$exportoptions{'padded'} = 1 if $padded;
$exportoptions{'acquirelock'} = 1 if $lock;

foreach my $project (@projects) {

    my $Project;

    $Project = $adb->getProject(project_id=>$project) if ($project !~ /\D/);

    $Project = $adb->getProject(projectname=>$project) if ($project =~ /\D/);

    $logger->info("Project returned: ".($Project|'undef'));

    next if (!$Project && $batch); # skip error (possible) message

    $logger->warning("Unknown project $project") unless $Project;

    next unless $Project;

    my ($s,$m);

    ($s,$m) = $Project->writeContigsToCaf($fhCAF, \%exportoptions) if $fhCAF;

    ($s,$m) = $Project->writeContigsToFasta($fhFASTA, $fhQuality, \%exportoptions) if $fhFASTA;

    $logger->warning($m) unless $s; # no contigs exported

    $logger->info("$s contigs exported for project $project") if $s;
}

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Export contigs in project(s) by ID/name or using a fofn with IDs or names\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-caf\t\tCAF output file name\n";
    print STDERR "-fasta\t\tFASTA sequence output file name\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-project\tProject ID or name\n";
    print STDERR "-fofn\t\tname of file with list of project IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-quality\tFASTA quality output file name\n";
    print STDERR "-padded\t\t(no value) export contigs in padded (caf) format\n";
    print STDERR "\n";
#    print STDERR "Default setting exports only projects which are either \n";
#    print STDERR "unlocked or are owned by the user running this script\n";
    print STDERR "Default setting exports all contigs in project\n";
    print STDERR "Using a lock check, only projects which either are unlocked \n"
               . "or are owned by the user running this script are exported, \n"
               . "while those project(s) will have a lock status set\n\n";
    print STDERR "-lock\t\t(no value) acquire a lock on the project and , if "
                . "successful,\n\t\t\t   export its contigs\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
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
