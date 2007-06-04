#!/usr/local/bin/perl -w

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

my $validKeys  = "organism|o|instance|i|project|p|pn|projectname|"
               . "assembly|a|project_id|pid|"
               . "owner|comment|verbose|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

 
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }  

    if ($nextword eq '-project' || $nextword eq '-p' || 
        $nextword eq '-projectname' ||  $nextword eq '-pn') {
        $projectname  = shift @ARGV;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly     = shift @ARGV;
    }

    if ($nextword eq '-project_id' || $nextword eq '-pid') {
        $project_id   = shift @ARGV;
    }

    $owner        = shift @ARGV  if ($nextword eq '-owner');

    $comment      = shift @ARGV  if ($nextword eq '-comment');

    $verbose      = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

&showUsage("Invalid data in parameter list: @ARGV") if @ARGV;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing projectname") unless $projectname;

if ($organism eq 'default' || $instance eq 'default') {
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

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# test if the current user has privilege to create a new project
#----------------------------------------------------------------

unless ($adb->userCanCreateProject()) {
# also tests if the user actually is known to this organism database 
    $logger->severe("Sorry, but you cannot create a new project "
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
    if (defined($owner)) {
        $logger->warning("Check if the intended owner user '$owner' exists");
    }
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    print STDERR "-projectname\tProject name (unique in an assembly)\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-project_id\tproject ID to be allocated (overrides autoincrement)\n";
    print STDERR "-assembly\tassembly name or ID to be used (default 1)\n";
    print STDERR "-owner\t\tAssign the new project to this user\n";
    print STDERR "-comment\tA comment in quotation marks\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code;
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
