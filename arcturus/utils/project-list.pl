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
my $project_id;
my $contig_id;
my $generation = 'current';
my $verbose;
my $longwriteup;
my $include;

my $validKeys  = "organism|instance|project_id|contig_id|"
               . "full|long|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $generation   = shift @ARGV  if ($nextword eq '-generation');

    $project_id   = shift @ARGV  if ($nextword eq '-project_id');

    $contig_id    = shift @ARGV  if ($nextword eq '-contig_id');

    $longwriteup  = 1            if ($nextword eq '-long');

    $verbose      = 1            if ($nextword eq '-verbose');

    $include      = 1            if ($nextword eq '-full');

    &showUsage(0) if ($nextword eq '-help');
}

#&showUsage(0,"Missing project name") unless $projectname;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'dev' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my @projects;

if ($contig_id) {
    my $project = $adb->getProject(contig_id=>$contig_id);
    $logger->warning("Failed to find project for contig $contig_id") unless $project;
    push @projects, $project if $project;
    $longwriteup = 1;
}

if ($project_id) {
    my $project = $adb->getProject(project_id=>$project_id);
    $logger->warning("Failed to find project $project_id") unless $project;
    push @projects, $project if $project;
}
elsif (defined($project_id)) { # = 0
# create new project to access unallocated contigs
    my $project = new Project();
    $project->setArcturusDatabase($adb);
    $project->setComment("Unallocated contigs");
    push @projects, $project;
}

unless (@projects || $project_id || $contig_id) {

    my $project_ids = $adb->getProjectInventory($include);

    foreach my $pid (@$project_ids) {
        my $project = $adb->getProject(project_id=>$pid);
        $logger->warning("Failed to find project $pid") unless $project;
        push @projects, $project if $project;
    }
# add unallocated
    my $project = new Project();
    $project->setArcturusDatabase($adb);
    $project->setComment("unallocated contigs");
    push @projects,$project;
}

if (@projects && !$longwriteup) {
    print STDOUT "\nProject inventory for database $organism:\n\n" 
               . "  nr name or comment          contigs   reads  "
               . "sequence   contig    owner locked\n\n";
}

foreach my $project (@projects) {
    print STDOUT $project->toStringShort() unless $longwriteup; 
    print STDOUT $project->toStringLong()  if $longwriteup; 
}
print STDOUT "\n";

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nProject Inventory listing\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' or 'dev' (default)\n";
    print STDERR "\n";
    print STDERR "-project_id\tproject ID (if not specified: all)\n";
    print STDERR "-long\t\t(no value) for long write up\n";
    print STDERR "-full\t\t(no value) to include empty projects\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
