#!/usr/local/bin/perl5.6.1 -w

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
my $projectname;
my $project_id;
my $generation = 'current';
my $verbose;

my $validKeys  = "organism|instance|projectname|project_id|generation|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $generation   = shift @ARGV  if ($nextword eq '-generation');

    $projectname  = shift @ARGV  if ($nextword eq '-projectname');

    $project_id   = shift @ARGV  if ($nextword eq '-project_id');

    $verbose      = 1            if ($nextword eq '-verbose');

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
if ($projectname) {
    my $project = $adb->getProject(projectname=>$projectname);
    $logger->warning("Failed to find project $projectname") unless $project;
    push @projects, $project if $project;
}

if ($project_id) {
    my $project = $adb->getProject(project_id=>$project_id);
    $logger->warning("Failed to find project $project_id") unless $project;
    push @projects, $project if $project;
}

unless (@projects) {

    my $output = $adb->getProjectInventory(generation=>$generation);
    &showUsage("Invalid input $generation") unless $output;

    print STDOUT "\nProject inventory ($generation generation) :\n\n". 
                 " nr Project      Contigs   Reads  ".
                 "Total lgt  Average     Mean   Maximum \n";
    foreach my $line (@$output) {
        printf STDOUT ("%3d %-12s %7d %7d  %9d %8d %8d %9d\n",@$line);
    }
    print STDOUT "\n";
}

$adb->disconnect();

foreach my $project (@projects) {
    print $project->toString;
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
    print STDERR "-projectname\tProject name\n";
    print STDERR "-project_id\tProject ID\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
