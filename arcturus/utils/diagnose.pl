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
my $recursive;

my $filter;

my $invocation = 1; # default status checking

my $info;

#------------------------------------------------------------------------------
# parse the command line input; options overwrite eachother; order is important
#------------------------------------------------------------------------------

my $validkeys = "organism|o|instance|i|project|p|verify|v|"
              . "status|s|subdir|sd|filter|f|recursive|r";

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

    $invocation = 0        if ($nextword eq '-verify'    || $nextword eq '-v');

    $invocation = 1        if ($nextword eq '-status'    || $nextword eq '-s');

    $project = shift @ARGV if ($nextword eq '-project'   || $nextword eq '-p');

    $subdir  = shift @ARGV if ($nextword eq '-subdir'   || $nextword eq '-sd');

    $filter  = shift @ARGV if ($nextword eq '-filter'    || $nextword eq '-f');

    $recursive = 1         if ($nextword eq '-recursive' || $nextword eq '-r');

    &showUsage(0)          if ($nextword eq '-help'      || $nextword eq '-h');
}

#---------------------------------------------------------------------------
# logging
#---------------------------------------------------------------------------

my $logger = new Logging();

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

$logger->info("invocation:  $invocation"); # experimental

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

    my $pwd = `pawd`; chomp $pwd;

    my $projects = [];
    my $msg;

    if ($recursive) {
        opendir DIR, $pwd || die "serious problems: $!";
        my @files = readdir DIR;
        closedir DIR;
        foreach my $file (@files) {
            next unless (-d $file);
            next if ($filter && $file !~ /$filter/);
           (my $list,$msg) = &findprojects($project,$file);
            foreach my $entry (@$list) {
                push @$projects,"$file/$entry";
	    }
	}
    }
    else {
        ($projects,$msg) = &findprojects($project,$subdir);
    }

    &showUsage($msg) unless (@$projects);

# $logger->warning("project(s) @$projects");

# and run each project through the diagnostic shell script

    $subdir .= "/" if $subdir;
    $logger->warning("Status of projects in/under $pwd",skip=>1);
    foreach my $project (@$projects) {
        my $msg = `$root/projectstatus project $subdir$project` || 'FAILED';
        next if ($filter && $msg !~ /$filter/i);
        chomp $msg;
        $logger->warning($msg,skip=>1);
    }
}

exit 0;

# script to test version B (latest imported) against database

#--------------------------------------------------------------------------

sub findprojects {
# get the files in the current directory
    my $project = shift;
    my $subdir = shift;

    my $pwd = `pawd`;

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

    if (@projects) {

        return [@projects], "OK";
    }
    elsif ($project) {
 
        return [@projects], "project $project not found in $pwd";
    }
    else {
        return [@projects], "no project found in $pwd";
    }
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



