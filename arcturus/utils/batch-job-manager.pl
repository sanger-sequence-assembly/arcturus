#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

use Cwd;

#----------------------------------------------------------------

# standard import/export of Arcturus project(s)

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my ($organism,$instance);

my ($project,$fopn,$assembly,$problem,$gap4name,$version);

my ($ioport,$perl,$script); $perl = 1; # default

my ($delayed,$batch,$subdir,$superuser); my ($babel,$pcs3);

my ($verbose,$confirm,$debug,$minerva);

my $validKeys  = "organism|o|instance|i|"
               . "project|p|assembly|a|fopn|fofn|gap4name|"
               . "import|export|script|noperl|problem|passon|po|"
               . "batch|nobatch|delayed|subdir|sd|r|superuser|su|"
               . "verbose|debug|minerva|confirm|submit|help|h";

my $host = $ENV{HOST};

# $validKeys .= "babel|pcs3|" if ($host =~ /pcs/); obsolete

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

    $gap4name     = shift @ARGV    if ($nextword eq '-gap4name');

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

    $perl         = 0              if ($nextword eq '-noperl'); # TBD (later use as default)
    $script       = shift @ARGV    if ($nextword eq '-script');
    if ($nextword eq '-superuser' || $nextword eq '-su') {
        $superuser = 1;
    }              

#    $babel        = 1              if ($nextword eq '-babel');
#    $pcs3         = 0              if ($nextword eq '-babel');
#    $pcs3         = 1              if ($nextword eq '-pcs3');
#    $babel        = 0              if ($nextword eq '-pcs3');

    $minerva      = 1              if ($nextword eq '-minerva');
    if ($nextword eq '-passon' || $nextword eq '-po') {
        last;                        
    }

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

# test user against prohibited names (force login with own unix username)

my $user = $adb->getArcturusUser();

my %forbidden = (pathdb => 1, pathsoft => 1, yeastpub => 1,othernames => 1);

if ($forbidden{$user}) {
    $adb->disconnect();
    die "You cannot access Arcturus under username $user";
}

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
    $projectid =~ s/\*/%/g; # replace possible linux wildcard by MySQL equi
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

if ($gap4name && @projects > 1) {
    &showUsage("Only one project allowed when specifying gap4name");
}

#----------------------------------------------------------------

# get the software directory

my $utilsdir;

my $OS = `uname -s`; chomp $OS;

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

# override default directory if script run in a test mode

my $scriptdir = $0;
$scriptdir =~ s/\/[^\/]+$//; # remove script name
$utilsdir = $scriptdir if ($scriptdir =~ /ejz/);

$logger->debug("host : $host, OS : $OS, utils : $utilsdir");
$logger->debug("projects: @projects");

# get current directory

my $pwd = Cwd::cwd();
 
$logger->debug("This script is run from directory : $pwd",ss=>1);

my $date = `date +%Y%m%d`; $date =~ s/\s//g;

foreach my $project (@projects) {

# the project must be in the directory the script is run in

    if ($subdir) {
        chdir($pwd); # to be sure
# or in a subdirectory named after the project
        my $lcdirname = lc($project); # 1-st alias
        my $ucdirname = uc($project); # 2-nd alias
        my $subdir = "$pwd/$project";
        if (-d $project) {
            chdir ($subdir);
        }
        elsif ($lcdirname ne $project && (-d $lcdirname)) {
           $subdir = "$pwd/$lcdirname";
           chdir ($subdir);
        }
        elsif ($ucdirname ne $project && (-d $ucdirname)) {
           $subdir = "$pwd/$ucdirname";
           chdir ($subdir);
        }
        else {
	    undef $subdir; # forces exit with error message
	}
        my $subpwd = Cwd::cwd();
        unless ($subpwd eq $subdir) { # to be sure            
            $logger->warning("FAILED to locate subdir $project");
            next;
	}
        $logger->debug("- moved to project directory $subpwd");
    }

# compose the import/export part of the command (both batch and command line)

    my $command;
    my $currentpwd = Cwd::cwd();
    if ($currentpwd =~ /automount/) {
        $currentpwd =~ s?.*automount.*/nfs?/nfs?;
        $logger->warning("removing 'automount' prefix from pwd : $currentpwd");
        chdir($currentpwd);
    }

    my $message = "Project $project will be ${ioport}ed ";
    if ($ioport eq 'import') {
# perl script
        if ($perl) {
            $command .= "$utilsdir/importintoarcturus " unless ($utilsdir =~ /ejz/);
            $command .= "$utilsdir/importintoarcturus.pl "  if ($utilsdir =~ /ejz/); # test
            $command .= "-i $instance -o $organism ";
            $command .= "-p $project ";
            $command .= "-g $gap4name "      if $gap4name;
            $command .= "-v $version "       if defined $version;
            $command .= "-script $script "   if $script;
            $command .= "-problem $problem " if $problem;
            $command .= "-su " if $superuser;
            $command .= "-rundir $currentpwd ";
            $command .= "-debug " if $debug;
	    $command .= " @ARGV" if @ARGV; # passed on to import script
	}
        else {
# shell script
            $command .= "$utilsdir/importprojectintoarcturus.csh ";
            $command .= "$instance $organism $project ";
            if ($problem || $script) {
                $problem = 'PROBLEMS' unless $problem; # default
                $command .= "$problem ";
                $command .= "$script" if $script;
	    }
	    $command .= " @ARGV" if @ARGV; # passed on to import script
	}
# add in perl script: gap4 name different from project, list of contigs etc
        $gap4name = $project unless $gap4name;
        $version  = 0 unless defined $version;
        $message .= "from gap4 database\n   $currentpwd/$gap4name.$version";
        undef $gap4name; # for possible next project
    }
    elsif ($ioport eq 'export') {
# perl script
        if ($perl) {
            $command .= "$utilsdir/exportfromarcturus " unless ($utilsdir =~ /ejz/);
            $command .= "$utilsdir/exportfromarcturus.pl "  if ($utilsdir =~ /ejz/); # test
            $command .= "-i $instance -o $organism ";
            $command .= "-p $project "; # or scaffold? mutually exclusive + test
            $command .= "-s $script "    if $script;
            $command .= "-db $gap4name " if $gap4name; # (if scaffold in wrapper script)
            $command .= "-v $version " if $version;
            $command .= "-su " if $superuser;
            $command .= "-rundir $currentpwd ";
            $command .= "-debug " if $debug;
            $command .= "-minerva " if $minerva;
	    $command .= " @ARGV" if @ARGV; # passed on to export script
        }
        else {
# shell script
            $command .= "$utilsdir/exportprojectfromarcturus.csh ";
            $command .= "$instance $organism $project ";
            $command .= "$script" if $script;
	    $command .= " @ARGV" if @ARGV; # passed on to export script
# add in perl script: gap4 name different from project
            $message .= "to gap4 database\n   $currentpwd/$project.A";
	}
    }

# batch or run
 
    if ($batch) {
# get the repository position
        my $work_dir = `pfind -q -u $organism`;
        if ($work_dir) {
            $work_dir .= "/arcturus/import-export"; # full work directory
	}
	elsif ($subdir) {
            $work_dir = Cwd::pwd();
            $work_dir =~ s?.*automount.*/nfs?/nfs?;
	}
	else {
            &showUsage("Can't locate project directory for $organism (use -r)");
	}
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

        unless ($confirm) {
            $logger->debug("=> $message");
            $logger->warning("=> command to be submitted:\n$command");
            $logger->info("=> use '-confirm' to submit"); 
            next;
        }

        unless ( (0xffff & system($command)) == 0) {
            $logger->severe("failed to submit $ioport job for project $project");
        }
    }
    else {
# im/export under user control
        unless ($confirm) {
            $logger->warning("=> command to be executed:\n$command");
            $logger->warning("=> $message");
            $logger->warning("=> repeat using '-confirm'");
            next;
        }

        $logger->warning("Project $project is being ${ioport}ed: "
			."this may take some time .. be patient");

        unless ( (0xffff & system($command)) == 0) {
            $logger->severe("failed to ${ioport} project $project");
        }
    }
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
    print STDERR "Batch job manager for import/export of Arcturus projects\n";
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\t(o) Arcturus organism database\n" unless $organism;
        print STDERR "-instance\t(i) Arcturus database instance\n" unless $instance;
        print STDERR "\n";
    }
    unless ($ioport) {
        print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-import\t\t\n";
        print STDERR "-export\t\t\n";
        print STDERR "\n";
    }
    print STDERR "-project\t(p) project identifier (number or name, may include "
                                               . "wildcards)\n";
    print STDERR "-fopn\t\t(fofn) file of project identifiers\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-confirm\tstart execution / submit as batch job\n";
    print STDERR "-perl\t\t(TESTING) use perl script\n";
    print STDERR "\n";
    print STDERR "-assembly\t(a) required if project is ambiguous\n";
    print STDERR "-gap4name\tif different from (default) project name; one project only\n";
    print STDERR "-problem\texplicitly define project for problem parent contigs\n";
    print STDERR "-subdir\t\t(sd,r) to be used if project is located in subdir of current\n";
    print STDERR "-script\t\tname of import or export script (other than default) used\n";
    print STDERR "\n";
    print STDERR "-nobatch\t(default) run under user control\n" if $batch;
    print STDERR "-batch\t\tsubmit as batch job\n" unless $batch;
    print STDERR "-delayed\tfor batch jobs, submit to run after 18:00\n";
    print STDERR "\t\tdefault execution on seq1\n";
    if ($host =~ /pcs/) {
        print STDERR "-babel\t\texecute on pcs2 (babel cluster)\n";
        print STDERR "-pcs3\t\texecute on pcs3\n";
    }

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
