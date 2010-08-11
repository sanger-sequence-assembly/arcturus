#!/usr/local/bin/perl

use strict;
use ArcturusDatabase;

use Project;
use ArcturusDatabase::ADBProject;

$ENV{ARCTURUS_TEST_DIRECTORY_BASE}= "./base";

# default value
my $instance = 'test';
my $organism = 'SHISTO';
my $project_name = 'zFD381H22';
my @metadirs;

my ($import, $export);


# parsing ARGS
while (my $nextword = shift @ARGV) {
  $instance = shift @ARGV if ($nextword eq '-instance');

  $organism = shift @ARGV if ($nextword eq '-organism');

  $project_name = shift @ARGV if ($nextword eq '-project');

  push @metadirs, shift @ARGV if ($nextword eq '-metadir');

  $ENV{ARCTURUS_TEST_DIRECTORY_BASE}= "" if ($nextword eq '-no_base_directory');

  $import = 1 if ($nextword eq '-import');
  $export = 1 if ($nextword eq '-export');
}

@metadirs = @metadirs || (
  "/baredirectory" ,
  "#SCHEMA#subdir" ,
  "#PROJECT#subdir" ,
  "{SHISTO}subdir" ,
  "{to_fail}subdir" ,
  undef,
);

if (defined($export) && $ENV{ARCTURUS_TEST_DIRECTORY_BASE}) {
  print "exporting ...\n";

  print `utils/exportfromarcturus.lsf -instance $instance -organism $organism -project $project_name`;

}

elsif (defined($import) && $ENV{ARCTURUS_TEST_DIRECTORY_BASE}) {
  print "importing ...\n";

  print `utils/importintoarcturus.lsf -instance $instance -organism $organism -project $project_name`;

  print "done\n";

}
else {

  my $adb = new ArcturusDatabase(-instance => $instance, -organism => $organism);
  my @projects = $adb->getProject(projectname => $project_name);
  my $project = $projects[0][0];
  print "MyProject => $project\n";

  for my $metadir (@metadirs) {
    eval {
      my $project_dir  = $project->metadirToDirectory($metadir);
      print "meta: $metadir => '$project_dir'\n"; 
    } or do {
      print "meta: $metadir ** not metadir found ***\n";
    };
  }

  print "dir: ", $project->getDirectory(), "\n";


}

