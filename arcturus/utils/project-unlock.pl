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
my $forcing;
my $verbose;
my $confirm;

my $validKeys  = "organism|instance|assembly|project|forcing|confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $forcing      = 1            if ($nextword eq '-forcing');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing project name or ID") unless $project;
 
my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Unknown organism '$organism' on server '$instance'");
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

my $success;

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
# only one project found, continue
    my $project = shift @$projects;
    $logger->info($project->toStringLong); # project info if verbose

# unlocking a project with someone else as lockowner requires transfer of the lock

    if ($forcing) {
# acquire the lock ownership yourself (if you don't have it but can acquire it)
       ($success,$message) = $adb->transferLockOwnershipForProject($project,
				                          confirm=>1,forcing=>1);
        $logger->warning($message);
        $logger->skip();
    }


    my %options;
    $options{confirm} = 1 if $confirm;

   ($success,$message) = $adb->releaseLockForProject($project,%options);

    $logger->skip();
    if ($success == 2) {
        $logger->warning($message);
    }
    elsif ($success == 1) {
        $logger->warning($message." (=> use '-confirm')");
    }
    else {
        $message = "FAILED to release lock: ".$message if $confirm;
        $logger->warning($message);
    }
    $logger->skip();
}

$adb->disconnect();

exit 0 unless $success;

exit 1; # failed

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nRelease a lock on a project\n";
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
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "-forcing\tunlock a project locked by another user\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value)\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for full info\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
