#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;
use Project;

# Convert a directory to a metadir (like #PROJECT# ...) or a metadir to a dir

#------------------------------------------------------------------------------
# command line input parser
#------------------------------------------------------------------------------

my ($instance, $organism, $projectname, $directory, $metadir);


while (my $nextword = shift @ARGV) {

  if ($nextword eq "-instance" || $nextword eq "-i") {
    die "You can't re-define instance" if $instance;
    $instance  = shift @ARGV;
  }
  elsif($nextword eq "-organism" || $nextword eq "-o") {
    die "You can't re-define organism" if $organism;
    $organism = shift @ARGV;
  }
  elsif ($nextword eq "-project" || $nextword eq "-p") {
    die "You can't re-define project" if $projectname;
    $projectname  = shift @ARGV;
  }
  elsif ($nextword eq "-directory" || $nextword eq "-d") {
    die "You can't re-define directory" if $directory;
    die "You can'r define a directory and a metadirectory" if $metadir;
    $directory  = shift @ARGV;
  }
  elsif ($nextword eq "-metadir" || $nextword eq "-m") {
    die "You can't re-define metadir" if $metadir;
    die "You can'r define a directory a metametadir" if $metadir;
    $metadir  = shift;
  }
  else {
    &showusage("Invalid keyword '$nextword'"); # and exit
  }
}

#------------------------------------------------------------------------------
# test input
#------------------------------------------------------------------------------

unless (defined($instance) && defined($organism)) {
    print STDOUT "\n";
    print STDOUT "!! -- No database instance specified --\n" unless $instance;
    print STDOUT "!! -- No organism database specified --\n" unless $organism;
    &showusage(); # and exit
}

unless (defined($projectname)) {
    print STDOUT "\n";
    print STDOUT "!! -- No project name specified --\n";
    &showusage(); # and exit
}

#------------------------------------------------------------------------------
# get a Project instance
#------------------------------------------------------------------------------
sub showusage {
  my $code = shift || 0;

  print STDERR "\n";
  print STDERR "\n Parameter input ERROR for $0: $code \n" if $code;
  print STDERR "\n";
  print STDERR "Convert a directory to a metadirectory for a given project.\n";
  print STDERR "\n";
  print STDERR "MANDATORY PARAMETERS:\n";
  print STDERR "\n";
  print STDERR "-instance\t(i) Database instance name\n";
  print STDERR "\n";
  print STDERR "-organism \t(o) Arcturus database name\n";
  print STDERR "\n";
  print STDERR "-project\t(p) project name\n";
  print STDERR "\n";
  print STDERR "OPTIONAL PARAMETERS:\n";
  print STDERR "\n";
  print STDERR "-directory\t(d) the path to convert to a metadir\n";
  print STDERR "\n";
  print STDERR "-metadir\t(m) use the metadir of the project\n";
  print STDERR "\n";
  print STDERR "\n Parameter input ERROR for $0: $code \n" if $code;
  exit 1;

}

#my $adb = new ArcturusDatabase(-instance => $instance, -organism => $organism);
#if (!$adb || $adb->errorStatus()) {
#  &showusage("Invalid organim '$organism' or instance '$instance'");
#}
#
#my ($projects,$msg);
#if ($projectname =~ /\D/) {
#   ($projects,$msg) = $adb->getProject(projectname=>$projectname);
#}
#else {
#   ($projects,$msg) = $adb->getProject(project_id=>$projectname);
#} 
#
## test uniqueness    
#     
#unless ($projects && @$projects == 1) {
#    &showusage("Invalid or ambiguous project specification: $msg");
#}
#
#my $project = $projects->[0];
my $schemaname = $organism;

my $output;
if ($directory) {
  $output = Project->convertDirectoryToMetadir($directory, $schemaname, $projectname);
}
elsif ($metadir) {
  $output = Project->convertMetadirToDirectory($metadir, $schemaname, $projectname);
}
else {
  &showusage("Invalid parameters, you should specify -directory or -metadir");
}

if (defined($output)) {
  print $output;
}
else {
  die "Problem ";

}

