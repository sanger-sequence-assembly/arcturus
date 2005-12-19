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
my $assembly = 1; # default assembly ID
my $owner;
my $comment;
my $verbose;

my $validKeys  = "organism|instance|project_id|projectname|assembly|"
               . "owner|comment|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $project_id   = shift @ARGV  if ($nextword eq '-project_id');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $owner        = shift @ARGV  if ($nextword eq '-owner');

    $comment      = shift @ARGV  if ($nextword eq '-comment');

    $projectname  = shift @ARGV  if ($nextword eq '-projectname');

    $verbose      = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage("Invalid data in parameter list: @ARGV") if @ARGV;
 
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
# test if the current user has privilege to create a new project
#----------------------------------------------------------------

unless ($adb->userCanCreateProject()) {
# also tests if the user actually is known to this organism database 
    $logger->error("Sorry, but you cannot create a new project "
                  ."on this $organism database");
    $adb->disconnect();
    exit 1;
}

#----------------------------------------------------------------
# identify the assembly
#----------------------------------------------------------------

my ($Ary,$Assembly);
if ($assembly =~ /\D/) {
   ($Ary,$Assembly) = $adb->getAssembly(assemblyname => $assembly);
    undef $Assembly if ($Ary && @$Ary > 1); # ambiguous asssembly name
}
else {
    $Assembly = $adb->getAssembly(assembly_id => $assembly);
}

unless ($Assembly) {
    &showUsage("Assembly $assembly does not exist or is ambiguous");
    $adb->disconnect();
    exit 1;
}

my $assembly_id = $Assembly->getAssemblyID();

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $project = new Project();

$project->setProjectName($projectname);

$project->setProjectID($project_id) if defined($project_id);

$project->setAssemblyID($assembly_id);

$project->setOwner($owner) if defined($owner);

$project->setComment($comment) if $comment;

my $pid = $adb->putProject($project);

if ($pid) {
    $logger->warning("New project $projectname added with ID = $pid");
}
else {
    $logger->severe("FAILED to add new project $projectname");
    $logger->warning("Check if user '$owner' exists") if defined $owner;
}

$adb->disconnect();

exit 0;

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
    print STDERR "-project_id\tproject ID to be allocated (overrides autoincrement)\n";
    print STDERR "-assembly\tassembly name or ID to be used (default 1)\n";
    print STDERR "-owner\t\tAssign the new project to this user\n";
    print STDERR "-comment\tA comment in quotation marks\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
