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
my $project; # = 20884;
my $batch;
my $nolock; # default export only unlocked projects (acquirelock = 1)
my $padded;
my $fasta;
my $fofn;
my $FileDNA;
my $FileQTY;

my $validKeys  = "organism|instance|project|fofn|padded|fasta|"
               . "FDNA|FQTY|nolock|batch|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(1,"Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $project   = shift @ARGV  if ($nextword eq '-project');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-debug');

    $padded    = 1            if ($nextword eq '-padded');

    $fasta     = 1            if ($nextword eq '-fasta');

    $FileDNA   = shift @ARGV  if ($nextword eq '-FDNA');

    $FileQTY   = shift @ARGV  if ($nextword eq '-FQTY');

    $nolock    = 1            if ($nextword eq '-nolock');

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

&showUsage("Missing project ID or name") unless ($project || $fofn);

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

$logger->warning("Redundant '-padded' key ignored") if ($padded && $fasta);

# get file handles

$FileDNA = new FileHandle($FileDNA,"w") if $FileDNA;
$FileDNA = *STDOUT unless $FileDNA;

$FileQTY = new FileHandle($FileQTY,"w") if $FileQTY;

# get project(s) to be exported

my @projects;

push @projects, $project if $project;
 
if ($fofn) {
    foreach my $project (@$fofn) {
        push @projects, $project if $project;
    }
}

my %exportoptions;
$exportoptions{padded} = 1 if $padded;
$exportoptions{nolock} = 1 if $nolock;

foreach my $project (@projects) {

    my $Project;

    $Project = $adb->getProject(project_id=>$project) if ($project !~ /\D/);

    $Project = $adb->getProject(projectname=>$project) if ($project =~ /\D/);

    $logger->info("Project returned: $Project");

    next if (!$Project && $batch); # skip error (possible) message

    $logger->warning("Unknown project $project") unless $Project;

    next unless $Project;

    my ($s,$m);

    ($s,$m) = $Project->writeContigsToCaf($FileDNA,\%exportoptions) unless $fasta;

    ($s,$m) = $project->writeToFasta($FileDNA,$FileQTY,\%exportoptions) if $fasta;

    $logger->warning($m) unless $s; # no contigs exported

    $logger->info("$s contigs exported for project $project") if $s;
}

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n\nExport (contigs in) project(s) by ID/name or using a fofn with IDs or names\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n\n";
    print STDERR "either -contig_id or -fofn :\n\n";
    print STDERR "-project\tProject ID or name\n";
    print STDERR "-fofn \t\tname of file with list of project IDs or names\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "The default export is in CAF on STDOUT\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' (default) or 'dev'\n";
    print STDERR "-padded\t\t(no value) export contigs in padded format\n";
    print STDERR "-fasta\t\t(no value) export contigs in fasta format\n";
    print STDERR "-FDNA\t\tfile name for output (overrides default; DNA if fasta)\n";
    print STDERR "-FQTY\t\tfile name for quality data (with fasta only)\n";
    print STDERR "\n";
    print STDERR "Default setting exports only projects which either have\n";
    print STDERR "the unlocked status or are owned by the user\n";
    print STDERR "\n";
    print STDERR "-nolock\t\t(no value) export all contigs\n";
    print STDERR "\n";
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
