#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;


#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $read;
my $verbose;
my $project;
my $assembly;
my $confirm;
my $fofn;

my $validKeys = "organism|instance|read|fofn|project|assembly|"
              . "verbose|confirm|preview|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $read       = shift @ARGV  if ($nextword eq '-read');

    $fofn         = shift @ARGV  if ($nextword eq '-fofn');

    $project      = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm' && !defined($confirm));

    $confirm      = 0            if ($nextword eq '-preview');

    &showUsage(0,1) if ($nextword eq '-help'); # long write up
}

&showUsage("Missing read ID, readname or fofn") unless ($read || $fofn);

&showUsage("Missing project ID or projectname") unless $project;
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------

$fofn = &getNamesFromFile($fofn) if $fofn;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# get the read (by ID or readname)

my @reads;

push @reads, $read if defined($read);

if ($fofn) {
    foreach my $read (@$fofn) {
        push @reads, $read;
    }
}

# get the project and assembly information (ID or name for both)

my %projectoptions;
$projectoptions{project_id}  = $project if ($project !~ /\D/);
$projectoptions{projectname} = $project if ($project =~ /\D/);
if (defined($assembly)) {
    $projectoptions{assembly_id}   = $assembly if ($assembly !~ /\D/);
    $projectoptions{assemblyname}  = $assembly if ($assembly =~ /\D/);
}

my ($Project,$log) = $adb->getProject(%projectoptions);
# test if any found
unless ($Project && @$Project) {
    my $message = "No project $project found";
    $message .= " in assembly $assembly" if $projectoptions{assemblyname};
    $logger->warning("$message: $log");
    $adb->disconnect();
    exit 0;
}
# test if not too many found
if (@$Project > 1) {
    my $list = '';
    foreach my $project (@$Project) {
	$list .= $project->getProjectName()." (".$project->getAssemblyID().") ";
    }
    $logger->warning("More than one project found: $list");
    $logger->warning("Are you sure you do not need to specify assembly?")
        unless defined($assembly);
    exit 0;
} 
    
$project = $Project->[0];

# execute if confirm switch set, else list 

# print "reads:@reads\n";
foreach my $read (@reads) {
    my %options;
# determine selection by ID or by readname
    $options{read_id}  = $read if ($read !~ /\D/);
    $options{readname} = $read if ($read =~ /\D/);
    $options{noload} = 1 unless $confirm;
    my ($status,$message) = $adb->assignReadAsContigToProject($project,%options);
    if ($status) {
        $logger->warning("read $read to be added to project ".$project->getProjectName()) unless $confirm;
        $logger->warning("read $read is added to project ".$project->getProjectName()) if $confirm;
    }
    else {
        $logger->warning("read $read cannot be added : $message");
    }
}
  
$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage(0,"File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage(0,"Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;
    my $long = shift || 0;

    if ($long) {
     print STDERR "\n";
     print STDERR "Allocate read(s) to a specified project, optionally in a\n";
     print STDERR "specified assembly\n\n";
     print STDERR "A read can be specified on the command line by a number (ID)\n";
     print STDERR "or by the name of a read occurring in it; a list of reads can\n";
     print STDERR "be presented in a file using the '-fofn' option\n\n";
     print STDERR "Both project and assembly can be specified with \n";
     print STDERR "a number (ID) or a name (i.e. not a number)\n\n";
     print STDERR "The allocation process tests the project locking status:\n";
     print STDERR "Contigs will only be (re-)allocated from their current\n";
     print STDERR "project (if any) to the new one specified, if BOTH the\n";
     print STDERR "current project AND the target project are not locked by\n";
     print STDERR "another user. Carefully check the results log!\n\n";
     print STDERR "A special case is when a contig is in a project owned by\n";
     print STDERR "another user, but not locked. In default mode such contigs\n";
     print STDERR "are NOT re-allocated (as a protection measure). In order to \n";
     print STDERR "reassign those contig(s), the '-force' switch must be used.\n\n";
     print STDERR "In default mode this script lists the contigs that it will\n";
     print STDERR "(try to) re-allocate. In order to actually make the change,\n";
     print STDERR "the '-confirm' switch must be used\n";
     print STDERR "\n";
    }
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "-project\tproject ID or projectname\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-read\t\tread ID or readname\n";
    print STDERR "-fofn\t\tfilename with list of read IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or assemblyname\n";
    print STDERR "-confirm\t(no value) to execute on the database\n";
    print STDERR "-preview\t(no value) produce default listing (negates 'confirm')\n";
    print STDERR "-force\t\t(no value) to process reads allocated to other users\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
