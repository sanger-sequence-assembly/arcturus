#!/usr/local/bin/perl

use strict;

use RepositoryManager;
use ArcturusDatabase;

my $instance;
my $organism;
my $projectname;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $projectname = shift @ARGV if ($nextword eq '-project');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($projectname)) {
    &showUsage();
    exit(1);
}

my $adb = new ArcturusDatabase (-instance => $instance,
				-organism => $organism);

die "Could not create ArcturusDatabase" unless defined($adb);

my $rm = new RepositoryManager();

my ($project, $msg) = $adb->getProject(projectname=>$projectname);

die "Failed to find project $projectname"
    unless (defined($project) && ref($project) eq 'ARRAY' && scalar(@{$project}) > 0);

$project = $project->[0];

die "getProject did not return an array with at least one element" unless defined($project);

my $metadir = $project->getDirectory();

die "Undefined meta-directory for project $projectname\n" unless defined($metadir);

print "Meta-directory: $metadir\n";

my $assembly = $project->getAssembly();

die "Undefined assembly for project $projectname" unless defined($assembly);

my $assemblyname = $assembly->getAssemblyName();

die "Undefined assembly name for project $projectname" unless defined($assemblyname);

print "Assembly name: $assemblyname\n";

my $rundir = $rm->convertMetaDirectoryToAbsolutePath($metadir,
						     'assembly' => $assemblyname,
						     'project' => $projectname);

print defined($rundir) ? "Absolute path: $rundir\n" : "***** Could not convert meta-directory *****\n";

$adb->disconnect();

exit 0;

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-project\tName of project\n";
}
