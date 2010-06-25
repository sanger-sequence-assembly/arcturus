#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

# import a single gap5 database into arcturus

# script to be run from directory of gap5 database to be imported 

# for input parameter description use help

#------------------------------------------------------------------------------

my $pwd = `pwd`; chomp $pwd; # the current directory
   $pwd =~ s?.*automount.*/nfs?/nfs?;
   $pwd =~ s?.*automount.*/root?/nfs?;
my $basedir = `dirname $0`; chomp $basedir; # directory of the script
my $arcturus_home = "${basedir}/..";
$arcturus_home =~ s?/utils/\.\.??;

my $gap5root = "/software/badger/bin";

#my $javabasedir   = "${arcturus_home}/utils";
#$javabasedir = "/nfs/users/nfs_e/ejz/workspace/core-system-migration/src/uk/ac/sanger/arcturus/apps"; # test

my $gap5toSam = "$gap5root/gap5_export -test "; # test to be disabled later
my $gap5consensus = "$gap5root/gap5_consensus ";
my $samtools = "/software/solexa/bin/aligners/samtools/current/samtools";
my $javacontroller = "/nfs/users/nfs_e/ejz/arcturus/dev/utils/run-arcturus-class.sh";
my $memory;

#------------------------------------------------------------------------------
# command line input parser
#------------------------------------------------------------------------------

my ($instance,$organism,$projectname,$assembly,$gap5name,$version);

my $problemproject = 'PROBLEMS'; # default

my $import_script = "uk.ac.sanger.arcturus.apps.ContigLoader";

my $scaffold_script = "${arcturus_home}/utils/contigorder.sh";

my $repair = "-movetoproblems";

my ($forcegetlock,$keep,$abortonwarning,$noagetest,$rundir,$debug);

my $validkeys = "instance|i|organism|o|project|p|assembly|a|gap5name|g|"
              . "version|v|superuser|su|problem|script|abortonwarning|aow|"
              . "noagetest|nat|keep|rundir|rd|debug|help|h|passon|po|"
              . "memory|mem";

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
        $gap5name = uc($projectname) unless $gap5name;
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') { # optional
        $assembly = shift @ARGV;
    }

    if ($nextword eq '-gap5name' || $nextword eq '-g') { # optional, default project
        $gap5name = shift @ARGV;
    }

    if ($nextword eq '-version'  || $nextword eq '-v') { # optional, default 0
        $version = shift @ARGV;
    }

    if ($nextword eq '-problem') { # optional, default PROBLEMS
        $problemproject = shift @ARGV;
    }

    if ($nextword eq '-script') {  # optional, default contig-loader
        $import_script = shift @ARGV;
        if ($import_script =~ /test/i) {
            $import_script = " -Ddebugging=true -Dtesting=true test.importer.BAMContigLoaderTest";
        }
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

    if ($nextword eq '-memory' || $nextword eq '-mem') {
	$memory = shift @ARGV; # abort input parsing here
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
# test memory spec
#------------------------------------------------------------------------------

if ($memory && $memory != 4) {
    my $xJAVA_OPTS = "-Ddebugging=true -Dtesting=true -Xmx${memory}000M";
    $javacontroller .= " xJAV_OPTS \"$xJAVA_OPTS\"";
}


#------------------------------------------------------------------------------
# get a Project instance
#------------------------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);
if (!$adb || $adb->errorStatus()) {
# abort with error message
     &showusage("Invalid organism '$organism' on instance '$instance'");
}

my ($projects,$msg);
if ($projectname =~ /\D/) {
   ($projects,$msg) = $adb->getProject(projectname=>$projectname);
}
else {
   ($projects,$msg) = $adb->getProject(project_id=>$projectname);
} 

# test uniqueness    
     
unless ($projects && @$projects == 1) {
    &showusage("Invalid or ambiguous project specification: $msg");
}

my $project = $projects->[0];

#------------------------------------------------------------------------------
# change to the right directory; use current if rundir is defined but 0
#------------------------------------------------------------------------------

unless (defined($rundir)) {
# try to pick up the directory from the database
     $rundir = $project->getDirectory();
     print STDERR "Undefined directory for project $projectname\n" unless $rundir;
}

if ($rundir && $rundir ne $pwd) {
    print STDOUT "Changing work directory from $pwd to $rundir\n";
    unless (chdir($rundir)) {
# failed to change directory, try to recover by staggering the change
        unless (chdir ("/nfs/repository") && chdir($rundir)) {
            print STDERR "|| -- Failed to change work directory : "
                              ."possible automount failure\n";
	    exit 1;
	}
	print STDOUT "chdir recovered from automount failure\n";
    }
 # get current directory
    $pwd = `pwd`; chomp $pwd;
    $pwd =~ s?.*automount.*/nfs?/nfs?;
    $pwd =~ s?.*automount.*/root?/nfs?;
}

#------------------------------------------------------------------------------
# check existence and accessibility of gap5 database to be imported
#------------------------------------------------------------------------------

unless ( -f "${gap5name}.$version") {
    print STDOUT "!! -- Project $gap5name version $version"
                     ." does not exist in $pwd --\n";
    exit 1;
}

if ( -f "${gap5name}.$version.BUSY") {
    print STDOUT "!! -- Import of project $gap5name aborted:"
                     ." version $version is BUSY --\n";
    exit 1;
}

if ( -f "${gap5name}.A.BUSY") {
    print STDOUT "!! -- Import of project $gap5name WARNING:"
                     ." version A is BUSY --\n";
    exit 1 if $abortonwarning;
}

if ( -f "${gap5name}.B.BUSY") {
    print STDOUT "!! -- Import of project $gap5name aborted:"
                     ." version B is BUSY --\n";
    exit 1;
}

# determine if script run in standard mode

my $nonstandard = (uc($gap5name) ne uc($projectname) || $version ne '0') ? 1 : 0;
print STDOUT "$0 running in non-standard mode\n" if $nonstandard;

# check age

unless ($version eq "A" || $nonstandard) {
    my @astat = stat "$gap5name.A";
    my @vstat = stat "$gap5name.$version";
    if (@vstat && @astat && $vstat[9] <= $astat[9]) {
        print STDERR "!! -- Import of project $gap5name WARNING:"
                     ." version $version is older than version A --\n";
        unless ($noagetest) {
	    print STDERR "!! -- Import of $gap5name.$version skipped --\n";
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

#------------------------------------------------------------------------------
# export the database as a depadded CAF file
#------------------------------------------------------------------------------

my $samfile = "/tmp/${gap5name}.$$.samfile.sam";

my $bamroot = "/tmp/${gap5name}.$$.bamfile";
my $bamfile = "$bamroot.bam";
my $idxfile = "$bamroot.bai";

my $tmpfile = "/tmp/${gap5name}.$$.tmpfile.bam"; # intermediate

my $consensus = "/tmp/${gap5name}.$$.consensus.faq";

print STDOUT "Converting Gap5 database $gap5name.$version to indexed BAM\n";

system ("$gap5toSam -out $samfile  $gap5name.$version"); # create sam file
print STDOUT "using samtools to convert SAM to BAM\n";
system ("$samtools view -S -b -u $samfile > $tmpfile") if ($? == 0);    # create raw bam file
print STDOUT "using samtools to sort and index\n";
system ("$samtools sort $tmpfile $bamroot")            if ($? == 0);    # sort bam file
system ("$samtools index $bamfile $idxfile")           if ($? == 0);    # index bam file

print STDOUT "Writing Gap5 consensus for database $gap5name.$version to fastq file\n";

system ("$gap5consensus -out $consensus $gap5name.$version"); # create fasta file

unless ($? == 0) {
    print STDERR "!! -- FAILED to create a BAM file from $gap5name.$version ($?) --\n";
    print STDERR "!! -- Import of $gap5name.$version aborted --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# change data in the repository: create backup version B  
#------------------------------------------------------------------------------

unless ($version eq "B" || $nonstandard) {
    print STDOUT "Backing up version $version to $gap5name.B\n";
    if (-f "$gap5name.B") {
# extra protection against busy B version preventing the backup
        if ( -f "${gap5name}.B.BUSY") {
            print STDERR "!! -- Import of project $gap5name ABORTED:"
                        ." version B is BUSY; backup cannot be made --\n";
            exit 1;
        }
        system ("rmdb $gap5name B");
        unless ($? == 0) {
            print STDERR "!! -- FAILED to remove existing $gap5name.B ($?) --\n"; 
            print STDERR "!! -- Import of $gap5name.$version aborted --\n";
            exit 1;
        }
    }
    system ("cpdb $gap5name $version $gap5name B");
    unless ($? == 0) {
        print STDERR "!! -- WARNING: failed to back up $gap5name.$version ($?) --\n";
        if ($abortonwarning) {
            print STDERR "!! -- Import of $gap5name.$version aborted --\n";
            exit 1;
        }
    }       
}

#------------------------------------------------------------------------------
# extract contig order from the Gap5 database
#------------------------------------------------------------------------------

#my $scaffoldfile = "/tmp/".lc($gap5name.".".$version.".$$.sff");
#&mySystem ("$scaffold_script $gap5name $version > $scaffoldfile");

#------------------------------------------------------------------------------
# change the data in Arcturus
#------------------------------------------------------------------------------

$project->fetchContigIDs(); # load the current contig IDs before import
#$project->fetchContigIDs(noscaffold=>1); # load the current contig IDs before import

print STDOUT "Importing into Arcturus\n";

$command  = "$javacontroller $import_script -instance $instance -organism $organism "
          . "-projectname $projectname -in $bamfile"; 

print STDOUT "$command \n";

my $rc = &mySystem ($command);

# exit status 0 for no errors with or without new contigs imported
#             1 (or 256) for an error status 

if ($rc) {
    print STDERR "!! -- FAILED to import from CAF file $bamfile ($?) --\n";
    exit 1;
}

exit 0; # test abort

# decide if new contigs were imported by probing the project again

if (0 && $project->hasNewContigs()) { # disabled for the moment

#------------------------------------------------------------------------------
# consensus import
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# consistence tests after import
#------------------------------------------------------------------------------

    my $allocation_script = "${arcturus_home}/utils/read-allocation-test"; # better use Davids count script

    my $username = $ENV{'USER'};
# if script is run in test mode add .pl to bypass the wrapper
    $allocation_script .= ".pl" if (defined($username) && $basedir =~ /$username/);

# first we test between projects, then inside, because inside test may reallocate

    print STDOUT "Testing read allocation for possible duplicates between projects\n";

# do not use repair mode for inconsistencies between projects, just record them

    my $allocation_b_log = "readallocation-b-.$$.${gap5name}.log"; # between projects

    &mySystem ("$allocation_script -instance $instance -organism $organism "
           ."-nr -problemproject $problemproject -workproject $projectname "
           ."-between -log $allocation_b_log -mail arcturus-help");


    print STDOUT "Testing read allocation for possible duplicates inside projects\n";

# use repair mode for inconsistencies inside the project

    my $allocation_i_log = "readallocation-i-.$$.${gap5name}.log"; # inside project

    &mySystem ("$allocation_script -instance $instance -organism $organism "
           ."$repair -problemproject $problemproject -workproject $projectname "
           ."-inside -log $allocation_i_log -mail arcturus-help");

    print STDOUT "New data from database $gap5name.$version successfully processed\n";
}

else {
    print STDOUT "Database $gap5name.$version successfully processed, "
               . "but does not contain new contigs\n";
}
     
$adb->disconnect();

#-------------------------------------------------------------------------------

unless ($keep) {

    print STDOUT "Cleaning up\n";

#    &mySystem ("rm -f $samfile $bamfile $scaffoldfile");
}

print STDOUT "\n\nIMPORT OF $projectname HAS FINISHED.\n";

exit 0;


# The next subroutine was shamelessly stolen from WGSassembly.pm


sub mySystem {
    my ($cmd) = @_;

    my $res = 0xffff & system($cmd);
    return 0 if ($res == 0); # success

    print STDERR "$cmd\n";
    printf STDERR "system(%s) returned %#04x: ", $cmd, $res;

    if ($res == 0xff00) {
	print STDERR "command failed: $!\n";
	return 1;
    } 
    elsif ($res > 0x80) {
	$res >>= 8;
	print STDERR "exited with non-zero status $res\n";
    } 
    else {
	my $sig = $res & 0x7f;
	print STDERR "exited through signal $sig";
	if ($res & 0x80) {print STDERR " (core dumped)"; }
	print STDERR "\n";
    }
    exit 1;
}

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
    print STDERR "-gap5name\t(g) Gap4 database if different from default "
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

