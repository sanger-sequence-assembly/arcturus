#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Tag;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $datafile;

my $verbose;
my $confirm;
my $debug;

my $validKeys  = "organism|instance|filename|fn|"
               . "confirm|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance   = shift @ARGV  if ($nextword eq '-instance');
      
    $organism   = shift @ARGV  if ($nextword eq '-organism');

    $datafile   = shift @ARGV  if ($nextword eq '-filename');
    $datafile   = shift @ARGV  if ($nextword eq '-fn');

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
# MAIN
#-----------------------------------------------------------------------

my $FILE = new FileHandle($datafile,'r'); # open for read 

$logger->severe("FAILED to open file $datafile") unless $FILE;

my $contigtaghash = {};

# collect tags and store as a hash of arrays of arrays keyed on contig name

my $line = 0;

while ($FILE && defined(my $record = <$FILE>)) {

    $line++;

    next unless ($record =~ /\S/);

    if ($record =~ /(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s*$/) {
        my $contig = $1;
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

# ok, now run through all the contigs

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

    my $contig = $adb->getContig(withRead=>$contigname,metaDataOnly=>1);

    unless ($contig) {
        $logger->warning("contig $contigname NOT FOUND");
        next;
    }
    $logger->info("contig $contigname: ".$contig->getContigID());

    foreach my $tag (@tags) {
        $contig->addTag($tag);
    }

    next unless $confirm;

# load the data into the database

    my %options;
    $options{debug} = 1 if $debug;

    my $success = $adb->enterTagsForContig($contig,%options);

    $logger->warning("enterTagsForContig $contigname : success = $success");
}

$logger->warning("To load this stuff: repeat with '-confirm'") unless $confirm;

$adb->disconnect();

exit;

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
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "-filename\t(fn) file with tag info in records of 4 items\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-debug\t\t(no value)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
