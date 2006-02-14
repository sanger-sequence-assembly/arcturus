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
my $username;
my $password;
my $project;
my $assembly;
my $generation = 'current';
my $confirm;
my $verbose;

my $validKeys  = "organism|instance|username|password|project|assembly|"
               . "confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $username     = shift @ARGV  if ($nextword eq '-username');

    $password     = shift @ARGV  if ($nextword eq '-password');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $confirm      = 1            if ($nextword eq '-confirm');

    $verbose      = 1            if ($nextword eq '-verbose');

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

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing project name or ID") unless $project;

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

$logger->info("Database ".$adb->getURL." opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------
 
my %options;
 
$options{project_id}  = $project if ($project !~ /\D/);
$options{projectname} = $project if ($project =~ /\D/);
 
if (defined($assembly)) {
    $options{assembly_id}  = $assembly if ($assembly !~ /\D/);
    $options{assemblyname} = $assembly if ($assembly =~ /\D/);
}
 
my ($projects,$message) = $adb->getProject(%options);
 
if ($projects && @$projects > 1) {
    my @namelist;
    foreach my $project (@$projects) {
        push @namelist,$project->getProjectName();
    }
    $logger->warning("Non-unique project specification : $project (@namelist)");
    $logger->warning("Perhaps specify the assembly ?") unless defined($assembly);
}
elsif (!$projects || !@$projects) {
    $logger->warning("Project $project not available : $message");
}
elsif ($confirm) {
    my $pid = $projects->[0]->getProjectID();
    my $aid = $projects->[0]->getAssemblyID();
    my ($status,$message) = $adb->deleteProject(project_id => $pid,
                                               assembly_id => $aid);
    $logger->warning($message);
}
else {
    $project = shift @$projects;
    if (my $status = $project->getLockedStatus()) {
        $logger->warning("Project " . $project->getProjectName() .
                         " is locked by user " . $project->getOwner());
    }
    $logger->warning("Project " . $project->getProjectName() .
                     " will be deleted : please confirm");
}

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\nDelete a project\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "-project\tproject ID or name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
