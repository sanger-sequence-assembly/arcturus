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
my $comment;
my $verbose;
my $confirm;
my $replace;

my $validKeys  = "organism|instance|assembly|project|comment|replace|"
               . "confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $comment      = shift @ARGV  if ($nextword eq '-comment');

    $replace      = 1            if ($nextword eq '-replace');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage(0,"Missing project name or ID") unless $project;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage(0,"Missing organism database") unless $organism;

&showUsage(0,"Missing database instance") unless $instance;

&showUsage(0,"Missing project name or ID") unless $project;

&showUsage(0,"Missing comment") unless $comment;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
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

my $status;

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
    $project = shift @$projects;
    if ((my $currentcomment = $project->getComment()) && !$replace) {
        $comment = $currentcomment." ".$comment;
    }
    $project->setComment($comment);
    my ($status,$message) = $adb->addCommentForProject($project);
    $logger->warning($message);
}
else {
    $project = shift @$projects;
    if (my $status = $project->getLockedStatus()) {
        $logger->warning("Project $project ".$project->getProjectName()
                        ." is locked by user ".$project->getOwner());
    }
    my $msg = "The comment '$comment' will ";
    if (my $currentcomment = $project->getComment()) {
        $logger->warning("Current description of project ".
            $project->getProjectName()." : '$currentcomment'"); 
        $msg .= "replace " if $replace;
        $msg .= "be added to " unless $replace;
        $msg .= "the description";
    }
    else {
        $msg .= "be entered";
    }
    $logger->warning($msg." for project ".$project->getProjectName());
    $logger->warning("Please confirm by adding the '-confirm' switch");
}

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nProject locking\n";
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

    $code ? exit(1) : exit(0);
}
