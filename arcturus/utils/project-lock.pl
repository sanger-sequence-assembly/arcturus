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
my $verbose;
my $superuser;
my $newuser;
my $confirm;
my $test;

my $validKeys  = "organism|o|instance|i|assembly|a|project|p|"
               . "superuser|su|transfer|"
               . "confirm|test|verbose|help";

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

    $newuser      = shift @ARGV  if ($nextword eq '-transfer');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm');

    $test         = 1  if ($nextword eq '-test');

    &showUsage(0) if ($nextword eq '-help');
}

$superuser = 0 if $test; # overrides
$confirm = 0 if $test; # overrides
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging(); # default STDOUT
 
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
    $logger->warning("Non-unique project specification : $project (@namelist)",ss=>1);
    unless (defined($assembly)) {
        $logger->warning("Perhaps specify the assembly ?",skip=>1);
    }

}
elsif (!$projects || !@$projects) {
    $logger->warning("Project $project not available : $message", ss=>1);
}

else {

# only one project found, continue

    my $project = shift @$projects;
    $logger->info($project->toStringLong,skip=>1); # project info if verbose

    my $lockstatus = $project->getLockedStatus();

    if ($test && $lockstatus) {
        $logger->warning("Project ".$project->getProjectName()." is "
                        ."curently locked (level $lockstatus)",ss=>1);
        $success = 2; # project is locked
    }
    elsif ($test) {
	$success = 1; # project is unlocked
    }

    else { # not test

# 1) if project is already locked, test if it is locked by the intended user

        if ($lockstatus && $newuser) {
# only newuser tested here: current arcturus user is tested in transfer/acquireLock
            my $lockowner = $project->getLockOwner();
            my $projectowner = $project->getOwner();
            $newuser = $projectowner if ($projectowner && $newuser eq 'owner');
	    if ($newuser eq $lockowner) {
                my $projectname = $project->getProjectName();
                $logger->warning("Project $projectname is locked by $lockowner");
                $adb->disconnect();
                exit 1; # project is already locked by intended user
	    }
	}

# 2) else, acquire lock by using privilige, if so specified

        my %options = (confirm => 0);
        $options{confirm} = 1 if $confirm;

        if ($superuser) {
# used in case the project is already locked by someone else, then first
# acquire the lock ownership yourself (if you don't have it but can acquire it)
           ($success,$message) = $project->transferLock(forcing=>1, %options);
            $message =~ s/transfere?/acquire/;
            $logger->warning($message,skip=>1);
        }

# 3) or, acquire the lock in standard mode

        unless ($success) {
# acquire the lock on the project (either by already having it, or when unlocked) 
           ($success,$message) = $project->acquireLock(%options);

            if ($success == 2) {
                $logger->warning($message,ss=>1); # project locked
            }
            elsif ($success == 1) {
                $logger->warning($message." (=> use '-confirm')",ss=>1);
            }
# no success
            elsif ($newuser && $newuser eq $project->getLockOwner()) {
                $logger->warning($message,ss=>1);
            }
            else {
                $message .= "; you may have no privileges on"
                         .  " database $organism" if $confirm;
                $logger->warning($message,ss=>1);
            }
        }
    }

# 4) then, if the lock was acquired by current user, possible transfer to new user

    if ($success == 2 && $newuser && $newuser eq 'owner') {
	$newuser = $project->getOwner(); # substitute the name
        unless ($newuser) {
            my $projectname = $project->getProjectName();
            $message = "Project $projectname has no owner; lock retained";
	    $logger->severe($message,ps=>1);
            $adb->disconnect();
            exit 2; # project is locked, but lock could not be transfered
        }
    }

    if ($success == 2 && $newuser && $newuser ne $adb->getArcturusUser()) {

        $options{newowner} = $newuser;

       ($success,$message) = $project->transferLock(%options);

        if ($success == 2) {
            $logger->warning($message,ss=>1);
        }
        elsif ($success == 1) {
            $logger->warning($message." (=> use '-confirm')",ss=>1);
        }
        else {
            $message .= "; perhaps user '$newuser' has no privileges on database "
                      . $organism if $confirm;
            $logger->warning($message,ss=>1);
        }
    }
}

$adb->disconnect();

exit 0 if ($success == 2); # done, project is locked, lock possibly transfered

exit 1; # project not locked

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
        print STDERR "-instance\tMySQL database instance\n" unless $instance;
        print STDERR "\n";
    }
    unless ($project) {
        print STDERR "-project\tproject identifier (ID or name)\n";
        print STDERR "\n";
    }
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "-su\t\t(use privilege, no value) acquire an existing lock\n";
    print STDERR "-transfer\tname of new user to transfer lock ownership to\n";
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
