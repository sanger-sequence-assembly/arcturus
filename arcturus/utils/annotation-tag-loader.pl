#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use ContigFactory::ContigFactory;

use Alignment;

use Mapping;

use Tag;

use Logging;

use MyTimer;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $datafile;  # for list of tag ids and positions
my $fastafile; # for the fasta fuile on which the annotation has been made 

my $propagate;
my $reanalyze;

my $contig;
my $testtag;

my $verbose;
my $confirm;
my $debug;
my $override;

my $swprog;
my $nopads = 1;
my $noembl = 1;
my $emblfile;
my $qclip;


my $validKeys  = "organism|instance|tagfile|tf|fasta|ff|swprog|"
               . "embl|emblfile|ef|contig|tag|confirm|dbload|noload|"
               . "propagate|reanalyze|qualityclip|qc|"
               . "override|verbose|debug|nodebug|help";

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

    $datafile   = shift @ARGV  if ($nextword eq '-tagfile');
    $datafile   = shift @ARGV  if ($nextword eq '-tf');

    $fastafile  = shift @ARGV  if ($nextword eq '-fasta');
    $fastafile  = shift @ARGV  if ($nextword eq '-ff');

    $contig     = shift @ARGV  if ($nextword eq '-contig');

    $testtag    = shift @ARGV  if ($nextword eq '-tag');

    $propagate  = 1            if ($nextword eq '-propagate');
    $propagate  = 1            if ($nextword eq '-reanalyze');
    $reanalyze  = 1            if ($nextword eq '-reanalyze');

    $verbose    = 1            if ($nextword eq '-verbose');

    if ($nextword eq '-debug') {
        if (defined($debug) && !$debug) {
            &showUsage("Option '$nextword' has been disabled");
        }
        $verbose = 2;
        $debug   = 1;
    }
    $debug       = 0            if ($nextword eq '-nodebug');

    if ($nextword eq '-confirm' || $nextword eq '-dbload') { 
        if (defined($confirm) && !$confirm) {
            &showUsage("Option '$nextword' has been disabled");
        }
        $confirm = 1;
    }
    $confirm    = 0            if ($nextword eq '-noload');


    $noembl     = 0            if ($nextword eq '-embl');
    $emblfile   = shift @ARGV  if ($nextword eq '-emblfile');
    $emblfile   = shift @ARGV  if ($nextword eq '-ef');
    if ($nextword eq '-qualityclip' || $nextword eq '-qc') {
        $qclip   = 20; # fixed value
        $confirm = 0;
    }

    if ($nextword eq '-swprog') {
        if (defined($swprog) && !$swprog) {
            &showUsage("Option '$nextword' has been disabled");
        }
        $swprog  = shift @ARGV;
    }

    $override    = 1            if ($nextword eq '-override');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# use forking if Smith-Waterman alignment is to be used
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

$logger->setFilter(0) if ($verbose && $verbose > 1); # set reporting level

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

# parse the file to load the sequence into Contig instances

    my $fastacontigs = ContigFactory->fastaFileParser($fastafile,report=>1000000);

    unless (defined $fastacontigs) {
# file not found
        $logger->severe("FAILED to open file $fastafile");
        $fastacontigs = []; # to have it defined
    }

    $logger->warning(scalar(@$fastacontigs)." annotation contigs detected");

#-----------------------------------------------------------------------
# build the consensus length hash (if any contigs read)
#-----------------------------------------------------------------------

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
# parse the file with annotation data and build tag data hash
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
        unless ($3 == 1 && $4 == $5 || $2 =~ /source/i) {
            push @$contigtaglist, \@tagdata;
            $annotatedlength->{$contig} = $5;
	}
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

my $nc = scalar(keys %$contigtaghash);

$logger->warning("data read for $nc contigs from file $datafile ($line lines)");

#-----------------------------------------------------------------------
# if the emblfile is defined, open it for writing
#-----------------------------------------------------------------------

my $EMBL;

if ($emblfile) {
    $EMBL = new FileHandle($emblfile,'w');
    &showUsage("Failed to open EMBL file $emblfile") unless $EMBL;
}

#-----------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------

# run through all the contigs

my $currentcontigs = {};
my $acdestinations = {}; # original contig destinations
my $ccontigorigins = {}; # current contigs origins contig

my $lengthmismatch = 0;
my $fastamappinghash = {};
my $numberprocessed = 0;

foreach my $contigname (sort keys %$contigtaghash) {

    $logger->info("Assembling tags for contig $contigname");

    next unless (!$contig || $contigname =~ /$contig/);

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
    elsif ($contigname =~ /\b(\d+)\b/) {
        $arcturuscontig = $adb->getContig(contig_id=>$contigname,metaDataOnly=>1);    }
    else {
        $arcturuscontig = $adb->getContig(withRead=>$contigname,metaDataOnly=>1);
    }

    unless ($arcturuscontig) {
        $logger->warning("contig $contigname NOT FOUND");
        next;
    }

    $logger->info("contig $contigname identified as Arcturus contig: "
                 . $arcturuscontig->getContigID());
    &listtags($arcturuscontig,'arcturuscontig from database');

    my $alength = $arcturuscontig->getConsensusLength();

# compare the length of the contig in Arcturus with the one given in the

    if (defined($fastafile)) {
# identify the fasta contig using the contig ID
        my $cid = $arcturuscontig->getContigID();
        my $fastacontig = $fastacontighash->{$cid};
        unless ($fastacontig) {
            $logger->warning("No contig provided on file $fastafile "
                            ."for contig $contigname");
            $annotatedlength->{$contigname} = 0;
            next;
	}
        my $flength = $fastacontig->getConsensusLength();

        unless ($annotatedlength->{$contigname}) {
            $logger->warning("No annotated sequence length provided "
                            ."for contig $contigname");
            $annotatedlength->{$contigname} = 0;
	}
# test the three lengthes (annotation contig, annotatedlength and length)
        my $nlength = $annotatedlength->{$contigname};
        my $summary = "Annotated: ". sprintf("%8d",$nlength) . "; "
                    . "Arcturus: " . sprintf("%8d",$alength) . "; "
		    . "Fasta: " . sprintf("%8d",$flength);
        $logger->warning("processing contig $contigname ($summary)");
        unless ($nlength && $nlength == $flength || $override) {
            $logger->severe("SKIPPED $contigname: incompatible contig lengths");
            next;
	}

# clip low quality pads

        ContigFactory->replaceLowQualityBases($arcturuscontig);

# determine the transformation from annotation contig to arcturus contig

        my $fsequence = $fastacontig->getSequence();
        my $asequence = $arcturuscontig->getSequence();
        $logger->fine("Processing $contigname lengths: "
                      .length($asequence)." & ".length($fsequence));
        &listtags($fastacontig,'fastacontig before alignment');
  
# get the alignment from the annotated sequence to the sequence in arcturus

        my $mapping;

# METHOD 1 : Smith-Waterman alignment

        if ($swprog && length($asequence) < 30000) {
	    $logger->warning("Smith Waterman Alignment selected");
           ($mapping,my $s) = &SmithWatermanAlignment($asequence,$fsequence);
            unless ($mapping) {
                print STDOUT "Failed SW mapping for $contigname ($s)\n\n";
	    }
        }

# METHOD 2 : if (still) no mapping, use the Alignment package version

        unless ($mapping) {
	    $logger->warning("Alignment.pm correlation selected");
#	    my $flength = $annotatedlength->{$contigname};
   	    my $peakdrift = $alength - $flength;
            my $linear = 1.0 + 2.0 * $peakdrift/($alength + $flength);
            my $bandedwindow = 4.0 * sqrt($peakdrift); # generous minimum of 
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
            my $aquality = $arcturuscontig->getBaseQuality();
#            $options{squality} = $aquality;
#            $options{tquality} = 0;
 
            my $output = $logger->getOutputDevice() || *STDOUT;
            $options{debug} = $output if $debug;

            $mapping = Alignment->correlate($fsequence,0,$asequence,0,%options);
	}

# here we must have a mapping between the (original) arcturus contig and
# the input (annotated) contig

        unless ($mapping) {
	    $logger->severe("Unable to determine a mapping!");
	    next;
        }

# mapping determined: add the annotation as tags to fasta contig 

	$mapping = $mapping->inverse();
        $mapping->setMappingName($contigname);
        $logger->fine("Mapping : ".$mapping->toString() );

# ok, here we have a mapping; put the tags on the fastacontig

        my $tagcount = 0;
        foreach my $tag (@tags) {
        my @pos = $tag->getPosition();
            unless ($pos[0] > 0 && $pos[1] <= $flength) {
                $logger->severe("Tag outside range for contig $contigname: "
			       ."@pos  (1-$flength)");
	        next;
	    }
            $fastacontig->addTag($tag);
            $tagcount++;
        }
        $logger->warning("$tagcount tags found for contig $contigname");
        &listtags($fastacontig,'fastacontig $tagcount tags added');

# make the arcturus contig its child



        $mapping->setSequenceID(1);
        $fastacontig->setContigID(1);


      my $METHOD = 0;
      if ($METHOD == 1) {
        $arcturuscontig->addParentContig($fastacontig);
        $arcturuscontig->addContigToContigMapping($mapping);

# then propagate the tags from parent to child

#        $fastacontig->writeToEMBL(*STDOUT) unless $noembl;
#$contig->setDEBUG($logger);
$arcturuscontig->setDEBUG($logger) if $debug;

        $arcturuscontig->inheritTags();

      }
      else {
# the other way around
#$fastacontig->setDEBUG($logger);
        $fastacontig->addChildContig($arcturuscontig);
        $arcturuscontig->addContigToContigMapping($mapping);
        $fastacontig->propagateTags(break=>1);
$fastacontig->setDEBUG();
      }
    }

    elsif (!$annotatedlength->{$contigname}) {
# no annotated sequence length provided
        $logger->warning("No annotated sequence length provided for contig $contigname");
        $logger->warning("Contig assumed to be correctly identified");
# in this case, we add the tag directly to the arcturus contig
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
        $logger->warning("$tagcount tags found for contig $contigname"); 
        &listtags($arcturuscontig,'arcturuscontig $tagcount tags added');
    }

    elsif ($alength != $annotatedlength->{$contigname}) {
# the length of the contig in Arcturus differs from that used for annotation
# and we have no fasta contig provided: we cannot do the job for this contig
        my $summary = "Annotated: ".sprintf("%8d",$annotatedlength->{$contigname})."; "
                    . "Arcturus: " .sprintf("%8d",$alength);
        $logger->warning("Length mismatch for contig $contigname ($summary)");
        $logger->warning("-confirm switch is reset") if $confirm;
        $lengthmismatch++;
        next;
    }

# prepare for possible propagation of tags

    $logger->info("Processing contig ".$arcturuscontig->getContigName());

# $arcturuscontig->setDEBUG(1) if $debug;

    my $contigs = [];

    if ($propagate) {
# test set up for propagation to offspring
        my $acid = $arcturuscontig->getContigID();
        $contigs = &propagate($arcturuscontig);
	$logger->info("Contigs after propagation of $contigname:");
        if (my $fastacontig = $fastacontighash->{$acid}) {
  	    &listtagsequence($fastacontig,$testtag) if $testtag;
        }
        foreach my $contig (@$contigs) {
            my $ccid = $contig->getContigID();
            my $ccnm = $contig->getContigName();
	    &listtagsequence($contig,$testtag) if $testtag;
            unless ($adb->isCurrentContigID($ccid)) {
		$logger->info("$ccnm is intermediate");
		next;
	    }
            $logger->warning("$ccnm is a current contig");
# test if it has tags (split contigs may not have them)
            unless ($contig->hasTags()) {
                $logger->warning("$ccnm is ignored because it has no tags");
		next;
	    }
# register the current contig the first time it is encountered, otherwise ..
            if (my $currentcontig = $currentcontigs->{$ccnm}) {
# .. add the tags to the taglist of the contig instance we already have
                my $additionaltags = $contig->getTags();
                $currentcontig->addTag(@$additionaltags);
            }
            else { 
                $currentcontigs->{$ccnm} = $contig;
	    }
# register the destination of tags from the original arcturus contig
            $acdestinations->{$acid} = [] unless $acdestinations->{$acid};
            push @{$acdestinations->{$acid}},$ccid;
            $ccontigorigins->{$ccid} = [] unless $ccontigorigins->{$ccid};
            push @{$ccontigorigins->{$ccid}},$arcturuscontig;
	} 

# list summary of result if not loading tags or other export 

        unless ($confirm || !$noembl || $EMBL) {
            foreach my $contig (@$contigs) {
                my $tags = $contig->getTags(); # as is, no delayed loading
                $tags = [] unless $tags;
                $logger->info("contig ".$contig->getContigName()
			      ." has ".scalar(@$tags)." tags");
                foreach my $tag (@$tags) {
                    $logger->info($tag->writeToCaf(0,annotag=>1));
		}
	    }
	}
    }
    else {
        push @$contigs,$arcturuscontig;
    }

    $numberprocessed++;
}

# here all tags have gone through the propagation using Arcturus info

# RE-DO mode: erase all tags from CCs and remap directly from AC contigs

if ($reanalyze) {
# for each CC: get link to original ACs directly
    $logger->warning("Re-analyzing contig links to ancestors");
    foreach my $ccnm (sort keys %$currentcontigs) {
        my $contig = $currentcontigs->{$ccnm};
        my $ccid = $contig->getContigID();
        $logger->warning("Processing current contig $ccid");
# skip if the current contig is the originally annotated one
        if ($acdestinations->{$ccid}) {
            $logger->warning("Contig $ccid is the original annotated contig");
            next;
	}
# remove tags, parents, children and links, if any
        $contig->addChildContig();
        $contig->addParentContig();
        $contig->addContigToContigMapping();
        $contig->addTag();
# ensure that the mappings are defined
        $contig->hasMappings(1); # use delayed loading
# get the original arcturus contig(s)

        my $ancestors = $ccontigorigins->{$ccid};
        unless ($ancestors) {
            $logger->severe("contig $ccid unexpectedly has no original");
            next;
	}
# get link to each ancestor and import the tags (two methods for comparison)
        my $method = 0;
        foreach my $ancestor (@$ancestors) {
            $contig->addParentContig($ancestor);
            $ancestor->hasMappings(1); # ensure read mappings are loaded
            unless ($method) {
# each ancestor individually
                $ancestor->propagateTagsToContig($contig, delayedloading=>0);
	        next;
	    }
# the alternative: get mapping beforehand (allows testing it here)
            my ($status,$deallocated) = $contig->linkToContig($ancestor);
            unless ($status) {
                my $acid = $ancestor->getContigID();
                $logger->severe("contig $ccid unexpectedly has no link to $acid");
		next;
	    }
        }

        $contig->inheritTags() if $method;
    }
}

# here we have a list of current contigs

if (!$noembl || $EMBL) {

    my $timer = new MyTimer();

    foreach my $ccnm (sort keys %$currentcontigs) {
        my $contig = $currentcontigs->{$ccnm};
        if ($qclip) {
            my %qcoptions = (threshold => $qclip, newcontig => 1,
                             exportaschild => 1);
            my ($newcontig,$status) = ContigFactory->deleteLowQualityBases
                                                     ($contig,%qcoptions);
            if ($status) {
print STDOUT "begin Inherit tags\n";
$timer->timer('propagate',0);
                $contig->propagateTagsToContig($newcontig,speedmode=>1,timer=>$timer,overlap=>1);
$timer->timer('propagate',1);
print STDOUT "DONE Inherit tags\n";
# next;
                $contig = $newcontig;
	    }
        }
        $contig->writeToEMBL(*STDOUT,0,tagsonly=>0) unless $noembl;
        $contig->writeToEMBL($EMBL  ) if $EMBL;
    }
}

$EMBL->close() if $EMBL;

if ($confirm) { # AND not in redo mode!
# load the data for the current contigs into the database
    my %options;
    $options{debug} = 1 if $debug;

    foreach my $ccnm (sort keys %$currentcontigs) {
        my $contig = $currentcontigs->{$ccnm};

#        my $ccid = $contig->getContigID();
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
    $logger->skip();
    $logger->severe("!! You need to provide the fasta file used for annotation");
    $logger->skip();
}
elsif (!$numberprocessed) {
    $logger->warning("NO contigs processed");
}
elsif ( !defined($confirm) ) {
    $logger->warning("To load this stuff: repeat with '-confirm'");
}

$adb->disconnect();

# generate a listing of the current contigs involved

my @currentcontigs = sort (keys %$currentcontigs);

$logger->skip();
$logger->warning("NO current contigs found") unless @currentcontigs;
$logger->warning("current contigs affected:")  if @currentcontigs;
$logger->skip();

if (@currentcontigs) {
# list contigs and mapping of originals to new ones
    foreach my $contig (@currentcontigs) {
        $logger->warning("$contig");
    }

    $logger->skip();
    $logger->warning("mappings from original contigs to current contigs");
    $logger->skip();

    foreach my $acid (sort {$a <=> $b} keys %$acdestinations) {
        my $destinations = $acdestinations->{$acid};
        $logger->warning("contig $acid  => @$destinations");
    }
    $logger->skip();
}

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
    my $scoring = 0;
    while (my $line = <CHILD_RDR>) {
# print STDOUT "line $line \n";
        last if ($line =~ /^\./);
        my @words = split(';', $line);
# decode the first field (overall mapping and quality)
        my ($score, $smap, $fmap, $segs) = split(',', $words[0]);

        if ($segs > 0 && $score > 50) {
            $goodread = 1;
            $scoring = $score;
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
            $scoring = $score;
	}
    }
    return $mapping,$scoring;
}

sub listtags {
    my $contig = shift;
    my $label = shift || '';

    my $tags = $contig->getTags(); # as is, no delayed loading
    $tags = [] unless $tags;
    $logger->fine("contig ".$contig->getContigName()
		           ." has ".scalar(@$tags)." tags; $label");
    foreach my $tag (@$tags) {
        $logger->fine($tag->writeToCaf(0,annotag=>1));
    }

}

sub listtagsequence {
    my $contig = shift;
    my $tag_id = shift;

    return unless $contig->hasTags();

    my $tags = $contig->getTags();

# identify the tag (could be more than one)

    my @tags;
    foreach my $tag (@$tags) {
        my $sys_id = $tag->getSystematicID();
        next unless ($sys_id =~ /$tag_id/);
        push @tags,$tag;
    }

    return unless @tags;

    my $sequence = $contig->getSequence();
    my $contigname = $contig->getContigName();

    foreach my $tag (@tags) {
        my ($start,$final) = $tag->getPosition();
        my $tagsequence = substr $sequence,$start-1,$final-$start+1;
        my $strand = $tag->getStrand();
        if ($strand eq 'Reverse') {
            $tagsequence = reverse($tagsequence);
            $tagsequence =~ tr/ACGTacgt/TGCAtgca/;
        }
        my $sys_id = $tag->getSystematicID();
        $logger->warning("tag $sys_id : $start - $final  $strand  on $contigname");
        $logger->warning($tagsequence);
    }

}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Annotation tag loader/remapper. Annotation is read from an ";
    print STDERR "input file\nand put as tags on the corresponding contigs; ";
    print STDERR "subsequently they are\nre-mapped to the current generation ";
    print STDERR "of the assembly.\n";
    print STDERR "\n";
    print STDERR "If the annotated sequence is an edited version of the original ";
    print STDERR "Arcturus\ncontig, that sequence has to be provided in fasta ";
    print STDERR "format, on a separate\ninput file. The input tags are then ";
    print STDERR "mapped back onto the original contig\nby determination of the ";
    print STDERR "sequence alignment. Small contigs (length < 30000)\ncan be ";
    print STDERR "handled by the Smith-Waterman program; larger contigs require ";
    print STDERR "the\n(still experimental) Alignment package.\n";
    print STDERR "\n";
    print STDERR "Remapped tags can be loaded into arcturus, or written to an ";
    print STDERR "output file.\n";
    print STDERR "\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    print STDERR "-tagfile\t(tf) input file with tag info in records of 4 or 5 items :\n";
    print STDERR "\t\tcontigname, systematic name, position start & end , and\n";
    print STDERR "\t\toptionally [length of annotated sequence]\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    unless (defined($propagate)) {
        print STDERR "-propagate\t(no value) propagate contig tag(s) to the last generation\n";
        print STDERR "\t\t(in its absence only map from edited to original sequence)\n";
        print STDERR "\n";
    }
    print STDERR "-reanalyze\t(no value) re-do mapping from original to current";
    print STDERR " generation\n\t\tfrom scratch\n";
    print STDERR "-fasta\t\t(ff) input fasta file with sequences used for annotation\n";
    unless (defined($swprog)) {
        print STDERR "-swprog\t\t(optional) use Smith-Waterman alignment algorithm\n";
    }
    print STDERR "\n";
    unless (defined($confirm)) {
        print STDERR "-confirm\t(dbload) store remapped tags into the database\n";
    }
    print STDERR "-embl\t\t(no value) list current contig & tags in EMBL";
    print STDERR " format on STDOUT\n";
    print STDERR "-emblfile\t(ef) write contig & tags of the current generation";
    print STDERR " to file\n";
    unless (defined($qclip)) {
        print STDERR "-qualityclip\t(qc, no value) to remove low quality pads from re-mapped\n\t\t sequence\n";
    }
    print STDERR "\n";
    print STDERR "-contig\t\tselect a particular contig by ID\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-debug\t\t(no value)\n" unless defined($debug);
    print STDERR "\n";
    print STDERR "**** Parameter input ERROR: $code ****\n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
