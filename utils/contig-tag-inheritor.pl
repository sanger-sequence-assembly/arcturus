#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my ($contig,$begin,$final,$block);
my $strong = 0;
my $fofn;
my $filter;
my $next = 1;
my $confirm = 0;
my $cleanup = 0;
my $force = 0;
my $verbose;
my $debug;
my $logfile;
my $synchronize = 1;

my $reverse; # test mode
my $tagtype;
my $showtag;

my $validKeys  = "organism|instance|contig|begin|final|block|fofn|pidf|filter|next|"
               . "cleanup|reversecontig|rc|reverseparent|rp|preview|nosynchronize|nosync|"
               . "inherittags|it|showtags|st|showtagsreversed|str|"
               . "strong|force|log|confirm|commit|verbose|info|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $contig    = shift @ARGV  if ($nextword eq '-contig');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    if ($nextword eq '-pidf' || $nextword eq '-filter') {
        $filter    = shift @ARGV;
	$synchronize = 0;
    }

    $logfile   = shift @ARGV  if ($nextword eq '-log');

    $strong    = 1            if ($nextword eq '-strong');

    $force     = 1            if ($nextword eq '-force');

    $begin     = shift @ARGV  if ($nextword eq '-begin');

    $final     = shift @ARGV  if ($nextword eq '-final');

    $block     = shift @ARGV  if ($nextword eq '-block');

    $cleanup   = 1            if ($nextword eq '-cleanup');

    $reverse   = 1            if ($nextword eq '-rp'  || $nextword eq '-reverseparent');
    $reverse   = 2            if ($nextword eq '-rc'  || $nextword eq '-reversecontig');

    $tagtype   = shift @ARGV  if ($nextword eq '-it'  || $nextword eq '-inherittags');
 
    $showtag   = 1            if ($nextword eq '-st'  || $nextword eq '-showtags');

    $showtag   = -1           if ($nextword eq '-str' || $nextword eq '-showtagreverse'); # for reverse

    if ($nextword eq '-nosync' || $nextword eq '-nosynchronize') {
        $synchronize  = 0;
    }       

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-info');

    $debug     = 1            if ($nextword eq '-debug');

    $confirm   = 0            if ($nextword eq '-preview');

    $confirm   = 1            if ($nextword eq '-confirm');

    $confirm   = 1            if ($nextword eq '-commit');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter($verbose) if defined $verbose; # set reporting level

$logger->setDebugStream('STDOUT',list=>1)   if $debug;

$logger->setSpecialStream($logfile,list=>1) if $logfile;

#$logger->setBlock('debug',unblock=>1) if $debug;

Contig->setLogger($logger); 
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig ID") unless ($contig || $fofn);

&showUsage("Missing tagtype") unless $tagtype;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

$fofn = &getNamesFromFile($fofn) if $fofn;

# get the list of contigs to investigate

my @contigs;

if ($fofn) {
    @contigs = @$fofn;
}
elsif ($contig =~ /\,/) {
    @contigs = split /\,/,$contig;
}
elsif ($contig eq 'current' || $contig eq 'range') {
    my $cc = $adb->getCurrentContigIDs();
    @contigs = @$cc if $cc;
    if ($contig eq 'range') {
        $begin = 1 unless defined $begin;
        $block = $final - $begin + 1 if defined($final);
        $block = 1 unless defined $block;
	my $final = $begin + $block - 1;
        $logger->warning("contig range to be used $begin - $final");
    }
}
elsif ($contig) {
    push @contigs,$contig;
    while (--$next > 0) {
        push @contigs,++$contig;
    }
}
else {
    &showUsage("Missing contig specification");
}

my $tagtotal = 0;

foreach my $contig_id (@contigs) {

    if ($begin && $block) {
        next if ($begin && $contig_id < $begin);
        last if ($block && $contig_id > ($begin + $block - 1));
    }

    $logger->warning("Getting contig $contig_id",ps=>1);

    my $contig = $adb->getContig(contig_id=>$contig_id,metadataonly=>1);

    $logger->warning("Contig $contig_id not found") unless $contig;

    next unless $contig; # no contig found

    $logger->warning("Contig returned for $contig_id: $contig");

    $contig->addTag(0); # remove existing tags (just in case)

    my $c2pmappings = $contig->getContigToContigMappings(1);

    my @parentids;
    my $parentidhash = {};
    foreach my $mapping (@$c2pmappings) {
        next unless $mapping->hasSegments();
        my $parent_id = $mapping->getSequenceID();
        $parentidhash->{$parent_id}++;
#        push @parentids, $parent_id;
    }

    @parentids = sort {$a <=> $b} keys %$parentidhash;

    unless (@parentids) {
        $logger->info("No parents found for contig $contig_id");
	next;
    }

    $logger->debug("Parents @parentids with mappings found for contig $contig_id");

# replace the parent ID by the parent Contig instance

    my @parents;
    foreach my $parentid (@parentids) {
        next if ($filter && $parentid !~ /$filter/);
	$logger->info("Loading parent $parentid");
        my $parent = $adb->getContig(contig_id=>$parentid,metadataonly=>1);
        unless (ref($parent) eq 'Contig') {
            $logger->error("Contig $parentid not retrieved");
	    next;
	}
        unless ($parent->hasTags(1)) { # load tags
            $logger->warning("parent contig ".$parent->getContigName()." has no tags");
	    next;
	}
#        $contig->addParentContig($parent);
        push @parents, $parent;
    }


# test section to inherit tags

    my @pidlist;
    foreach my $parent (@parents) {
        my $pid = $parent->getContigID();
        my $currenttags = 0;
        if (my $tags = $contig->getTags()) {
            $currenttags = scalar(@$tags);
        }
# specify both contig and parent
        $parent->propagateTagsToContig($contig,annotation=>0,finishing=>$tagtype);
# $contig->inheritTags(annotation=>0,finishing=>$tagtype,nocache=>1);
        if (my $tags = $contig->getTags()) {
            my $newtags = scalar(@$tags) - $currenttags;
            if ($newtags) {
                $logger->warning("$newtags tags inherited from parent $pid");
                push @pidlist,$pid;
            }
            else {
                $logger->warning("NO tags inherited from parent $pid")
            }
        }
        if ($showtag) {
            &showtagsoncontig($parent);
            &showtagsoncontig($contig,$showtag);
            $contig->addTag(0); # erase existing tags for test purposes 
        }
        $parent->erase(); # remove all self references prepare for garbage collection
        undef $parent;
    }


# give tag summary

    if (my $tags = $contig->getTags()) {
        my $total = scalar(@$tags);
        $logger->warning("contig $contig_id inherited $total tags (total) from parent(s) @pidlist",skip=>1);
        foreach my $tag (@$tags) {
            next unless ($tag->getType() eq $tagtype);
            $logger->warning($tag->writeToCaf());
        }
        if ($confirm) {
            my $addedtagcount = $adb->putTagsForContig($contig);
            $logger->warning("$addedtagcount tags loaded for contig $contig_id");

	}
	else {
            my $newtagcount = $adb->enterTagsForContig($contig);
            $logger->warning("contig $contig_id has $newtagcount new tags");
	}
    }
    else {
        $logger->warning("contig $contig_id has NO inherited tags");
    }
   
    $contig->erase(); # remove all self references prepare for garbage collection
    undef $contig;
}

exit;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------
 
sub getNamesFromFile {
    my $file = shift; # file name
 
    &showUsage("File $file does not exist") unless (-e $file);
 
    my $FILE = new FileHandle($file,"r");
 
    &showUsage("Can't access $file for reading") unless $FILE;
 
    my @list;
    while (defined (my $name = <$FILE>)) {
        last unless ($name =~ /\S/);
        $name =~ s/^\s+|\s+$//g;
        $name =~ s/.*\scontig\s+(\d+)\s.*/$1/;
        push @list, $name;
    }
 
    return [@list];
}

sub showtagsoncontig {
    my $contig = shift;
    my $align = shift;

    my $tags = $contig->getTags();
    my $consensus = $contig->getSequence();

    foreach my $tag (@$tags) {
        $logger->warning($tag->writeToCaf());
        my @position = $tag->getPosition();
        my $start = $position[0] - 1;
        my $length = $position[1] - $position[0] + 1;
        my $tagsequence = substr $consensus, $start, $length;
        if ($align && $align < 0) {
            $tagsequence = reverse($tagsequence);
            $tagsequence =~ tr/ACGTacgt/tgcatgca/;
	}
        $logger->warning($tagsequence,skip=>1);
    }
}
 
#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------
#rc/reversecontig

sub showUsage {
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "Test contig to parent links using common reads; propagate tags\n";
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID, comma-separated list of IDs, 'current' or 'range'\n";
    print STDERR "\t\tWhen using 'range' specify -begin and -final or -block\n";
    print STDERR "-fofn\t\tfile with list of contig IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-strong\t\t(no value) find links using common reads having identical read mappings\n";
    print STDERR "\n";
    print STDERR "-next\t\tnumber of contigs to be tested from given contig\n";
    print STDERR "-begin\t\twith '-range': first contig_id to be used (default 1)\n";
    print STDERR "-final\t\twith '-range':  last contig_id to be used\n";
    print STDERR "-block\t\twith '-range': number of ids after '-begin' to be used\n";
    print STDERR "\n";
    print STDERR "-filter\t\t(pidf;parent-identifier-filter) select parent contig ID(s) to be tested\n";
    print STDERR "\n";
    print STDERR "-nosync\t\t(nosynchronize) do not remove mappings in the database which\n";
    print STDERR "\t\t do not correspond to the links found; default synchronize\n";
    print STDERR "-force\t\t(no value) force installation of the links\n";
    print STDERR "\n";
    print STDERR "-it\t\t(inherittags) propagate tags of the tag type specified\n";
    print STDERR "\n";
    print STDERR "-confirm\t(-commit) do the change(s) to mappings and/or tags\n";
    print STDERR "-cleanup\t(no value) cleanup of segments database \n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for testing:\n";
    print STDERR "\n";
    print STDERR "-preview\n";
    print STDERR "\n";
    print STDERR "-st\t\t(showtags) show tag sequence on both the contig and its parent(s)\n";
    print STDERR "-str\t\t as for '-st' but in reverse complement\n";
    print STDERR "\n";
    print STDERR "-rc\t\t(reversecontig) reverse the input contig\n";
    print STDERR "-rp\t\t(reverseparent) reverse the parent contig(s)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
