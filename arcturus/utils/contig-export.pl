#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $contig;
my $padded;
my $readsonly = 0;
my $noreads;
#my $ignoreblocked = 0;
my $fofn;
my $caffile;
my $fastafile;
my $emblfile;
my $qualityfile;
my $masking;
my $msymbol;
my $mshrink;
my $metadataonly = 1;
my $qualityclip;
my $clipthreshold;
my $clipsymbol;
my $endregiontrim;
my $gap4name;

my $validKeys  = "organism|instance|contig|contigs|fofn|focn|ignoreblocked|caf|"
               . "embl|fasta|quality|padded|mask|symbol|shrink|readsonly|noreads|"
               . "qualityclip|qc|qclipthreshold|qct|qclipsymbol|qcs|"
               . "endregiontrim|gap4name|g4n|ert|verbose|help";

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

    $contig        = shift @ARGV  if ($nextword eq '-contig'); # name or ID
    $contig        = shift @ARGV  if ($nextword eq '-contigs'); # names or IDs

    $fofn          = shift @ARGV  if ($nextword eq '-fofn'); # file of names/IDs
    $fofn          = shift @ARGV  if ($nextword eq '-focn'); # file of names/IDs

    if ($nextword eq '-caf' || $nextword eq '-fasta' || $nextword eq '-embl') {
        die "You can not select more than one output format (CAF, fasta or embl)"         if (defined($caffile) || defined($fastafile) || defined($emblfile));
    }

    $caffile       = shift @ARGV  if ($nextword eq '-caf');

    $fastafile     = shift @ARGV  if ($nextword eq '-fasta');

    $emblfile      = shift @ARGV  if ($nextword eq '-embl');

    $qualityfile   = shift @ARGV  if ($nextword eq '-quality');

    $masking       = shift @ARGV  if ($nextword eq '-mask');

    $msymbol       = shift @ARGV  if ($nextword eq '-symbol');

    $mshrink       = shift @ARGV  if ($nextword eq '-shrink');

    $qualityclip   = 1            if ($nextword eq '-qualityclip');
    $qualityclip   = 1            if ($nextword eq '-qc');

    $clipthreshold = shift @ARGV  if ($nextword eq '-qclipthreshold');
    $clipthreshold = shift @ARGV  if ($nextword eq '-qct');

    $clipsymbol    = shift @ARGV  if ($nextword eq '-qclipsymbol');
    $clipsymbol    = shift @ARGV  if ($nextword eq '-qcs');

    $endregiontrim = shift @ARGV  if ($nextword eq '-endregiontrim');
    $endregiontrim = shift @ARGV  if ($nextword eq '-ert');

    $gap4name      = 1            if ($nextword eq '-gap4name');
    $gap4name      = 1            if ($nextword eq '-g4n');

    $verbose       = 1            if ($nextword eq '-verbose');

    $padded        = 1            if ($nextword eq '-padded');

    $readsonly     = 1            if ($nextword eq '-readsonly');

    $noreads       = 1            if ($nextword eq '-noreads');

#    $metadataonly = 0            if ($nextword eq '-full'); # redundent

#    $ignblocked   = 1            if ($nextword eq '-ignoreblocked');

    &showUsage(0) if ($nextword eq '-help');
}
 
&showUsage("Sorry, padded option not yet operational") if $padded;

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

unless (defined($caffile) || defined($fastafile) || defined($emblfile)) {
    &showUsage("Missing caf, fasta or EMBL file specification");
}

&showUsage("Missing contig name or ID") unless ($contig || $fofn);

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
 
$fofn = &getNamesFromFile($fofn) if $fofn;
 
#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

if ($padded && defined($fastafile)) {
    $logger->warning("Redundant '-padded' key ignored");
    undef $padded;
}

if (defined($caffile)) {
    $logger->warning("Ineffective '-readsonly' key ignored") if $readsonly;
    $logger->warning("Redundant '-qualityclip' key ignored") if $qualityclip;
    $logger->warning("Redundant '-shrink' key ignored") if $mshrink;
    undef $readsonly;
}

# get file handles

my ($fhDNA, $fhQTY);

# CAF output

if (defined($caffile) && $caffile) {
    $caffile .= '.caf' unless ($caffile =~ /\.caf$|null/);
    unless ($fhDNA = new FileHandle($caffile, "w")) {
        &showUsage("Failed to create CAF output file \"$caffile\"");
    }
}
elsif (defined($caffile)) {
    $fhDNA = *STDOUT;
}

# FASTA output

if (defined($fastafile) && $fastafile) {
    $fastafile .= '.fas' unless ($fastafile =~ /\.fas$|null/);
    unless ($fhDNA = new FileHandle($fastafile, "w")) {
        &showUsage("Failed to create FASTA sequence output file \"$fastafile\"");
    }
    if (defined($qualityfile)) {
        unless ($fhQTY = new FileHandle($qualityfile, "w")) {
	    &showUsage("Failed to create FASTA quality output file \"$qualityfile\"");
        }
    }
    elsif ($fastafile eq '/dev/null') {
        $fhQTY = $fhDNA;
    }
}
elsif (defined($fastafile)) {
    $fhDNA = *STDOUT;
}

# EMBL format

if (defined($emblfile) && $emblfile) {
    $emblfile .= '.embl' unless ($emblfile =~ /\.embl$|null/);
    unless ($fhDNA = new FileHandle($emblfile, "w")) {
        &showUsage("Failed to create EMBL output file \"$emblfile\"");
    }
    if (defined($qualityfile)) {
        unless ($fhQTY = new FileHandle($qualityfile, "w")) {
	    &showUsage("Failed to create EMBL quality output file \"$qualityfile\"");
        }
    }
    elsif ($emblfile eq '/dev/null') {
        $fhQTY = $fhDNA;
    }
}
elsif (defined($emblfile)) {
    $fhDNA = *STDOUT;
}

my @contigs;

push @contigs, split(/,/, $contig) if $contig;
 
if ($fofn) {
    foreach my $contig (@$fofn) {
        push @contigs, $contig if $contig;
    }
}

# get the write options (caf and fasta only, for now)

my %woptions;
if (defined($fastafile)) {
# fasta options
    if ($readsonly) {
        $woptions{readsonly} = 1;
        $logger->warning("Redundant '-qualityclip' key ignored") if $qualityclip;
        $logger->warning("Redundant '-shrink' key ignored") if $mshrink;
        $woptions{qualitymask} = $masking if $masking;
        $woptions{qualitymask} = $msymbol if $msymbol; # overrides
    }
    else {
        $woptions{endregiononly} = $masking if defined($masking);
        $woptions{maskingsymbol} = $msymbol || 'X';
        $woptions{shrink} = $mshrink if defined($mshrink);

        $woptions{qualityclip} = 1 if defined($qualityclip);
        $woptions{qualityclip} = 1 if defined($clipthreshold);
        $woptions{qualityclip} = 1 if defined($clipsymbol);
        $woptions{qcthreshold} = $clipthreshold if defined($clipthreshold);
        $woptions{qcsymbol} = $clipsymbol if defined($clipsymbol);
        $woptions{gap4name} = 1 if $gap4name;
    }
}
elsif (defined($caffile)) {
# caf options
    $woptions{noreads} = 1 if $noreads;
    $woptions{qualitymask} = $masking if $masking;
    $woptions{qualitymask} = $msymbol if $msymbol; # overrides
}

my $errorcount = 0;

foreach my $identifier (@contigs) {

    unless ($identifier) {
        $logger->warning("Invalid or missing contig identifier");
        next;
    }

# get the contig select options

    undef my %coptions;
    $coptions{metaDataOnly} = $metadataonly; # redundent?
    $coptions{withRead}  = $identifier if ($identifier =~ /\D/);
    $coptions{contig_id} = $identifier if ($identifier !~ /\D/);
# $options{ignoreblocked} = 1;

    my $contig = $adb->getContig(%coptions) || 0;

    $logger->info("Contig returned: $contig");

    $logger->warning("Blocked or unknown contig $identifier") unless $contig;

    next unless $contig;

    if ($endregiontrim) {
        my ($ql,$qr) = $contig->endregiontrim(cliplevel=>$endregiontrim);
        $logger->warning("end region clipping $endregiontrim clipped range $ql, $qr");
    }

#    $contig->toPadded() if $padded;

    my $err;

    $contig->setContigName($identifier) if ($identifier =~ /\D/);

    $err = $contig->writeToCaf($fhDNA,%woptions)          if defined($caffile);

    $err = $contig->writeToFasta($fhDNA,$fhQTY,%woptions) if defined($fastafile);

    $err = $contig->writeToEMBL($fhDNA)                   if defined($emblfile);

    $errorcount++ if $err;
}

$fhDNA->close() if $fhDNA;

$fhQTY->close() if $fhQTY;

$adb->disconnect();

# TO BE DONE: message and error testing

#$logger->warning("There were no errors") unless $errorcount;
#$logger->warning("$errorcount Errors found") if $errorcount;

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n\nExport contig(s) by ID or using a fofn with IDs\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "MANDATORY NON-EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-contig\t\tcontig name or ID, or comma-separated list of "
               . "names or IDs\n";
    print STDERR "-fofn \t\t(focn) name of file with list of Contig IDs\n";
#    print STDERR "-ignoreblock\t(no value) include contigs from blocked projects\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\toutput file name (specify 0 for default STDOUT), CAF "
               . "format\n\t\t('-caf' always exports the whole contig including "
               . "its reads)\n";
    print STDERR "-fasta\t\toutput file name (specify 0 for default STDOUT), fasta "
               . "format\n\t\t(default, '-fasta' exports the consensus sequence "
               . "(no reads)\n";
    print STDERR "-embl\t\toutput file name (specify 0 for default STDOUT), EMBL "
               . "format\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for CAF export:\n";
    print STDERR "\n";
    print STDERR "-mask\t\tmask low quality data in reads by this symbol\n";
#    print STDERR "-padded\t\t(no value) export contig & reads in padded format\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for fasta export:\n";
    print STDERR "\n"; 
    print STDERR "-quality\toutput file name for fasta quality data\n";
    print STDERR "-readsonly\t'-fasta' exports only the reads (no consensus); in "
               . "this case\n\t\tonly the '-mask' option applies and acts as for "
               . "'-caf' export\n";
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
    print STDERR "-qclipsymbol\tuse specified symbol as low quality pad\n";
    print STDERR "-qclipthreshold\tclip those quality values below threshold\n";
    print STDERR "\n";
    print STDERR "-gap4name\tadd the gap4name (lefthand read) to the identifier\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

sub getNamesFromFile {
    my $file = shift; # file name
                                                                                
    &showUsage("File $file does not exist") unless (-e $file);
 
    my $FILE = new FileHandle($file,"r");
 
    &showUsage("Can't access $file for reading") unless $FILE;
 
    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }
 
    return [@list];
}
