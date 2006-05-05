#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use ContigFactory::ContigFactory;

# use Correlate;

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

my $validKeys  = "organism|instance|filename|fn|propagate|fasta|"
               . "confirm|verbose|debug|help";

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

    &showUsage(0) if ($nextword eq '-help');
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

$FILE->close();

$logger->warning("$line records read from file $datafile");

#-----------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------

# run through all the contigs

my $lengthmismatch = 0;

foreach my $contigname (keys %$contigtaghash) {

    $logger->info("Processing contig $contigname");

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

    my $length = $arcturuscontig->getConsensusLength();

# compare the length of the contig in Arcturus with the one given in the

    if (defined($fastafile)) {
# identify the fasta contig using the contig ID
        my $cid = $arcturuscontig->getContigID();
        my $fastacontig = $fastacontighash->{$cid};
        unless ($annotatedlength->{$contigname}) {
            $logger->warning("No annotated sequence length provided for contig $contigname");
            $annotatedlength->{$contigname} = 0;
	}
# test the three lengthes (annotation contig, annotatedlength and length)
        my $summary = "Annotated: " . sprintf("%8d",$annotatedlength->{$contigname}) . "; "
                    . "Arcturus: " . sprintf("%8d",$length) . "; "
		    . "Fasta: " . sprintf("%8d",$fastacontig->getConsensusLength());
        $logger->warning("processing contig $contigname ($summary)");

# determine the transformation from annotation contig to arcturus contig

#*********** THIS PART IS EXPERIMENTAL AND UNDER DEVELOPMENT
        $logger->warning("SORRY, this part is not yet operational"); next;
	my $peakdrift = $length - $annotatedlength->{$contigname};
        my %options = (kmersize=>9,coaligned=>1,peakdrift=>$peakdrift);
# no peakdrift? but linear drift? in this case
Correlate->setDebug(1) if $debug;
        my $mapping = Correlate->correlate($fastacontig->getSequence(),0,
                                           $arcturuscontig->getSequence(),0,
                                           %options);
# 4) transform the tags accordingly
        foreach my $tag (@tags) {
#            $tag->transpose(); ??
        }
next;
#*********** UNTIL HERE
    }
# warn if no annotated sequence length provided
    elsif (!$annotatedlength->{$contigname}) {
        $logger->warning("No annotated sequence length provided for contig $contigname");
    }
# compare the length of the contig in Arcturus with that given with annotation
    elsif ($annotatedlength->{$contigname} != $length) {
        my $summary = "Annotated: ".sprintf("%8d",$annotatedlength->{$contigname})."; "
                    . "Arcturus: " .sprintf("%8d",$length);
        $logger->warning("Length mismatch for contig $contigname ($summary)");
        $logger->warning("-confirm switch is reset") if $confirm;
        $lengthmismatch++;
        $confirm = 0;
    }

    my $tagcount = 0;
    foreach my $tag (@tags) {
        my @pos = $tag->getPosition();
        unless ($pos[0] > 0 && $pos[1] <= $length) {
            $logger->severe("Tag outside range for contig $contigname: "
			    ."@pos  (1-$length)");
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
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-debug\t\t(no value)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
