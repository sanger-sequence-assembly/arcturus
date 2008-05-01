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
my $batch;
my $lock = 0;
my $padded;
my $readsonly = 0;
my $output;
my $minerva;
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
my $append = 0;

my $METHOD = 1; # test construction

my $validKeys  = "organism|instance|project|assembly|fopn|ignore|caf|maf|"
               . "readsonly|fasta|quality|lock|minNX|minerva|"
               . "mask|symbol|shrink|qualityclip|qc|qclipthreshold|qct|"
               . "qclipsymbol|qcs|endregiontrim|ert|gap4name|g4n|padded|"
               . "preview|confirm|batch|verbose|debug|help|test|append";

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

    $assembly    = shift @ARGV  if ($nextword eq '-assembly');

    $identifier  = shift @ARGV  if ($nextword eq '-project');

    $fopn        = shift @ARGV  if ($nextword eq '-fopn');

    $ignorename  = shift @ARGV  if ($nextword eq '-ignore');

    $minerva     = 1            if ($nextword eq '-minerva');

    $verbose     = 1            if ($nextword eq '-verbose');

    $verbose     = 2            if ($nextword eq '-debug');

    $preview     = 1            if ($nextword eq '-preview');

    $preview     = 0            if ($nextword eq '-confirm');

    $padded      = 1            if ($nextword eq '-padded');

    $readsonly   = 1            if ($nextword eq '-readsonly');

    if ($nextword eq '-fasta' || $nextword eq '-caf' || $nextword eq '-maf') {
#print STDOUT "next $nextword\n";
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

    $endregiontrim = shift @ARGV  if ($nextword eq '-endregiontrim');
    $endregiontrim = shift @ARGV  if ($nextword eq '-ert');

    $gap4name    = 1            if ($nextword eq '-gap4name');
    $gap4name    = 1            if ($nextword eq '-g4n');

    $lock        = 1            if ($nextword eq '-lock');

    $batch       = 1            if ($nextword eq '-batch');

    $METHOD      = 0            if ($nextword eq '-test');

    &showUsage(0) if ($nextword eq '-help');
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

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing server instance") unless $instance;

unless (defined($fastafile) || defined($caffile) || $maffile) {
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
    $logger->info("Redundant '-padded' key ignored");
    undef $padded;
}

# get file handles

my ($fhDNA, $fhQTY, $fhRDS);

unless ($preview) {
    if (defined($caffile) && $caffile) {
        $caffile .= '.caf' unless ($caffile =~ /\.caf$|null/);
        $fhDNA = new FileHandle($caffile, $append ? "a" : "w");
        &showUsage("Failed to create CAF output file \"$caffile\"") unless $fhDNA;
    }
    elsif (defined($caffile)) {
        $fhDNA = *STDOUT;
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

$exportoptions{logger} = $logger if $minerva;

$exportoptions{endregiontrim} = $endregiontrim if $endregiontrim;

if (defined($caffile)) {
#    $exportoptions{padded} = 1 if $padded;
    $exportoptions{qualitymask} = $masking if defined($masking);
}
elsif (defined($fastafile)) {
    $exportoptions{'readsonly'} = 1 if $readsonly; # fasta
    $exportoptions{endregiononly} = $masking if defined($masking);
    $exportoptions{maskingsymbol} = $msymbol || 'X';
    $exportoptions{shrink} = $mshrink if $mshrink;

    $exportoptions{qualityclip} = 1 if defined($qualityclip);
    $exportoptions{qualityclip} = 1 if defined($clipthreshold);
    $exportoptions{qualityclip} = 1 if defined($clipsymbol);
    $exportoptions{qcthreshold} = $clipthreshold if defined($clipthreshold);
    $exportoptions{qcsymbol} = $clipsymbol if defined($clipsymbol);
    $exportoptions{gap4name} = 1 if $gap4name;
#    if ($qualityclip) {
#        $exportoptions{lqpm} = 30;
#        $exportoptions{lqpm} = $clipthreshold if defined($clipthreshold);
#    }
}
elsif (defined($maffile)) {
    $exportoptions{'minNX'} = $minNX;
}

$exportoptions{'notacquirelock'} = 1 - $lock; # TO BE TESTED

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

    if ($preview) {
        $logger->warning("Project $projectname with $numberofcontigs "
                        ."contigs is to be exported");
        next;
    }

    my @emr;

    if ($METHOD) {

      if (defined($caffile)) {
        @emr = $project->writeContigsToCaf($fhDNA,%exportoptions);
      }
      elsif (defined($fastafile)) {
        @emr = $project->writeContigsToFasta($fhDNA,$fhQTY,%exportoptions);
      }
      elsif (defined($maffile)) {
        @emr = $project->writeContigsToMaf($fhDNA,$fhQTY,$fhRDS,%exportoptions);
      }
# end METHOD 1
    }
    else {
# to be tested
      my $contigs = $project->fetchContigIDs(1-$lock) || [];

      foreach my $contig (@$contigs) {
    
        my $err = 0;
        if (defined($caffile)) {
#            $err = $project->writeContigsToCaf($fhDNA,%exportoptions);
        }
        elsif (defined($fastafile)) {
#            $err = $project->writeContigsToFasta($fhDNA,$fhQTY,%exportoptions);
        }
        elsif (defined($maffile)) {
#            $err = $project->writeContigsToMaf($fhDNA,$fhQTY,$fhRDS,%exportoptions);
        }
        $emr[0]++ unless $err;
        $emr[1]++ if $err;
        undef $contig;
      }
# end METHOD 0
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
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\t'prod','dev','test'\n"    unless $instance;
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
    unless ($fastafile || $caffile || $maffile) {
        print STDERR "\t\t***** CHOOSE AN OUTPUT FORMAT *****\n";
    }
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-project\tProject ID or name; specify 'all' for everything\n";
    print STDERR "-fopn\t\tname of file with list of project IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    if ($preview) {
        print STDERR "-confirm\t(no value) go ahead\n";
    }
    else {
        print STDERR "-preview\t(no value) show what's going to happen\n";
    }
    print STDERR "\n";
    print STDERR "-quality\tFASTA quality output file name\n";
#    print STDERR "-padded\t\t(no value) export contigs in padded (caf) format\n";
    print STDERR "-readsonly\t(no value) export only reads in fasta output\n";
    print STDERR "\n";
    print STDERR "-gap4name\tadd the gap4name (lefthand read) to the identifier\n";
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
    print STDERR "-mask\t\tlength of end regions of contig(s) to be exported, while "
               . "the\n\t\tbases in the central part thereof will be replaced by a "
               . "masking\n\t\tsymbol (to be specified separately)\n";
    print STDERR "-symbol\t\tthe symbol used for the masking (default 'X')\n";

    print STDERR "-shrink\t\tif specified, the size of the masked central part will "
               . "be\n\t\ttruncated to size 'shrink'; longer contigs are then "
               . "clipped\n\t\tto size '2*mask+shrink'; shrink values "
               . "smaller than 'mask'\n\t\twill be reset to 'mask'\n";
#    print STDERR "-padded\t\t(no value) export padded consensus sequence only\n";
    print STDERR "\n";
    print STDERR "-endregiontrim\ttrim low quality endregions at level\n";
    print STDERR "\n";
    print STDERR "-qualityclip\tRemove low quality pads (default '*')\n";
    print STDERR "-qclipsymbol\t(qcs) use specified symbol as low quality pad\n";
    print STDERR "-qclipthreshold\t(qct) clip quality values below threshold\n";
    print STDERR "\n";
    print STDERR "-append\t\tappend output to named file\n";
    print STDERR "\n";
    print STDERR "-minNX\t\treplace runs of at least minNX 'N's by 'X'-es\n";
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
