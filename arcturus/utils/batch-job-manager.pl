#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

use Cwd;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;

my $project;
my $assembly;
my $fopn;
my $problem;

my $subdir;

my $ioport;
my $delayed;
my $batch;
my $babel;
my $pcs3;

my $new;
my $script;

my $verbose;
my $confirm;
my $debug;

my $validKeys  = "organism|o|instance|i|project|p|assembly|a|fopn|fofn|problem|"
               . "import|export|script|new|"
               . "batch|nobatch|delayed|subdir|sd|r|babel|pcs3|" # default phrap
               . "verbose|debug|confirm|submit|help|h";

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

    $fopn         = shift @ARGV    if ($nextword eq '-fopn');
    $fopn         = shift @ARGV    if ($nextword eq '-fofn');

    $problem      = shift @ARGV    if ($nextword eq '-problem');

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

    $new          = 1              if ($nextword eq '-new'); # TBD
    $script       = shift @ARGV    if ($nextword eq '-script');

    $babel        = 1              if ($nextword eq '-babel');
    $pcs3         = 0              if ($nextword eq '-babel');
    $pcs3         = 1              if ($nextword eq '-pcs3');
    $babel        = 0              if ($nextword eq '-pcs3');

    $verbose      = 1              if ($nextword eq '-verbose');

    $debug        = 1              if ($nextword eq '-debug');

    $confirm      = 1              if ($nextword eq '-confirm');
    $confirm      = 1              if ($nextword eq '-submit');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter(0) if $verbose; # set reporting level

$logger->setDebugStream('STDOUT',list=>1) if $debug;
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing project ID or fopn") unless ($project || $fopn);

&showUsage("Missing import or export key") unless $ioport;

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

$adb->setLogger($logger);

#----------------------------------------------------------------
# identify the project
#----------------------------------------------------------------

my @projects;

my @projectids;

# get project IDs specified with '-project' key

if ($project && $project =~ /\,|\;|\s/) {
    @projectids = split /[\,\;\s]+/,$project;
}
elsif ($project) {
    push @projectids,$project;
}

# get/add project IDs specified with '-fofn/fopn' key

if ($fopn) {
    $fopn = &getNamesFromFile($fopn);
    push @projectids,@$fopn if $fopn;
}

# get/confirm the project names

my %projects;
foreach my $projectid (@projectids) {
# identify each specified project in the database (may contain wildcards)
    my $Projects = &getProjectInstance($projectid,$assembly,$adb,1);
# test if any project found
    unless ($Projects) {
        $logger->error("Unknown project(s) $projectid");
        next;
    }
# get project names, taking care of duplicates   
    foreach my $project (@$Projects) {
        my $name = $project->getProjectName();
        next if $projects{$name};
        push @projects, $name;
        $projects{$name}++;
    }
}

&showUsage("No valid projects specified (@projectids)") unless @projects;

#----------------------------------------------------------------

# get the software directory

my $utilsdir;

my $OS = `uname -s`; chomp $OS;

my $host = $ENV{HOST};
if ($host =~ /^pcs/ && $OS eq "OSF1") {
    $utilsdir = "/nfs/pathsoft/arcturus/utils";
}
elsif ($host =~ /^seq/ && $OS eq "Linux") {
# ? further test on platform with uname -m ?
    $utilsdir = "/software/arcturus/utils";
}
else {
    &showUsage("Can't run this script on this host or OS : $host, $OS");
}

$logger->debug("host : $host, OS : $OS, utils : $utilsdir");
$logger->debug("projects: @projects");

# get current directory

my $pwd = Cwd::cwd();
 
$logger->debug("This script is run from directory : $pwd",ss=>1);

# get the repository position

my $work_dir = `pfind -q -u $organism`;

&showUsage("Can't locate project directory for $organism") unless $work_dir;

$work_dir .= "/arcturus/import-export"; # full work directory

my $date = `date +%Y%m%d`; $date =~ s/\s//g;

foreach my $project (@projects) {

# the project must by in the directory the script is run in

    if ($subdir) {
# or in a subdirectory named after the project
        my $subdir = "$pwd/$project";
        chdir ($subdir) if (-d $project);
        my $subpwd = Cwd::cwd();
        unless ($subpwd eq $subdir) {
            $logger->warning("FAILED to locate subdir $project");
            next;
	}
        $logger->debug("Project directory $subpwd used");
    }

# compose the import/export part of the command (both batch and command line)

    my $command;
    my $currentpwd = Cwd::cwd();
    my $message = "Project $project will be ${ioport}ed ";
    if ($ioport eq 'import') {
# $command .= "$utilsdir/importintoarcturus.pl ";
# $command .= "-i $instance -o $organism ";
# $command .= "-p $project " if $project; # split in base project and gap4project
# $command .= "-s $script "  if $script;
# $command .= "-pp $problem  if $problem;
# $command .= "-db $gap4name " or $project? (in wrapper script)
        $command .= "$utilsdir/importprojectintoarcturus.csh ";
        $command .= "$instance $organism $project ";
        if ($problem || $script) {
            $problem = 'PROBLEM' unless $problem; # default
            $command .= "$problem ";
            $command .= "$script" if $script;
	}
# add in perl script: gap4 name different from project, list of contigs etc
        $message .= "from gap4 database\n   $currentpwd/$project.0";
    }
    elsif ($ioport eq 'export') {
# $command .= "$utilsdir/exportfromarcturus.pl ";
# $command .= "-i $instance -o $organism ";
# $command .= "-p $project " if $project; # or scaffold? mutually exclusive + test
# $command .= "-s $script "  if $script;
# $command .= "-db $gap4name " or $project? (if scaffold in wrapper script)
        $command .= "$utilsdir/exportprojectfromarcturus.csh ";
        $command .= "$instance $organism $project ";
        $command .= "$script" if $script;
# add in perl script: gap4 name different from project
        $message .= "to gap4 database\n   $currentpwd/$project.A";
    }

# batch or run
 
    if ($batch) {
# im/export by batch job
        my $submit;
        if ($host =~ /^pcs/) {
            $submit = "bsub -q babelq1 -N " if $babel;
            $submit = "bsub -q pcs3q1  -N " if $pcs3;
            $submit = "bsub -q pcs3q1  -N " unless $submit; # default
	}
        else {
            $submit = "bsub -q phrap   -N "; # on seq
	}

	$submit .= "-R 'select[mem>16000] rusage[mem=16000]' ";
        $submit .= "-b 18:00 " if $delayed;
        $submit .= "-o $work_dir/$ioport-$date-".lc($project)." "; # output file

        $command = $submit.$command; # the actual import/export command

        $logger->debug("Current directory : ".Cwd::cwd());

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
# im/export under user control
        unless ($confirm) {
            $logger->warning("=> command to be issued:\n$command");
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

    close $FILE;

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
    print STDERR "-batch\n";
    print STDERR "-nobatch\n";
    print STDERR "\n";
    print STDERR "-babel\telse execute on pcs3\n";

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
 

