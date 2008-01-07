#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Cwd;

# import a single gap4 database into arcturus

# script to be run from directory of gap4 database to be imported 

# for input parameter description use help

#------------------------------------------------------------------------------

my $pwd = Cwd::cwd(); # the current directory
   $pwd =~ s?.*automount.*/nfs?/nfs?;
   $pwd =~ s?.*automount.*/root?/nfs?;
my $basedir = `dirname $0`; chomp $basedir; # directory of the script
my $arcturus_home = "${basedir}/..";
$arcturus_home =~ s?/utils/\.\.??;
my $javabasedir   = "${arcturus_home}/utils";
my $badgerbin     = "$ENV{BADGER}/bin";

#------------------------------------------------------------------------------
# command line input parser
#------------------------------------------------------------------------------

my ($instance,$organism,$projectname,$assembly,$gap4name,$version);

my $problemproject = 'PROBLEMS'; # default

my $import_script = "${arcturus_home}/utils/contig-loader";
$import_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

my $repair = "-movetoproblems";

my ($forcegetlock,$keep,$abortonwarning,$noagetest,$rundir,$debug);

my $validkeys = "instance|i|organism|o|project|p|assembly|a|gap4name|g|"
              . "version|v|superuser|su|problem|script|abortonwarning|aow|"
              . "noagetest|nat|keep|rundir|rd|debug|help|h|passon|po";

#------------------------------------------------------------------------------

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validkeys)\b/) {
        &showusage("Invalid keyword '$nextword'"); # and exit
    }

    if ($nextword eq '-instance' || $nextword eq '-i') { # mandatory
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') { # mandatory
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism = shift @ARGV;
    }  

    if ($nextword eq '-project'  || $nextword eq '-p') { # mandatory
        die "You can't re-define project" if $projectname;
        $projectname  = shift @ARGV;
        $version = "0" unless defined($version);
        $gap4name = $projectname unless $gap4name;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') { # optional
        $assembly = shift @ARGV;
    }

    if ($nextword eq '-gap4name' || $nextword eq '-g') { # optional, default project
        $gap4name = shift @ARGV;
    }

    if ($nextword eq '-version'  || $nextword eq '-v') { # optional, default 0
        $version = shift @ARGV;
    }

    if ($nextword eq '-problem') { # optional, default PROBLEMS
        $problemproject = shift @ARGV;
    }

    if ($nextword eq '-script') {  # optional, default contig-loader
        $import_script = shift @ARGV;
    }

    if ($nextword eq '-repair') {  # optional, default movetoproblem (project)
        $repair = shift @ARGV;
        $repair = "-$repair";
    }

    if ($nextword eq '-abortonwarning'  || $nextword eq '-aow'){
        $abortonwarning = 1;
    }

    if ($nextword eq '-noagetest'  || $nextword eq '-nat'){
        $noagetest = 1;
    }

    if ($nextword eq '-keep') {
        $keep = 1;
    }

    if ($nextword eq '-superuser' || $nextword eq '-su') {
        $forcegetlock = 1;
    }

    if ($nextword eq '-rundir' || $nextword eq '-rd') {
        $rundir = shift @ARGV;
    }

    if ($nextword eq '-debug') {
        $debug = 1;
    }

    if ($nextword eq '-help' || $nextword eq '-h') {
        &showusage(); # and exit
    }

    if ($nextword eq '-passon' || $nextword eq '-po') {
	last; # abort input parsing here
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
# change to the right directory; use current if rundir is defined but 0
#------------------------------------------------------------------------------

unless (defined($rundir)) {
# pick up the directory from the database
     my $adb = new ArcturusDatabase (-instance => $instance,
			             -organism => $organism);
     if (!$adb || $adb->errorStatus()) {
# abort with error message
         &showUsage("Invalid organism '$organism' on server '$instance'");
     }
     my ($project,$msg);
     if ($projectname =~ /\D/) {
        ($project,$msg) = $adb->getProject(projectname=>$projectname);
     }
     else {
        ($project,$msg) = $adb->getProject(project_id=>$projectname);
     } 
     $adb->disconnect();
# get the directory     
     unless ($project && @$project == 1) {
         &showusage("Invalid or ambiguous project specification");
     }
     $rundir = $project->[0]->getDirectory();
     print STDERR "Undefined directory for project $projectname\n" unless $rundir;
}

if ($rundir) {
    print STDOUT "Changing work directory from $pwd to $rundir\n";
    chdir ($rundir);
    $pwd = Cwd::cwd();
    $pwd =~ s?.*automount.*/nfs?/nfs?;
    $pwd =~ s?.*automount.*/root?/nfs?;
}

#------------------------------------------------------------------------------
# check existence and accessibility of gap4 database to be imported
#------------------------------------------------------------------------------

unless ( -f "${gap4name}.$version") {
    print STDOUT "!! -- Project $gap4name version $version"
                     ." does not exist in $pwd --\n";
    exit 1;
}

if ( -f "${gap4name}.$version.BUSY") {
    print STDOUT "!! -- Import of project $gap4name aborted:"
                     ." version $version is BUSY --\n";
    exit 1;
}

if ( -f "${gap4name}.A.BUSY") {
    print STDOUT "!! -- Import of project $gap4name WARNING:"
                     ." version A is BUSY --\n";
    exit 1 if $abortonwarning;
}

# detrmine if script run in standard mode

my $nonstandard = ($gap4name ne $projectname || $version ne '0') ? 1 : 0;
print STDOUT "$0 running in non-standard mode\n" if $nonstandard;

# check age

unless ($version eq "A" || $nonstandard) {
    my @astat = stat "$gap4name.A";
    my @vstat = stat "$gap4name.$version";
    if (@vstat && @astat && $vstat[9] <= $astat[9]) {
        print STDERR "!! -- Import of project $gap4name WARNING:"
                     ." version $version is older than version A --\n";
        unless ($noagetest) {
	    print STDERR "!! -- Import of $gap4name.$version skipped --\n";
            exit 0;
	}
    }
}

#------------------------------------------------------------------------------
# check existence and accessibility of arcturus database to be modified 
#------------------------------------------------------------------------------

my $lock_script = "${arcturus_home}/utils/project-lock";
$lock_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

my $command = "$lock_script -i $instance -o $organism -p $projectname -confirm";

$command .= " -su" if $forcegetlock; # (try to) invoke privilege (if user has it)

system ($command);

if ($?) {
# project lock cannot be acquired by the current user 
    print STDOUT "!! -- Arcturus project $projectname is not accessible --\n";
    exit 1;
}

#print STDOUT "can proceed but test abort\n"; exit 1; # busy test
#------------------------------------------------------------------------------
# export the database as a depadded CAF file
#------------------------------------------------------------------------------

my $padded   = "/tmp/${gap4name}.$$.padded.caf";

my $depadded = "/tmp/${gap4name}.$$.depadded.caf";

print STDOUT "Converting Gap4 database $gap4name.$version to CAF\n";

system ("${badgerbin}/gap2caf -project $gap4name -version $version -ace $padded");

unless ($? == 0) {
    print STDERR "!! -- FAILED to create a CAF file from $gap4name.$version ($?) --\n";
    print STDERR "!! -- Import of $gap4name.$version aborted --\n";
    exit 1;
}
   
print STDOUT "Depadding CAF file\n";

system ("${badgerbin}/caf_depad < $padded > $depadded");

unless ($? == 0) {
    print STDERR "!! -- FAILED to depad CAF file $padded ($?) --\n";
    print STDERR "!! -- Import of $gap4name.$version aborted --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# change data in the repository: create backup version B  
#------------------------------------------------------------------------------

unless ($version eq "B" || $nonstandard) {
    print STDOUT "Backing up version $version to B\n";
    if (-f "$gap4name.B") {
        system ("rmdb $gap4name B");
        unless ($? == 0) {
            print STDERR "!! -- FAILED to remove existing $gap4name.B ($?) --\n"; 
            print STDERR "!! -- Import of $gap4name.$version aborted --\n";
            exit 1;
        }
    }
    system ("cpdb $gap4name $version $gap4name B");
    unless ($? == 0) {
        print STDERR "!! -- WARNING: failed to back up $gap4name.$version ($?) --\n";
        if ($abortonwarning) {
            print STDERR "!! -- Import of $gap4name.$version aborted --\n";
            exit 1;
        }
    }       
}

#------------------------------------------------------------------------------
# change the data in Arcturus
#------------------------------------------------------------------------------

print STDOUT "Importing into Arcturus\n";

$command  = "$import_script -instance $instance -organism $organism "
          . "-caf $depadded -defaultproject $projectname "
          . "-gap4name ${pwd}/$gap4name.$version";
$command .= " @ARGV" if @ARGV; # pass on any remaining input

print STDERR "$command\n" if @ARGV;
# exit 0 if @ARGV;

system ($command);

# exit status 0 for import of contigs
#             1 (or 256) for no contigs imported, but no errors
#             2 (or 512) for an error status 

my $status = $?; 

if ($status && ($status == 2 || $status == 512)) {
    print STDERR "!! -- FAILED to import from CAF file $depadded ($?) --\n";
    exit 1;
}

# if contigs were imported (status == 0) do post-processing

if ($status) {
    print STDOUT "Database $gap4name.$version successfully processed, "
               . "but does not contain new data\n";
}

else {

#------------------------------------------------------------------------------
# consensus calculation
#------------------------------------------------------------------------------

    my $consensus_script = "${javabasedir}/calculateconsensus";

    my $database = '';
    unless ($instance eq 'default' || $organism eq 'default') {
        $database = "-instance $instance -organism $organism";
    }
 
    system ("$consensus_script $database -project $projectname -quiet -lowmem");

#------------------------------------------------------------------------------
# consistence tests after import
#------------------------------------------------------------------------------

    my $allocation_script = "${arcturus_home}/utils/read-allocation-test";

    my $username = $ENV{'USER'};
    $allocation_script .= ".pl" if (defined($username) && $basedir =~ /$username/); # script is run in test mode

    print STDOUT "Testing read allocation for possible duplicates inside projects\n";

    # use repair mode for inconsistencies inside the project

    my $allocation_i_log = "readallocation-i-.$$.${gap4name}.log"; # inside project

    system ("$allocation_script -instance $instance -organism $organism "
           ."$repair -problemproject $problemproject -workproject $projectname "
           ."-inside -log $allocation_i_log -mail ejz");

# no repair mode for inconsistencies between projects

    print STDOUT "Testing read allocation for possible duplicates between projects\n";

    my $allocation_b_log = "readallocation-b-.$$.${gap4name}.log"; # between projects

    system ("$allocation_script -instance $instance -organism $organism "
           ."-nr -problemproject $problemproject -workproject $projectname "
           ."-between -log $allocation_b_log -mail ejz");

    print STDOUT "New data from database $gap4name.$version successfully processed\n";
}

#-------------------------------------------------------------------------------

unless ($keep) {
    print STDOUT "Cleaning up\n";

    system ("rm -f $padded $depadded");

# purge readallocation logs older than a given date  TO BE COMPLETED
# "find . -mtime +30 -type f -exec rm -f {} \;"
# cleanup files of name "readallocation*log"
}

print STDOUT "\n\nIMPORT OF $projectname HAS FINISHED.\n";

exit 0;

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub showusage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "\nParameter input ERROR for $0: $code \n" if $code;
    print STDERR "\n";
    print STDERR "Import a Gap4 database into Arcturus for a specified project\n";
    print STDERR "\n";
    print STDERR "script to run in directory of Gap4 database\n";
    print STDERR "\n";
    $version = "0" unless defined($version);
    print STDERR "import will be from database 'project.$version'\n";
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    unless ($organism && $instance) {
        print STDERR "\n";
        print STDERR "-instance\t(i) Database instance name\n" unless $instance;
        print STDERR "-organism\t(o) Arcturus database name\n" unless $organism;
    }
    print STDERR "\n";
    print STDERR "-project\t(p) unique project identifier (number or name)\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\t(a) needed to resolve ambiguous project name\n";
    print STDERR "\n";
    print STDERR "-gap4name\t(g) Gap4 database if different from default "
                ."project.0\n";
    print STDERR "-version\t(v) Gap4 database version if different from 0\n";
    print STDERR "\n";
    print STDERR "-rundir\t\t(rd) explicitly set directory where script will run\n";
    print STDERR "\n";
    print STDERR "-script\t\t(default contig-loader) name of loader script used\n";
    print STDERR "\n";
    print STDERR "-superuser\t(su) (try to) lock the database using su privilege\n";
    print STDERR "\n";
    print STDERR "-problem\t(default PROBLEM) project name for unresolved "
               . "parent contigs\n";
    print STDERR "\n";
    print STDERR "-aow\t\t(abortonwarning) stop if any db is BUSY or backup fails\n";
    print STDERR "-nat\t\t(noagetest) skip age test on Gap4 database(s)\n";
    print STDERR "-keep\t\t keep temporary files\n";
    print STDERR "\n";
    print STDERR "-debug\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR for $0: $code \n" if $code;
    exit 1;
}

#------------------------------------------------------------------------------
