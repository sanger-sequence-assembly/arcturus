#!/software/bin/perl

use strict;

use warnings;

use Test::More 'no_plan';

use ContigFactory::ContigFactory;

# we test Regular Mappings, Canonical Mappings and Segments

my $caffilename = shift @ARGV || 'Missing CAF file name';

# read a selection of test contigs from a file using the contig loader

my $inventory = ContigFactory->buildInventory($caffilename);

ok (defined($inventory),"Making an inventory of $caffilename");
exit unless $inventory;

$inventory = ContigFactory->getInventory();

# make a list of contigs in the inventory

my @inventory = sort keys %$inventory; # better: sort on position in file

my @contignames;
foreach my $objectname (@inventory) {
# ignore non-objects
    my $objectdata = $inventory->{$objectname};
# Read and Contig objects have data store as a hash; if no hash, ignore
    next unless (ref($objectdata) eq 'HASH');

    my $objecttype = $objectdata->{Is};

    push @contignames,$objectname if ($objecttype =~ /contig/);
}

my $nc = scalar(@contignames);

ok ($nc > 0,"There should be at least one contig in the inventory ($nc)");
            
# extract each contig in turn an run a number of tests

foreach my $contigname (@contignames) {
# extract the contig
    my $contig = ContigFactory->extractContig($contigname,0,addreads=>1);
# is it a contig
    ok (ref($contig) eq 'Contig',"ContigFactory should return a Contig");
# does it have reads
    ok ($contig->hasReads(),"Contig should have reads");
# does it have mappings
    ok ($contig->hasMappings(),"Contig should have mappings");
# are they the same (use isValid) for both import and export
    my $reads = $contig->getReads() || [];
    my $mappings = $contig->getMappings() || [];
#    &addSeqIDs($reads,$mappings);
    ok (@$reads == @$mappings,"Number of reads and mappings should be equal");
    ok ($contig->isValid(forimport=>1),'is contig valid for import');
#    ok ($contig->isValid(),'read IDs should not be defined');
# copy and test equality
    my $copy = $contig->copy();
    ok ($copy ne $contig,'copy contig is different instance');
    ok ($copy->isEqual($contig),'copy contig equals original');
# apply shift
    my $shift = 100;
    $mappings = $copy->getMappings();
    foreach my $mapping (@$mappings) {
        $mapping->applyShiftToContigPosition($shift);
    }
    my $isequal = $copy->isEqual($contig);
    ok ($isequal == 1,"copy contig shifted equals original ($isequal)");
# apply mirror
    my $mirrorcontig = $contig->reverse();
    ok ($mirrorcontig ne $contig,'mirror contig is different instance');
    $isequal = $mirrorcontig->isEqual($contig,bidirectional=>1);
    ok ($isequal == -1,"mirror contig equals original ($isequal)");
#    $mirrorcontig->writeToCaf(*STDOUT,noreads=>1);

# build and test a link between contig and copy

    my ($nroflinksegments,$deallocated) = $copy->linkToContig($contig);
    ok ( $nroflinksegments == 1,"number of mapping segments in link should be 1 ($nroflinksegments)");
    ok ( $deallocated == 0,"number of deallocated reads should be 0 ($deallocated)");
#   $contig->writeToCaf(*STDOUT,noreads=>1);
#   $copy->writeToCaf(*STDOUT,noreads=>1);
    my $linkmappings = $copy->getContigToContigMappings() || [];
    ok (@$linkmappings == 1,"number of link mappings should be 1");
    my $link = $linkmappings->[0];
    ok (ref($link) eq 'Mapping',"mapping should be of type 'Mapping'");
# compare link with identity based on contiglength
    my $identity = $link->new();
    my $length = $contig->getConsensusLength();
    $identity->putSegment(1,$length,1,$length);
    my @isequal = $link->isEqual($identity);
    ok(&isequal(\@isequal,[(1,1,$shift)]),"link mapping should be identity shifted by $shift (@isequal)");
    
# build and test a link between contig and inverse

   ($nroflinksegments,$deallocated) = $mirrorcontig->linkToContig($contig);
    ok ( $nroflinksegments == 1,"number of mapping segments in link should be 1 ($nroflinksegments)");
    ok ( $deallocated == 0,"number of deallocated reads should be 0 ($deallocated)");
    $linkmappings = $mirrorcontig->getContigToContigMappings() || [];
    ok (@$linkmappings == 1,"number of link mappings should be 1");
    $link = $linkmappings->[0];
    ok (ref($link) eq 'Mapping',"mapping should be of type 'Mapping'");
# compare link with identity based on contiglength
    @isequal = $link->isEqual($identity);
    $isequal[2] = -$isequal[2]; # compensates for peculiar definition in Segment class
    my $mirror = $length+1;
    ok(&isequal(\@isequal,[(1,-1,$mirror)]),"link mapping should be identity mirrored in $mirror (@isequal)");
    @isequal = $identity->isEqual($link);

#    my $ilink = &tocanonical($identity);
#    my $mlink = &tocanonical($link);
#    @isequal = $mlink->isEqual($ilink);
#    ok(&isequal(\@isequal,[(1,-1,$mirror)]),"link mapping should be identity mirrored in $mirror (@isequal)");

#print STDOUT $link->toString()."\n"; 
}

exit;

# subs

sub addSeqIDs {
    my ($r,$m) = @_;

    @$r = sort {$a->getReadName() cmp $b->getReadName()} @$r;
    @$m = sort {$a->getMappingName() cmp $b->getMappingName()} @$m;

    my $n = @$r;
    foreach my $i (1 .. $n) {
	$r->[$i-1]->setSequenceID($i);
	$m->[$i-1]->setSequenceID($i);
    }
}

sub isequal {
    my $isequal = shift;
    my $reference = shift;

    return 0 unless (@$isequal == @$reference);

    my $n = scalar(@$isequal);
    foreach my $i (1 .. $n) {
#        return 0 unless (defined($isequal->[$i]) && defined($reference->[$i])); 
	return 0 unless ($isequal->[$i-1] == $reference->[$i-1]);
    }
    return 1;
}

use RegularMapping;
use MappingFactory::MappingFactory;

sub tocanonical {
    my $m = shift;

    my @segments;
    my $segments = $m->getSegments();
    foreach my $segment (@$segments) {
	my @segment = $segment->getSegment();
        push @segments,[@segment];
    }
 
    my $c = new RegularMapping(\@segments);
    print MappingFactory->getStatus() unless $c;
    return $c;
}
