#!/usr/local/bin/perl5.6.1 -w

use strict;

use ArcturusDatabase;

use Project;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $project;
my $assembly;
my $contig;
my $generation = 'current';
my $verbose;
my $longwriteup;
my $includeempty;

my $validKeys  = "organism|instance|project|assembly|contig|"
               . "full|long|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $generation   = shift @ARGV  if ($nextword eq '-generation');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $contig       = shift @ARGV  if ($nextword eq '-contig');

    $longwriteup  = 1            if ($nextword eq '-long');

    $verbose      = 1            if ($nextword eq '-verbose');

    $includeempty = 1            if ($nextword eq '-full');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage("Invalid data in parameter list") if @ARGV;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Organism '$organism' not found on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %options;

if (defined($contig)) {
    $options{contig_id}  = $contig    if ($contig !~ /\D/ && $contig !~ /\,/);
    $options{contigname} = $contig    if ($contig =~ /\D/ && $contig !~ /\,/);
    $options{contig_id}  = [split /,/,$contig] if ($contig =~ /\,/);
    $longwriteup = 1;
}
$options{project_id}   = $project  if (defined($project) && $project !~ /\D/);
$options{projectname}  = $project  if ($project && $project =~ /\D/);
$options{assembly_id}  = $assembly if (defined($assembly) && $assembly !~ /\D/);
$options{assemblyname} = $assembly if ($assembly && $assembly =~ /\D/);

my @projects;

if (keys %options > 0) {
    $options{binautoload} = 0;
    my ($Project,$status) = $adb->getProject(%options);
    $logger->warning("Failed to find project: $status") unless $Project;
    push @projects, $Project  if (ref($Project) eq 'Project');
    push @projects, @$Project if (ref($Project) eq 'ARRAY');
}

unless (@projects || keys %options) {

    my %ioptions;
    $ioptions{assembly} = $assembly if defined($assembly);
    $ioptions{includeempty} = 1 if $includeempty; # list also empty projects
    my $project_ids = $adb->getProjectInventory(%ioptions);

    my $bin_project;
    foreach my $pid (@$project_ids) {
        my ($Project,$status) = $adb->getProject(project_id=>$pid);
        $logger->warning("Failed to find project $pid") unless @$Project;
        next unless ($Project && @$Project);
        $bin_project = $Project->[0] unless $pid; # register project with pid=0
        push @projects, @$Project;
    }
# add unallocated
    unless ($bin_project) {
        $bin_project = new Project();
        $bin_project->setArcturusDatabase($adb);
        $bin_project->setComment("unallocated");
        $bin_project->setProjectName("the bin");
        push @projects,$bin_project;
    }
}

if (@projects && !$longwriteup) {
    print STDOUT "\nProject inventory for database $organism ";
    print STDOUT "(assembly $assembly) " if defined($assembly);
    print STDOUT ":\n\n  nr as name     contigs    reads  "
               . "sequence   largest  owner    locked comment\n\n";
}

foreach my $project (@projects) {
    next if ($project->getProjectName() eq 'the bin' && !$project->getNumberOfContigs());
    print STDOUT $project->toStringShort() unless $longwriteup; 
    print STDOUT $project->toStringLong()  if $longwriteup; 
}
print STDOUT "\n";

my $hangingprojectids = $adb->getHangingProjectIDs();

if ($hangingprojectids && @$hangingprojectids) {
    print STDOUT "WARNING: there are hanging project IDs (referenced in"
               . " CONTIG but not in PROJECT):\n @$hangingprojectids\n\n";
} 

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\nProject Inventory listing (default: having contigs)\n\n";
    print STDERR "Parameter input ERROR: $code \n\n" if $code; 
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL EXCLUSIVE PARAMETER:\n";
    print STDERR "\n";
    print STDERR "-contig\tcontig or name ID\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-project\tproject ID or name\n";
    print STDERR "-assembly\tassembly ID or name (default 0)\n";
    print STDERR "\n";
    print STDERR "LIST OPTIONS:\n";
    print STDERR "\n";
    print STDERR "-long\t\t(no value) for long write up\n";
    print STDERR "-full\t\t(no value) to include empty projects\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
