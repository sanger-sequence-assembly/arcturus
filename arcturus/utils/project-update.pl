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

my $extend;
my $projectname;
my $projectowner;
my $projectstatus;
my $projectcomment;

my $useprivilege;

my $verbose;
my $confirm;

my $validKeys  = "organism|instance|assembly|project|comment|pc|extend|"
               . "owner|po|name|pn|status|ps|privilege|"
               . "confirm|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance         = shift @ARGV  if ($nextword eq '-instance');
      
    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $project          = shift @ARGV  if ($nextword eq '-project');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $projectcomment   = shift @ARGV  if ($nextword eq '-comment');
    $projectcomment   = shift @ARGV  if ($nextword eq '-pc');
    $extend           = 1            if ($nextword eq '-extend');

    $projectowner     = shift @ARGV  if ($nextword eq '-owner');
    $projectowner     = shift @ARGV  if ($nextword eq '-po');

    $projectname      = shift @ARGV  if ($nextword eq '-name');
    $projectname      = shift @ARGV  if ($nextword eq '-pn');

#    $projectlockowner = shift @ARGV  if ($nextword eq '-lockowner');
#    $projectlockowner = shift @ARGV  if ($nextword eq '-plo');

    $projectstatus    = shift @ARGV  if ($nextword eq '-status');
    $projectstatus    = shift @ARGV  if ($nextword eq '-ps');

    $useprivilege     = 1            if ($nextword eq '-privilege');

    $verbose          = 1            if ($nextword eq '-verbose');

    $confirm          = 1            if ($nextword eq '-confirm');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage("Missing project name or ID") unless $project;
 
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

&showUsage("Missing project name or ID") unless $project;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
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

# assemble the new data in the project instance

else {
    my $project = shift @$projects;

# apply the changes to the project instance

    $project->setProjectName($projectname)     if $projectname;
    $project->setOwner($projectowner)          if $projectowner;
# replace underscore/hyphen by blanks
    $projectstatus =~ s/\_|\-/ /g if $projectstatus;
    $project->setProjectStatus($projectstatus) if $projectstatus;
# special case
    if ($projectcomment && $extend && $project->getComment()) {
        my $currentcomment = $project->getComment();
        $projectcomment = $currentcomment." / ".$projectcomment;
    }
    $project->setComment($projectcomment)      if $projectcomment;
    
    $confirm = 0 unless $confirm;

    my %uoptions = (confirm => $confirm);
    $uoptions{useprivilege} = 1 if $useprivilege;
    my ($success,$message) = $adb->updateProjectAttribute($project,%uoptions);

# from here change

    my %skips = (preskip=>1,skip=>1);
    if ($success == 2) {
        $logger->warning($message,%skips);
    }
    elsif ($success == 1) {
        $logger->warning($message,preskip=>1);
        $logger->warning("=> repeat command and add '-confirm'",skip=>1);
    }
    else {
        $message = "FAILED: ".$message if $confirm;
        $logger->warning($message,%skips);
    }
}

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;
    my $user = shift || 0;

    print STDERR "\n";
    print STDERR "Updating Project attributes\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n" if $code;
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
    print STDERR "\n";
    print STDERR "-comment\tthe comment to be entered or added (between '')\n";
    print STDERR "-append\t\t(with comment) extend existing comment (else replace)\n";
    print STDERR "-name\t\tnew project name (must be unique)\n";
    print STDERR "-owner\t\tchange project ownership\n";
    print STDERR "-status\t\tchange project status (may result in locking)\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "-privilege\tuse privilege if project owned by someone else\n" if $user;
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
