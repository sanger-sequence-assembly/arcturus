#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $fofn;
my $list;
my $parents;
my $children;

my $verbose;

my $validKeys  = "organism|instance|contig|fofn|focn|parents|children|"
               . "report|list|longlist|verbose|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
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

    $contig    = shift @ARGV  if ($nextword eq '-contig');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');
    $fofn      = shift @ARGV  if ($nextword eq '-focn');

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-debug');

    $parents   = 1            if ($nextword eq '-parents');

    $children  = 1            if ($nextword eq '-children');

    $list      = 1            if ($nextword eq '-list');
    $list      = 2            if ($nextword eq '-longlist');
    $list      = 0            if ($nextword eq '-report');

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

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing contig identifier (name or ID)") unless ($contig || $fofn);

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

my @contigs;

push @contigs,$contig if $contig;

push @contigs,@$fofn if $fofn;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

foreach my $contig (@contigs) {
# translate a name into an ID
    if ($contig =~ /\D/) {
        my $contigs = $adb->getContigIDsForReadNames([($contig)]);
        &showUsage("Unidentified contig $contig") unless @$contigs;
        $contig = $contigs->[0]->[0];
    }
    &showUsage("Unidentified contig $contig") unless $contig;
}

# get the related contigs in the generation tree

my $output = [];
foreach my $contigid (@contigs) {

    $logger->info("\nProcessing contig $contigid");

    my %soptions;
    $soptions{parents} = 1 if $parents;
    $soptions{children} = 1 if $children;
    my $generationhash = $adb->getRelationsForContigID($contigid);

    unless (keys %$generationhash) {
        $logger->warning("No contigs found for $contigid");
    }

    my @contigids = sort {$a <=> $b} keys %$generationhash;

    my $lastgeneration = $generationhash->{$contigids[$#contigids]};

    my $report = "Original contig $contigid is now : ";

    foreach my $contigid (@contigids) {
        if ($generationhash->{$contigid} == $lastgeneration) {
            $report .= "contig $contigid ";
	    my %options = (contig_id=>$contigid,metaDataOnly=>1);
            if (my $contig = $adb->getContig(%options)) {
                my $gap4name = $contig->getGap4Name();
                $report .= "($gap4name); ";
                my @result = ($gap4name);
                push @result,$contig if ($list && $list > 1);
                push @$output,\@result;
            }
            else {
                $report .= "(not found)";
	    }
	}
        $logger->info("$contigid generation $generationhash->{$contigid}");
    }
    $logger->warning($report) unless $list;
}

if ($list) {
    foreach my $result (@$output) {
        $logger->warning("@$result");
    }
}

$adb->disconnect();

exit;


#------------------------------------------------------------------------
# subs
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        $name =~ s/.*\.0*(\d+)\s*$/$1/; # ends in a number
        push @list, $name if ($name =~ /\S/);
    }

    $FILE->close() if $FILE;

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Contig parents and children\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\t'\n" unless $instance;
        print STDERR "\n";
    } 
    print STDERR "MANDATORY EXCLUSIVE PARAMETER:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tContig identifier (ID or name of read in it)\n";
    print STDERR "-fofn\t\tfile of contig names or IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-list\t\t(no value) output of contig names found\n";
    print STDERR "-longlist\t(no value) output of contig names and IDs found\n";
    print STDERR "-report\t\t(no value, default) default reporting\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
