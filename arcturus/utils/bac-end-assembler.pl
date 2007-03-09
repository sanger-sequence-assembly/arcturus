#!/usr/local/bin/perl -w

use strict;

use Alignment;

use ArcturusDatabase;

use Mapping;

use Logging;

my $DEBUG;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $datafile;  # for list of read-contig-positions

my $breakmode;
my $contig;
my $filter;
my $cleanup;

my $verbose;
my $confirm;
my $debug;

my $swprog;
my $caffile;

my $validKeys  = "organism|instance|filename|fn|swprog|caf|breakmode|bm|"
               . "cleanup|contig|read|confirm|verbose|debug|help";

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

    $datafile   = shift @ARGV  if ($nextword eq '-filename');
    $datafile   = shift @ARGV  if ($nextword eq '-fn');

    $verbose    = 1            if ($nextword eq '-verbose');

    $cleanup    = 1            if ($nextword eq '-cleanup');

    $verbose    = 2            if ($nextword eq '-debug');
    $debug      = 1            if ($nextword eq '-debug');

    $caffile    = shift @ARGV  if ($nextword eq '-caf');

    $breakmode  = 1            if ($nextword eq '-breakmode');
    $breakmode  = 1            if ($nextword eq '-bm');

    $contig     = shift @ARGV  if ($nextword eq '-contig');
    $filter     = shift @ARGV  if ($nextword eq '-read');

    $confirm    = 1            if ($nextword eq '-confirm');

    $swprog     = shift @ARGV  if ($nextword eq '-swprog');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# use forking if Smith=-Waterman alignment is to be used
#----------------------------------------------------------------

if ($swprog) {

    die "\"$swprog\" is not an executable program"
        unless (-x $swprog);

    pipe(PARENT_RDR, CHILD_WTR);
    pipe(CHILD_RDR, PARENT_WTR);

    my $pid;

    if ($pid = fork) {
        close PARENT_RDR;
        close PARENT_WTR;

        select CHILD_WTR; # default output for print command
# NOTE: from here you have to use explicitly STDOUT for print
        $| = 1;
    } 
    else {
        close CHILD_RDR;
        close CHILD_WTR;

        open(STDIN, "<&PARENT_RDR");
        open(STDOUT, ">&PARENT_WTR");

        exec($swprog);

        exit(0);
    }
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(2) if $verbose; # set reporting level
$logger->setFilter(1) if $debug;  # fine reporting level
$DEBUG = $debug if $debug;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing data file with read info") unless $datafile;

&showUsage("Missing Smith Waterman algorithm executable") unless $swprog;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#-----------------------------------------------------------------------
# parse the file with annotation data and build tag data in a hash
#-----------------------------------------------------------------------

my $FILE = new FileHandle($datafile,'r'); # open for read 

$logger->severe("FAILED to open file $datafile") unless $FILE;

my $contigreadhash = {};

# collect readinfo and store as a hash of arrays of arrays keyed on contig name

my $line = 0;

my $readnamehash = {};

my $duplicates = 0;
while ($FILE && defined(my $record = <$FILE>)) {

    $line++;

    next unless ($record =~ /\S/);

    if ($record =~ /(\S+)\s+([FR])\s+(\S+)\s+(\d+)\s+(\d+)\s*$/) {
        my $contig = $3; # Arcturus contig number 
        if ($readnamehash->{$1}) {
            $logger->fine("Duplicate readname $1 ignored on file $datafile");
            $duplicates++;
            next;
        }
        $readnamehash->{$1}++;
        $contigreadhash->{$contig} = [] unless $contigreadhash->{$contig};
        my $contigreadlist = $contigreadhash->{$contig}; # an array ref      
        my @readdata = ($1,$2,$4,$5); # read, alignment, begin, end
        push @$contigreadlist, \@readdata;
    }
    else {
        $logger->warning("invalid input on file $datafile line $line:\n".$record);
    }
}

$FILE->close() if $FILE;

$logger->warning("$duplicates duplicates ignored") if $duplicates;
$logger->warning("$line records read from file $datafile");
$logger->warning(scalar(keys %$contigreadhash)." contigs to be processed");

#-----------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------

my $CAF;
if ($caffile) {
    $caffile .= '.caf' unless ($caffile =~ /\.caf/);
    $CAF = new FileHandle($caffile,'w');
    $logger->warning("File $caffile opened for caf output") if $CAF;
    $logger->warning("Failed to open file for caf output") unless $CAF;
}
elsif (defined($caffile)) {
    $CAF = *STDOUT;
}

# run through all the contigs

foreach my $contigname (sort keys %$contigreadhash) {

    next if ($contig && $contigname !~ /$contig/);

    $logger->warning("Processing contig $contigname");

    my $bacendreads = $contigreadhash->{$contigname};

    unless (ref($bacendreads) eq 'ARRAY') {
        $logger->severe("Invalid data structure for contig $contigname");
	next;
    }

# in break mode: abort this contig if "new" reads are already assembled

# do a preliminary scan of the reads and skip contig if anyone read is 
# already assembled (meaning that the contig has been processed earlier)

    my $newread = 0;
    foreach my $bacreadinfo (@$bacendreads) {

        my ($name,$strand,$cstart,$cfinal) = @$bacreadinfo;
        $logger->info("bacreadinfo $name,$strand,$cstart,$cfinal");

        if ($adb->isUnassembledRead(readname=>$name)) {
            $newread++;
        }
        else {
            if ($breakmode) {
	        print STDERR "Read $name is an assembled read (1)\n";
                next;
	    }
	    else {
		$logger->info("Read $name is an assembled read (2)");
                $newread++;
    	    }
        }
    }

    unless ($newread) {
        print STDERR "No new reads found for this contig\n";
        next;
    }

# get the contig from the database

    my $arcturuscontig;

    if ($contigname =~ /\w+\.(\d+)/) {
        my $contig_id = $1 + 0;
        $arcturuscontig = $adb->getContig(contig_id=>$contig_id,metaDataOnly=>1);
    }
    elsif ($contigname =~ /[contig]?(\d+)/i) {
        my $contig_id = $1 + 0;
        $logger->warning("getting contig $contig_id");
        $arcturuscontig = $adb->getContig(contig_id=>$contig_id,metaDataOnly=>1);
    }
    else {
        $arcturuscontig = $adb->getContig(withRead=>$contigname,metaDataOnly=>1);
    }

    unless ($arcturuscontig) {
        $logger->warning("contig $contigname NOT FOUND");
        next;
    }

# test if it is a current contig

    my $contig_id = $arcturuscontig->getContigID();

    unless ($adb->isCurrentContigID($contig_id)){
        $logger->severe("Contig $contigname is not a current contig");
        next;
    }

# test lock status of the project this contig is in

    my @lockinfo = $adb->getLockedStatusForContigID($contig_id);
    unless ($lockinfo[0] == 0) {
        $logger->severe("the project of contig $contigname is locked");
        next;
    }

# test the project status

    my $project_id = $arcturuscontig->getProject();
    my ($projects,$status) = $adb->getProject(project_id=>$project_id);
    unless ($projects->[0] && $status eq 'OK') {
       ($projects,$status) = $adb->getProject(projectname=>'BIN');
    }
    if ($projects->[0] && $status eq 'OK') {
        my $projectname = $projects->[0]->getProjectName();
        $logger->warning("Project $projectname found for ID $project_id");
    }

# remove one-base mappings, if any

    if ($cleanup) {
        $logger->warning("Removing readmappings shorter than $cleanup");
        my $newcontig = $arcturuscontig->removeShortReads();
        $logger->severe("Failed to return a valid contig") unless $newcontig;
        $arcturuscontig = $newcontig if $newcontig;
    }

# add the currently existing mappings and consensus by delayed loading

    if ($confirm || $CAF) {
        $logger->warning("Getting existing mappings for $contigname ... patience!");
        $arcturuscontig->getMappings(1);

        $logger->warning("Getting assembled reads for $contigname ... patience!");
        $arcturuscontig->getReads(1);
    }

    $logger->info("Getting consensus");

    my $consensus = $arcturuscontig->getSequence();

# run through the reads and create a Tag object for each

    $logger->warning(scalar(@$bacendreads)." new reads specified for $contigname\n");

    my $readhash = {};
    my $readscore = {};
    my $readmapping = {};
    my $placedreads = 0;
    foreach my $bacreadinfo (@$bacendreads) {

        my ($name,$strand,$cstart,$cfinal) = @$bacreadinfo;
        $logger->info("bacreadinfo $name,$strand,$cstart,$cfinal");
        
# get the read from the database

        unless ($adb->isUnassembledRead(readname=>$name)) {
	    print STDERR "Read $name is an assembled read\n";
            next if $breakmode;
	}

        my $read = $readhash->{$name};
        unless ($read) {
            $read = $adb->getRead(readname=>$name);
	    unless ($read) {
		$logger->warning("Read $name not found") if ($confirm || $CAF);
                next;
	    }
            $readhash->{$name} = $read;
	}

# get boundaries used

        $read->vectorScreen();
        my $lql = $read->getLowQualityLeft() + 1;
        my $lqr = $read->getLowQualityRight() - 1;
	my $lgt = $read->getSequenceLength();
        my $sequence = $read->getSequence();

# assemble the substrings and the corresponding mappings

$DEBUG = 0 if  $filter;
$DEBUG = 1 if ($filter && $read->getReadName() =~ /$filter/);

        my $cslength = $cfinal - $cstart + 1;
        my $csubstring = substr $consensus,$cstart-1,$cslength;
        my $tocmapping = new Mapping($contigname);
        $tocmapping->putSegment(1,$cslength,$cstart,$cfinal);

$logger->warning( "contig $cstart   $cfinal   $cslength ") if $DEBUG;
$logger->warning( $tocmapping->toString() )                if $DEBUG;
$logger->warning( "contig sequence $csubstring")           if $DEBUG;

        my $rslength = $lqr - $lql + 1;
        my $rsubstring = substr $sequence,$lql-1,$rslength;
        my $fmrmapping = new Mapping($name); # read to quality range

        if ($strand eq 'F') {
# forward map the quality range to the read section
            $fmrmapping->putSegment($lql,$lqr,1,$rslength);
        }
        elsif ($strand eq 'R') {
# reverse map the quality range to the read section; reverse complement the string
            $rsubstring = &reversecomplement($rsubstring);
            $fmrmapping->putSegment($lqr,$lql,1,$rslength);
	}

$logger->warning( "read $name   $lql  $lqr  $lgt")         if $DEBUG;
$logger->warning( $fmrmapping->toString() )                if $DEBUG;
$logger->warning( "read sequence $rsubstring")             if $DEBUG;

        my $rlength = length($rsubstring);
        my $clength = length($csubstring);

        my ($mapping,$score);

        if ($swprog) {

           ($mapping,$score) = &SmithWatermanAlignment($csubstring,$rsubstring);

	    if ($mapping) {
$logger->warning( "mapping $mapping, score $score ")       if $DEBUG;
                $mapping->setMappingName("SW");
$logger->warning($mapping->toString(Xdomain=>$csubstring,
                                    Ydomain=>$rsubstring)) if $DEBUG;
            }
            else {
	        $logger->severe("Failed read placement : "
                              ."($name,$strand,$cstart,$cfinal)");
	        $logger->warning("score $score for lengths: r: $rlength  c:$clength\n$rsubstring\n$csubstring");
	        next;
	    }

            if (&mappingrange($mapping) <= 50) {
		$logger->warning("Low mapping range (r: $rlength  c: $clength)");
                $logger->warning($mapping->toString(Xdomain=>$csubstring,Ydomain=>$rsubstring));
            }
 	    $placedreads++;
        }
	else {
            print STDERR "No alignment method specified\n";
            last;
        }

# select the best score

        next if ($readscore->{$name} && $readscore->{$name} > $score);

        $readscore->{$name} = $score;

# transform the mapping back to the original contig and the read

        my $r2cmapping = $fmrmapping->multiply($mapping,debug=>0);
        $r2cmapping = $r2cmapping->multiply($tocmapping,debug=>0);
# it's the inverse of this one we need (to get the Assembled_from order right) 
        $r2cmapping = $r2cmapping->inverse();
        $r2cmapping->setMappingName($name);

        $logger->warning($r2cmapping->toString(Xdomain=>$sequence,
                                               Ydomain=>$consensus)) if $DEBUG;

        $readmapping->{$name} = $r2cmapping; 

        if (&mappingrange($r2cmapping) < 50) {
	     $logger->warning("Low mapping range AFTER transform (r: $rlength  c: $clength $name $strand )");
             $logger->warning($mapping->toString());
             $logger->warning($r2cmapping->toString());
        }
    }

# here the mappings have been determined; add them (and reads) to contig

    if ($placedreads) {
	$logger->warning("$placedreads new reads placed for contig $contigname");
    }
    else {
	$logger->warning("No new reads placed for contig $contigname");
	next;
    }

    foreach my $name (keys %$readmapping) {

        my $mapping = $readmapping->{$name};

        $logger->severe("Missing mapping for read $name") unless $mapping;

        $arcturuscontig->addMapping($mapping);

        my $read = $readhash->{$name};

        $logger->severe("Missing read $name") unless $read;

        $arcturuscontig->addRead($read);
    }
        
    $arcturuscontig->setNumberOfReads(); # forces re-calculation

# load the data into the database

    last if $DEBUG;

    if ($CAF) {
        $arcturuscontig->writeToCaf($CAF);
        next;
    }

#    $arcturuscontig->setContigID(); # clear to force search from scratch
#    my $parentids = $adb->getParentIDsForContig($arcturuscontig);
#    print STDOUT "parentids $parentids \n";
#    next unless $parentids;
#    print STDOUT "parents @$parentids \n";

    next unless $confirm;

    my ($added,$msg) = $adb->putContig($arcturuscontig);

    my $maps = $arcturuscontig->getMappings();
    my $nr = scalar(@$maps);

    $logger->warning("Put contig $contigname with $nr reads: status $added, $msg");
}

if (!$confirm && !$CAF) {
    $logger->warning("To load this stuff: repeat with '-confirm'");
}

$adb->disconnect();

exit;

#------------------------------------------------------------------------

sub SmithWatermanAlignment {
# uses ADH's C programme
    my ($in_sequence,$outsequence) = @_;

# write the contents of the sequences to the input handle of the child process

    my $offset = 0;
    my $length = length($in_sequence);
    while ($offset < $length) {    
	print substr($in_sequence,$offset,50)."\n";
	$offset += 50;
    }
    print ".\n";

    $offset = 0;
    $length = length($outsequence);
    while ($offset < $length) {    
	print substr($outsequence,$offset,50)."\n";
	$offset += 50;
    }
    print ".\n";

# and capture the output of the child process

    my $goodread = 0;

# just one mapping expected

    my $mapping;
    my $scoring = 0;
    while (my $line = <CHILD_RDR>) {
        $logger->fine("sw output: '$line'") if $DEBUG;
        last if ($line =~ /^\./);
        my @words = split(';', $line);
# decode the first field (overall mapping and quality)
        my ($score, $smap, $fmap, $segs) = split(',', $words[0]);

        if ($segs > 0 && $score > 20) {
            $goodread = 1;
            $mapping = new Mapping();
            foreach my $i (1..$segs) {
                my ($xs,$xf,$ys,$yf) = split /\:|\,/ , $words[$i];
                if (abs($xf-$xs) != abs($yf-$ys)) {
                    print STDERR "invalid mapping segment $words[$i] "
                               . "($xs,$xf,$ys,$yf)\n";
		    next;
                }
	        $mapping->putSegment($xs,$xf,$ys,$yf);
            }
            $scoring = $score;
        }
        else {
            $scoring = $score;
	}
    }

    return $mapping,$scoring;
}

sub reversecomplement {
# helper method: return inverse complement of input sequence
    my $sequence = shift;

    my $length = length($sequence);

    my $reverse = reverse($sequence);

    $reverse =~ tr/atcgATCG/tagcTAGC/;

    return $reverse;
}

sub mappingrange {
    my $mapping = shift;
    
    my @range = $mapping->getContigRange();

    return $range[1] - $range[0] + 1;
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Bac-end reads assembled into existing contigs\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    print STDERR "-filename\t(fn) file with read alignment in records of 5 items :\n";
    print STDERR "\t\tread name, alignment direction, contig identifier, and \n"
               . "\t\tapproximate start & end position of read on contig\n";
    print STDERR "\n";
    print STDERR "-swprog\t\tSmith-Waterman alignment algorithm executable\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tprocess only the given contig (ID)\n";
    print STDERR "-cleanup\t\tremove possible single-base mappings\n";
    print STDERR "-read\t\t(debug mode) show details for given read\n";
    print STDERR "\n";
    print STDERR "-caf\t\toutput as caf file\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-debug\t\t(no value)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
