#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# test script for contig tag remapping
# runs through contigs of current generation and compares mapped
# from parent contig with originals using raw segments of the
# mapping between parent and contig (i.e. independent of Arcturus
# mapping modules)
#----------------------------------------------------------------

my $organism;
my $instance;

# my ($contig,$begin,$final,$block);

my $verbose;
my $debug;

my $validKeys  = "organism|instance|contig|begin|final|"
               . "verbose|info|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

#    $contig    = shift @ARGV  if ($nextword eq '-contig');

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-info');

    $debug     = 1            if ($nextword eq '-debug');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter($verbose) if defined $verbose; # set reporting level

$logger->setDebugStream('STDOUT',list=>1)   if $debug;
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

#&showUsage("Missing contig ID") unless ($contig || $fofn);

#&showUsage("Missing tagtype") unless $tagtype;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# preparations
#----------------------------------------------------------------

my $dbh = $adb->getConnection();

# prepare the queries used

my $parentcontigquery = "select parent_id,mapping_id,direction,"
                      . "       cstart,cfinish,pstart,pfinish"
                      . "  from C2CMAPPING"
                      . " where contig_id = ?"
                      . " order by cstart";
my $pqsth = $dbh->prepare($parentcontigquery);

my $c2csegmentquery   = "select cstart,pstart,length from C2CSEGMENT"
                      . " where mapping_id = ?"
                      . " order by cstart";
my $sqsth = $dbh->prepare($c2csegmentquery);

my $tagpositionquery  = "select id,parent_id,cstart,cfinal,strand"
                      . "   from TAG2CONTIG"
                      . " where contig_id = ?" 
                      . " order by cstart";
my $tqsth = $dbh->prepare($tagpositionquery);

# get list of current contigs

my $currentcontigids = $adb->getCurrentContigIDs();

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $remaphash = {};

foreach my $contig_id (@$currentcontigids) {

# find the parents with tags 

    $pqsth->execute($contig_id) || &testerror();

    my $parentidhash = {};
    while (my @ary = $pqsth->fetchrow_array()) {
        my $parent_id = shift @ary;
        my $mappingid = shift @ary;
        $parentidhash->{$parent_id} = {} unless $parentidhash->{$parent_id};
        $parentidhash->{$parent_id}->{$mappingid} = [@ary];
    }
    $pqsth->finish();
    unless (keys %$parentidhash) {
        $logger->warning("contig $contig_id has no parents");
        $pqsth->finish();
        next;
    }

# find remapped tags on the contig

    $tqsth->execute($contig_id) || &testerror();

    my $contigtagidhash = {};
    while (my @ary = $tqsth->fetchrow_array()) {
        my $id = shift @ary;
        my $parenttagid = shift @ary;
        next unless $parenttagid; # ignore tags which appear for the first time
        $contigtagidhash->{$parenttagid} = [@ary]; 
    }
    $tqsth->finish();
    unless (keys %$contigtagidhash) {
        $logger->info("contig $contig_id has no remapped tags");
        next;
    }
    $logger->warning("contig $contig_id has remapped tags:".scalar(keys %$contigtagidhash));

# test each parent-mapping combination in turn

    my @parentids = sort {$a <=> $b} keys %$parentidhash;

    foreach my $parent_id (@parentids) {
                    
        $remaphash->{$parent_id} = {} unless $remaphash->{$parent_id};

# get the tags on the parent

        $tqsth->execute($parent_id) || &testerror();

        my $parenttagidhash = {};
        while (my @ary = $tqsth->fetchrow_array()) {
            my $id = shift @ary;
            my $parent_id = shift @ary;
            $parenttagidhash->{$id} = [@ary];
        }
        $tqsth->finish();
        unless (keys %$parenttagidhash) {
            $logger->warning("parent $parent_id has no tags");
            next;
        }
        $logger->warning("parent $parent_id has tags:".scalar(keys %$parenttagidhash));

# for each mapping in turn

        my $mappingidhash = $parentidhash->{$parent_id};
        my @mappingids = sort {$a <=> $b} keys %$mappingidhash;

        foreach my $mapping_id (@mappingids) {

# get the mapping segments

            $sqsth->execute($mapping_id) || &testerror();
            my $alignmentdirection = $mappingidhash->{$mapping_id}->[0] || 0;
            my $alignment = ($alignmentdirection eq 'Forward') ? 1 : -1;
            my $k = ($alignment > 0) ? 0 : 1; # used in interval
            my $segmentlist = [];
            while (my ($cstart,$pstart,$length) = $sqsth->fetchrow_array()) {
                my $cfinish = $cstart + $length;
                my $pfinish = $pstart + $alignment*$length;
                ($pstart,$pfinish) = ($pfinish,$pstart) if ($alignment < 0);
                my @segment = ($cstart,$cfinish,$pstart,$pfinish);
                push @$segmentlist,[@segment];
                $logger->info("mapping segment : @segment");
            }
            $sqsth->finish();
            unless (@$segmentlist) {
                $logger->warning("empty mapping $mapping_id between contigs $contig_id and $parent_id");
                next;
	    }
         
# test each tag on the parent and determine if it has been remapped to this contig
# if so, check the quality of the mapping and register possible problems.
# if not, add the tag as not having been remapped in the remaphash

            foreach my $parenttagid (sort {$a <=> $b} keys %$parenttagidhash) {
# get the tag position on parent           
                my $parenttagdata = $parenttagidhash->{$parenttagid};
                my @parenttagposition = ($parenttagdata->[0],$parenttagdata->[1]);                
# find the corresponding remapped tag on contig
                my $contigtagdata = $contigtagidhash->{$parenttagid};
                unless ($contigtagdata) {
# do not override a previous status setting
		    $logger->info("Tag $parenttagid at @parenttagposition "
                                 ."on parent $parent_id was not remapped");
                    next if defined $remaphash->{$parent_id}->{$parenttagid}; # mapped to another contig
                    $remaphash->{$parent_id}->{$parenttagid} = -1; # set not remapped
# TBC check tag position against mapping range

                    next;
		}
# get the tag position on contig           
                my @contigtagposition = ($contigtagdata->[0],$contigtagdata->[1]);
# check these positions against the mapping segments
		$logger->info("testing tag $parenttagid : on parent @parenttagposition,"
                                                       ." on contig @contigtagposition");

# get the tags on the parent and find segments where the end-points remap
# find the segments at begin and end in the segment list on the parent side
# test if both, one or none of the end points are in a segment;
                
                my $segmenterror = 0;
                my @segmentonparent;
                my @segmentoncontig;
		my $n = scalar(@$segmentlist)-1;
                foreach my $j (0 .. $n) {

                    foreach my $i (0,1) {
                        if ($contigtagposition[$i] >= $segmentlist->[$j]->[0]
                         && $contigtagposition[$i] <= $segmentlist->[$j]->[1]) {
                            if (defined $segmentoncontig[$i]) {
                                $segmenterror++;
			    }
                            $segmentoncontig[$i] = $j;
			}
		    }
                    foreach my $i (0,1) {
                        if ($parenttagposition[$i] >= $segmentlist->[$j]->[2]
                         && $parenttagposition[$i] <= $segmentlist->[$j]->[3]) {
                            if (defined $segmentonparent[$i]) {
                                $segmenterror++;
			    }
                            $segmentonparent[$i] = $j;
			}
		    }
		}
# analyse result 
                unless (defined($segmentoncontig[0]) && defined($segmentoncontig[1])) {
# this condition occurs when the tag is not remapped (both values undefined) 
# or it signals a change of mapping from the one used to remap (only one value undefined)
                    if (defined $remaphash->{$parent_id}->{$parenttagid}) {
# test if the tag was remapped with an earlier mapping
                        next if ($remaphash->{$parent_id}->{$parenttagid} == 0);
                        next if ($remaphash->{$parent_id}->{$parenttagid} <= 3);
		    }

                    if (defined($segmentoncontig[0]) || defined($segmentoncontig[1])) { 
                        $remaphash->{$parent_id}->{$parenttagid} = 10; # change of mapping
		    }
		    else {
                        $remaphash->{$parent_id}->{$parenttagid} = 20; # not remapped at all
		    }
                    next; # tag
                }

                $remaphash->{$parent_id}->{$parenttagid} = 0; # no errors

                if (defined($segmentonparent[0]) && defined($segmentonparent[1])) {
# these should never occur: would indicate mapping to different segment, hence corrupted mapping
                    unless ($segmentoncontig[0] == $segmentonparent[$k]) {
                        $remaphash->{$parent_id}->{$parenttagid} = 20;
		    }
                    unless ($segmentoncontig[1] == $segmentonparent[1-$k]) {
                        $remaphash->{$parent_id}->{$parenttagid} = 20;
		    }
# if no error, the tags are remapped correctly
                }
                elsif (defined($segmentonparent[0])) {
# the tag is truncated, the leading position falls outside the mapping segments
                    $remaphash->{$parent_id}->{$parenttagid} += 1;
		}
                elsif (defined($segmentonparent[1])) {
# the tag is truncated, the traiing position falls outside the mapping segments
                    $remaphash->{$parent_id}->{$parenttagid} += 2;
		}
		$logger->info("Tag error status : $remaphash->{$parent_id}->{$parenttagid}");
	    } # next mapping
	}
    }

#last;
#last unless ($contig_id < 201600);
}

my %status = ( 1 => 'truncated on the left side',
               2 => 'truncated on the right side',
               3 => 'truncated on both sides',
              10 => 'was not remapped (should not occur!)',
              20 => 'in discordant segments; possibly changed contig-parent mapping',
	    '-1' => 'was not remapped, outside mapping range');

foreach my $parent_id (sort {$a <=> $b} keys %$remaphash) {
    my $problemtags = 0;
    my $parenttaghash = $remaphash->{$parent_id};
    my @parenttagids = sort {$a <=> $b} keys %$parenttaghash;
    foreach my $parenttagid (@parenttagids) {
        my $mapstatus = $parenttaghash->{$parenttagid};
        next unless $mapstatus;
        $problemtags++;
    }
    $logger->warning("Problem tags for parent contig $parent_id : $problemtags");
    foreach my $parenttagid (@parenttagids) {
        my $mapstatus = $parenttaghash->{$parenttagid};
        next if ($mapstatus == 0);
        my $status = $status{$mapstatus} || $mapstatus;
        $logger->warning("remap status of tag $parenttagid : $status");
    }
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

sub testerror {
    return unless $DBI::err;
    my $msg = $adb->errorStatus(1);
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit;
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
