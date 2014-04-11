#!/usr/local/bin/perl -w

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


use strict; # Constraint variables declaration before using them

use ArcturusDatabase;

use FileHandle;
use Logging;
use PathogenRepository;

use DBI;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;
my $assembly;
my $ligation;
my $isligationname;
my $complement;
my $outputFileName;
my $selectmethod;
my $aspedbefore;
my $aspedafter;
my $nosingleton = 1;
my $blocksize = 10000;
my $limit;
my $mask;

my $number;

my $fasta;
my $addtag = 1;

my $namelike;
my $namenotlike;
my $excludelist;
my $includelist;
my $excludefilter;
my $status;

my $threshold;  # only with clipmethod
my $clipmethod;
my $minimumrange;

my $logfile;            # default STDERR
my $loglevel;           # default log warnings and errors only
my $debug;
my $test;

my $validKeys  = "organism|o|instance|i|"
               . "assembly|a|ligation|l|ligationname|ln|ligationcomplement|lc|"
               . "caf|fasta|fastq|aspedbefore|ab|aspedafter|aa|"
               . "includesingleton|is|blocksize|bs|selectmethod|sm|namelike|nl|"
               . "namenotlike|nnl|excludelist|el|includelist|il|fofn|"
               . "excludefilter|ef|mask|notags|all|nofile|count|"
               . "clipmethod|cm|threshold|th|minimumqualityrange|mqr|"
               . "status|nostatus|limit|"
               . "test|info|verbose|debug|log|help|h";


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

    $selectmethod     = shift @ARGV  if ($nextword eq '-selectmethod');
    $selectmethod     = shift @ARGV  if ($nextword eq '-sm');

# selection on name or date

    $aspedbefore      = shift @ARGV  if ($nextword eq '-aspedbefore');
    $aspedbefore      = shift @ARGV  if ($nextword eq '-ab');
 
    $aspedafter       = shift @ARGV  if ($nextword eq '-aspedafter');
    $aspedafter       = shift @ARGV  if ($nextword eq '-aa');

    $namelike         = shift @ARGV  if ($nextword eq '-namelike');
    $namelike         = shift @ARGV  if ($nextword eq '-nl');

    $namenotlike      = shift @ARGV  if ($nextword eq '-namenotlike');
    $namenotlike      = shift @ARGV  if ($nextword eq '-nnl');

    if ($nextword eq '-el' || $nextword eq '-excludelist') {
        $excludelist  = shift @ARGV;
    }

    if ($nextword eq '-fofn' || $nextword eq '-il' || $nextword eq '-includelist') {
        $includelist  = shift @ARGV;
    }

    if ($nextword eq '-ef' || $nextword eq '-excludefilter') {
        $excludefilter = shift @ARGV;
        $excludefilter = '%.[pq][12][kl].%-%' if ($excludefilter eq 'standard');
        $excludefilter = qw($excludefilter);
    }

# selection on assembly 

    if ($nextword eq  '-a'  ||  $nextword eq '-assembly') {
        $assembly     = shift @ARGV;
    }

    if ($nextword eq  '-l'  ||  $nextword eq '-ligation') {
        $ligation       = shift @ARGV;
    }

    if ($nextword eq '-ln'  ||  $nextword eq '-ligationname') {
        $ligation       = shift @ARGV;
	$isligationname = 1;
    }

    if ($nextword eq '-lc'  ||  $nextword eq '-ligationcomplement') {
        $complement     = 1;
    }

    if (defined($fasta) && ($nextword eq '-caf' || $nextword eq '-fasta' || $nextword eq '-fastq')) {
        die "-caf and -fasta specification are mutually exclusive";
    }

    $outputFileName   = shift @ARGV  if ($nextword eq '-caf');
    $fasta            = 0            if ($nextword eq '-caf');

    $outputFileName   = shift @ARGV  if ($nextword eq '-fasta');
    $fasta            = 1            if ($nextword eq '-fasta');

    $outputFileName   = shift @ARGV  if ($nextword eq '-fastq');
    $fasta            = 2            if ($nextword eq '-fastq');

    $test             = 1            if ($nextword eq '-nofile');
    $test             = 1            if ($nextword eq '-count');

    $blocksize        = shift @ARGV  if ($nextword eq '-blocksize');
    $blocksize        = shift @ARGV  if ($nextword eq '-bs');

    $clipmethod       = shift @ARGV  if ($nextword eq '-clipmethod');
    $clipmethod       = shift @ARGV  if ($nextword eq '-cm');

    $mask             = shift @ARGV  if ($nextword eq '-mask');

    $threshold        = shift @ARGV  if ($nextword eq '-threshold');
    $threshold        = shift @ARGV  if ($nextword eq '-th');

    $minimumrange     = shift @ARGV  if ($nextword eq '-minimumqualityrange');
    $minimumrange     = shift @ARGV  if ($nextword eq '-mqr');

    $nosingleton      = 0            if ($nextword eq '-includesingleton');
    $nosingleton      = 0            if ($nextword eq '-is');

    $status           = 0            if ($nextword eq '-nostatus');
    $status           = shift @ARGV  if ($nextword eq '-status');

    $limit            = shift @ARGV  if ($nextword eq '-limit');

    $addtag           = 0            if ($nextword eq '-notags');

    $loglevel         = 1            if ($nextword eq '-verbose'); 
    $loglevel         = 2            if ($nextword eq '-info'); 
    $loglevel         = 1            if ($nextword eq '-debug');

    $debug            = 1            if ($nextword eq '-debug'); 

    $test             = 2            if ($nextword eq '-test'); 

    $number           = shift @ARGV  if ($nextword eq '-all');

    $logfile          = shift @ARGV  if ($nextword eq '-log');


    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardFilter($loglevel) if defined $loglevel; # reporting level

$logger->stderr2stdout() if defined $loglevel;

$logger->setBlock('debug',unblock=>1) if $debug;

$logger->setSpecialStream($logfile,list=>1) if $logfile;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism && $organism eq 'default' || $instance && $instance eq 'default') {
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
# MAIN
#----------------------------------------------------------------

my ($CAF,$FAS,$QLT,$QMASK,$FAQ);

if (!defined($fasta)) {
    $logger->info("No output file format specified");
}

elsif ($fasta == 1) {
# fasta output
    if ($outputFileName) {
        $outputFileName .= '.fas' unless ($outputFileName =~ /\.fas/);
        $logger->info("Opening fasta file $outputFileName for DNA output");
        $FAS = new FileHandle($outputFileName,"w");
    }
    $FAS = *STDOUT unless $FAS;
    if ($outputFileName) {
        $outputFileName =~ s/\.fas\w*/\.qlt/;
        $outputFileName .= '.qlt' unless ($outputFileName =~ /\.qlt/);
        $logger->info("Opening fasta file $outputFileName for Quality output");
        $QLT = new FileHandle($outputFileName,"w");
    }
    $QLT = *STDOUT unless $QLT;
}

elsif ($fasta == 2) {
# fastq output
    if ($outputFileName) {
        $outputFileName .= '.faq' unless ($outputFileName =~ /\.faq/);
        $logger->info("Opening fasta file $outputFileName for DNA output");
        $FAQ = new FileHandle($outputFileName,"w");
    }
    $FAQ = *STDOUT unless $FAQ;
}
 
elsif (defined($outputFileName)) {
# caf output
    if ($outputFileName) {
        $outputFileName .= '.caf' unless ($outputFileName =~ /\.caf/);
        $logger->info("Opening CAF file $outputFileName for output");
        $CAF = new FileHandle($outputFileName,"w");
    }
    $CAF = *STDOUT unless $CAF;
}
if ($mask && $outputFileName) {
    $outputFileName =~ s/\.(fas|qlt|caf)//;
    $QMASK = new FileHandle($outputFileName.'.mask.lis',"w");
}

my %options;
$options{nosingleton}  = 1             if $nosingleton;
$options{aspedbefore}  = $aspedbefore  if $aspedbefore;
$options{aspedafter}   = $aspedafter   if $aspedafter;
$options{status}       = $status       if defined($status);
$options{limit}        = $limit        if ($limit && $limit > 0);
# assembly info is accessed via the CLONE table
$options{assembly}     = $assembly     if $assembly;
# ligation info; name can be expliticly defined
if ($ligation) {
    $options{ligation}     = $ligation unless $isligationname;
    $options{ligationname} = $ligation     if $isligationname;
    $options{complement}   = 1             if $complement;
}

if (defined($selectmethod)) {
    $options{method} = $selectmethod;
    $options{method} = 'usetemporarytables' if ($selectmethod >= 2);
    $options{method} = 'usesubselect'       if ($selectmethod == 1);
}

if ($namelike) {
    $options{namelike}   = $namelike if ($namelike !~ /[^\w\.\%\_]/);
    $options{nameregexp} = $namelike if ($namelike =~ /[^\w\.\%\_]/);
}

if ($namenotlike) {
    $options{namenotlike}   = $namenotlike if ($namenotlike !~ /[^\w\.\%\_]/);
    $options{namenotregexp} = $namenotlike if ($namenotlike =~ /[^\w\.\%\_]/);
}

my %excludehash;
if ($excludelist) {
    my $namelist = &getNamesFromFile($excludelist);
    foreach my $name (@$namelist) {
        $excludehash{$name}++;
    }
}

my %includehash;
if ($includelist) {
    my $namelist = &getNamesFromFile($includelist);
    foreach my $name (@$namelist) {
        $logger->warning("duplicate read name $name on file $includelist") if $includehash{$name};
        $includehash{$name}++;
    }
    $logger->warning(scalar(keys %includehash)." readnames to include");
}

$logger->info("Getting read IDs for unassembled reads");

my $readids = [];

if ($number) {
# overrides all other qualifiers, export all reads up to read_id number
    if ($number =~ /^\d+$/) {
        my @readids = (1 .. $number);
        $readids = \@readids;
    }
    else {
	$logger->severe("invalid specification for '-all' option: integer expected");
    }
}
else {
# standard mode
    $options{test} = 1 if $test;
    $logger->monitor('getIDsForUnassembledReads',timing=>1)   if $test;
    $readids = $adb->getIDsForUnassembledReads(%options);
    $logger->monitor('getIDsForUnassembledReads',timing=>1)   if $test;

    if ($test) {
        $logger->warning("found ".scalar(@$readids)." reads");
        if ($test == 2) {
            $logger->warning("testing ".scalar(@$readids)." individual reads");
            &testsection($readids);
	}
        $adb->disconnect();
	exit 0;
    }
}

$logger->info("Retrieving ".scalar(@$readids)." Reads");

unless ($CAF || $FAS  || $FAQ) {
    $logger->warning("to export ".scalar(@$readids)." reads, specify output file");
    undef @$readids;
}

my $discarded = 0;
my $excluded  = 0;

while (my $remainder = scalar(@$readids)) {

    $logger->flush();

    $blocksize = $remainder if ($blocksize > $remainder);

    my @readblock = splice (@$readids,0,$blocksize);

    $logger->info("Processing next $blocksize reads");

    $logger->info("$readblock[0] $readblock[$#readblock] ".scalar(@readblock));

    next if $debug;

    my $reads = $adb->getReadsByReadID(\@readblock);

    unless ($reads && @$reads) {
        $logger->error("$readblock[0] $readblock[$#readblock] ".scalar(@readblock));
	$logger->error("Unexpectedly no reads returned");
	next;
    }

    $logger->info("Adding sequence");

    $adb->getSequenceForReads($reads);

    if ($addtag) {
        $logger->info("Adding tags");
        $adb->getTagsForReads($reads);
    }

    $logger->info("Writing to output file $outputFileName");

    $threshold = 1 if (defined($threshold) && $threshold < 1);

    my $exported = 0;
    foreach my $read (@$reads) {
        my $readname = $read->getReadName();
        $logger->special($readname);

        if ($includelist && !$includehash{$readname}) {
            $logger->error("read $readname not in include list");
            $excluded++;
            next;
        }
        if ($excludelist && $excludehash{$readname}) {
            $logger->error("read $readname excluded");
            $excluded++;
            next;
        }
        if ($excludefilter && $readname =~ /$excludefilter/) {
            $logger->error("read $readname excluded (filter)");
            $excluded++;
            next;
        }
        if (defined($clipmethod) || defined($threshold) || $minimumrange) {
            $clipmethod = 0 unless defined($clipmethod);
            unless ($read->qualityClip(clipmethod=>$clipmethod,
                                       threshold=>$threshold,
				       minimum=>$minimumrange)) {
                $logger->error("read $readname discarded after clipping");
                $discarded++;
                next;
	    }
            $read->vectorScreen();
        }
        my $s = $read->getSequence();
        my $q = $read->getBaseQuality();
        unless ($s && $q && length($s) == scalar(@$q)) {
            $logger->error("read $readname discarded because of conflicting "
                         . "sequence lengths : DNA ".length($s)
                         . "  q: ".scalar(@$q));
            $discarded++;
            next;
	}

        $read->writeToCaf($CAF,qualitymask=>$mask)        if $CAF;
        $read->writeToFasta($FAS,$QLT,qualitymask=>$mask) if $FAS;
        $read->writeToFastq($FAQ,qualitymask=>$mask)      if $FAQ;

        $exported++;
        delete $includehash{$readname} if ($includelist);

        next unless ($mask && $QMASK);
# export the quality range for the read if masking is used
        my $lql = $read->getLowQualityLeft();
        my $lqr = $read->getLowQualityRight();
        print $QMASK "$readname $lql $lqr\n";
    }
    $logger->info("$exported reads written");
    undef @$reads;
}
    
$logger->error("$discarded reads ignored") if $discarded;
$logger->error("$excluded reads excluded") if $excluded;

if ($includelist && scalar(keys %includehash)) {
    $logger->warning(scalar(keys %includehash)." specified reads not exported");
    foreach my $readname (keys %includehash) {
	$logger->info("$readname not a free read ?");
    }
}

$adb->disconnect();

foreach my $FILE ($CAF,$FAS,$QLT,$QMASK,$FAQ) {
    close ($FILE) if $FILE;
}

exit 0;

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $record = <$FILE>)) {
        $record =~ s/^\s+|\s+$//g;
        my @names = split /\s+/,$record;
        push @list, $names[0];
    }

    $logger->info(scalar(@list)." names read from file $file");

    return [@list];
}

#------------------------------------------------------------------------

sub testsection {
    my $readids = shift;

    @$readids = sort {$a <=> $b} @$readids;
# assembled reads ?
    my $notfree = 0;
    $logger->warning("Testing ".scalar(@$readids)." reads found");
    foreach my $readid (@$readids) {
        my $isfree = $adb->isUnassembledRead('read_id',$readid);
        next if $isfree;
        $logger->info("read $readid is not free");
        $notfree++;
    }
    $logger->warning("$notfree assembled reads found") if $notfree;
# multiple read IDs?
    $logger->info("testing for duplicates");
    for (my $i = 1 ; $i < scalar(@$readids) ; $i++) {
        next unless ($readids->[$i] == $readids->[$i-1]);
        $logger->error("duplicate read ID $readids->[$i]");
    }
# testing against FREEREADS table
    $logger->warning("testing against FREEREADS view");
    $logger->monitor('getIDsOfFreeReads',timing=>1);
    $logger->flush();
    my $freereads = $adb->getIDsOfFreeReads(%options);
    $logger->monitor('getIDsOfFreeReads',timing=>1);
    $logger->warning("found ".scalar(@$freereads)." reads");
    $logger->flush();
 
    my $inventory = {};
    foreach my $readid (@$readids) {
        $inventory->{$readid} = [] unless $inventory->{$readid};
        $inventory->{$readid}->[0] = 1;
    }
    foreach my $readid (@$freereads) {
        $inventory->{$readid} = [] unless $inventory->{$readid};
        $inventory->{$readid}->[1] = 1;
    }

    my $stragglers = [];
    foreach my $readid (sort {$a <=> $b} keys %$inventory) {
        my $occurs = $inventory->{$readid};
        next if ($occurs->[0] && $occurs->[1]);
        $logger->warning("read $readid occurs in U but not in F") if $occurs->[0]; 
        $logger->info("read $readid occurs in F but not in U") if $occurs->[1];
        push @$stragglers,$readid;
    }
    if (@$stragglers) {
        my $notfree = 0;
        $logger->info("testing ".scalar(@$stragglers)." discordant reads");
        foreach my $readid (@$stragglers) {
            my $isfree = $adb->isUnassembledRead('read_id',$readid);
            next if $isfree;
            $logger->info("read $readid is not free");
            $notfree++;
        }
        $logger->warning("$notfree assembled reads found") if $notfree;
        $logger->warning("all reads are free reads")  unless  $notfree;
# do some tests on the temporary tables
        $logger->info("testing TEMPORARY tables");
        unless ($selectmethod && $selectmethod == 2) {
            $options{method} = 'intemporarytable';
            $adb->getIDsForUnassembledReads(%options);
        }
# test the temporaryu tables
        my $dbh = $adb->getConnection();
        foreach my $table ('CURCTG','CURSEQ','CURREAD','FREEREADS') {
            my $query = "select count(*) from $table";
            my $sth = $dbh->prepare($query);
	    $sth->execute() || $logger->error("Failed query '$query': ");
            $logger->error("MySQL error: $DBI::err ($DBI::errstr)") if ($DBI::err);
            my $count = $sth->fetchrow_array() || 'unknown number of';
	    $logger->info("temporary table $table has $count rows");
            $sth->finish();
        }
    }
    for (my $i = 1 ; $i <= 10 ; $i++) {
	 my $query = $adb->logQuery($i);
         next unless $query;
         $logger->warning("query $i:\n$query");
    }
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

    print STDOUT "\nParameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";
    unless ($organism && $instance) {
        print STDOUT "MANDATORY PARAMETERS:\n";
        print STDOUT "\n";
        print STDOUT "-organism\tArcturus organism database\n" unless $organism;
        print STDOUT "-instance\tArcturus database instance\n" unless $instance;
        print STDOUT "\n";
    }
    unless ($outputFileName) {
        print STDOUT "MANDATORY EXCLUSIVE PARAMETER:\n";
        print STDOUT "\n";
        print STDOUT "-caf\t\tcaf file name for output (0 for STDOUT)\n";
        print STDOUT "-fasta\t\tfile name for output in fasta format (DNA & quality files)\n";
        print STDOUT "-fastq\t\tfile name for output in fastq format\n";
        print STDOUT "\n";
    }
    print STDOUT "OPTIONAL PARAMETERS:\n";
    print STDOUT "\n";
    print STDOUT "-sm\t\t(selectmethod)\t1: for using sub queries\n"
               . "\t\t\t\t2: for using temporary tables\n"
               . "\t\t\t\t0: for a blocked search (default)\n";
#               . "\t\tdefault selection of either method 1 or 2\n";
    print STDOUT "-is\t\t(includesingleton) include reads from single-read".
                 " contigs\n\t\t> default exclude\n";
    print STDOUT "\n";
    print STDOUT "-aa\t\t(aspedafter) date lower bound (inclusive)\n";
    print STDOUT "-ab\t\t(aspedbefore) date upper bound (exclusive, strictly before)\n";
    print STDOUT "-nl\t\t(namelike) select on readname with wildcard or a pattern\n";
    print STDOUT "-nnl\t\t(namenotlike) exclude readnames with wildcard or a pattern\n";
    print STDOUT "\n";
    print STDOUT "-a\t\t(assembly) ID or name (selected via clone info)\n";
    print STDOUT "-l\t\t(ligation) comma-separated list of IDs or names of ligations\n";
    print STDOUT "-ln\t\t(ligationname) as for ligation with values treated as names only\n";
    print STDOUT "\t\t> names can contain wildcards ('_','%','*'), also if in a list\n";
    print STDOUT "\t\t> default, reads are selected having the specified ligations\n";
    print STDOUT "-lc\t\t(ligationcomplement) to exclude all reads with ligations listed\n";
    print STDOUT "\n";
    print STDOUT "-nostatus\t(no value) do not select on read status; default select 'PASS'\n";
    print STDOUT "-status\t\tspecify status explicitly (e.g. QUAL,SVEC,CONT)\n";
    print STDOUT "\n";
    print STDOUT "-all\t\toverrides all other selection (except excludelist &\n";
    print STDOUT "\t\tstatus); exports reads 1 to number provided \n";
    print STDOUT "\n";
    print STDOUT "-fofn\t\t(il,includelist) file of readnames to be included\n";
    print STDOUT "-el\t\t(excludelist) file of readnames to be excluded\n";
    print STDOUT "-ef\t\t(excludefilter) regexp to filter readnames; use 'standard'\n";
    print STDOUT "\t\tto filter out capillary read names mangled by Newbler assembler\n";
    print STDOUT "\n";
    print STDOUT "-blocksize\t(default 50000) for blocked execution\n";
    print STDOUT "\n";
    print STDOUT "\t\ton-the-fly quality clipping if any of cm, th or mqr defined\n";
    print STDOUT "-cm\t\t(clipmethod) On the fly quality clipping using method specified\n";
    print STDOUT "\t\t> default (and only available as yet) asp quality clipping\n";
    print STDOUT "-mask\t\tSymbol replacing low quality data (recommended: 'x')\n";
    print STDOUT "\t\t> the masking includes screening for (possible) vector sequence\n";
    print STDOUT "-th\t\t(threshold) quality clipping threshold level\n";
    print STDOUT "-mqr\t\t(minimumqualityrange) reject reads if length of clipped sequence\n";
    print STDOUT "\t\tis shorter than minimum specified\n";
    print STDOUT "\n";
    print STDOUT "-info\t\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "HINT : if query does not return all the reads expected, try '-nostatus'\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDOUT "\n";

    $code ? exit(1) : exit(0);
}
