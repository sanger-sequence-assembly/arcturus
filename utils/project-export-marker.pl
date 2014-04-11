#!/usr/local/bin/perl -w

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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

my $file;

my $loglevel;

my $validKeys  = "organism|o|instance|i|project|p|assembly|a|file|f|"
               . "info|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
 
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }

    if ($nextword eq '-project'  || $nextword eq '-p') {
        $project      = shift @ARGV;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly     = shift @ARGV;
    }

    if ($nextword eq '-file'     || $nextword eq '-f') {
        $file         = shift @ARGV;
    }

    $loglevel         = 2            if ($nextword eq '-info'); 


    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
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

$project->setGap4Name($file) if $file;

my $message = "Project '".$project->getProjectName."' verified";

my $success = $project->markExport();

$logger->info($message." and marked as exported") if $success;

$logger->severe($message."; FAILED to mark as exported") unless $success;

$adb->disconnect();

exit 0 if $success;

exit 1;

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
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
