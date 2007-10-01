#!/usr/local/bin/perl -w

use strict;

use Cwd;

# export a single project or a scaffold from arcturus into a gap4 database

# script to be run from directory where gap4 database is to be created 

# for input parameter description use help

#------------------------------------------------------------------------------

my $pwd = Cwd::cwd(); # the current directory
my $basedir = `dirname $0`; chomp $basedir; # directory of the script
my $arcturus_home = "${basedir}/..";
my $javabasedir   = "${arcturus_home}/utils";
my $badgerbin     = "$ENV{BADGER}/bin";

#------------------------------------------------------------------------------
# command line input parser
#------------------------------------------------------------------------------

my ($instance,$organism,$projectname,$assembly,$gap4name,$version,$scaffold);

my $export_script = "${arcturus_home}/utils/contig-export";
$export_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

my ($nolock,$rundir,$create,$superuser,$keep,$debug);

my $validkeys = "instance|i|organism|o|project|p|assembly|a|scaffold|c|"
              . "gap4name|g|version|v|"
              . "script|nolock|rundir|rd|create|superuser|su|"
              . "keep|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validkeys)\b/) {
        &showusage("Invalid keyword '$nextword'"); # and exit
    }

    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance      = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism      = shift @ARGV;
    }  

    if ($nextword eq '-project'  || $nextword eq '-p') {
        die "You can't re-define project" if $projectname;
        $projectname   = shift @ARGV;
        $version = "A" unless defined($version);   #? somewhere else
        $gap4name = $projectname unless $gap4name; #? somewhere else
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly      = shift @ARGV;
    }

    if ($nextword eq '-scaffold' || $nextword eq '-s') {
        $scaffold      = shift @ARGV; # agp file or ' separated list
    }

    if ($nextword eq '-gap4name' || $nextword eq '-g') {
        $gap4name      = shift @ARGV;
    }

    if ($nextword eq '-version'  || $nextword eq '-v') {
        $version       = shift @ARGV;
    }

    if ($nextword eq '-script') {  # optional, default contig-export
        $export_script = shift @ARGV;
    }

    if ($nextword eq '-rundir' || $nextword eq '-rd') {
        $rundir        = shift @ARGV;
    }

    if ($nextword eq '-create') {
        $create        = 1;
    }

    if ($nextword eq '-superuser' || $nextword eq '-su') {
        $superuser     = 1;
    }

    if ($nextword eq '-keep') {
        $keep          = 1;
    }

    if ($nextword eq '-help'     || $nextword eq '-h') {
        &showusage(); # and exit
    }
}

#------------------------------------------------------------------------------
# test input parameters
#------------------------------------------------------------------------------

unless (defined($instance) && defined($organism)) {
    print STDOUT "!! -- No database instance specified --\n" unless $instance;
    print STDOUT "!! -- No organism database specified --\n" unless $organism;
    &showusage(); # and exit
}

unless (defined($projectname)) {
    print STDOUT "!! -- No project name specified --\n";
    &showusage(); # and exit
}

# if no scaffold is defined, the project will be exported to gap4name
# if  a scaffold is defined, the contigs will be exported to gap4name, which
# must be different from projectname; hence, if no gap4name explicitly defined
# generate one like "projectscaffold<n>" ?

if (defined($scaffold) && $projectname eq $gap4name) {
    print STDOUT "!! -- No (valid) gap4name specified --\n";
    &showusage(); # and exit
}

# if a project is exported, you cannot use version '0' or 'B'

if (!$scaffold && ($version eq '0' || $version eq 'B')) {
    print STDOUT "!! -- Project version $version can not be overwritten --\n";
    exit 1;
}

# ? IF NOLOCK test that you are not exporting to the standard version A ?

#------------------------------------------------------------------------------
# change to the right directory
#------------------------------------------------------------------------------

if ($rundir) {
# test if directory exists; if not (try to) create it
    unless (-d $rundir) {
        print STDOUT "Directory $rundir does not exist\n";
	exit 1 unless $create;
        print STDOUT "Creating directory $rundir\n";
        system("mkdir $rundir");
        if ($?) {
            print STDERR "Failed to create $rundir\n";
            exit 1;
	}
        system("chmod g+w $rundir");
    }         
    print STDOUT "Changing work directory from $pwd to $rundir\n";
    chdir ($rundir);
    $pwd = Cwd::cwd();
}

#------------------------------------------------------------------------------
# check if target gap4 database is accessible
#------------------------------------------------------------------------------

if ( -f "${gap4name}.$version.BUSY") {
    print STDERR "!! -- Project $gap4name version $version is BUSY --\n";
    print STDERR "!! -- Export of $gap4name.$version aborted --\n";
# or, change name?
    exit 1;
}

#------------------------------------------------------------------------------
# update consensus for the project
#------------------------------------------------------------------------------

my $consensus_script = "${javabasedir}/calculateconsensus";

my $database = '';
unless ($instance eq 'default' || $organism eq 'default') {
    $database = "-instance $instance -organism $organism";
}

system ("$consensus_script $database -project $projectname -quiet -lowmem");

#------------------------------------------------------------------------------
# lock the project (before export, to prevent any changes while exporting)
#------------------------------------------------------------------------------

my $lock_script = "${arcturus_home}/utils/project-lock";
$lock_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

unless ($nolock) {
# try to acquire the lock, but do not use privilege ??
    my $command = "$lock_script -i $instance -o $organism -p $projectname ";

    system ("$command -confirm") unless $superuser;
    system ("$command -su -confirm") if $superuser; # ??
       
    if ($?) {
        print STDOUT "!! -- Arcturus project $projectname is not"
                   . " accessible --\n"; # you cannot acquire a lock
        exit 1;
    }
}

#------------------------------------------------------------------------------
# export the project or scaffold as a depadded CAF file
#------------------------------------------------------------------------------

my $depadded = "/tmp/${gap4name}.$$.depadded.caf";

my $command = "$export_script -instance $instance -organism $organism "
            . "-caf $depadded ";

if ($scaffold) {
# export using contig-export.pl TO BE DEVELOPED
    $command .= "-scaffold $scaffold "; # processing of $scaffold in export script
    unless ($gap4name) {
# if gap4name defined, use that, else generate one project_scaffold_NN
    }
}
else { # standard project export
    $command =~ s/contig/project/; # temporary change to project-export script
    $command .= "-project $projectname ";
}

print STDOUT "Exporting from Arcturus to CAF file $depadded\n";

system ($command);

unless ($? == 0) {
    print STDERR "!! -- FAILED to create valid CAF file $depadded ($?) --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# converting CAF file into gap4 database
#------------------------------------------------------------------------------

print STDOUT "Converting CAF file into Gap4 database\n";

# for both projects and scaffolds remove existing gap4 db version

if ( -f "${gap4name}.$version.BUSY") {
    print STDERR "!! -- Project $gap4name version $version is BUSY --\n";
    print STDERR "!! -- Export of $gap4name.$version aborted --\n";
# or, change name?
    exit 1;
}

if ( -f "${gap4name}.$version") {
    system ("rmdb $gap4name $version");
    unless ($? == 0) {
        print STDERR "!! -- FAILED to remove existing $gap4name.$version ($?) --\n"; 
        print STDERR "!! -- Export of $gap4name.$version aborted --\n";
# or, change name?
        exit 1;
    }
}

system ("${badgerbin}/caf2gap -project $gap4name -version $version -ace $depadded");

unless ($? == 0) {
    print STDERR "!! -- FAILED to create a Gap4 database ($?) --\n";
    print STDERR "!! -- Export of $gap4name.$version aborted --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# changing access privileges on newly created database
#------------------------------------------------------------------------------

print STDOUT "Changing access provileges on Gap4 database\n";

system ("chmod g-w ${gap4name}.$version");

system ("chmod g-w ${gap4name}.$version.aux");

#------------------------------------------------------------------------------
# marking project as exported (only in standard export mode)
#------------------------------------------------------------------------------

unless ($scaffold || $projectname ne $gap4name || $version ne 'A') {

    print STDOUT "Marking project $projectname as exported\n";

    my $marker_script =  "${arcturus_home}/utils/project-export-marker";
    $marker_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

    system ("$marker_script -i $instance -o $organism -p $projectname "
	   ."-file $pwd/${gap4name}.$version");

    if ($?) {
	print STDERR "!! -- No export mark written ($?) --\n";
    }
}

#------------------------------------------------------------------------------
# transfer the project lock to the project owner
#------------------------------------------------------------------------------

unless ($nolock) { # possibly completely different, what about scaffolds?

    print STDERR "Transferring lock to project owner\n";

    system ("$lock_script -i $instance -o $organism -p $projectname "
	   ."-transfer owner -confirm");

    my $status = $?;

    if ($status && $status == 2) {
# transfer failed because the project has no owner, unlock it
        my $unlock_script = "${arcturus_home}/utils/project-unlock";
        $unlock_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

        system ("$unlock_script -i $instance -o $organism -p $projectname "
	       ."-up -confirm");

        print STDERR "!! -- Failed to unlock project $projectname --\n" if $?;
    }
    elsif ($status) {
        print STDERR "!! -- Failed to transfer lock --\n";
    }
}

#------------------------------------------------------------------------------
# cleaning up only standard project export 
#------------------------------------------------------------------------------

unless ($scaffold || $projectname ne $gap4name || $version ne 'A') {

    print STDOUT "Cleaning up\n";

    system ("rm -f $depadded");

    unless (-e "${gap4name}.B") {
        print STDERR "!! -- version ${gap4name}.0 kept because "
                   . "no back-up B version found --\n";
        exit 0;
    }

    if ( -z "{gap4name}.B") {
        print STDERR "!! -- version ${gap4name}.0 kept because "
	           . "corrupted B version found --\n";
        exit 0;
    }

    if (-f "${gap4name}.0") {
# delete version 0 if it is older than B
        my @vstat = stat "$gap4name.0";
        my @bstat = stat "$gap4name.B";

        if ($vstat[9] <= $bstat[9]) {
            print STDOUT "project version ${gap4name}.0 is deleted\n";
            system ("rmdb ${gap4name} 0");
	}
	else {
            print STDERR "!! -- version ${gap4name}.0 kept because "
		       . "no valid B version was found\n";
        }
    }
}

#-------------------------------------------------------------------------------

exit 0 if $keep;

print STDOUT "Cleaning up\n";

system ("rm -f $depadded");

exit 0;

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub showusage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code;
    print STDERR "\n";
    print STDERR "Export a project from Arcturus to a specified Gap database\n";
    print STDERR "\n";
    print STDERR "script to run in directory of Gap4 database\n";
    print STDERR "\n";
    print STDERR "default export is of database 'project.0'\n";
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
    print STDERR "-create\t\t(try to) create the directory if it does not exist\n";
    print STDERR "\n";
    print STDERR "-script\t\t(default project-export) name of loader script used\n";
    print STDERR "\n";
    print STDERR "-nolock\t\t(nl) explicitly do not (try to) lock the database\n";

    print STDERR "\n";
    print STDERR "-keep\t\t keep temporary caf file\n";
    print STDERR "\n";
    print STDERR "-debug\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code;

    exit 1;
}
