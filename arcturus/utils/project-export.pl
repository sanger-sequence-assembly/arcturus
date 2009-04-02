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
my $ignorename;
my $assembly;
my $scaffold;
my $batch;
my $lock = 0;
my $padded;
my $readsonly = 0;
my $minimum;
my $maximum;
my $output;
my $minerva;
my $fopn;
my $caffile; # for standard CAF format
my $maffile; # for Millikan format
my $fastafile; # fasta
my $qualityfile;
my $singletonfile; # file for special singleton output
my $masking;
my $msymbol;
my $mshrink;
my $minNX = 1; # default
my $qualityclip;
my $clipthreshold;
my $endregiontrim;
#my $endregiononly;
my $clipsymbol;
my $gap4name;
my $preview;
my $append = 0;

my $validKeys  = "organism|o|instance|i|project|p|assembly|a|"
               . "fopn|fofn|ignore|scaffold|"
               . "caf|maf|readsonly|fasta|quality|lock|minNX|minerva|"
               . "minimum|min|maximum|max|singletons|readsonly|"
               . "mask|symbol|shrink|qualityclip|qc|qclipthreshold|qct|"
               . "qclipsymbol|qcs|endregiontrim|ert|gap4name|g4n|padded|"
               . "preview|confirm|batch|verbose|debug|help|h|test|append";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                          

    if ($nextword eq '-i' || $nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-o' || $nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism  = shift @ARGV;
    }

    if ($nextword eq '-p' || $nextword eq '-project') {
        $identifier = shift @ARGV;
    }

    if ($nextword eq '-a' || $nextword eq '-assembly') {
        $assembly  = shift @ARGV;
    }

    $scaffold    = shift @ARGV  if ($nextword eq '-scaffold');

    $fopn        = shift @ARGV  if ($nextword eq '-fopn');
    $fopn        = shift @ARGV  if ($nextword eq '-fofn');

    $ignorename  = shift @ARGV  if ($nextword eq '-ignore');

    $minerva     = 1            if ($nextword eq '-minerva');

    $verbose     = 1            if ($nextword eq '-verbose');

    $verbose     = 2            if ($nextword eq '-debug');

    $preview     = 1            if ($nextword eq '-preview');

    $preview     = 0            if ($nextword eq '-confirm');

    $padded      = 1            if ($nextword eq '-padded');

    $readsonly   = 1            if ($nextword eq '-readsonly');

    if ($nextword eq '-fasta' || $nextword eq '-caf' || $nextword eq '-maf') {

        if (defined($fastafile) && $nextword ne '-fasta'
         || defined($caffile)   && $nextword ne '-caf'
         || defined($maffile)   && $nextword ne '-maf') {
#        if (defined($fastafile) || defined($caffile) || defined($maffile)) {
            &showUsage("You can only select one output format");
        }
        $fastafile   = shift @ARGV  if ($nextword eq '-fasta'); # '0' for STDOUT
        $caffile     = shift @ARGV  if ($nextword eq '-caf');   # '0' for STDOUT
        $maffile     = shift @ARGV  if ($nextword eq '-maf');   # cannot be '0'
    }
    if ($nextword eq '-singletons') {
        $singletonfile = shift @ARGV; 
        $minimum = 2; # for other contigs
    }

    $append      = 1            if ($nextword eq '-append');

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

    if ($nextword eq '-ert' || $nextword eq '-endregiontrim') {
        $endregiontrim = shift @ARGV;
        if ($endregiontrim =~ /\D/ || $endregiontrim <= 0) {
	    $nextword = $endregiontrim if ($endregiontrim =~ /\D/);
            $endregiontrim = 15;
        }
    }

    if ($nextword eq '-min' || $nextword eq '-minimum') {
	$minimum = shift @ARGV;
    }

    if ($nextword eq '-max' || $nextword eq '-maximum') {
	$maximum = shift @ARGV;
    }

    $gap4name    = 1            if ($nextword eq '-gap4name');
    $gap4name    = 1            if ($nextword eq '-g4n');

    $lock        = 1            if ($nextword eq '-lock');

    $batch       = 1            if ($nextword eq '-batch');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

&showUsage("Invalid data in parameter list") if @ARGV;
&showUsage("Sorry, padded option not yet operational") if $padded; # to be removed later

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
$logger->setPrefix("#MINERVA") if $minerva;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

unless (defined($fastafile) || defined($caffile) || $maffile) {
    &showUsage("Missing CAF, FASTA or MAF output file name") unless $preview;
}

unless (defined($identifier) || $fopn || defined($assembly)) {
    &showUsage("Missing project ID or name");
}

if ($organism && $organism eq 'default' ||
    $instance && $instance eq 'default') {
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
    $logger->info("Redundant '-padded' key ignored");
    undef $padded;
}

# get file handles

my ($fhDNA, $fhQTY, $fhRDS, $fhSTN);

unless ($preview) {
    my $choice;
    if (defined($caffile) && $caffile) {
        $caffile .= '.caf' unless ($caffile =~ /\.caf$|null/);
        $fhDNA = new FileHandle($caffile, $append ? "a" : "w");
        &showUsage("Failed to create CAF output file \"$caffile\"") unless $fhDNA;
        $choice = 'caf';
    }
    elsif (defined($caffile)) {
        $fhDNA = *STDOUT;
        $choice = 'caf';
    }

    if (defined($fastafile) && $fastafile) {
        $fastafile .= '.fas' unless ($fastafile =~ /\.fas$|null/);
        $fhDNA = new FileHandle($fastafile, $append ? "a" : "w");
        &showUsage("Failed to create FASTA sequence output file \"$fastafile\"") unless $fhDNA;
        if (defined($qualityfile)) {
            $fhQTY = new FileHandle($qualityfile, $append ? "a" : "w"); 
  	    &showUsage("Failed to create FASTA quality output file \"$qualityfile\"") unless $fhQTY;
        }
        elsif ($fastafile eq '/dev/null') {
            $fhQTY = $fhDNA;
        }
        $choice = 'fas';
    }
    elsif (defined($fastafile)) {
        $fhDNA = *STDOUT;
        $choice = 'fas';
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

    if (defined($singletonfile) && $singletonfile) {
        &showUsage("You can't use the -singleton option for this output format") unless $choice;
        $singletonfile .= '.$choice' unless ($singletonfile =~ /\.(${choice})$|null/); # or fasta?
        $fhSTN = new FileHandle($singletonfile, $append ? "a" : "w");
        &showUsage("Failed to create output file \"$singletonfile\" for singleton contigs") unless $fhSTN;
    }
    elsif (defined($singletonfile)) {
        $fhSTN = *STDOUT;
    }
}

# get project(s) to be exported

my @identifiers;
# special case: all/ALL (ignore identifier)
if (defined($identifier) && uc($identifier) ne 'ALL') {
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
# no project name or ID is defined: get all project for specified assembly
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

# if the projects should be locked: acquire the lock here

my $i = 0;
# acquire the lock on the projects
while ($lock && $i < scalar(@projects)) {
    my $project = $projects[$i];
    my ($status,$msg) = $project->acquireLock();
    if ($status && $status == 2) { # success
        $i++;
        next;
    }
 # failed to acquirelock on project
    $logger->severe("Failed to acquire lock on project "
		   .$project->getProjectName()." : $msg");
    splice @projects,$i,1; # remove project from list
}

# okay, here we have collected all projects to be exported

my %exportoptions;
my %singleoptions; # for (possible) singleton export

$exportoptions{logger} = $logger if $minerva;

$exportoptions{scaffoldids} = $scaffold if $scaffold;

$exportoptions{endregiontrim} = $endregiontrim if $endregiontrim;

$exportoptions{minnrofreads} = $minimum if ($minimum && $minimum > 0);

$exportoptions{maxnrofreads} = $maximum if ($maximum && $maximum > 0);

if (defined($caffile)) {
#    $exportoptions{padded} = 1 if $padded;
    $exportoptions{qualitymask} = $masking if defined($masking);
    $exportoptions{readsonly} = 1 if $readsonly;
}
elsif (defined($fastafile)) {
    $exportoptions{readsonly} = 1 if $readsonly;
    if (defined($masking)) {
        $exportoptions{endregiononly} = $masking;
        $exportoptions{maskingsymbol} = $msymbol || 'X';
        $exportoptions{shrink} = $mshrink if $mshrink;
    }

    $exportoptions{qualityclip} = 1 if defined($qualityclip);
    $exportoptions{qualityclip} = 1 if defined($clipthreshold);
    $exportoptions{qualityclip} = 1 if defined($clipsymbol);
    $exportoptions{threshold} = $clipthreshold if defined($clipthreshold);
    $exportoptions{symbol}    = $clipsymbol if defined($clipsymbol);
    $exportoptions{gap4name}  = 1 if $gap4name;
}
elsif (defined($maffile)) {
    $exportoptions{'minNX'} = $minNX;
}

$exportoptions{'notacquirelock'} = 1 - $lock; # TO BE TESTED ? should be $lock

# copy the options for the export of singleton (may or may not be actually used)

foreach my $option (keys %exportoptions) {
    next if ($option eq 'minnrofreads');
    $singleoptions{$option} = $exportoptions{$option};
}
$singleoptions{maxnrofreads} = 1;
$singleoptions{readsonly} = 1;

# here we go

my $errorcount = 0;

$ignorename =~ s/\W+/|/g if $ignorename; # replace any separator by '|'

@projects = sort {$a->getProjectName() cmp $b->getProjectName()} @projects;

foreach my $project (@projects) {

    my $projectname = $project->getProjectName();

    if ($ignorename && $projectname =~ /$ignorename/i) {
        $logger->info("project $projectname is skipped");
	next;
    }

    my $numberofcontigs = $project->getNumberOfContigs();

    $logger->info("processing project $projectname with $numberofcontigs contigs");
    next unless $numberofcontigs;

    if ($preview) {
        $logger->warning("Project $projectname with $numberofcontigs "
                        ."contigs is to be exported");
        next;
    }

    my @emr;

    if (defined($caffile)) {
        @emr = $project->writeContigsToCaf($fhDNA,%exportoptions);
        if ($singletonfile) {
            my @semr = $project->writeContigsToCaf($fhSTN,%singleoptions);
            $emr[0] += $semr[0];
            $emr[1] += $semr[1];
	}
    }
    elsif (defined($fastafile)) {
        @emr = $project->writeContigsToFasta($fhDNA,$fhQTY,%exportoptions);
        if ($singletonfile) {
            my @semr = $project->writeContigsToFasta($fhSTN,$fhQTY,%singleoptions);
            $emr[0] += $semr[0];
            $emr[1] += $semr[1];
	}
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
        $logger->warning("$emr[1] error(s) detected while processing project "
                        ."$projectname\n$emr[2]\n$emr[0] contigs exported");
        $errorcount += $emr[1];
        $logger->info($emr[2]); # report (or to be written to a log file?)
    }
    else {
# no contigs dumped, but no errors either
        $logger->warning("no contigs exported for project $projectname");
    }
}

$adb->disconnect();

if ($preview) {
    $logger->warning("To export these projects, use '-confirm'");
}
else {
#    $logger->warning("There were no errors") unless $errorcount;
    $logger->warning("$errorcount Errors found") if $errorcount;
}

$fhDNA->close() if $fhDNA;

$fhQTY->close() if $fhQTY;

$fhRDS->close() if $fhRDS;

exit 0;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Export contigs in project(s) by ID/name or using a fofn with IDs or names\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus organism database\n" unless $organism;
        print STDERR "-instance\tArcturus database instance\n" unless $instance;
        print STDERR "\n";
    }
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    unless ($caffile) {
        print STDERR "-caf\t\tCAF output file name ('0' for STDOUT)\n";
    }
    unless ($fastafile) {
        print STDERR "-fasta\t\tFASTA sequence output file name ('0' for STDOUT)\n";
    }
    print STDERR "-maf\t\tMAF output file name root (not '0')\n" unless $maffile;
    unless (defined($fastafile) || defined($caffile) || defined($maffile)) {
        print STDERR "\t\t***** CHOOSE AN OUTPUT FORMAT *****\n";
    }
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-project\tProject ID or name; specify 'all' for everything\n";
    print STDERR "-fofn\t\t(or fopn) name of file with list of project IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tAssembly ID or name, required if ambiguous project name\n";
    print STDERR "\n";
    if ($preview) {
        print STDERR "-confirm\t(no value) go ahead\n";
    }
    else {
        print STDERR "-preview\t(no value) show what's going to happen\n";
    }
    print STDERR "\n";
    print STDERR "-singletons\texport singleton contigs on this (separate) file\n";
    print STDERR "\n";
    print STDERR "-quality\tFASTA quality output file name\n";
    print STDERR "\n";
    print STDERR "-append\t\tappend output to (possibly) exiting file\n";
    print STDERR "\n";
    print STDERR "-gap4name\tadd the gap4name (lefthand read) to the identifier\n";
    print STDERR "\n";
    print STDERR "-min\t\t(minimum) minimum number of reads in a contig\n";
    print STDERR "-max\t\t(maximum) maximum number of reads in a contig\n";
#    print STDERR "-padded\t\t(no value) export contigs in padded (caf) format\n";
    print STDERR "\n";
    print STDERR "-readsonly\t(no value) export only reads in caf or fasta output\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS relating to locking and scaffolding\n";
    print STDERR "\n";
    print STDERR "Default setting exports all contigs in project scaffolded to\n";
    print STDERR "reproduce the order of the last import; override with -scaffold\n";
    print STDERR "\n";
    print STDERR "When using a lock check, only those projects are exported ";
    print STDERR "which either\n are unlocked or are owned by the user running "
               . "this script, while those\nproject(s) will have their lock "
               . "status switched to 'locked'\n";
    print STDERR "\n";
    print STDERR "-scaffold\t(comma-separated list of) scaffold identifier(s)\n";
    print STDERR "\n";
    print STDERR "-lock\t\t(no value) acquire a lock on the project and , if "
                . "successful,\n\t\t\t   export its contigs\n";
    print STDERR "\n"; 
    print STDERR "OPTIONAL PARAMETERS for data manipulation before export (fasta only)\n";
    print STDERR "\n";
    print STDERR "-qc\t\t(qualityclip) remove low quality pads (default '*')\n";
    print STDERR "\n";
    print STDERR "-ert\t\t(endregiontrim) clip low quality endregions at this quality\n";
    print STDERR "\n"; 
    print STDERR "-mask\t\texport only the end regions of a contig of length specified\n";
    print STDERR "\t\tthe two end parts will be separated by a string of (default) 'N'\n";
    print STDERR "\t\tmasking symbols and given quality 1\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS qualifiers for data manipulation\n";
    print STDERR "\n";
    print STDERR "-qcs\t\t(qclipsymbol) use this symbol as low quality pad clipping\n";
    print STDERR "-qct\t\t(qclipthreshold) clip quality values below threshold\n";
    print STDERR "\n";
    print STDERR "-symbol\t\tsymbol used for the masking \n";
    print STDERR "-shrink\t\tif specified, the size of the masked central part will be\n"
               . "\t\ttruncated to size 'shrink'; longer contigs are then clipped\n"
               . "\t\tto size '2*mask+shrink'; shrink values smaller than mask length\n"
               . "\t\twill be reset to 'mask'\n";
    print STDERR "\n";
    print STDERR "-minNX\t\treplace runs of at least minNX 'N's by 'X'-es\n";
    print STDERR "\n";
#    print STDERR "-padded\t\t(no value) export padded consensus sequence only\n";
#    print STDERR "-ero\t\t(endregiononly) extract this size endregions endregions at both ends\n";
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
