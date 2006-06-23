#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use ContigFactory::ContigFactory;

use Alignment;

use Mapping;

use Tag;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $datafile;  # for list of tag ids and positions
my $fastafile; # for the fasta fuile on which the annotation has been made 

my $propagate;

my $verbose;
my $confirm;
my $debug;

my $swprog;
my $nopads = 1;
my $noembl = 1;

my $validKeys  = "organism|instance|filename|fn|propagate|fasta|swprog|"
               . "embl|confirm|verbose|debug|help";

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

    $fastafile  = shift @ARGV  if ($nextword eq '-fasta');

    $propagate  = 1            if ($nextword eq '-propagate');

    $verbose    = 1            if ($nextword eq '-verbose');

    $verbose    = 2            if ($nextword eq '-debug');
    $debug      = 1            if ($nextword eq '-debug');

    $confirm    = 1            if ($nextword eq '-confirm');

    $noembl     = 0            if ($nextword eq '-embl');

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
$logger->setFilter(3) if $debug;  # fine reporting level

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing data file with annotation tag info") unless $datafile;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#-----------------------------------------------------------------------
# if fasta file defined, build a list of annotation contigs
#-----------------------------------------------------------------------

my $fastacontighash = {};

if ($fastafile) {

    my $FASTA = new FileHandle($fastafile,'r'); # open for read

    $logger->severe("FAILED to open file $fastafile") unless $FASTA;

# parse the file to load the sequence into Contig instances

    my $fastacontigs = ContigFactory->fastaFileParser($FASTA,report=>1000000); # array

    $logger->warning(scalar(@$fastacontigs)." annotation contigs detected");

# build the length hash

    my $processed = 0;
    foreach my $contig (@$fastacontigs) {
        my $length = $contig->getConsensusLength();
        my $contigname = $contig->getContigName();
# extract the contig ID if the name contains a number and put back in
        if ($contigname =~ /\b(\d+)\b/) {
            $contig->setContigID($1+0);
        }
# extract the contig ID, if any
        my $contigid = $contig->getContigID();
        if ($contigid > 0) { 
      	    $fastacontighash->{$contigid} = $contig;
	    $processed++;
	}
	else {
            $logger->severe("Missing ID for contig ".$contig->getContigName());
	}
    }

    $logger->warning("$processed annotation contigs tested");
}

#-----------------------------------------------------------------------
# parse the file with annotation data and build tag data in a hash
#-----------------------------------------------------------------------

my $FILE = new FileHandle($datafile,'r'); # open for read 

$logger->severe("FAILED to open file $datafile") unless $FILE;

my $contigtaghash = {};

# collect tags and store as a hash of arrays of arrays keyed on contig name

my $line = 0;

my $annotatedlength = {};
while ($FILE && defined(my $record = <$FILE>)) {

    $line++;

    next unless ($record =~ /\S/);

    if ($record =~ /(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$/) {
        my $contig = $1; # Arcturus contig number 
        $contigtaghash->{$contig} = [] unless $contigtaghash->{$contig};
        my $contigtaglist = $contigtaghash->{$contig}; # an array ref      
        my @tagdata = ($2,$3,$4);
        push @$contigtaglist, \@tagdata;
        $annotatedlength->{$contig} = $5;
    }
    elsif ($record =~ /(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s*$/) {
        my $contig = $1; # Arcturus contig number 
        $contigtaghash->{$contig} = [] unless $contigtaghash->{$contig};
        my $contigtaglist = $contigtaghash->{$contig}; # an array ref      
        my @tagdata = ($2,$3,$4);
        push @$contigtaglist, \@tagdata;
    }
    else {
        $logger->warning("invalid input on file $datafile line $line:\n".$record);
    }
}

$FILE->close() if $FILE;

$logger->warning("$line records read from file $datafile");

#-----------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------

# run through all the contigs

my $lengthmismatch = 0;
my $fastamappinghash = {};

foreach my $contigname (keys %$contigtaghash) {

    $logger->info("Processing contig $contigname");

    next unless ($contigname =~ /1926|0031/); # 2701 2103

# run through the tags and create a Tag object for each

    my @tags;
    my $contigtags = $contigtaghash->{$contigname};
    foreach my $contigtag (@$contigtags) {
	$logger->fine("tag for $contigname: @$contigtag");
        my ($strand,$pstart,$pfinal);
        if ($contigtag->[1] <= $contigtag->[2]) {
            $pstart = $contigtag->[1];
            $pfinal = $contigtag->[2];
	    $strand = "Forward";
	}
	else {
            $pstart = $contigtag->[2];
            $pfinal = $contigtag->[1];
	    $strand = "Reverse";
	}
            
        my $tag = new Tag('contigtag');
        $tag->setType('ANNO');
        $tag->setPosition($pstart,$pfinal);
        $tag->setStrand($strand);
        $tag->setSystematicID($contigtag->[0]);
        push @tags,$tag;

        $logger->fine($tag->dump(0,1)."\n");
    }

    $logger->info(scalar(@tags)." contig tags assembled for $contigname\n");

# get the contig from the database

    my $arcturuscontig;

    if ($contigname =~ /\w+\.(\d+)/) {
        my $contig_id = $1;
        $arcturuscontig = $adb->getContig(contig_id=>$contig_id,metaDataOnly=>1);
    }
    else {
        $arcturuscontig = $adb->getContig(withRead=>$contigname,metaDataOnly=>1);
    }

    unless ($arcturuscontig) {
        $logger->warning("contig $contigname NOT FOUND");
        next;
    }

    $logger->info("contig $contigname: ".$arcturuscontig->getContigID());

    my $alength = $arcturuscontig->getConsensusLength();

# compare the length of the contig in Arcturus with the one given in the

    if (defined($fastafile)) {
# identify the fasta contig using the contig ID
        my $cid = $arcturuscontig->getContigID();
        my $fastacontig = $fastacontighash->{$cid};
        unless ($annotatedlength->{$contigname}) {
            $logger->warning("No annotated sequence length provided "
                            ."for contig $contigname");
            $annotatedlength->{$contigname} = 0;
	}
# test the three lengthes (annotation contig, annotatedlength and length)
        my $summary = "Annotated: "
                    . sprintf("%8d",$annotatedlength->{$contigname}) . "; "
                    . "Arcturus: " . sprintf("%8d",$alength) . "; "
		    . "Fasta: "
                    . sprintf("%8d",$fastacontig->getConsensusLength());
        $logger->warning("processing contig $contigname ($summary)");

# determine the transformation from annotation contig to arcturus contig

        my $fsequence = $fastacontig->getSequence();
        my $asequence = $arcturuscontig->getSequence();
        $logger->fine("Processing $contigname lengths: "
                      .length($asequence)." & ".length($fsequence));
  
# get the alignment from the annotated sequence to the sequence in arcturus

        my $mapping;

# method 1 : Smith-Waterman alignment

        if ($swprog && length($asequence) < 20000) {
	    $logger->warning("Smith Waterman Alignment selected");
            $mapping = &SmithWatermanAlignment($asequence,$fsequence);
            unless ($mapping) {
                print STDOUT "Failed SW mapping for $contigname\n\n";
	    }
        }

# method 2:  using pads in the quality data

        unless ($mapping || $nopads) {
	    $logger->warning("Low quality padding analysis selected");

#$logger->warning("\n\n\n\n");
#$fastacontig->writeDNA(*STDOUT);
#$logger->warning("\n\n\n\n");
#$arcturuscontig->writeDNA(*STDOUT);
#$logger->warning("\n\n\n\n");

my $mismatch = length($asequence) - length($fsequence);
$logger->warning("Re-processing $contigname lengths: "
         .length($asequence)." & ".length($fsequence)." $mismatch" );

            my $quality = $arcturuscontig->getBaseQuality();

            my %poptions = (threshold=>15 , window=>7);

            $mapping = &PaddedAlignment($asequence,$quality,$fsequence,
                                        %poptions);
	}

# method 3 : using the Alignment package version

       unless ($mapping) {
	    $logger->warning("Alignment.pm correlation selected");
	    my $flength = $annotatedlength->{$contigname};
   	    my $peakdrift = $alength - $flength;
            my $linear = 1.0 + 2.0 * $peakdrift/($alength + $flength);
            my $bandedwindow = 2.0 * sqrt($peakdrift); # generous minimum of 
            $bandedwindow = $peakdrift/2 if ($peakdrift/2 < $bandedwindow);
	    $logger->warning("peak drift: $peakdrift, window: $bandedwindow");
            my %options = (kmersize=>9,
                           coaligned=>1,
                           peakdrift=>$peakdrift,
                           bandedwindow=>$bandedwindow,
                           bandedlinear=>$linear,
                           bandedoffset=>0.0,
                           list=>1);
# experimental options
            $options{autoclip} = 0;
	    $options{goldenpath} = 1; # not operational yet
            my $fquality = $arcturuscontig->getBaseQuality();
            $options{fquality} = $fquality;
            $options{aquality} = 0;
            my $output = $logger->getOutputDevice() || *STDOUT;
            $options{debug} = $output if $debug;
#$logger->warning("ENTER CORRELATE");
            $mapping = Alignment->correlate($fsequence,0,$asequence,0,%options);
	}

        $mapping->setMappingName($contigname);
        $logger->warning("Mapping : ".$mapping->toString() );

# ok, here we have a mapping; put the tags on the fastacontig

        foreach my $tag (@tags) {
            $fastacontig->addTag($tag);
        }

# and make the arcturus contig its child

        $mapping->setSequenceID(1);
        $fastacontig->setContigID(1);

        $arcturuscontig->addParentContig($fastacontig);
        $arcturuscontig->addContigToContigMapping($mapping);

# then propagate the tags from parent to child

$fastacontig->writeToEMBL(*STDOUT) unless $noembl;
$arcturuscontig->setDEBUG();
        $arcturuscontig->inheritTags();
$arcturuscontig->writeToEMBL(*STDOUT) unless $noembl;
last;

# transform the tags accordingly

        my %options;
        $options{sequence} = $fsequence;
        $options{break} = 1;

        foreach my $tag (@tags) {
            my $tags = $tag->remap($mapping,%options);
            next unless $tags; # possibly outside range
            foreach my $tag (@$tags) {
                $arcturuscontig->addTag($tag);
            }
        }
$fastacontig->writeToEMBL(*STDOUT) unless $noembl;

$arcturuscontig->writeToEMBL(*STDOUT) unless $noembl;
    }
# warn if no annotated sequence length provided
    elsif ($annotatedlength->{$contigname}) {
        $logger->warning("No annotated sequence length provided for contig $contigname");
        $logger->warning("Contig assumed to be correctly identified");

    }
# compare the length of the contig in Arcturus with that given with annotation
    elsif ($alength != $annotatedlength->{$contigname}) {
        my $summary = "Annotated: ".sprintf("%8d",$annotatedlength->{$contigname})."; "
                    . "Arcturus: " .sprintf("%8d",$alength);
        $logger->warning("Length mismatch for contig $contigname ($summary)");
        $logger->warning("-confirm switch is reset") if $confirm;
        $lengthmismatch++;
        next; # contigname
    }

    my $tagcount = 0;
    foreach my $tag (@tags) {
        my @pos = $tag->getPosition();
        unless ($pos[0] > 0 && $pos[1] <= $alength) {
            $logger->severe("Tag outside range for contig $contigname: "
			    ."@pos  (1-$alength)");
	    next;
	}
        $arcturuscontig->addTag($tag);
        $tagcount++;
    }

    $logger->warning("$tagcount tags found on contig $contigname");    

# prepare for possible propagation of tags

    $logger->info("Processing contig ".$arcturuscontig->getContigName());

    $arcturuscontig->setDEBUG(1) if $debug;

    my $contigs = [];

    if ($propagate) {
# test set up for propagation to offspring
#my $cid = $arcturuscontig->getContigID();
#my $fastacontig = $fastacontighash->{$cid};
#$arcturuscontig->addChildContig($fastacontig);
# 
        $contigs = &propagate($arcturuscontig);
	$logger->info("Contigs after propagation:");
        unless ($confirm) {
            foreach my $contig (@$contigs) {
                my $tags = $contig->getTags(); # as is, no delayed loading
                $tags = [] unless $tags;
                $logger->info("contig ".$contig->getContigName()
			      ." has ".scalar(@$tags)." tags");
	    }
	}
    }
    else {
        push @$contigs,$arcturuscontig;
    }

    next unless $confirm;

# load the data into the database

    my %options;
    $options{debug} = 1 if $debug;

    foreach my $contig (@$contigs) {

        my $tags = $contig->getTags(); # as is, no delayed loading
        $tags = [] unless $tags;
        $logger->info("contig ".$contig->getContigName() .
		      " has " . scalar(@$tags)." tags");

        my $success = $adb->enterTagsForContig($contig,%options);

        $logger->warning("enterTagsForContig " . $contig->getContigName()
                        ." : success = $success");
    }
}

if ($lengthmismatch && !$fastafile) {
    $logger->severe("You need to include the fasta file used for annotation");
}
elsif (!$confirm) {
    $logger->warning("To load this stuff: repeat with '-confirm'");
}

$adb->disconnect();

exit;

#------------------------------------------------------------------------

sub propagate {
# recursively propagate tags down the generations
    my $contig = shift;
    my $cstack = shift;

    $cstack = [] unless defined $cstack;

print "propagating parent ".$contig->getContigName()."\n" if $debug;
    push @$cstack, $contig;

    $contig->propagateTags();
    
    return $cstack unless $contig->hasChildContigs();

    my $children = $contig->getChildContigs();

    foreach my $child (@$children) {
print "propagating child  ".$child->getContigName()."\n" if $debug;
        &propagate($child, $cstack);
    }

    return $cstack;    
}

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
    while (my $line = <CHILD_RDR>) {
# print STDOUT "line $line \n";
        last if ($line =~ /^\./);
        my @words = split(';', $line);
# decode the first field (overall mapping and quality)
        my ($score, $smap, $fmap, $segs) = split(',', $words[0]);

        if ($segs > 0 && $score > 50) {
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
        }
        else {
            return undef;
	}
    }
    return $mapping;
}

sub PaddedAlignment {
# find alignment, using low quality pads
    my $asequence = shift;
    my $aquality  = shift;
    my $fsequence = shift;
    my %options = @_;

    my $threshold = $options{threshold} || 15;
    my $window = $options{window} || 5;
    my $lgt = 2 * int(($window-1)/2) + 1; # ensure odd value

    my $mismatch = length($asequence) - length($fsequence);

    my @pads;
    for (my $i = 2 ; $i < @$aquality ; $i++) {
# trigger investigation by detection of minimum
        next unless ($aquality->[$i] > $aquality->[$i-1]);
        my $reference = $aquality->[$i-2] + $aquality->[$i]; 
        next unless ($aquality->[$i - 1] < $reference/2 - $threshold);
# at i-1 a deep minumum was found which may be a pad

$logger->warning("possible pad at $i  $aquality->[$i-2], $aquality->[$i-1], $aquality->[$i]");
my $asub = substr $asequence, $i-1-int($lgt/2), $lgt;
my $j = $i - scalar(@pads); 
my $fsub = substr $fsequence, $j-1-int($lgt/2), $lgt;
$logger->warning("a: $asub    f: $fsub");

        next if ($asub eq $fsub);
        push @pads, ($i-1);
    }
# compare the number of pads with the length mismatch
$logger->warning("Pads ".scalar(@pads)." $mismatch");

    my $mapping;
    if ($mismatch == scalar(@pads)) {
# ok, here we most likely have the original pads recovered
        push @pads,length($asequence); # add ficticious pad at end
        my ($ss,$sf,$ts,$tf) = (1,0,1,0);
        $mapping = new Mapping('recovered pads');
        for (my $i = 0 ; $i < @pads ; $i++) {
            $tf = $pads[$i];
            $sf = $ss + ($tf - $ts);
            my $lgt = $tf - $ts + 1;
my $asub = substr $asequence, $ts-1, $lgt;
my $fsub = substr $fsequence, $ss-1, $lgt;
$logger->warning("segment $ss, $sf   $ts, $tf \na: $asub\nf: $fsub\n");
# add segment
            $ss = $tf - $i + 1;
            $ts = $tf + 2;
	}
    }
    return $mapping; 
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Ad hoc tag sequence loader/retrieval test\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    print STDERR "-filename\t(fn) file with tag info in records of 4 or 5 items :\n";
    print STDERR "\t\tcontigname, systematic name, position start & end , and\n";
    print STDERR "\t\toptionally [length of annotated sequence]\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-propagate\tpropagate contig tag(s) to the last generation\n";
    print STDERR "\n";
    print STDERR "-fasta\t\tFasta file with contigs used for annotation\n";
    print STDERR "-swprog\t\tuse Smith-Waterman alignment algorithm\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-debug\t\t(no value)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
