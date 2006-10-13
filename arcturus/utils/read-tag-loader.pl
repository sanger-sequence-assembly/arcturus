#!/usr/local/bin/perl5.6.1 -w

use strict;

use ArcturusDatabase;

use Tag;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $read;
my $forn;

my $tagtype;
my $tagtext;

my $verbose;
my $confirm;
my $debug = 0;
my $limit = 1;

my $validKeys  = "organism|instance|read|forn|fofn|"
               . "tagtype|type|tagtext|text|limit|"
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

    $read         = shift @ARGV  if ($nextword eq '-read');

    $forn         = shift @ARGV  if ($nextword eq '-forn');
    $forn         = shift @ARGV  if ($nextword eq '-fofn');

    $tagtype      = shift @ARGV  if ($nextword eq '-tagtype');
    $tagtype      = shift @ARGV  if ($nextword eq '-type');

    $tagtext      = shift @ARGV  if ($nextword eq '-tagtext');
    $tagtext      = shift @ARGV  if ($nextword eq '-text');

    $limit        = shift @ARGV  if ($nextword eq '-limit');

    $confirm      = 1            if ($nextword eq '-confirm');

    $debug        = 1            if ($nextword eq '-debug');

    $verbose      = 1            if ($nextword eq '-verbose');

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

&showUsage("Missing read ID or name") unless ($read || $forn);

&showUsage("Missing tag type") unless $tagtype;
&showUsage("Missing tag text") unless $tagtext;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$logger->info("Database ".$adb->getURL." opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my @reads;

# get the read or reads

if ($forn) {
    $forn = &getNamesFromFile($forn);
    push @reads,@$forn if $forn;
}

if ($read =~ /[\%\*\_]/) {
    $read =~ s/\*/%/g if ($read =~ /\*/);
    my $reads = $adb->getReadNamesLike($read,limit=>$limit);
    push @reads,@$reads if $reads;
}
elsif ($read) {
    push @reads,$read;
}

$logger->warning(scalar(@reads)." reads identifiers found");

# go through all reads and add the tag

my @Reads;

foreach my $read (@reads) {

    my $Read;
    $Read = $adb->getRead(read_id  => $read) if ($read !~ /\D/);
    $Read = $adb->getRead(readname => $read) if ($read =~ /\D/);

    unless ($Read) {
	$logger->severe("Unknown read $read");
	next;
    }

    push @Reads,$Read;
}

$adb->getTagsForReads(\@Reads);

# create the tag for these reads

my $tagstoload = 0;

foreach my $Read (@Reads) {

    my $tag = new Tag('Read');
    $tag->setPosition(1,$Read->getSequenceLength());
    $tag->setType($tagtype);
    if ($tagtext eq 'ligation') {
        $tagtext = "LI ".$Read->getLigation();
    }
    elsif ($tagtext eq 'clone') {
	$tagtext = "CN ".$Read->getClone();
    }
    elsif ($tagtext eq 'all') {
        $tagtext = "CN ".$Read->getClone()."  LI ".$Read->getLigation();
    }
    $tag->setTagComment($tagtext);

    if ($Read->hasTags()) {
        my $tagisnew = 1;
        my $tags = $Read->getTags();
        foreach my $etag (@$tags) {
            if ($etag->isEqual($tag)) {
                $logger->warning("Existing $tagtype tag equals new tag for " .
                                  $Read->getReadName());
                $tagisnew = 0;
	    }
        }
        next unless $tagisnew;
    }

    $logger->info($Read->getReadName() ." : ". $tag->writeToCaf());

    $Read->addTag($tag);

    $tagstoload++;
}

# all tags now assembled

if ($tagstoload && $confirm) {
    my $success = $adb->putTagsForReads(\@Reads,debug=>$debug);
    if ($success) {
        $logger->warning("$tagstoload tags were loaded ($success)");
    }
    else {
        $logger->warning("FAILED to load tags");
    }
}
elsif ($tagstoload) {
    $logger->warning("To load these tags repeat with '-confirm'");
}
else {
    $logger->warning("There are no tags to load");
}

$adb->disconnect();

exit 0;

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
        next unless $name;
        $name =~ s/^\s+|\s+$//g;
        my @names = split /\s/,$name;
        push @list, $names[0]; 
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Define and load tags for selected reads\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n" unless $organism;
    print STDERR "-instance\t'prod', 'dev', 'test' or 'linux'\n" unless $instance;  
    print STDERR "\n";
    print STDERR "-tagtype\t(type) 4 character tag type\n";
    print STDERR "-tagtext\t(text) tag comment to be use for each tag\n";
    print STDERR "\t\t(special: 'clone' or 'ligation' or 'all')\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-read\t\tread ID or name or name with wildcards\n";
    print STDERR "-fofn\t\tfile with read names or IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-limit\t\t(with 'read') maximum number of reads; 0 for all\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}




