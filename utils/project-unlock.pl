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
my $project;
my $assembly;
my $superuser;
my $verbose;

my $confirm;
my $test;

my $validKeys  = "organism|o|instance|i|assembly|a|project|p|"
               . "superuser|su|confirm|test|verbose|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism = shift @ARGV;
    }  

    if ($nextword eq '-project'  || $nextword eq '-p') {
        $project  = shift @ARGV;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly = shift @ARGV;
    }

    if ($nextword eq '-superuser' || $nextword eq '-su') {
        $superuser = 1;
    }

    $verbose      = 1  if ($nextword eq '-verbose');

    $confirm      = 1  if ($nextword eq '-confirm');

    $test         = 1  if ($nextword eq '-test');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

$superuser = 0 if $test; # overrides
$confirm   = 0 if $test; # overrides

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing project name or ID") unless $project;

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
# MAIN
#----------------------------------------------------------------

my %options;

$options{project_id}  = $project if ($project !~ /\D/);
$options{projectname} = $project if ($project =~ /\D/);

if (defined($assembly)) {
    $options{assembly_id}  = $assembly if ($assembly !~ /\D/);
    $options{assemblyname} = $assembly if ($assembly =~ /\D/);
}

my $success = 0;

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

# next block executed when only one project found

else {
    my $project = shift @$projects;
    $logger->info($project->toStringLong); # project info if verbose

    my $lockstatus = $project->getLockedStatus();

    if ($test && $lockstatus) {
        $logger->warning("Project ".$project->getProjectName()." is "
                        ."curently locked (level $lockstatus)",ss=>1);
    }
    elsif ($test) {
	$success = 2; # project is found to be unlocked
    }
    else {

# unlocking a project with someone else as lockowner requires transfer of the lock

        my %options = (confirm => 0); # to have it defined
        $options{confirm} = 1 if $confirm;

        if ($superuser) {
# acquire the lock ownership yourself (if you don't have it but can acquire it)
           ($success,$message) = $project->transferLock(forcing=>1,%options);
            $logger->warning($message,ps=>1);
        }

       ($success,$message) = $project->releaseLock(%options);

        if ($success == 2) {
            $logger->warning($message,ss=>1);
        }
        elsif ($success == 1 || $success == 0 && !$confirm) {
            my $flag = "-confirm";
            $flag .= " -force" if ($message =~ /belong/i);
            $message .= " (=> use '$flag' to unlock)";
            $logger->warning($message,ss=>1);
        }
        else {
            $message = "FAILED to release lock: ".$message;
            $message .= " (=> try '-force' to unlock)" if ($message =~ /belong/i);
            $logger->warning($message,ss=>1);
	}
    }
}

$adb->disconnect();

exit 0 if ($success == 2);

exit 1; # failed (project not unlocked)

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
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
    print STDERR "-superuser\t(su) run this script as superuser\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value)\n";
    print STDERR "-test\t\t(no value) explicitly no confirm\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for full info\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
