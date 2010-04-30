#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use ArcturusDatabase::ADBMapping;

use FileHandle;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig_id;
my $verbose;
my $metadataonly = 0;
my $new;

my ($showreferencecontig,$showtestmappings,$mirrortest,$emptymappingtest);
my ($shifttest,$multiplytest,$testreverse,$equalitytest,$splittest,$jointest);

my $validKeys  = "organism|instance|contig|new|".
                 "caf|delayed|extended|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig_id    = shift @ARGV  if ($nextword eq '-contig');

    $new          = 1            if ($nextword eq '-new');

    $verbose      = 1            if ($nextword eq '-verbose');

    $metadataonly = 1            if ($nextword eq '-delayed');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'dev' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

&showUsage(0,"Missing contig ID") unless $contig_id;

my $adb;

if ($new) {

    $adb = new ADBMapping (-instance => $instance,
		           -organism => $organism);
}
else {
    $adb = new ArcturusDatabase (-instance => $instance,
	 	                 -organism => $organism);
}

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %options;

$options{metaDataOnly} = 1;
#$options{report} = 1;

$logger->warning("Contig $contig_id to be processed");
my $testcontig = $adb->getContig(contig_id=>$contig_id,%options);
$logger->warning("Contig $testcontig constructed") if $testcontig;
undef $testcontig->{SOURCE}; # prevent delayed loading
$testcontig->writeToCaf(*STDOUT);
#$logger->warning($adb->logQuery());
#undef $adb->{querylog};
exit unless $new;


my $referencecontig;
if ($showreferencecontig || $mirrortest) {

    $referencecontig = $adb->getContig(contig_id=>$contig_id,report=>1);
    $logger->warning("Reference contig $referencecontig constructed") if $referencecontig;
    $logger->warning("Reference contig NOT constructed") unless $referencecontig;
    $logger->warning($adb->logQuery());

    $logger->warning("Reference mappings",ss=>1);

    my $refmappings = $referencecontig->getMappings();
    foreach my $mapping (@$refmappings) {
        $logger->warning("$mapping");
        $logger->warning($mapping->toString());
    }
}

#---

my $testmappings;

if ($showtestmappings || $mirrortest || $shifttest) {

    $adb->newgetReadMappingsForContig($testcontig);

    $logger->warning("Test mappings",ss=>1);

    $testmappings = $testcontig->getMappings();
    foreach my $mapping (@$testmappings) {
        $logger->warning("$mapping");
        $logger->warning($mapping->toString());
    }
}

#-----

if ($mirrortest) {

    $logger->warning("Mirror reference contig mappings",ss=>1);

    my $inversecontig = $referencecontig->reverse(); 
    my $inversecontigmappings = $inversecontig->getMappings();
    foreach my $mapping (@$inversecontigmappings) {
        $logger->warning("mirror $mapping");
        $logger->warning($mapping->toString());
    }

    $logger->warning("Mirror test mappings",ss=>1);

    my $contiglength = $testcontig->getConsensusLength();

    foreach my $mapping (@$testmappings) {
        my $mirrored = $mapping->copy();
        $mirrored->applyMirrorTransform($contiglength+1);
        $logger->warning("mirrored test mapping $mapping");
        $logger->warning($mirrored->toString());
    }
}

#---

if ($shifttest) {

    $logger->warning("Shift X test mappings",ss=>1);

    my $contiglength = $testcontig->getConsensusLength();

    foreach my $mapping (@$testmappings) {
        my $shifted = $mapping->copy();
        $shifted->applyShiftToContigPosition( 10 );
        $logger->warning("mirrored test mapping $mapping");
        $logger->warning($shifted->toString());
    }
}

#---

$logger->flush();

#exit;

$logger->warning("Building test mapping forward",ss=>1);

my @returns;
push @returns,[( 737,1414,124,801)];
push @returns,[(1417,1430,802,815)];
push @returns,[(1432,1440,816,824)];
push @returns,[(1442,1448,825,831)];
#push @returns,[(1442,1448,831,825)]; # test alignment
#push @returns,[(1448,1448,831,831)]; # test alignment
#push @returns,[(1448,1448,832,832)]; # test alignment
push @returns,[(1450,1455,832,837)];
push @returns,[(1457,1464,838,845)];
#push @returns,[(1465,1469,846,850)]; # test collate
#push @returns,[(1466,1469,847,850)]; # test collate

my $ftestmap = new RegularMapping(\@returns,bridgegap=>0);

$logger->warning(MappingFactory->getStatus()) unless $ftestmap;
$logger->warning("Build returns succes $ftestmap") if $ftestmap;
$logger->warning($ftestmap->toString()) if $ftestmap;



$logger->warning("Building test mapping reverse",ss=>1);
undef @returns;
push @returns,[(933,722, 61,272)];  
push @returns,[(720,522,273,471)];
push @returns,[(520,339,472,653)];

my $rtestmap = new RegularMapping(\@returns);
$logger->warning(MappingFactory->getStatus()) unless $rtestmap; 
$logger->warning("Build returns succes $rtestmap") if $rtestmap;
$logger->warning($rtestmap->toString()) if $rtestmap;

if ($testreverse) {

    my $finverse = $ftestmap->inverse();
    $logger->warning("Build returns succes") if $finverse;
    $logger->warning($finverse->toString());

    my $rinverse = $rtestmap->inverse();
    $logger->warning("Build returns succes") if $rinverse;
    $logger->warning($rinverse->toString());

    my $fcopy = $ftestmap->copy();
    $logger->warning("Build returns succes $fcopy") if $fcopy;
    $logger->warning($fcopy->toString());

    my $rcopy = $rtestmap->copy();
    $logger->warning("Build returns succes $rcopy") if $rcopy;
    $logger->warning($rcopy->toString());
}

$multiplytest = 0;
if ($multiplytest) {
    $logger->warning("Input test mapping and its reverse to multiply",ss=>1);
    $logger->warning($ftestmap->toString());
    my $finverse = $ftestmap->inverse();
    $logger->warning($finverse->toString());

    $logger->warning("inverse*ftestmap",ss=>1);
    my $identity = $finverse->multiply($ftestmap);
    $logger->warning("Build inverse*ftestmap returns succes") if $identity;
    $logger->warning($identity->toString())  if $identity;
    $logger->warning(MappingFactory->getStatus()) unless $identity;

    $logger->warning("ftestmap*inverse",ss=>1);
    $identity = $ftestmap->multiply($finverse);
    $logger->warning("Build returns succes") if $identity;
    $logger->warning($identity->toString())  if $identity;
    $logger->warning(MappingFactory->getStatus()) unless $identity;


    $logger->warning("inverse*ftestmap using bridgegap",ss=>1);
    $identity = $ftestmap->multiply($finverse,bridgegap=>1);
    $logger->warning($identity->toString())  if $identity;
}

$multiplytest = 0;
if ($multiplytest) {
    $logger->warning("Input test mapping and its reverse to multiply",ss=>1);
    $logger->warning($rtestmap->toString());
    my $finverse = $rtestmap->inverse();
    $logger->warning($finverse->toString());

    $logger->warning("inverse*rtestmap",ss=>1);
    my $identity = $finverse->multiply($rtestmap);
    $logger->warning("Build inverse*rtestmap returns succes") if $identity;
    $logger->warning($identity->toString())  if $identity;
    $logger->warning(MappingFactory->getStatus()) unless $identity;

    $logger->warning("rtestmap*inverse",ss=>1);
    $identity = $rtestmap->multiply($finverse);
    $logger->warning("Build returns succes") if $identity;
    $logger->warning($identity->toString())  if $identity;
    $logger->warning(MappingFactory->getStatus()) unless $identity;


    $logger->warning("inverse*rtestmap using bridgegap",ss=>1);
    $identity = $rtestmap->multiply($finverse,bridgegap=>1);
    $logger->warning($identity->toString())  if $identity;
}

if ($emptymappingtest) {
    $logger->warning("Empty mapping test",ss=>1);
    my $emptymapping = new RegularMapping(undef,empty=>1);
    #my $emptymapping = new RegularMapping() || 0;
    $logger->warning("returned: $emptymapping");
    $logger->warning(MappingFactory->getStatus()) unless $emptymapping;
    $logger->warning($emptymapping->toString()) if $emptymapping;
}

$equalitytest = 0;
if ($equalitytest) {
    $logger->warning("Equality mapping test",ss=>1);
    my $fderived = $ftestmap->copy();
    $logger->warning(MappingFactory->getStatus()) unless $fderived;
    $fderived->applyShiftToContigPosition(+100);
    $logger->warning(MappingFactory->getStatus()) unless $fderived;
    my @isequalf = $ftestmap->isEqual($fderived);
    print STDOUT "output isequal aligned: @isequalf\n";

    my $rderived = $ftestmap->copy();
    $rderived->applyMirrorTransform(+5000);
    my @isequalr = $ftestmap->isEqual($rderived);
    print STDOUT "output isequal reverse aligned: @isequalr\n";


    $fderived = $rtestmap->copy();
    $logger->warning(MappingFactory->getStatus()) unless $fderived;
    $fderived->applyShiftToContigPosition(+100);
    $logger->warning(MappingFactory->getStatus()) unless $fderived;
    @isequalf = $rtestmap->isEqual($fderived);
    print STDOUT "output isequal aligned: @isequalf\n";

    $rderived = $rtestmap->copy();
    $rderived->applyMirrorTransform(+5000);
    @isequalr = $rtestmap->isEqual($rderived);
    print STDOUT "output isequal reverse aligned: @isequalr\n";
}

$splittest = 1;
if ($splittest) {
    $logger->warning("Split mapping test",ss=>1);
    my $fderived = $ftestmap->copy();
    $logger->warning($fderived->toString());
    my $fsplits = $fderived->split();
    foreach my $split (@$fsplits) { 
	$logger->warning($split->toString());
    }
    my $rderived = $rtestmap->copy();
    $logger->warning($rderived->toString());
    my $rsplits = $rderived->split();
    foreach my $split (@$rsplits) { 
	$logger->warning($split->toString());
    }

    $logger->warning("Rejoin mapping test",ss=>1);
    my $join = pop @$fsplits;
    my $result = $join->join($fsplits);
    $logger->warning($result->toString());
    my @isequal = $result->isEqual($ftestmap);
    $logger->warning("is equal: @isequal");
}

exit;

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
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' or 'dev' (default)\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-contig\t\tContig ID\n";
    print STDERR "-fofn\t\tfilename with list of contig IDs to be included\n";
    print STDERR "-fasta\t\tOutput in fasta format\n";
    print STDERR "-short\t\t(no value) only metadata & parents\n";
    print STDERR "-delayed\t(no value) using delayed loading\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
