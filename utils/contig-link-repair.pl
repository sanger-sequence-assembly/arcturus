#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use TagFactory::TagFactory;

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
my $bridge;

my $reverse; # test mode
my $tagtype;
my $showtag;
my $tagfilter;
my $mappingdetails;

my $validKeys  = "organism|instance|contig|begin|final|block|fofn|pidf|filter|next|"
               . "cleanup|reversecontig|rc|reverseparent|rp|preview|nosynchronize|nosync|"
               . "tf|tagfilter|inherittags|it|showtags|st|showtagsreversed|str|inspect|"
               . "strong|force|bridge|log|confirm|commit|verbose|info|debug|help";

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

    $bridge    = 1            if ($nextword eq '-bridge');

    $force     = 1            if ($nextword eq '-force');

    $begin     = shift @ARGV  if ($nextword eq '-begin');

    $final     = shift @ARGV  if ($nextword eq '-final');

    $block     = shift @ARGV  if ($nextword eq '-block');

    $cleanup   = 1            if ($nextword eq '-cleanup');

    $reverse   = 1            if ($nextword eq '-rp'  || $nextword eq '-reverseparent');
    $reverse   = 2            if ($nextword eq '-rc'  || $nextword eq '-reversecontig');

    $tagtype   = shift @ARGV  if ($nextword eq '-it'  || $nextword eq '-inherit');
 
    $showtag   = 1            if ($nextword eq '-st'  || $nextword eq '-showtags');

    $showtag   = -1           if ($nextword eq '-str' || $nextword eq '-showtagreverse'); # for reverse

    $tagfilter = shift @ARGV  if ($nextword eq '-tf'  || $nextword eq '-tagfilter');

    if ($nextword eq '-nosync' || $nextword eq '-nosynchronize') {
        $synchronize  = 0;
    }       

    $mappingdetails  = 1      if ($nextword eq '-inspect');

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
 
TagFactory->setLogger($logger); 
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig ID") unless ($contig || $fofn);

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

$adb->setLogger($logger);

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
elsif ($contig eq 'range') {
    $begin = 1 unless defined $begin;
    $block = $final - $begin + 1 if defined($final);
    $block = 1 unless defined $block;
    my $final = $begin + $block - 1;
    $logger->warning("contig range to be used $begin - $final");
    @contigs = ($begin .. $final);
}
elsif ($contig eq 'currentrange' || $contig eq 'current') {
    my $cc = $adb->getCurrentContigIDs();
    @contigs = @$cc if $cc;
    if ($contig eq 'currentrange') {
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

    $contig->addContigToContigMapping(0); # erase any existing C2CMappings

    $contig->addTag(0); # remove existing tags (just in case)

    unless ($contig->hasReads(1)) { # load reads only (needed to link contig)
	$logger->warning("No reads found for contig $contig_id");
	next;
    }

    my $creads = $contig->getNumberOfReads();

    unless ($contig->hasMappings(1)) { # load read mappings only
	$logger->warning("No read mappings found for contig $contig_id");
	next;
    }

# get the parent IDs from a database search

    my %loptions;
    $loptions{parentfilter} = $filter if $filter; # specifically include this one
    my $linked = $adb->getParentIDsForContig($contig,%loptions); # exclude self

    unless ($linked && @$linked) {
# can't do this unless getParentIDsForReadsInContig is amended to deal with other generations
#        $logger->debug("No parent contigs found using reads for contig $contig_id");
#        $linked = $adb->getParentIDsForReadsInContig($contig);
#        unless ($linked && @$linked) {
#   	    $logger->warning("No parent contigs found for contig $contig_id");
#  	    next;
#	}
        $logger->info("No parents found for contig $contig_id");
        next if ($contig->getNumberOfReads() > 1);
    }

    $logger->debug("Parents @$linked found using mappings for contig $contig_id");

# replace the parent ID by the parent Contig instance

    my @pidlist;
    my @rejectids; # for spurious links

    my @selected;
    my $parentid_hash = {};
    my $chainrepair = [];
    foreach my $parentid (@$linked) {
        next if (!$bridge && $filter && $parentid !~ /$filter/);
	$logger->info("Loading parent $parentid");
        my $parent = $adb->getContig(contig_id=>$parentid,metadataonly=>1);
        unless (ref($parent) eq 'Contig') {
            $logger->error("Contig $parentid not retrieved");
	    next;
	}
        if ($bridge && $parent->getNumberOfReads() == 1) {
            my $grandparent_arrayref = $parent->getParentContigs(1);
            if ($grandparent_arrayref && @$grandparent_arrayref) {
                my $ireads = $parent->getNumberOfReads();
                my %chainrepair = ($contig_id=>$creads , $parentid=>$ireads);
                $parent = $grandparent_arrayref->[0];
  	        my $parent_id = $parent->getContigID();
                $logger->warning("grandparent $parent_id accepted as parent");
                my $preads = $parent->getNumberOfReads();
                $chainrepair{$parent_id} = $parent->getNumberOfReads();
                push @$chainrepair,\%chainrepair;
	    }
        }
	my $parent_id = $parent->getContigID();
        next if ($filter && $parent_id !~ /$filter/);
        $logger->warning("contig $parent_id accepted as parent for $contig_id");

        push @selected,$parent if $parent;
    }

# test the link for each of the parents, determine the mapping from scratch

    foreach my $parent (@selected) {
#---
        my $pid = $parent->getContigID();

        $logger->warning("\nTesting against parent ".$parent->getContigName);

        $parent->getMappings(1); # load mappings

        if ($reverse) {
            $parent->reverse(nonew=>1,complete=>1) if ($reverse == 1);
            $contig->reverse(nonew=>1,complete=>1) if ($reverse == 2);
        }

#        my ($segments,readsincommon,$dealloc) = $contig->linkToContig($parent,
        my ($segments,$dealloc) = $contig->linkToContig($parent,
                                                        forcelink => $force,
                                                        strong => $strong);
        $logger->warning("de-alloacted $dealloc reads from ".$parent->getContigName());

        $parent->addRead(0);    # remove reads
        $parent->addMapping(0); # and read mappings

        next if $reverse; # skip tag testing

        unless ($segments) {
            my $previous = $parent->getContigName();
            $logger->warning("empty/spurious link detected to $previous");
next;
            push @rejectids, $parent->getContigID();
            my $exclude = join ',',@rejectids;
# determine if any new contig ids are added to the list
            my $parentidhash = {};
            foreach my $contig (@selected) {
                unless (ref($contig) eq 'Contig') {
#                    $logger->error("undefined parent 2 ".($contig||'undef'));
	            next;
                }

                next unless (ref($contig) eq 'Contig');
                my $pid = $contig->getContigID();
                $parentidhash->{$pid}++;
	    }
# find the newly added parent IDs, if any, which do not occur in the parent ID hash
            unless ($filter) {
                my $newids = $adb->getParentIDsForContig($contig,exclude=>$exclude);
                foreach my $pid (@$newids) {
                    next if $parentidhash->{$pid}; # already in list
	            $logger->warning("Loading new parent $pid");
                    my $contig = $adb->getContig(contig_id=>$pid);
                    my $preads = $contig->getNumberOfReads();
                    print STDERR "Contig $pid not retrieved\n" unless $contig;
                    push @$linked,$contig if $contig;
		}
            }
            next;
        }
 
        my $length = $parent->getConsensusLength();
 
        $logger->warning("number of mapping segments = $segments ($length)");

# test section to inherit tags

        if ($tagtype) {
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
                    $logger->warning("NO tags inherited from parent $pid");
	        }
	    }
            if ($showtag) {
                my %toptions;
		$toptions{filter} = $tagfilter if $tagfilter;
                &showtagsoncontig($parent,%toptions);
                $toptions{align} = $showtag;
                &showtagsoncontig($contig,%toptions);
                $contig->addTag(0); # erase existing tags for test purposes 
	    }
	}
        $parent->erase(); # remove all self references prepare for garbage collection
        undef $parent;
    }

# mapping summary

    if ($contig->hasContigToContigMappings) {

        $logger->warning("summary of parents for contig $contig_id");

        my $ccm = $contig->getContigToContigMappings();

        my $length = $contig->getConsensusLength();

        $logger->warning("number of mappings : ".scalar(@$ccm)." ($length)");
    }

    if ($mappingdetails) {

        my $ccm = $contig->getContigToContigMappings();

        my $contigconsensus = $contig->getSequence();

        foreach my $mapping (@$ccm) {
	    $mapping->normaliseOnX();
            $logger->info($mapping->toString);
            my $parent_id = $mapping->getSequenceID();
            my $parentcontig = $adb->getContig(contig_id=>$parent_id,metadataonly=>1);
            my $parentconsensus = $parentcontig->getSequence();
            my $segments = $mapping->getSegments();
	    my $alignment = $mapping->getAlignment();
            my ($contigsequence,$parentsequence);
            my $discordantsegments = 0;
            foreach my $segment (@$segments) {
                my @segment = $segment->getSegment();
                my $length = $segment->getSegmentLength();
                $contigsequence = substr $contigconsensus, $segment[0]-1, $length;
                if ($alignment > 0) {
                    $parentsequence = substr $parentconsensus, $segment[2]-1, $length;
		}
		else {
                    $parentsequence = reverse substr $parentconsensus, $segment[3]-1, $length;
                    $parentsequence =~ tr/ACGTacgt/TGCAtgca/;
		}
                next if ($contigsequence eq $parentsequence);
		$discordantsegments++;
                $logger->warning("parent sequence :\n$parentsequence");
                $logger->warning("mapped sequence :\n$contigsequence",skip=>1);
            }
            $logger->warning("$discordantsegments discordant segments out of "
                            .scalar(@$segments)." for parent $parent_id",skip=>2);            
        }
    }

    $logger->info("comparing with mappings in database",ss=>1);

    my ($s,$m)= $adb->repairContigToContigMappings($contig,
                                                   synchronize=>$synchronize,
                                                   synchronizeparent=>$filter,
                                                   cleanup=>$cleanup,
                                                   confirm=>$confirm);
    $logger->warning($m);

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
    my %options = @_;

    my $align = $options{align};

    my $filter = $options{filter};

    my $tags = $contig->getTags();
    my $consensus = $contig->getSequence();

    foreach my $tag (@$tags) {
        my $string = $tag->writeToCaf();
        chomp $string;
        next unless (!$filter || $string =~ /$filter/);
        $string .= " on strand ".$tag->getStrand();
        $logger->warning($string);
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
#    print STDERR "-spf\t\t(simpleparentfilter) relax selection of parent(s)\n";
    print STDERR "\n";
    print STDERR "-nosync\t\t(nosynchronize) do not remove mappings in the database which\n";
    print STDERR "\t\t do not correspond to the links found; default synchronize\n";
    print STDERR "-force\t\t(no value) force installation of the links\n";
    print STDERR "-bridge\t\t(no value) bridge links by single-read contig to find earlier parent\n";
    print STDERR "\n";
    print STDERR "-it\t\t(inherittags) propagate tags of the tag type specified\n";
    print STDERR "\n";
    print STDERR "-confirm\t(-commit) do the change(s) to mappings and/or tags\n";
    print STDERR "-cleanup\t(no value) cleanup of segments database \n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for testing:\n";
    print STDERR "\n";
    print STDERR "-preview\tas it says\n";
    print STDERR "-inspect\tshow the sequence of parent and contig in mapping segments\n";
    print STDERR "\n";
    print STDERR "-st\t\t(showtags) show tag sequence on both the contig and its parent(s)\n";
    print STDERR "-str\t\t as for '-st' but in reverse complement\n";
    print STDERR "-tf\t\t(tagfilter) filter tags on systematic_id or comment\n";
    print STDERR "\n";
    print STDERR "-rc\t\t(reversecontig) reverse the input contig\n";
    print STDERR "-rp\t\t(reverseparent) reverse the parent contig(s)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
