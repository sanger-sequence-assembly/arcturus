#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

# script to be run from the work directory of the project

# verify mode to test the database status against the last import (version B)

# status mode to test the import/export status of a project  

my $instance;
my $organism;

my $project;
my $subdir = '';

my $filter;

my $invocation = 1; # default status checking

my $info;

#------------------------------------------------------------------------------
# parse the command line input; options overwrite eachother; order is important
#------------------------------------------------------------------------------

my $validkeys = "project|p|verify|v|status|s|subdir|sd|filter|f";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validkeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    elsif ($nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
#        $verify = 1;
    }

    elsif ($nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
#        $verify = 1;
    }

    $invocation = 0         if ($nextword eq '-verify'  || $nextword eq '-v');

    $invocation = 1         if ($nextword eq '-status'  || $nextword eq '-s');

    $project = shift @ARGV  if ($nextword eq '-project' || $nextword eq '-p');

    $subdir  = shift @ARGV  if ($nextword eq '-subdir'  || $nextword eq '-sd');

    $filter  = shift @ARGV  if ($nextword eq '-filter'  || $nextword eq '-f');

    &showUsage(0)           if ($nextword eq '-help'    || $nextword eq '-h');
}

#---------------------------------------------------------------------------
# logging
#---------------------------------------------------------------------------

my $logger = new Logging('STDOUT');

#---------------------------------------------------------------------------
# in verify mode require full project name
#---------------------------------------------------------------------------

my $root = "utils";
unless (-e $root) {
    $root = "../".$root;
    unless (-e $root) {
        $logger->severe("Cannot locate root directory 'utils' or '../utils'");
        exit 1;
    }
}

unless ($invocation != 0) {

print STDOUT "inv:  $invocation\n";
#    &showUsage("Missing organism database") unless $organism;

#    &showUsage("Missing database instance") unless $instance;

    &showUsage("Missing project name") unless $project;

    &showUsage("Invalid project name") if ($project =~ /\?|\*/);

    my ($projects,$msg) = &findprojects($project,$subdir);

    &showUsage($msg) unless (@$projects);

    foreach my $project (@$projects) {

        my $gap2caf = "/nfs/pathsoft/prod/WGSassembly/bin/64bit/gap2caf "
                    . "-project $project -version B "
		    . "-ace /tmp/$project.b.caf";
        `$gap2caf`;

        my $cafdepad = "caf_depad < /tmp/$project.b.caf "
	             . "> /tmp/$project.b.depad.caf";
        `$cafdepad`;

        my $cloader = "$root/contig-loader -caf /tmp/$project.b.depad.caf "
	            . "-tc -noload > $project.test.log";
        `$cloader`;
    }

}

else {
# status analysis: get the projects in the current directory

    my ($projects,$msg) = &findprojects($project,$subdir);

    &showUsage($msg) unless (@$projects);

# print STDOUT "project(s) @$projects\n";

# and run each project through the diagnostic shell script

    $subdir .= "/" if $subdir;
    foreach my $project (@$projects) {
        my $msg = `$root/projectstatus -project $subdir$project` || 'FAILED';
        next if ($filter && $msg !~ /$filter/i);
        $logger->skip();
        $logger->warning("$msg");
    }
    $logger->skip();
}

exit 0;

# script to test version B (latest imported) against database

#--------------------------------------------------------------------------

sub findprojects {
# get the files in the current directory
    my $project = shift;
    my $subdir = shift;

    my $pwd = `pwd`;

    chomp $pwd;

    $pwd .= "/$subdir" if $subdir;

    opendir DIR, $pwd || die "serious problems: $!";

    my @files = readdir DIR;

    closedir DIR;

# make an inventory of projects in this list

    my $projecthash = {};

    foreach my $file (@files) {

        next unless ($file =~ /^([^\.]+)\.[0AB]$/);

        my $name = $1;

        next if ($project && $file !~ /$project/i);

        $projecthash->{$name}++;
    }

    my @projects = sort keys %$projecthash;

    return [@projects], "OK" if @projects; 

    return [@projects], "project $project not found in $pwd" unless @projects;
}

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "$code\n" if $code;
    print STDERR "\n";

    print STDERR "\n";
    print STDERR "$code\n" if $code;
    print STDERR "\n";

    exit;
}
