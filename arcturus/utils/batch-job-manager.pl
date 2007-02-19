#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;

my $project;
my $assembly;
my $fopn;

my $subdir;

my $ioport;
my $delayed;
my $batch;

my $verbose;
my $confirm;

my $validKeys  = "organism|instance|project|assembly|fopn|import|export|"
               . "batch|nobatch|delayed|subdir|sd|r|"
               . "verbose|debug|confirm|submit|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                           
    if ($nextword eq '-instance') {
        &showUsage("You can't re-define instance") if $instance;
        $instance = shift @ARGV;
    }
      
    if ($nextword eq '-organism') {
        &showUsage("You can't re-define organism") if $organism;
        $organism = shift @ARGV; 
    }

    $project      = shift @ARGV    if ($nextword eq '-project');

    $assembly     = shift @ARGV    if ($nextword eq '-assembly');

    $fopn         = shift @ARGV    if ($nextword eq '-fopn');

    $delayed      = 1              if ($nextword eq '-delayed');

    $subdir       = 1              if ($nextword eq '-subdir');
    $subdir       = 1              if ($nextword eq '-sd');
    $subdir       = 1              if ($nextword eq '-r');

    if ($nextword eq '-import' || $nextword eq '-export') {
        &showUsage("Invalid input parameter $nextword") if ($ioport);
        $ioport   = 'import'       if ($nextword eq '-import');
        $ioport   = 'export'       if ($nextword eq '-export');
    }
    
    $delayed      = 1              if ($nextword eq '-delayed');
    $batch        = 1              if ($nextword eq '-delayed');
    $batch        = 1              if ($nextword eq '-batch');
    $batch        = 0              if ($nextword eq '-nobatch');

    $verbose      = 1              if ($nextword eq '-verbose');

    $verbose      = 2              if ($nextword eq '-debug');

    $confirm      = 1              if ($nextword eq '-confirm');
    $confirm      = 1              if ($nextword eq '-submit');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing project ID or fopn") unless ($project || $fopn);

&showUsage("Missing import or export key") unless $ioport;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$logger->info("Database ".$adb->getURL." opened succesfully");

$adb->setLogger($logger);

#----------------------------------------------------------------
# identify the project
#----------------------------------------------------------------

my @projects;

if ($project) {
    my $Projects = &getProjectInstance($project,$assembly,$adb,1); # allow multiple
 
    &showUsage("Unknown project(s) $project") unless $Projects;

    foreach my $project (@$Projects) {
        push @projects, $project->getProjectName();
    }
}
elsif ($fopn) {
    my @ids;
    $fopn = &getNamesFromFile($fopn);
    foreach my $project (@$fopn) {
        my $Projects = &getProjectInstance($project,$assembly,$adb); 
# allow multiple projects (use wildcards)
        next unless $Projects;
        foreach my $project (@$Projects) {
            push @projects, $project->getProjectName();
        }
    }
}
 
&showUsage("Missing project ID or fopn, or unknown project(s)") unless @projects;

#----------------------------------------------------------------

# det get current directory

my $pwd = `pwd`;
chomp $pwd;

# get the repository position

my $work_dir = `pfind -q $organism`;

#my $import_script = "/nfs/pathsoft/arcturus/utils/importprojectintoarcturus.csh";
# temporary use test script
#$import_script = "/nfs/team81/ejz/arcturus/dev/utils/importprojectintoarcturus.csh";

#my $export_script = "/nfs/pathsoft/arcturus/utils/exportprojectfromarcturus.csh";
# temporary use test script
#$export_script = "/nfs/team81/ejz/arcturus/dev/utils/exportprojectfromarcturus.csh";

&showUsage("Can't locate project directory for $organism") unless $work_dir;

$work_dir .= "/arcturus/import-export"; # full work directory

my $date = `date +%Y%m%d`; $date =~ s/\s//g;

foreach my $project (@projects) {

    if ($subdir) {
        my $subdir = "$pwd/$project";
        chdir ($subdir);
        my $newpwd = `pwd`;
        chomp $newpwd;
        unless ($newpwd eq $subdir) {
            $logger->warning("FAILED to find subdir $project");
	}
        $logger->info("Project directory $newpwd used");
    }

    if ($batch) {
# export by batch job
        my $command = "bsub -q  pcs3q1 -N ";
        $command .= "-b 18:00 " if $delayed;
        $command .= "-o $work_dir/$ioport-$date-".lc($project)." "; # output file
        if ($ioport eq 'import') {
            $command .= "$work_dir/importintoarcturus.csh $project";
#        $command .= "$import_script $instance $organism $project 64 0"; # ?
#        $command .= "$import_script -instance $instance -organism $organism -project $project -64bit -consensus "; # ?
        }
        elsif ($ioport eq 'export') {
            $command .= "$work_dir/exportfromarcturus.csh $project";
#        $command .= "$export_script $instance $organism $project 64 0"; # ?
#        $command .= "$export_script -instance $instance -organism $organism -project $project -64bit -consensus "; # ?
        }

        unless ($confirm) {
            $logger->warning("=> command to be issued:\n$command");
            $logger->warning("=> use '-confirm' to submit"); 
            next;
        }

        unless ( (0xffff & system($command)) == 0) {
            $logger->severe("failed to submit $ioport job for project $project");
        }
    }
    else {
# export under user control
        my $command;
        my $message = "Project $project will be ${ioport}ed ";
        my $pwd = `pwd`; chomp $pwd;
        if ($ioport eq 'import') {
            $command = "$work_dir/importintoarcturus.csh $project";
            $message .= "from gap4 database\n   $pwd/$project.0";
	}
        elsif ($ioport eq 'export') {
            $command = "$work_dir/exportfromarcturus.csh $project";
            $message .= "to gap4 database\n   $pwd/$project.A";
        }

        unless ($confirm) {
            $logger->warning("=> $message");
            $logger->warning("=> repeat using '-confirm'");
            next;
        }

        $logger->warning("Project $project is being ${ioport}ed: "
			."this may take some time .. be patient");

#	$logger->warning("Not yet operational");
#        next;
        unless ( (0xffff & system($command)) == 0) {
            $logger->severe("failed to ${ioport} project $project");
        }
    }

    chdir ($pwd) if $subdir;
}

exit 0;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $record = <$FILE>)) {
        next unless ($record =~ /\S/);
        if ($record =~ s/^\s*(\S+)\s*$//) {
            push @list, $1;
        }
        elsif ($record =~ /^\s*from\s+(\d+)\s+to\s+(\d+)\s*$/i) {
            my $start = $1;
            my $final = $2;
            for my $i ($start .. $final) {
                push @list, $i;
            }
        }
        else {
            print STDERR "Invalid input on file $file: $record\n";
        }
    }
    return [@list];
}

#------------------------------------------------------------------------
# identify project
#------------------------------------------------------------------------

sub getProjectInstance {
# returns Project given project ID or name and (optionally) assembly
# (also in case of project ID we consult the database to check its existence)
    my $identifier = shift;  # ID or name
    my $assembly = shift; # ID or name
    my $adb   = shift;
    my $multi = shift;

    return undef unless defined($identifier);

# get project info by getting a Project instance

    my %projectoptions;
    $projectoptions{project_id}  = $identifier if ($identifier !~ /\D/);
    $projectoptions{projectname} = $identifier if ($identifier =~ /\D/);
    if (defined($assembly)) {
        $projectoptions{assembly_id}   = $assembly if ($assembly !~ /\D/);
        $projectoptions{assemblyname}  = $assembly if ($assembly =~ /\D/);
    }

# find the project and test if it is unique

    my ($Project,$log) = $adb->getProject(%projectoptions);
# test if any found
    unless ($Project && @$Project) {
        my $message = "No project $identifier found";
        $message .= " in assembly $assembly" if $projectoptions{assemblyname};
        $logger->warning("$message: $log");
        return undef;
    }
# if multiple projects allowed return an array ref
    return $Project if $multi;
# test if project is unique; if not return undef
    if ($Project && @$Project > 1) {
        my $list = '';
        foreach my $project (@$Project) {
            $list .= $project->getProjectName()." ("
                   . $project->getAssemblyID().") ";
        }
        $logger->warning("More than one project found: $list");
        $logger->warning("Are you sure you do not need to specify assembly?")
            unless defined($assembly);
        return undef;
    }

    return $Project->[0] if $Project;

    return undef;
}

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-import\t\t\n";
    print STDERR "-export\t\t\n";
    print STDERR "\n";
    print STDERR "-project\tproject identifier (number or name, including "
                                               . "wildcards)\n";
    print STDERR "-fopn\t\tfile of project identifiers\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-assembly\n";
    print STDERR "-gap4name\n";
    print STDERR "-delayed\n";
    print STDERR "\n";

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
 

