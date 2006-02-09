#!/usr/local/bin/perl -w

use strict;

use FileHandle;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $identifier;
my $assembly;
my $batch;
my $lock = 0;
my $padded;
my $readsonly = 0;
my $output;
my $fopn;
my $caffile; # for standard CAF format
my $maffile; # for Millikan format
my $fastafile; # fasta
my $qualityfile;
my $masking;
my $msymbol;
my $mshrink;
my $minNX = 1; # default
my $qualityclip;
my $clipthreshold;
my $endregiontrim;
my $clipsymbol;
my $gap4name;
my $preview;

my $validKeys  = "organism|instance|project|assembly|fopn|padded|caf|maf|"
               . "readsonly|fasta|quality|lock|minNX|preview|batch|verbose|"
               . "mask|symbol|shrink|qualityclip|qc|qclipthreshold|gap4name|"
               . "qct|qclipsymbol|qcs|endregiontrim|ert|g4n|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance    = shift @ARGV  if ($nextword eq '-instance');
      
    $organism    = shift @ARGV  if ($nextword eq '-organism');

    $assembly    = shift @ARGV  if ($nextword eq '-assembly');

    $identifier  = shift @ARGV  if ($nextword eq '-project');

    $fopn        = shift @ARGV  if ($nextword eq '-fopn');

    $verbose     = 1            if ($nextword eq '-verbose');

    $verbose     = 2            if ($nextword eq '-debug');

    $preview     = 1            if ($nextword eq '-preview');

    $padded      = 1            if ($nextword eq '-padded');

    $readsonly   = 1            if ($nextword eq '-readsonly');

    $fastafile   = shift @ARGV  if ($nextword eq '-fasta');
    $caffile     = shift @ARGV  if ($nextword eq '-caf');
    $maffile     = shift @ARGV  if ($nextword eq '-maf');

    $minNX       = shift @ARGV  if ($nextword eq '-minNX');

    $qualityfile = shift @ARGV  if ($nextword eq '-quality');

    $masking     = shift @ARGV  if ($nextword eq '-mask');

    $msymbol     = shift @ARGV  if ($nextword eq '-symbol');

    $mshrink     = shift @ARGV  if ($nextword eq '-shrink');

    $qualityclip   = 1          if ($nextword eq '-qualityclip');
    $qualityclip   = 1          if ($nextword eq '-qc');

    $clipthreshold = shift @ARGV  if ($nextword eq '-qclipthreshold');
    $clipthreshold = shift @ARGV  if ($nextword eq '-qct');

    $clipsymbol    = shift @ARGV  if ($nextword eq '-qclipsymbol');
    $clipsymbol    = shift @ARGV  if ($nextword eq '-qcs');

    $endregiontrim = shift @ARGV  if ($nextword eq '-endregiontrim');
    $endregiontrim = shift @ARGV  if ($nextword eq '-ert');

    $gap4name    = 1            if ($nextword eq '-gap4name');
    $gap4name    = 1            if ($nextword eq '-g4n');

    $lock        = 1            if ($nextword eq '-lock');

    $batch       = 1            if ($nextword eq '-batch');

    &showUsage(0) if ($nextword eq '-help');
}

&showUsage("Invalid data in parameter list") if @ARGV;

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing server instance") unless $instance;

unless (defined($fastafile) || defined($caffile) || defined($maffile)) {
    &showUsage("Missing CAF, FASTA or MAF output file name") unless $preview;
}

unless (defined($identifier) || $fopn || defined($assembly)) {
    &showUsage("Missing project ID or name");
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");
 
#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------
 
$fopn = &getNamesFromFile($fopn) if $fopn;
 
#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

if ($padded && (defined($fastafile) || defined($maffile))) {
    $logger->warning("Redundant '-padded' key ignored");
    undef $padded;
}

# get file handles

my ($fhDNA, $fhQTY, $fhRDS);

if (defined($caffile) && $caffile) {
    $caffile .= '.caf' unless ($caffile =~ /\.caf$|null/);
    $fhDNA = new FileHandle($caffile, "w");
    &showUsage("Failed to create CAF output file \"$caffile\"") unless $fhDNA;
}
elsif (defined($caffile)) {
    $fhDNA = *STDOUT;
}

if (defined($fastafile) && $fastafile) {
    $fastafile .= '.fas' unless ($fastafile =~ /\.fas$|null/);
    $fhDNA = new FileHandle($fastafile, "w");
    &showUsage("Failed to create FASTA sequence output file \"$fastafile\"") unless $fhDNA;
    if (defined($qualityfile)) {
        $fhQTY = new FileHandle($qualityfile, "w");
	&showUsage("Failed to create FASTA quality output file \"$qualityfile\"") unless $fhQTY;
    }
    elsif ($fastafile eq '/dev/null') {
        $fhQTY = $fhDNA;
    }
}
elsif (defined($fastafile)) {
    $fhDNA = *STDOUT;
}

if (defined($maffile)) {
    my $file = "$maffile.contigs.bases";
    $fhDNA = new FileHandle($file,"w");
    &showUsage("Failed to create MAF output file \"$file\"") unless $fhDNA;
    $file = "$maffile.contigs.quals";
    $fhQTY = new FileHandle($file,"w");
    &showUsage("Failed to create MAF output file \"$file\"") unless $fhQTY;
    $file = "$maffile.reads.placed";
    $fhRDS = new FileHandle($file,"w");
    &showUsage("Failed to create MAF output file \"$file\"") unless $fhRDS;
}

# get project(s) to be exported

my @identifiers;
# special case: all/ALL (ignore identifier)
if (defined($identifier) && $identifier !~ /all/i) {
    my @ids = split /,|:|;/,$identifier; # enable spec of several projects
    push @identifiers,@ids;
}
 
if ($fopn) {
    foreach my $identifier (@$fopn) {
        push @identifiers, $identifier if $identifier;
    }
}

# now collect all projects for the given identifiers

my @projects;

my %selectoptions;
if (defined($assembly)) {
    $selectoptions{assembly_id}  = $assembly if ($assembly !~ /\D/);
    $selectoptions{assemblyname} = $assembly if ($assembly =~ /\D/);
}

unless (@identifiers) {
# no project name or ID is defined
    my ($projects,$message) = $adb->getProject(%selectoptions);
    if ($projects && @$projects) {
        push @projects, @$projects;
    }
    elsif (!$batch) {
        $logger->warning("No projects found ($message)");
    }
}

foreach my $identifier (@identifiers) {

    $selectoptions{project_id}  = $identifier if ($identifier !~ /\D/);
    $selectoptions{projectname} = $identifier if ($identifier =~ /\D/);

    my ($projects,$message) = $adb->getProject(%selectoptions); 

    if ($projects && @$projects) {
        push @projects, @$projects;
    }
    elsif (!$batch) {
        $logger->warning("Unknown project $identifier");
    }
}

my %exportoptions;
$exportoptions{endregiontrim} = $endregiontrim;

if (defined($caffile)) {
#    $exportoptions{padded} = 1 if $padded;
    $exportoptions{qualitymask} = $masking if defined($masking);
}
elsif (defined($fastafile)) {
    $exportoptions{'readsonly'} = 1 if $readsonly; # fasta
    $exportoptions{endregiononly} = $masking if defined($masking);
    $exportoptions{maskingsymbol} = $msymbol || 'X';
    $exportoptions{shrink} = $mshrink;

    $exportoptions{qualityclip} = 1 if defined($qualityclip);
    $exportoptions{qualityclip} = 1 if defined($clipthreshold);
    $exportoptions{qualityclip} = 1 if defined($clipsymbol);
    $exportoptions{qcthreshold} = $clipthreshold if defined($clipthreshold);
    $exportoptions{qcsymbol} = $clipsymbol if defined($clipsymbol);
    $exportoptions{gap4name} = 1 if $gap4name;
}
elsif (defined($maffile)) {
    $exportoptions{'minNX'} = $minNX;
}

$exportoptions{'notacquirelock'} = 1 - $lock;

my $errorcount = 0;

foreach my $project (@projects) {

    my $projectname = $project->getProjectName();

    my $numberofcontigs = $project->getNumberOfContigs();

    $logger->info("processing project $projectname with $numberofcontigs contigs");

    my @emr;

    if ($preview) {
        $logger->warning("Project $projectname to be exported");
        next;
    }
    elsif (defined($caffile)) {
        @emr = $project->writeContigsToCaf($fhDNA,%exportoptions);
    }
    elsif (defined($fastafile)) {
        @emr = $project->writeContigsToFasta($fhDNA,$fhQTY,%exportoptions);
    }
    elsif (defined($maffile)) {
        @emr = $project->writeContigsToMaf($fhDNA,$fhQTY,$fhRDS,%exportoptions);
    }

# error reporting section

    if ($emr[0] > 0 && $emr[1] == 0) {
# no errors found    
        $logger->info("$emr[0] contigs were exported for project $projectname");
    }
    elsif ($emr[1]) {
# there were errors on some contigs
        $logger->warning("$emr[1] errors detected while processing project "
                        ."$projectname; $emr[0] contigs exported");
        $errorcount += $emr[1];
        $logger->info($emr[2]); # report (or to be written to a log file?)
    }
    else {
# no contigs dumped, but no errors either
        $logger->warning("no contigs exported for project $projectname");
    }
}

$fhDNA->close() if $fhDNA;

$fhQTY->close() if $fhQTY;

$fhRDS->close() if $fhRDS;

$adb->disconnect();

$logger->warning("There were no errors") unless $errorcount;
$logger->warning("$errorcount Errors found") if $errorcount;

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Export contigs in project(s) by ID/name or using a fopn with IDs or names\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-caf\t\tCAF output file name\n";
    print STDERR "-fasta\t\tFASTA sequence output file name\n";
    print STDERR "-maf\t\tMAF output file name root\n";
    print STDERR "-preview\t(no value) show what's going to happen\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-project\tProject ID or name\n";
    print STDERR "-fopn\t\tname of file with list of project IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-quality\tFASTA quality output file name\n";
    print STDERR "-padded\t\t(no value) export contigs in padded (caf) format\n";
    print STDERR "-readsonly\t(no value) export only reads in fasta output\n";
    print STDERR "\n";
    print STDERR "Default setting exports all contigs in project\n";
    print STDERR "When using a lock check, only those projects are exported ";
    print STDERR "which either\n are unlocked or are owned by the user running "
               . "this script, while those\nproject(s) will have their lock "
               . "status switched to 'locked'\n";
    print STDERR "\n";
    print STDERR "-lock\t\t(no value) acquire a lock on the project and , if "
                . "successful,\n\t\t\t   export its contigs\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
 
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
