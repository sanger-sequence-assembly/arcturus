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
my $verbose;
my $datafile;
my $confirm;
my $limit = 0;

my $validKeys  = "organism|instance|sequence|datafile|limit|"
               . "preview|confirm|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance   = shift @ARGV  if ($nextword eq '-instance');
      
    $organism   = shift @ARGV  if ($nextword eq '-organism');

    $datafile   = shift @ARGV  if ($nextword eq '-datafile');

    $limit      = shift @ARGV  if ($nextword eq '-limit');

    $verbose    = 1            if ($nextword eq '-verbose');

    $verbose    = 2            if ($nextword eq '-debug');
 
    $confirm    = 0            if ($nextword eq '-preview');
    $confirm    = 1            if (!defined($confirm) && $nextword eq '-confirm');

#    $update     = 0            if ($nextword eq '-insert');
#    $update     = 1            if ($nextword eq '-update');
#    $update     = 2            if ($nextword eq '-replace');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing input datafile") unless $datafile;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$adb->cDebug() if ($verbose && $verbose > 1);
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $DATA = new FileHandle($datafile,'r');
   
&showUsage("Failed to open data file $datafile") unless $DATA;

# build the tags

my @tags;

while (defined (my $record = <$DATA>)) {

    next unless $record;

    $record =~ s/^\s*//; # chop off leading blanks

    my @field = split /\s+/, $record;

    unless (scalar(@field) == 6) {
        print STDERR "Invalid record $record in file $datafile\n";
        next;
    }

    my $tag = new Tag();
    $tag->setSequenceID($field[0]);
    $tag->setType('REPT');
    
    $tag->setTagSequenceName($field[1]);
    if ($field[3] > $field[2]) {
        $tag->setStrand('Forward');
        $tag->setPosition($field[2],$field[3]);
    }
    elsif ($field[2] > $field[3])  {
        $tag->setStrand('Reverse');
        $tag->setPosition($field[3],$field[2]);
    }

    my $comment = "$field[1] from bp $field[4] to $field[5]";
    $tag->setTagComment($comment);

    push @tags,$tag;
} 

# get contig IDs, pull out the contigs and add the tags

my %contigs;

foreach my $tag (@tags) {
    my $contigid = $tag->getSequenceID();
    my $contig = $contigs{$contigid};
    unless ($contig) {
        $contig = $adb->getContig(contig_id=>$contigid,metaDataOnly=>1);
        if ($contig) {
            $contigs{$contigid} = $contig;
        }
        else {
            print STDERR "Unknown contig $contigid\n";
            next;
        }
    }    
    $contig->addTag($tag);
}

# add the contig tags

if ($confirm) {
    foreach my $contigid (sort {$a <=> $b} keys %contigs) {
        my $contig = $contigs{$contigid};
        $adb->enterTagsForContig($contig);
        last unless --$limit;
    }
}
else {
    foreach my $contigid (sort {$a <=> $b} keys %contigs) {
        my $contig = $contigs{$contigid};
        $logger->warning("\nProcessing contig $contigid");
        my $tags = $contig->getTags();
        foreach my $tag (@$tags) {
            $logger->info($tag->writeToCaf());
        }
        last unless --$limit;
    }
 }

$adb->disconnect();

exit;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n\nAd hoc tag sequence loader/retrieval test\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "-datafile\tfile with tag info\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) to enter data into arcturus, else preview\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
