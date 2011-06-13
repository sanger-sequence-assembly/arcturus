#!/usr/local/bin/perl -w

use strict;
use Cwd;

use ArcturusDatabase;

use constant WORKING_VERSION => '0';
use constant BACKUP_VERSION => 'Z';

# export a single project or a scaffold from arcturus into a gap database

# script to be run from directory where gap database is to be created 

# for input parameter description use help

#------------------------------------------------------------------------------

my $pwd = cwd();

my $basedir = `dirname $0`; chomp $basedir; # directory of the script
my $arcturus_home = "${basedir}/..";

my $gaproot = "/software/badger/bin";

my $export_script = "${arcturus_home}/java/scripts/exportsamfile";

my $java_opts = defined($ENV{'JAVA_DEBUG'}) ? "-Ddebugging=true -Dtesting=true -Xmx4000M" : "-Xmx4000M";

#------------------------------------------------------------------------------
# command line input parser
#------------------------------------------------------------------------------

my ($instance,$organism,$projectname,$assembly,$gapname,$version,$scaffold);

my ($nolock,$rundir,$create,$superuser,$keep,$debug);

my $minerva = '';

my $validkeys = "instance|i|organism|o|project|p|assembly|a|scaffold|c|"
              . "gapname|g|version|v|nolock|nl|"
              . "script|rundir|rd|create|superuser|su|"
              . "keep|minerva|m|passon|po|help|h|java_opts";

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
        $gapname = uc($projectname) unless $gapname; #? somewhere else
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly      = shift @ARGV;
    }

    if ($nextword eq '-scaffold' || $nextword eq '-s') {
        $scaffold      = shift @ARGV; # agp file or ' separated list
    }

    if ($nextword eq '-gapname' || $nextword eq '-g') {
        $gapname      = shift @ARGV;
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

#    if ($nextword eq '-transferlock' || $nextword eq '-tl') {
#        $     = 1;
#    }
    if ($nextword eq '-nolock' || $nextword eq '-nl') {
        $nolock        = 1;
    }

    if ($nextword eq '-keep') {
        $keep          = 1;
    }

    if ($nextword eq '-minerva' || $nextword eq '-m') {
        $minerva       = "#MINERVA "; # minerva prefix
    }

    if ($nextword eq '-passon' || $nextword eq '-po') {
        last; # abort parsing here and pass remainder of ARGV on to export script
    }

    if ($nextword eq '-java_opts') {
	$java_opts = shift @ARGV; # abort input parsing here
    }

    if ($nextword eq '-help'     || $nextword eq '-h') {
        &showusage(); # and exit
    }
}

#------------------------------------------------------------------------------
# test input parameters
#------------------------------------------------------------------------------

unless (defined($instance) && defined($organism)) {
    print STDERR "!! -- No database instance specified --\n" unless $instance;
    print STDERR "!! -- No organism database specified --\n" unless $organism;
    &showusage(); # and exit
}

unless (defined($projectname)) {
    print STDERR "!! -- No project name specified --\n";
    &showusage(); # and exit
}

#------------------------------------------------------------------------------
# Set the JVM options
#------------------------------------------------------------------------------

if (defined($java_opts)) {
    $ENV{'JAVA_OPTS'} = $java_opts;
}

# if no scaffold is defined, the project will be exported to gapname
# if  a scaffold is defined, the contigs will be exported to gapname, which
# must be different from projectname; if no gapname explicitly defined
# generate one like "projectscaffold<n>" ?

if (defined($scaffold) && $projectname eq $gapname) {
    print STDERR "!! -- No (valid) gapname specified --\n";
    &showusage(); # and exit
}

# if a project is exported, you cannot use version '0' or 'B'

if (!$scaffold && ($version eq '0' || $version eq 'B')) {
    print STDERR "!! -- Project version $version can not be overwritten --\n";
    exit 1;
}

if ($nolock && $version eq 'A') {
# you can not export to the standard version A when not locking the project 
    print STDERR "!! -- Project version $version may not be (over)written --\n";
    exit 1;
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
# test if directory exists; if not (try to) create it
    unless (-d $rundir) {
        print STDERR "Directory $rundir does not exist\n";
	exit 1 unless $create;
        print STDERR "Creating directory $rundir\n";
        my $rc = &mySystem("mkdir $rundir");
        if ($rc) {
            print STDERR "Failed to create $rundir\n";
            exit 1;
	}
        &mySystem("chmod g+w $rundir");
    }       

    unless (chdir($rundir)) {
# failed to change directory, try to recover by staggering the change
        unless (chdir ("/nfs/repository") && chdir($rundir)) {
            print STDERR "|| -- Failed to change work directory : "
                              ."possible automount failure ($!)\n";
            exit 1;
        }
        print STDOUT "chdir recovered from automount failure\n";
    }
    $pwd = cwd();
}

#------------------------------------------------------------------------------
# check if target gap database is accessible
#------------------------------------------------------------------------------

if ( -f "${gapname}.$version.BUSY") {
    print STDERR "!! -- Project $gapname version $version is BUSY --\n";
    print STDERR "!! -- Export of $gapname.$version aborted --\n";
# or, change name?
    exit 1;
}

#------------------------------------------------------------------------------
# backup working version (zero)
#------------------------------------------------------------------------------

my $backup_db = $gapname . '.' . BACKUP_VERSION;
my $backup_busy_file = $backup_db . '.BUSY';
my $backup_aux_file = $backup_db . '.aux';

my $working_db = $gapname . '.' . WORKING_VERSION;
my $working_busy_file = $working_db . '.BUSY';

if (-f $working_db && $version ne BACKUP_VERSION) {
    print STDOUT "Backing up version " . WORKING_VERSION . " to " . BACKUP_VERSION . "\n";

    if (-f $working_busy_file) {
	print STDERR "!! -- Version " . WORKING_VERSION . " is BUSY; backup cannot be made --\n";
            print STDERR "!! -- Export of $gapname.$version aborted --\n";
            exit 1;
    }

    if (-f $backup_db) {
        if ( -f $backup_busy_file) {
            print STDERR "!! -- Version " . BACKUP_VERSION . " is BUSY; backup cannot be made --\n";
            print STDERR "!! -- Export of $gapname.$version aborted --\n";
            exit 1;
        }

        system ("rmdb $gapname " . BACKUP_VERSION);

        unless ($? == 0) {
            print STDERR "!! -- FAILED to remove existing $backup_db ($?) --\n"; 
            print STDERR "!! -- Export of $gapname.$version aborted --\n";
            exit 1;
        }
    }

    system ("cpdb $gapname " . WORKING_VERSION . " $gapname " . BACKUP_VERSION);

    unless (-f $backup_db && -f $backup_aux_file) {
        print STDERR "!! -- WARNING: failed to back up $gapname " . WORKING_VERSION . " --\n";
	print STDERR "!! -- Export of $gapname.$version aborted --\n";
	exit 1;
    }

    print STDOUT "Successfully backed up version " . WORKING_VERSION . " to " . BACKUP_VERSION . "\n\n";
}

#------------------------------------------------------------------------------
# lock the project (before export, to prevent any changes while exporting)
#------------------------------------------------------------------------------

my $lock_script = "${arcturus_home}/utils/project-lock";
$lock_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

unless ($nolock) {
# try to acquire the lock, but do not use privilege ??
    my $command = "$lock_script -i $instance -o $organism -p $projectname ";
#    $command   .= "-minerva " if $minerva;

    system ("$command -confirm") unless $superuser;
    system ("$command -su -confirm") if $superuser; # ??
       
    if ($?) {
        print STDERR "!! -- Locking attempt failed : $command\n";
        print STDERR "!! -- Arcturus project $projectname is not"
                   . " accessible --\n"; # you cannot acquire a lock
        exit 1;
    }
}

#------------------------------------------------------------------------------
# export the project or scaffold as a samfile SAM file
#------------------------------------------------------------------------------

my $samfile = "/tmp/${gapname}.$$.samfile.sam";

my $command = "$export_script -instance $instance -organism $organism -out $samfile";

if ($scaffold) {
# export using contig-export.pl TO BE DEVELOPED project must be mentioned
    $command .= " -project $projectname"; # always required?
    $command .= " -minerva" if $minerva;

    $command .= " -scaffold $scaffold"; # processing of $scaffold in export script
    unless ($gapname) {
# if gapname defined, use that, else generate one project_scaffold_NN
# to be developed (or function in export script?)
    }
    $command .= " @ARGV" if @ARGV;
}
else { # standard project export
    $command .= " -project $projectname";
    $command .= " -minerva" if $minerva;
    $command .= " @ARGV" if @ARGV;
}

print STDERR "Exporting to SAM file $samfile\n";
print STDERR "${minerva}Exporting as SAM\n";

print STDERR "Command: $command\n";
my $rc = &mySystem ($command);

if ($rc) {
    print STDERR "!! -- FAILED to create valid SAM file $samfile ($?) --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# converting SAM file into gap database
#------------------------------------------------------------------------------

print STDERR "${minerva}Converting SAM file into Gap database\n";

# for both projects and scaffolds remove existing gap db version

if ( -f "${gapname}.$version.BUSY") {
    print STDERR "!! -- Project $gapname version $version is BUSY --\n";
    print STDERR "!! -- Export of $gapname.$version aborted --\n";
# or, change name?
    exit 1;
}

if ( -f "${gapname}.$version") {
    system ("rmdb $gapname $version");
    unless ($? == 0) {
        print STDERR "!! -- FAILED to remove existing $gapname.$version ($?) --\n"; 
        print STDERR "!! -- Export of $gapname.$version aborted --\n";
# or, change name?
        exit 1;
    }
}

system ("${gaproot}/tg_index -s $samfile -o $gapname.$version");

unless ($? == 0) {
    print STDERR "!! -- FAILED to create a Gap database ($?) --\n";
    print STDERR "!! -- Export of $gapname.$version aborted --\n";
    exit 1;
}

#------------------------------------------------------------------------------
# changing access privileges on newly created database
#------------------------------------------------------------------------------

print STDERR "Changing access privileges on Gap database\n";

&mySystem ("chmod ug-w ${gapname}.$version.g5d");

&mySystem ("chmod ug-w ${gapname}.$version.g5x");

#------------------------------------------------------------------------------
# marking project as exported (only in standard export mode)
#------------------------------------------------------------------------------

unless ($scaffold || uc($projectname) ne uc($gapname) || $version ne 'A') {

    print STDERR "Marking project $projectname as exported\n";

    my $marker_script =  "${arcturus_home}/utils/project-export-marker";
    $marker_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode
    system ("$marker_script -i $instance -o $organism -p ${gapname} "
	   ."-file $pwd/${gapname}.$version");

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
	   ."-transfer owner -confirm"); # minerva ?
    my $status = $?;

    if ($status && ($status == 2 || $status == 512)) {
# transfer failed because the project has no owner, unlock it
        my $unlock_script = "${arcturus_home}/utils/project-unlock";
        $unlock_script .= ".pl" if ($basedir =~ /ejz/); # script is run in test mode

        system ("$unlock_script -i $instance -o $organism -p $projectname -confirm");

        print STDERR "!! -- Failed to unlock project $projectname --\n" if $?;
    }
    elsif ($status) {
        print STDERR "!! -- Failed to transfer lock --\n";
    }
}

#------------------------------------------------------------------------------
# cleaning up only standard project export 
#------------------------------------------------------------------------------

unless ($scaffold || $projectname ne $gapname || $version ne 'A') {

    print STDERR "Cleaning up database directory\n";

    if ( !( -e "${gapname}.B")) {
        print STDERR "!! -- version ${gapname}.0 kept because no "
            . "back-up B version found --\n" if (-f "${gapname}.0");
    }

    elsif ( -z "{gapname}.B") {
        print STDERR "!! -- version ${gapname}.0 kept because "
	    . "corrupted B version found --\n" if (-f "${gapname}.0");
    }

    elsif ( -f "${gapname}.0") {
# delete version 0 if it is older than B
        my @vstat = stat "$gapname.0";
        my @bstat = stat "$gapname.B";

        if ($vstat[9] <= $bstat[9]) {
            print STDERR "Deleting project version ${gapname}.0\n";
            &mySystem ("rmdb ${gapname} 0");
	}
	else {
            print STDERR "!! -- version ${gapname}.0 kept because "
		       . "no valid B version was found\n";
        }
    }
}

#-------------------------------------------------------------------------------

unless ($keep) {
    print STDERR "Cleaning up temporary files\n";
    &mySystem ("rm -f $samfile");
}

print STDOUT "\n\nEXPORT OF $projectname HAS FINISHED.\n";

exit 0;

# The next subroutine was shamelessly stolen from WGSassembly.pm

sub mySystem {
    my ($cmd) = @_;

    my $res = 0xffff & system($cmd);
    return 0 if ($res == 0);

    print  STDERR "$cmd\n";
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
# info
#-------------------------------------------------------------------------------

sub showusage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code;
    print STDERR "\n";
    print STDERR "$0 wrapper script\n";
    print STDERR "\n";
    print STDERR "Export a project or scaffold from Arcturus project to a specified Gap database\n";
    print STDERR "\n";
    print STDERR "The script must be run in the directory containing the Gap database\n";
    print STDERR "\n";
    print STDERR "Default export is of database 'project.0'\n";
    print STDERR "\n";
    print STDERR "A backup copy will be made to 'project." . BACKUP_VERSION . "'\n";
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
    print STDERR "OPTIONAL PARAMETERS (data selection and destination):\n";
    print STDERR "\n";
    print STDERR "-assembly\t(a) needed to resolve ambiguous project name\n";
    print STDERR "\n";
    print STDERR "-gapname\t(g) Gap database if different from default "
                ."'project'\n";
    print STDERR "-version\t(v) Gap database version if different from 0\n";
    print STDERR "\n";
    print STDERR "-scaffold\t(s) comma-separated list of contigs (with sign)\n\t\t"
               . "    or '.apg' file name (NOT YET OPERATIONAL)\n\n";
    print STDERR "\t\tContigs of the scaffold must all belong to the specified\n"
               . "\t\tproject; the gapname must be different from the project\n"
               . "\t\tname; in its absence a name will be autogenerated\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS (control):\n";
    print STDERR "\n";
    print STDERR "-rundir\t\t(rd) explicitly set directory where script will run\n";
    print STDERR "-create\t\t(try to) create the directory if it does not exist\n";
    print STDERR "\n";
    print STDERR "-script\t\t(default 'project-export') name of loader script used\n";
    print STDERR "\n";
    print STDERR "-nolock\t\t(nl) explicitly do not (try to) lock the database\n";
    print STDERR "\n";
    print STDERR "-minerva\t(m) use when running script under Minerva control\n";
    print STDERR "\n";
    print STDERR "-keep\t\t keep temporary caf file\n";
    print STDERR "\n";
    print STDERR "-debug\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n\n" if $code;

    exit 1;
}
