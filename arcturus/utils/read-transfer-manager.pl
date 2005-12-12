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

my $read;  # for readname or ID
my $forn;  # for file with ibid
my $readtype; # for special reads (oligos etc.)
my $limit;

my $qclip;      # quality clipping threshold
my $lclip = 50; # minimum quality length

my $confirm;

my $verbose;
my $testmode;

my $validKeys = "organism|instance|project|assembly|"
              . "read|forn|oligo|finishing|limit|qclip|lclip|"
              . "confirm|verbose|test|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

# the next die statement prevent redefinition when used with e.g. a wrapper script

    die "You can't re-define instance" if ($instance && $nextword eq '-instance');
 
    $instance  = shift @ARGV  if ($nextword eq '-instance');

    die "You can't re-define organism" if ($organism && $nextword eq '-organism');

    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $read      = shift @ARGV  if ($nextword eq '-read');

    $forn      = shift @ARGV  if ($nextword eq '-forn');

    $readtype  = 1            if ($nextword eq '-oligo');
    $readtype  = 2            if ($nextword eq '-finishing');

    $limit     = shift @ARGV  if ($nextword eq '-limit');

    $project   = shift @ARGV  if ($nextword eq '-project');

    $assembly  = shift @ARGV  if ($nextword eq '-assembly');

    $qclip     = shift @ARGV  if ($nextword eq '-qclip');

    $lclip     = shift @ARGV  if ($nextword eq '-lclip');

    $verbose   = 1            if ($nextword eq '-verbose');
 
    $confirm   = 1            if ($nextword eq '-confirm' && !defined($confirm));

    $confirm   = 0            if ($nextword eq '-preview');

    $testmode  = 1            if ($nextword eq '-test');

    &showUsage(0,1) if ($nextword eq '-help'); # long write up
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;
 
&showUsage("Missing project ID or projectname") unless $project;

unless ($read || $forn || $readtype) {
    &showUsage("Missing read ID, read name, read type or a forn list");
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get project and assembly info (ID or name for both)
#----------------------------------------------------------------

my ($Project,$pid);

$Project = &getProjectInstance($project,$assembly,$adb);

&showUsage("Unknown project '$project'");

# check if the user has access privilege on the project

my $projectids = $adb->getAccessibleProjects();

# convert project IDs to string and match current pid; abort if mismatch

$pid = $Project->getProjectID();

my $pstring = join ',',@$projectids;

# what about open projects

unless ($pstring =~ /\b$pid\b/) {

    $logger->warning("Access denied to project ".$Project->getProjectName());

    $adb->disconnect();

    exit 0;
}

#----------------------------------------------------------------
# get read identifier(s)
#----------------------------------------------------------------

my @reads;

# case of read defined, either single or as comma separated list (no wildcard)

if ($read && $read !~ /\*|\%/ && !$readtype) {
# get read identifiers in array
    if ($read =~ /\,/) {
        @reads = split /\,/,$read;
    }
    else {
        push @reads,$read;
    }
}

# add info from file with names, if any
        
if ($forn) {
    my $reads = &getNamesFromFile($forn);
    push @reads,@$reads if $reads;
}

# the case that a readtype is defined or a read with wildcard (or both)

if ($readtype || ($read && $read =~ /\*|\%/)) {
# check for read type definition
    my $regexp;
    $regexp = "[pq][1-9]{1}k[a-z]{1}\$" if ($readtype && $readtype == 1); # oligo
    $regexp = "[pq][2-9]{1}k[0-9]{4}\$" if ($readtype && $readtype == 2); # finish

# if both regexp and read are defined, then regexp is treated as additional filter

    my %options;

    if ($read) {
        $read =~ s/\*/%/g;
        $options{nameregexp} = $regexp if $regexp;
    }
    elsif ($regexp) {
        $read = $regexp;
    }

    $options{unassembled} = 1;
    $options{nosingleton} = 1;
    $options{limit} = $limit || 16;

    my $reads = $adb->getReadNamesLike($read,%options);
    push @reads,@$reads if $reads;
}

$logger->warning(scalar(@reads)." reads found") if @reads;

$logger->warning("No reads found") unless @reads;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# run through the list of read IDs 

foreach my $read (@reads) {

    next unless $read;

# selection options

    my %roption;
# determine selection by ID or by readname
    $roption{read_id}  = $read if ($read !~ /\D/);
    $roption{readname} = $read if ($read =~ /\D/);
    my %options;
    $options{minimumlength} = $lclip if ($lclip >= 32);
    $options{qualityclip} = $qclip if $qclip;
    $options{noload} = 1 unless $confirm; # prevents actual loading
        $options{noload} = 1; # prevents actual loading
 
    my $report = "read $read ";

# preview option: test if the read is unassembled

    $logger->skip();

# confirm mode

    my ($status,$message) = $adb->assignReadAsContigToProject($Project,
                                                              %roption,
                                                              %options);
    if ($status) {
        $logger->warning("read $read is added to project ".
                         $Project->getProjectName());
    }
    elsif ($message =~ /no-load/i) {
        $logger->warning("read $read is to be added to project ".
                         $Project->getProjectName()."... use '-confirm'");
    }
    else {
        $logger->warning("read transfer request is REJECTED : $message");
        next if $confirm;

        next unless ($verbose && $message =~ /\bassembled\b/);

# the read is already assembled: list details 

        my $list = $adb->getAssemblyDataforReadName($read) || next;
        foreach my $contig_id (sort {$a <=> $b} keys %$list) {
            my $contig = sprintf("Contig%06d",$contig_id);
            my @items = @{$list->{$contig_id}};
            $items[1] = substr ($items[1],0,10);
            my $line = sprintf "%-24s  %10s  %-12s  %-8s  %2d", @items;
            $logger->warning("\t\t    in $contig = $line");
        }
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
        next unless $name;
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------

sub getProjectInstance {
# returns Project given project ID or name and (optionally) assembly
# (also in case of project ID we consult the database to check its existence)
    my $identifier = shift;  # ID or name
    my $assembly = shift; # ID or name
    my $adb = shift;

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
     print STDERR "A read can be specified on the command line by a read ID ";
     print STDERR "or by name;\n a list of reads can ";
     print STDERR "be presented in a file using the '-forn' option\n\n";
     print STDERR "Both project and assembly can be specified with \n";
     print STDERR "a number (ID) or a name (i.e. not a number)\n\n";
     print STDERR "The allocation process tests the project ownership:\n";
     print STDERR "reads will only be assigned to the project if you have ";
     print STDERR "write privilege\n";
     print STDERR "In default mode this script lists the reads that it will\n";
     print STDERR "(try to) allocate. In order to actually make the change,\n";
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
    print STDERR "MANDATORY NON-EXCLUSIVE PARAMETERS (at least one needed):\n";
    print STDERR "\n";
    print STDERR "-read\t\tread ID or readname\n";
    print STDERR "-forn\t\tfilename with list of read IDs or names\n";
    print STDERR "-oligo\t\tto select oligo reads (on name pattern)\n";
    print STDERR "-finishing\tto select finishing reads (on name pattern)\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or assemblyname\n";
    print STDERR "-confirm\t(no value) to execute on the database\n";
#    print STDERR "-preview\t(no value) produce default listing (negates 'confirm')\n";
#    print STDERR "-force\t\t(no value) to process reads allocated to other users\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
