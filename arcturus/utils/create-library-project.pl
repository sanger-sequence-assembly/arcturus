#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Tag;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;

my $project;
my $noreadload;

my $noproject; # if the project already exists
my $submit = 0;

my $verbose;
my $confirm;
my $limit = 0;

my $validKeys  = "organism|instance|project|pn|noreadload|nrl|nogap|gap|"
               . "preview|confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
    if ($nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }

    $project    = shift @ARGV  if ($nextword eq '-project');
    $project    = shift @ARGV  if ($nextword eq '-pn');

    $submit     = 0            if ($nextword eq '-nogap');
    $submit     = 1            if ($nextword eq '-gap');

    $verbose    = 1            if ($nextword eq '-verbose');
 
    $confirm    = 0            if ($nextword eq '-preview');
    $confirm    = 1            if (!defined($confirm) && $nextword eq '-confirm');

    $noreadload = 1            if ($nextword eq '-noreadload');
    $noreadload = 1            if ($nextword eq '-nrl');

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

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing library project name") unless $project;

# test the existence of the database

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$logger->info("Database $organism located succesfully");

# identify the project; test if it exists

my $projectname = uc($project);

my $pids = $adb->getProjectIDsForProjectName($projectname);

$noproject = 1 if (@$pids == 1); # exists

$adb->disconnect();

&showUsage("project name $projectname is ambiguous") if (@$pids > 1);

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $pwd = `pwd`;

unless ($confirm) {

    unless ($noproject) {
        $logger->warning("A new project $projectname will be added for $organism");
    }

    $logger->warning("Library project $projectname will be created "
		 ."in directory $pwd");
    $logger->warning("=> repeat the command and add '-confirm'"); 
}

my $rc = 0;

# find the work directory for the predefined scripts

my $root_dir = `pfind -q -u $organism`;

my $utils_dir = "$root_dir/arcturus/utils";

my $transfer_dir = "$root_dir/arcturus/transfer";

if (!$noreadload && $confirm) {

    $logger->warning("Loading new reads .... be patient");

    $rc = 0xffff & system ("$utils_dir/readloader");

    $logger->severe("Command failed; build abandonned: $!") if $rc;

    $confirm = '' if $rc; # only previews remaining operations 

    $logger->warning("HINT: next time run this script with '-noreadload'");
}

# create a new project of the name you specified

unless ($rc || !$confirm || $noproject) {

    $logger->warning("creating new library project $projectname");

    $rc = 0xffff & system ("$utils_dir/createProject -projectname $projectname");

    $logger->severe("Command failed; build abandonned: $!") if $rc;

    $confirm = '' if $rc; # only previews remaining operations 
}

# assigning data to this new project

unless ($rc || !$confirm) {

    $logger->warning("Assigning data to project $project");

    my $command = "$transfer_dir/requestRead -project $projectname -read '${project}%'";

    $rc = 0xffff & system ("$command -lclip 36 -limit 500 -confirm");

    $logger->severe("Command failed; build abandonned: $!") if $rc;

    $confirm = '' if $rc; # only previews remaining operations 
}

# export the project in the directory

unless ($rc || !$confirm || !$submit) {

    $logger->warning("Exporting library project $projectname in $pwd"); 

    $rc = 0xffff & system ("$utils_dir/exportProject -project $projectname -confirm");

    $logger->severe("Command failed; build abandonned: $!") if $rc;
}

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n\nCreate/populate a library project in the current directory\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
        print STDERR "\n";
    }
    print STDERR "-project\tproject name; all reads of format 'project%' are processed\n";
    print STDERR "\t\tthe project name will be used in UC; this allows LC readnames\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-nrl\t\t(noreadload) skip test for new reads\n";
    print STDERR "\n";
    print STDERR "-nogap\t\tdo not create a GAP4 database\n" if $submit;
    print STDERR "-gap\t\tdo create GAP4 database\n" unless $submit;
    print STDERR "\n";
    print STDERR "-confirm\t(no value) to enter data into arcturus, else preview\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
