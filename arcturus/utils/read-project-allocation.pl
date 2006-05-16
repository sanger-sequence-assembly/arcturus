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
my $readtype;
my $verbose;
my $project;
my $assembly;
my $confirm;
my $limit = 100;
my $forn;
my $ml = 0;
my $qc = 20; # default quality clip set differently from asp value

my $validKeys = "organism|instance|read|fofn|forn|oligo|finishing|minimumlength|ml|"
              . "qualityclip|qc|project|assembly|limit|confirm|preview|"
              . "verbose|list|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    if ($nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }  

    $read      = shift @ARGV  if ($nextword eq '-read');

    $readtype  = 'oligo'      if ($nextword eq '-oligo');
    $readtype  = 'finishing'  if ($nextword eq '-finishing');

    $limit     = shift @ARGV  if ($nextword eq '-limit');

    $forn      = shift @ARGV  if ($nextword eq '-fofn');
    $forn      = shift @ARGV  if ($nextword eq '-forn');

    $ml        = shift @ARGV  if ($nextword eq '-minimumlength');
    $ml        = shift @ARGV  if ($nextword eq '-ml');

    $qc        = shift @ARGV  if ($nextword eq '-qualityclip');
    $qc        = shift @ARGV  if ($nextword eq '-qc');

    $project   = shift @ARGV  if ($nextword eq '-project');

    $assembly  = shift @ARGV  if ($nextword eq '-assembly');

    $verbose   = 1            if ($nextword eq '-verbose');
 
    $confirm   = 1            if ($nextword eq '-confirm' && !defined($confirm));

    $confirm   = 0            if ($nextword eq '-preview');

    $verbose   = 2            if ($nextword eq '-list');

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
    &showUsage("Missing read ID, readname, readtype or forn");
}

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

$forn = &getNamesFromFile($forn) if $forn;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# get the read (by ID or readname)

my @reads;

if ($forn) {
# input from file
    foreach my $read (@$forn) {
        next unless $read;
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

# select readnames from the database if a readtype is defined

if ($readtype || ($read && $read =~ /\%|\*/)) {
    my $regexp; # check for read type definition
    if ($readtype) {
        $regexp = "[pq][1-9]{1}k[a-z]{1}\$" if ($readtype eq 'oligo');
        $regexp = "[pq][2-9]{1}k[0-9]{4}\$" if ($readtype eq 'finishing');
    }
    my %options;
    if ($read) {
        $read =~ s/\*/%/g;
# add possible type as option
        $options{nameregexp} = $regexp if $regexp;
    }
    elsif ($regexp) {
        $read = $regexp;
    }
    $options{unassembled} = 1;
#    $options{nosingleton} = 1;
    $options{limit} = $limit || 100;
    if (my $reads = $adb->getReadNamesLike($read,%options)) {
        foreach my $read (@$reads) {
            push @reads,$read;
	}
        $logger->warning(scalar(@reads)." reads found");
    }
    else {
        $logger->warning("No reads found");
    }
}
elsif (defined($read)) {
    if ($read =~ /\,/) {
        push @reads, split /\,/,$read;
    }
    else {
        push @reads, $read;
    }
}

# execute if confirm switch set, else list 

foreach my $read (@reads) {
    next unless ($read);
    if ($verbose && $verbose > 1) {
        $logger->info($read); # list option
        next;
    }
    my %roptions;
# determine selection by ID or by readname
    $roptions{read_id}  = $read if ($read !~ /\D/);
    $roptions{readname} = $read if ($read =~ /\D/);
    my %options;
    $options{minimumlength} = $ml if ($ml >= 32);
    $options{noload} = 1 unless $confirm;
    $options{qualityclip} = $qc if $qc;
    my ($status,$message) = $adb->assignReadAsContigToProject($project,%roptions,%options);
    if ($status) {
        $logger->warning("read $read is added to project ".$project->getProjectName());
    }
    elsif ($message =~ /no-load/i) {
        $logger->info("read $read to be added to project ".$project->getProjectName());
    }
    else {
        $logger->warning("read is NOT added : $message");
        next unless ($message =~ /\bassembled\b/);
        next unless $verbose;
# add details for assembled reads
        my $list = $adb->getAssemblyDataforReadName($read) || next;
        foreach my $contig_id (sort {$a <=> $b} keys %$list) {
            my $contig = sprintf("Contig%06d",$contig_id);
            my @items = @{$list->{$contig_id}};
            $items[1] = substr ($items[1],0,10);
            my $line = sprintf "%-24s  %10s  %-12s  %-8s  %2d", @items;
            $logger->warning("\t\t    in $contig = $line");
        }
#        my ($c,$p) = $adb->getProjectIDforReadName($read);
#$logger->warning("$c, $p");
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
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;
    my $long = shift || 0;

    if ($long) {
     print STDERR "\n";
     print STDERR "Allocate free read(s) to a specified project, optionally in a\n";
     print STDERR "specified assembly\n";
     print STDERR "\n";
     print STDERR "A read can be specified on the command line by a number (ID)\n";
     print STDERR "or by the readname which may contain wildcard symbols\n";
     print STDERR "A list of reads can be provided in a file using the '-forn' option\n";
     print STDERR "\n";
     print STDERR "Both project and assembly can be specified with \n";
     print STDERR "a number (ID) or a name (i.e. not a number)\n";
     print STDERR "\n";
     print STDERR "Reads found are converted into single-read contigs and allocated \n";
     print STDERR "to the project without regarding the project lock status\n";
     print STDERR "\n";
     print STDERR "Reads of insufficient quality will be ignored; you can adjust the \n";
     print STDERR "requirements for quality clipping and minimum good quality length\n";
     print STDERR "\n";
     print STDERR "In default mode this script lists the reads which it will allocate\n";
     print STDERR "In order to actually make the change, ";
     print STDERR "the '-confirm' switch must be used\n";
     print STDERR "\n";
    }
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\te.g.: 'prod', 'dev', or 'test'\n" unless $instance; 
    print STDERR "-project\tproject ID or projectname\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-read\t\tread ID or readname (may include wildcard)\n";
    print STDERR "-fofn\t\t(-forn) filename with list of read IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or assemblyname\n";
    print STDERR "-minimumlength\t(ml) required for quality-clipped data (default 50)\n";
    print STDERR "-qualityclip\t(qc) clip level (default 20) \n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) to execute on the database\n";
    print STDERR "-preview\t(no value) produce default listing (negates 'confirm')\n";
    print STDERR "-verbose\t(or: list; no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
