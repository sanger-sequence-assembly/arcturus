#!/usr/local/bin/perl -w

use strict; # Constraint variables declaration before using them

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

my $assembly;
my $project;

my $loglevel;

my $validKeys  = "organism|instance|project|assembly|info|help";

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

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $project          = shift @ARGV  if ($nextword eq '-project');

    $loglevel         = 2            if ($nextword eq '-info'); 


    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardFilter($loglevel) if defined $loglevel;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing project identifier") unless $project;

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
# identify the project, which must be unique
#----------------------------------------------------------------

# collect project specification

my %poptions;
$poptions{project_id}  = $project if ($project !~ /\D/); # a number
$poptions{projectname} = $project if ($project =~ /\D/); # a name
if (defined($assembly)) {
    $poptions{assembly_id}  = $assembly if ($assembly !~ /\D/); # a number
    $poptions{assemblyname} = $assembly if ($assembly =~ /\D/); # a name
}

my ($projects,$msg) = $adb->getProject(%poptions);

unless ($projects && @$projects) {
    $logger->warning("Unknown project $project ($msg)");
    $adb->disconnect();
    exit 0;
}

if ($projects && @$projects > 1) {
    $logger->warning("ambiguous project identifier $project ($msg)");
    $adb->disconnect();
    exit 0;
}

$project = $projects->[0];

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $message = "Project '".$project->getProjectName."' verified";

my $success = $adb->putExport($project);

$logger->info($message." and marked as exported") if $success;

$logger->severe($message."; FAILED to mark as exported") unless $success;

$adb->disconnect();

exit(0);

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
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\tMySQL instance name\n";
    print STDERR "-project \tproject  ID or name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-info\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
