#!/usr/local/bin/perl -w

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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

my ($organism,$instance);

my ($contig,$parent);

my ($log,$verbose,$debug);

my ($tagtype,$tagkey);


my $validKeys  = "organism|o|instance|i|"
               . "contig|parent|tagtype|tt|tagkey|tk|"
               . "log|verbose|info|fine|debug|help|h";

while (my $nextword = shift @ARGV) {

    $validKeys =~ s/\|contig// if defined $parent;
    $validKeys =~ s/\|parent// if defined $contig;

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           

    if ($nextword eq '-instance' || $nextword eq '-i') {
        $instance  = shift @ARGV;
# remove key from list to prevent redefinition when used with e.g. a wrapper script
        next;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
        $organism  = shift @ARGV;
# the next statement prevents redefinition when used with e.g. a wrapper script
        next;
    }

    $contig        = shift @ARGV  if ($nextword eq '-contig');

    $parent        = shift @ARGV  if ($nextword eq '-parent');

    if ($nextword eq '-tagtype' || $nextword eq '-tt') {
        $tagtype   = shift @ARGV;
    } 
    if ($nextword eq '-tagkey'  || $nextword eq '-tk') {
        $tagkey    = shift @ARGV;
    } 

    $log           = shift @ARGV  if ($nextword eq '-log');

    $verbose       = 0            if ($nextword eq '-fine');

    $verbose       = 1            if ($nextword eq '-verbose');

    $verbose       = 2            if ($nextword eq '-info');

    $debug         = 1            if ($nextword eq '-debug');

    if ($nextword eq '-help' || $nextword eq '-h') {
        &showUsage(0); 
    }
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter($verbose) if defined $verbose; # set reporting level

$logger->setDebugStream('STDOUT',list=>1) if $debug;

$logger->setSpecialStream($log) if $log; 

$logger->setSpecialStream('STDOUT') unless $log; 

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

# we use the ArcturusDatabase module ONLY to get the database connection
# and contig IDs of the contigs to be tested (default: current contigs)

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# contig selection
#----------------------------------------------------------------

my $contigids = [];
    
if ($contig && lc($contig) ne 'current') {
# single ID or comma-separated list or range(s), or mixture of these
    my @contigids;
    my @cids = split /[\s\,\:]+/,$contig;
    foreach my $contig (@cids) {
        unless ($contig =~ /\-/) {
            push @contigids,$contig;
            next;
        }
# it's a range defined
        my @range = sort {$a <=> $b} split /\-/,$contig;
        if (scalar(@range) > 2) {
            $logger->error("Invalid contig range specification: $contig");
            next;
        }
        push @contigids, ($range[0] .. $range[1]);
    }
# weedout duplicates
    my $contigidhash = {};
    foreach my $contig_id (@contigids) {
        $contigidhash->{$contig_id}++;
    }
    @$contigids = sort {$a <=> $b} keys %$contigidhash;
}
elsif ($parent) {
    my $cidhash = $adb->getRelationsForContigID($parent);
    @$contigids = sort {$a <=> $b} keys %$cidhash;
}
else { # default
    $contigids = $adb->getCurrentContigIDs();
}

#print STDERR "cids: @$contigids\n";# exit;

#----------------------------------------------------------------
# prepare statements
#----------------------------------------------------------------

my $dbh = $adb->getConnection();

# prepare the queries used

my $parentcontigquery = "select parent_id,mapping_id,direction,"
                      . "       cstart,cfinish,pstart,pfinish"
                      . "  from C2CMAPPING"
                      . " where contig_id = ?"
                      . " order by cstart";
my $pq_sth = $dbh->prepare($parentcontigquery);

my $c2csegmentquery   = "select cstart,pstart,length from C2CSEGMENT"
                      . " where mapping_id = ?"
                      . " order by cstart";
my $sq_sth = $dbh->prepare($c2csegmentquery);

my $tagpositionquery;
if ($tagtype || $tagkey) {
# do the join
    $tagpositionquery  = "select id,parent_id,cstart,cfinal,strand,"
                       . "       tagtype,comment,systematic_id,tagcomment"
                       . "  from TAG2CONTIG join CONTIGTAG using (tag_id)"
                       . " where contig_id = ?" 
                       . " order by cstart";
}
else {
# only use TAG2CONTIG
    $tagpositionquery  = "select id,parent_id,cstart,cfinal,strand"
                       . "   from TAG2CONTIG"
                       . " where contig_id = ?" 
                       . " order by cstart";
}
my $tq_sth = $dbh->prepare($tagpositionquery);

# get list of current contigs

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $remaphash = {};

foreach my $contig_id (@$contigids) {

# find the parents with tags 

    $pq_sth->execute($contig_id) || &testerror();

    my $parentidhash = {};
    while (my @ary = $pq_sth->fetchrow_array()) {
        my $parent_id = shift @ary;
        next if ($parent && $parent != $parent_id); # select only parent
        my $mappingid = shift @ary;
        $parentidhash->{$parent_id} = {} unless $parentidhash->{$parent_id};
        $parentidhash->{$parent_id}->{$mappingid} = [@ary];
    }
    $pq_sth->finish();
    unless (keys %$parentidhash) {
        $logger->info("contig $contig_id has no parents");
        $pq_sth->finish();
        next;
    }

# find remapped tags on the contig

    $tq_sth->execute($contig_id) || &testerror();

    my $contigtagidhash = {};
    while (my @ary = $tq_sth->fetchrow_array()) {
        my $id = shift @ary;
        my $parenttagid = shift @ary;
        next unless $parenttagid; # ignore tags which appear for the first time
        $contigtagidhash->{$parenttagid} = [@ary]; 
    }
    $tq_sth->finish();
    unless (keys %$contigtagidhash) {
        $logger->info("contig $contig_id has no remapped tags");
        next;
    }
    $logger->warning("contig $contig_id has remapped tags:"
                    .scalar(keys %$contigtagidhash),preskip=>1);

# test each parent-mapping combination in turn

    my @parentids = sort {$a <=> $b} keys %$parentidhash;

    foreach my $parent_id (@parentids) {
                    
        $remaphash->{$parent_id} = {} unless $remaphash->{$parent_id};

# get the tags on the parent

        $tq_sth->execute($parent_id) || &testerror();

        my $parenttagidhash = {};
        while (my @ary = $tq_sth->fetchrow_array()) {
            my $id = shift @ary;
            my $parent_id = shift @ary;
            if ($tagtype && @ary > 3) {
                next unless ($ary[3] eq $tagtype);
	    }
            if ($tagkey  && @ary > 4) {
                my $accept = 0;
                $accept = 1 if ($ary[4] && $ary[4] =~ /$tagkey/); # test systemtic ID
                $accept = 1 if ($ary[5] && $ary[5] =~ /$tagkey/); # test comment
                $accept = 1 if ($ary[6] && $ary[6] =~ /$tagkey/); # test tagcomment
                next unless $accept;
	    }
            $parenttagidhash->{$id} = [@ary];
        }
        $tq_sth->finish();
        unless (keys %$parenttagidhash) {
            $logger->warning("parent $parent_id has no "
                   .(($tagtype || $tagkey) ? "matching tags" : "tags"));
            next;
        }
        $logger->warning("parent $parent_id has tags:".scalar(keys %$parenttagidhash));

# for each mapping in turn

        my $mappingidhash = $parentidhash->{$parent_id};
        my @mappingids = sort {$a <=> $b} keys %$mappingidhash;

        foreach my $mapping_id (@mappingids) {

# get the mapping segments

            $sq_sth->execute($mapping_id) || &testerror();
            my $alignmentdirection = $mappingidhash->{$mapping_id}->[0] || 0;
            my $alignment = ($alignmentdirection eq 'Forward') ? 1 : -1;
            my $k = ($alignment > 0) ? 0 : 1; # used in interval
            my $segmentlist = [];
            while (my ($cstart,$pstart,$length) = $sq_sth->fetchrow_array()) {
                my $cfinish = $cstart + ($length-1);
                my $pfinish = $pstart + $alignment*($length-1);
                ($pstart,$pfinish) = ($pfinish,$pstart) if ($alignment < 0);
                my @segment = ($cstart,$cfinish,$pstart,$pfinish);
                push @$segmentlist,[@segment];
                $logger->info("mapping segment : @segment");
            }
            $sq_sth->finish();
            unless (@$segmentlist) {
                $logger->warning("empty mapping $mapping_id between contigs $contig_id and $parent_id");
                next;
	    }

            my $mappinglist;

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
                    my $previousstatus = $remaphash->{$parent_id}->{$parenttagid};
                    if (defined($previousstatus)) {
# skip if the tag was earlier found mapped to another contig
                        next if ($previousstatus >= 0 && $previousstatus <= 3);
		    }

                    $remaphash->{$parent_id}->{$parenttagid} = -1; # set to not remapped
# check tag positions against mapping range on parent contig; they may not overlap
                    my $outside = 1;
                    my $mappingranges = $mappingidhash->{$mapping_id};
                    foreach my $position (@parenttagposition) {
                        $outside = 0 if ($position >= $mappingranges->[3]
                                     &&  $position <= $mappingranges->[4]);
		    }
                    foreach my $position ($mappingranges->[3],$mappingranges->[4]) {
                        $outside = 0 if ($position >= $parenttagposition[0]
			     	     &&  $position <= $parenttagposition[1]);
		    }
                    if ($outside) { # the correct situation
                        $logger->info("Tag $parenttagid on parent $parent_id was not remapped",ps=>1);
                        $logger->info("tag range falls outside mapping range :");
	   	        $logger->info("tag (parent) position : @parenttagposition ; mapping "
                                      ."span : $mappingranges->[3] $mappingranges->[4]",skip=>1);
                    }
		    else { # the incorrect situation
                        $logger->special("Tag $parenttagid on parent $parent_id was not remapped",ps=>1);
                        $logger->special("Error! tag range has an overlap with mapping range :");
	   	        $logger->special("tag (parent) position : @parenttagposition ; mapping "
                                        ."span : $mappingranges->[3] $mappingranges->[4]");
                        $logger->special(&listmapping($segmentlist)) unless $mappinglist++;
                        $remaphash->{$parent_id}->{$parenttagid} = -2;
		    }
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

                if ($segmenterror && !$mappinglist++) {
                    $logger->special("Segment errors in parent to contig mapping : $segmenterror");
                    $logger->special("Mapping between parent $parent_id and contig $contig_id:");
                    $logger->special(&listmapping($segmentlist));          
		}

# analyse result; we do a full report here for tags with both contig segments defined  
                unless (defined($segmentoncontig[0]) && defined($segmentoncontig[1])) {
# this condition occurs when the tag is not remapped 
# possible cause can be a change of mapping from the one used to remap the tags 
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
# test the segments on the contig and the parent, they should be identical, if
# not, that would indicate mapping to a different segment, hence corrupted mapping
                    my $isinconsistent;
                    unless ($segmentoncontig[0] == $segmentonparent[$k]) {
                        $logger->special("Inconsistent mapping segment for tag $parenttagid "
			        	."on parent contig $parent_id mapped to $contig_id",ps=>1);
			$logger->special("Mapping segment on contig : $segmentoncontig[0]");
			$logger->special("Mapping segment on parent : $segmentonparent[$k]");
                        $remaphash->{$parent_id}->{$parenttagid} = 20;
                        $isinconsistent++;
		    }
                    unless ($segmentoncontig[1] == $segmentonparent[1-$k]) {
                        $logger->special("Inconsistent mapping segment for tag $parenttagid "
			        	."on parent contig $parent_id mapped to $contig_id",ps=>1);
			$logger->special("Mapping segment on contig : $segmentoncontig[1]");
			$logger->special("Mapping segment on parent : $segmentonparent[1-$k]");
                        $remaphash->{$parent_id}->{$parenttagid} = 20;
                        $isinconsistent++;
		    }
                    if ($isinconsistent) {
                        $logger->special("position of tag on parent $parent_id : @parenttagposition");
                        $logger->special("position of tag on contig $contig_id : @contigtagposition");
                        next if $mappinglist++;
                        $logger->special("Mapping between parent $parent_id and contig $contig_id:");
                        $logger->special(&listmapping($segmentlist));
			next;
		    }
# no error, the tags are remapped correctly in the same segments
# now do the detailed comparison
                    @parenttagposition = reverse @parenttagposition if ($alignment < 0);
                    foreach my $i (0,1) {
                        my $mappingsegment = $segmentlist->[$segmentoncontig[$i]];
                        my $mappedcontigposition = &remap($mappingsegment,$contigtagposition[$i],$alignment);
                        unless ($parenttagposition[$i] == $mappedcontigposition) {
                            $remaphash->{$parent_id}->{$parenttagid} = 4;
                            $logger->special("Inconsistent mapping position for tag $parenttagid "
					    ."on parent contig $parent_id mapped to $contig_id",ps=>1);
                            $logger->special("mapping segment : @$mappingsegment    alignment $alignment");
			    $logger->special("parent position : $parenttagposition[$i]");
			    $logger->special("contig position : $contigtagposition[$i]");
			    $logger->special("mapped position : $mappedcontigposition");
		        }
		    }
		    next;
                }
                elsif (defined($segmentonparent[0])) {
# the tag is truncated, the leading position on parent falls outside the mapping segments
                    $remaphash->{$parent_id}->{$parenttagid} += 1;
# check on tag boundary
                    my $mappingsegment = $segmentlist->[$segmentoncontig[1-$k]]; # 1
                    unless ($contigtagposition[1-$k] == $mappingsegment->[1-$k]) {
                        $logger->special("Inconsistent boundary position (R) for tag $parenttagid "
		       		        ."on parent contig $parent_id mapped to $contig_id",ps=>1);
                        $logger->special("mapping segment : @$mappingsegment    alignment $alignment");
                        $logger->special("tag boundary position $contigtagposition[1-$k]");
$logger->special("k = $k");
                        $logger->special("position on contig : @contigtagposition ",skip=>1);
		    }
		}
                elsif (defined($segmentonparent[1])) {
# the tag is truncated, the traiing position on parent falls outside the mapping segments
                    $remaphash->{$parent_id}->{$parenttagid} += 2;
# check on tag boundary
                    my $mappingsegment = $segmentlist->[$segmentoncontig[$k]]; # 0
                    unless ($contigtagposition[$k] == $mappingsegment->[$k]) {
                        $logger->special("Inconsistent boundary position (L) for tag $parenttagid "
		       		        ."on parent contig $parent_id mapped to $contig_id",ps=>1);
                        $logger->special("mapping segment : @$mappingsegment    alignment $alignment");
                        $logger->special("tag boundary position $contigtagposition[$k]");
$logger->special("k = $k");
                        $logger->special("position on contig : @contigtagposition ",skip=>1);
		    }
		}
# finally check the details of the mapping


		$logger->info("Tag error status : $remaphash->{$parent_id}->{$parenttagid}");
	    } # next mapping
	}
    }

#last;
#last unless ($contig_id < 201600);
}

$dbh->disconnect();

my %status = ( 1 => 'truncated on the right side on parent',
               2 => 'truncated on the  left side on parent',
               3 => 'truncated on both sides',
              10 => 'was not remapped (should not occur!)',
              20 => 'in discordant segments; possibly changed contig-parent mapping',
	    '-1' => 'was not remapped, outside mapping range',
	    '-2' => 'was incorrectly not remapped because stradling mapping range');

my @parentids = sort {$a <=> $b} keys %$remaphash;

$logger->warning("remapped tags tested from ".scalar(@parentids)." parent contigs");

my $totaltags = 0;
my $totalproblemtags = 0;
foreach my $parent_id (@parentids) {
    my $problemtags = 0;
    my $parenttaghash = $remaphash->{$parent_id};
    my @parenttagids = sort {$a <=> $b} keys %$parenttaghash;
    foreach my $parenttagid (@parenttagids) {
        $totaltags++;
        my $mapstatus = $parenttaghash->{$parenttagid};
        next unless $mapstatus; # status 0 for correct mapping
        $problemtags++;
    }
#    $logger->special("Problem tags for parent contig $parent_id : $problemtags");
    next unless $problemtags;
    $totalproblemtags += $problemtags;
    $logger->warning("Problem tags for parent contig $parent_id : $problemtags",preskip=>1);
    foreach my $parenttagid (@parenttagids) {
        my $mapstatus = $parenttaghash->{$parenttagid};
        next if ($mapstatus == 0);
        my $status = $status{$mapstatus} || $mapstatus;
        $logger->warning("remap status of tag $parenttagid : $status");
    }
}

$logger->warning("$totalproblemtags tags (out of $totaltags) had problems",ss=>1);

exit;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub remap {
    my $segment = shift; # array 0-1 contig  2-3 parent
    my $position = shift; # on contig
    my $alignment = shift;

    $position -= $segment->[0];
    return $segment->[2] + $position if ($alignment > 0); 
    return $segment->[3] - $position unless ($alignment > 0); 
}
 
sub testerror {
    return unless $DBI::err;
    my $msg = $adb->errorStatus(1);
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit;
}

sub listmapping {
    my $segments = shift;

    my $string = '';
    foreach my $segment (@$segments) {
        $string .= sprintf("%7d %7d %7d %7d\n",@$segment); 
    }
    return $string;
}
 
#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------
#rc/reversecontig

sub showUsage {
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "Test of tags remapped with Arcturus core system\n";
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID, comma-separated list of IDs, 'current' or 'range'\n";
    print STDERR "-parent\t\tselect just the contig having parent contig with specified ID\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-tt\t\t(tagtype) investigate only tags of the tag type specified\n";
    print STDERR "-tk\t\t(tagkey)  investigate only tags with a matching descriptor\n";
    print STDERR "\n";
    print STDERR "-log\t\tlog file for detailed output\n";
    print STDERR "\n";
    print STDERR "-info\n";
    print STDERR "-verbose\n";
    print STDERR "-debug\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
