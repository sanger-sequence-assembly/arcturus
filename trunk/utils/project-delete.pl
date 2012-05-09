#!/usr/local/bin/perl -w

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

my $validKeys  = "organism|o|instance|i|project|o|assembly|a|"
               . "username|password|"
               . "confirm|verbose|help|h";

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

    if ($nextword eq '-project'  || $nextword eq '-p') {
        $project      = shift @ARGV;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly     = shift @ARGV;
    }

    $username     = shift @ARGV  if ($nextword eq '-username');

    $password     = shift @ARGV  if ($nextword eq '-password');

    $confirm      = 1            if ($nextword eq '-confirm');

    $verbose      = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing project name or ID") unless $project;

&showUsage("Missing arcturus username") unless $username;

&showUsage("Missing arcturus password") unless $password;

if ($organism eq 'default' || $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism,
                                -username => $username,
                                -password => $password);

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

$adb->setLogger($logger);

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
    $logger->warning("Project $project not available : $message",ss=>1);
}

else {
    my $project = shift @$projects;
    $logger->info($project->toStringLong); # project info if verbose

    my %options;
    $options{confirm} = 1 if $confirm;
         
    my ($success,$message) = $adb->deleteProject($project,%options);

    if ($success == 2) {
        $logger->warning($message,ss=>1);
    }
    elsif ($success == 1) {
        $logger->warning($message." (=> use '-confirm')",ss=>1);
    }
    else {
        $logger->warning("FAILED to delete the project: ".$message,ss=>1);
    }
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
    print STDERR "you do not own\nthe lock, acquire it with 'project-lock\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance && $project && $username && $password) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
    }
    unless ($organism && $instance) {
        print STDERR "-organism\tArcturus database name\n"  unless $organism;
        print STDERR "-instance\t'prod', 'dev' or 'test'\n" unless $instance;
        print STDERR "\n";
    }
    unless ($username && $password) {
        unless ($username) {
            print STDERR "-username\tDatabase username with delete privilege\n";
	}
        print STDERR "-password\tDatabase password\n" unless $password;
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


