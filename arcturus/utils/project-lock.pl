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
my $verbose;
my $confirm;
my $forcing;
my $newuser;

my $validKeys  = "organism|instance|assembly|project|usurp|transfer|"
               . "confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $newuser      = shift @ARGV  if ($nextword eq '-transfer');

    $forcing      = 1            if ($nextword eq '-usurp');

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
    $logger->skip();
    $logger->warning("Non-unique project specification : $project (@namelist)");
    $logger->warning("Perhaps specify the assembly ?") unless defined($assembly);
    $logger->skip();
}
elsif (!$projects || !@$projects) {
    $logger->skip();
    $logger->warning("Project $project not available : $message");
    $logger->skip();
}

else {
# only one project found, continue
    my $project = shift @$projects;
    $logger->info($project->toStringLong); # project info if verbose

    $logger->skip();
    if ($forcing) {
# used in case the project is already locked by someone else
# acquire the lock ownership yourself (if you don't have it but can acquire it)
       ($success,$message) = $adb->transferLockOwnershipForProject($project,
				                          confirm=>1,forcing=>1);
        $logger->warning($message);
        $logger->skip();
    }


    unless ($success) {
# acquire the lock on the project (either by already having it, or when unlocked) 
        my %options;
        $options{confirm} = 1 if $confirm;

       ($success,$message) = $adb->acquireLockForProject($project,%options);

        if ($success == 2) {
            $logger->warning($message);
        }
        elsif ($success == 1) {
            $logger->warning($message." (=> use '-confirm')");
        }
        else {
            $message .= "; you may have no privileges on database "
                      . $organism if $confirm;
            $logger->warning($message);
        }
        $logger->skip();
    }

# if the lock was acquired by this user, now change to a new user

    if ($success == 2 && $newuser) {

        my %options = (newowner => $newuser);
        $options{confirm} = 1 if $confirm;
        
       ($success,$message) = $adb->transferLockOwnershipForProject($project,%options);

        if ($success == 2) {
            $logger->warning($message);
        }
        elsif ($success == 1) {
            $logger->warning($message." (=> use '-confirm')");
        }
        else {
            $message .= "; perhaps user '$newuser' has no privileges on database "
                      . $organism if $confirm;
            $logger->warning($message);
        }
        $logger->skip();
    }
}

$adb->disconnect();

exit 0 unless $success;

exit 1; # locking failed

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Acquire a lock on a project\n";
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
    print STDERR "-usurp\t\t(no value) to acquire existing lock ownership by privilege\n";
    print STDERR "-transfer\tname of new user to transfer lock ownership to\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value)\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for full info\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
