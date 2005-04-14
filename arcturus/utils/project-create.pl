#!/usr/local/bin/perl5.6.1 -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $project_id;
my $projectname;
my $assembly_id;
my $comment;
my $verbose;

my $validKeys  = "organism|instance|project_id|projectname|assembly_id|"
               . "comment|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $project_id   = shift @ARGV  if ($nextword eq '-project_id');

    $assembly_id  = shift @ARGV  if ($nextword eq '-assembly_id');

    $comment      = shift @ARGV  if ($nextword eq '-comment');

    $projectname  = shift @ARGV  if ($nextword eq '-projectname');

    $verbose      = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage("Invalid data in parameter list") if @ARGV;

#&showUsage(0,"Missing project description") unless $comment;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing projectname") unless $projectname;

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $project = new Project();

$project->setProjectName($projectname);

$project->setProjectID($project_id) if defined($project_id);

$project->setAssemblyID($assembly_id) if defined ($assembly_id);

$project->setComment($comment) if $comment;

my ($pid,$status) = $adb->putProject($project);

$logger->warning("New project added with ID = $pid") if $pid;

$logger->severe("FAILED to add new project: $status") unless $pid;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "-projectname\tProject name (should be unique for assembly)\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-project_id\tproject ID to be inserted\n";
    print STDERR "-assembly_id\tassembly ID to be used (default 0)\n";
    print STDERR "-comment\tA comment in quotation marks\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
