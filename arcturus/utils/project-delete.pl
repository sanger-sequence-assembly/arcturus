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


else {
    my $project = shift @$projects;
    $logger->info($project->toStringLong); # project info if verbose

    my %options;
    $options{confirm} = 1 if $confirm;
         
    my ($success,$message) = $adb->deleteProject($project,%options);

    $logger->skip();
    if ($success == 2) {
        $logger->warning($message);
    }
    elsif ($success == 1) {
        $logger->warning($message." (=> use '-confirm')");
    }
    else {
        $logger->warning("FAILED to delete the project: ".$message);
    }
    $logger->skip();
}

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Delete a project. Project to be specified with ID or ";
    print STDERR "project name [& assembly].\nThe project must be empty and ";
    print STDERR "you must be able to acquire a lock on the project\n";
    print STDERR "i.e. the project is either unlocked or you own the lock; if ";
    print STDERR "you do not own\nthe lock, acquire it with 'project-lock'";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance && $project) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
    }
    unless ($organism && $instance) {
        print STDERR "-organism\tArcturus database name\n"  unless $organism;
        print STDERR "-instance\t'prod', 'dev' or 'test'\n" unless $instance;
        print STDERR "\n";
    }
    unless ($project) {
        print STDERR "-project\tproject identifier (ID or name)\n";
        print STDERR "\n";
    }
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code;
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
