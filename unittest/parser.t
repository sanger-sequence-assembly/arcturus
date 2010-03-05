#!/software/bin/perl

use strict;

use warnings;

use Test::More 'no_plan';

use ContigFactory::ContigFactory;

# we test Regular Mappings, Canonical Mappings and Segments

my $caffilename = shift @ARGV || 'Missing CAF file name';

my $modify = shift @ARGV || 0; # new readversion simulation (one in $modify reads)

# read a selection of test contigs from a file using the contig loader

my $inventory = ContigFactory->buildInventory($caffilename);

ok (defined($inventory),"Making an inventory of $caffilename");
exit unless $inventory;

# make a list of contigs in the inventory

my $contigname_arrayref = ContigFactory->getContigNames() || [];

my $nc = scalar(@$contigname_arrayref);

ok ($nc > 0,"There should be at least one contig in the inventory ($nc)");

# make a list of reads in the inventory

my $readname_arrayref = ContigFactory->getReadNames() || [];

my $nr = scalar(@$readname_arrayref);

ok ($nr > 0,"There should be at least one read in the inventory ($nr)");

ok ($nr >= $nc,"There should be at least as many reads as contigs in the inventory ($nc,$nr)");

my $readversionhash = &buildversionhashstub($contigname_arrayref,$modify);
# calculate the expected number of modified reads, i.e. new version reads
my $modified = 0;
$modified = int(scalar(@$readname_arrayref)/$modify) if $modify;

my $rvhsize = scalar(keys %$readversionhash);

ok ($nr == $rvhsize,"read version hash stub should have $nr entries ($rvhsize)");

#&showreadinventory($contigname_arrayref);

my $newreadversion = ContigFactory->putReadSequenceIDs($readversionhash);
my $nv = scalar(@$newreadversion); # number of new version reads

ok ($modified == $nv,"number of reads with new sequence versions should be $modified ($nv)");

#&showreadinventory($contigname_arrayref);

if ($nv) {
# mimic entering new versions into database
    my $readversionhash = &buildversionhashstub($newreadversion,0,100000); 
    my $leftover = ContigFactory->putReadSequenceIDs($readversionhash);
    my $left = scalar(@$leftover);
    ok ($left == 0,"no reads should remain with new sequence versions (0)");
#    &showreadinventory($contigname_arrayref);
}

# now test the extracted mappings when extracting contigs using no reads

foreach my $contigname (@$contigname_arrayref) {
    foreach my $addreads (0,1) {
        my $contig = ContigFactory->extractContig($contigname,0,addreads=>$addreads);
        ok (ref($contig) eq 'Contig',"extractContig should return a Contig instance ($contig)");
# test read count
        my $reads = $contig->getReads() || [];
        my $nrofreads = scalar(@$reads);
        ok ($nrofreads == 0,"returned contig should have no reads ($nrofreads)") unless $addreads; 
        ok ($nrofreads > 0,"returned contig should have at least one read ($nrofreads)") if $addreads;
# test mappings
        my $mappings = $contig->getMappings() || []; 
        my $nrofmaps = scalar @$mappings;
        ok ($nrofmaps >  0,"returned contig should have at least one mapping ($nrofmaps)");
        ok ($nrofmaps == $nrofreads,"number of mappings should equal number of reads") if $addreads;
# test mapping sequence IDs (should all be defined)
        my ($status,$msg) = &testmappingsequenceids($mappings);
        ok ($status == 0,"all mappings should have unique name and sequence ID defined ($status, $msg)");

        if ($addreads) { # test if mappings and reads tally, i.e. all seq"
            my ($status,$msg) = &testmappingsequenceids($mappings,$reads);
            ok ($status == 0,"all mapping and read names and sequence IDs should match one-to-one ($status, $msg)");
        }
    }
}

exit;

# subscontigname_arrayref

sub buildversionhashstub {
    my $arrayref = shift;
    my $modify = shift;
    my $offset = shift || 10000;

    my @reads;

    if (ref($arrayref->[0]) ne 'Read') {
        foreach my $contigname (@$arrayref) {
            my $contig = ContigFactory->extractContig($contigname,0,addreads=>1);
            my $reads = $contig->getReads() || next;
            push @reads,@$reads;
	}
    }
    elsif (ref($arrayref->[0]) eq 'Read') {
        @reads = @$arrayref;
    }
    else {
	print STDERR "$arrayref\n";
	print STDERR "@$arrayref\n";
    }

    my $readversionhash = {};

    my $i = 0;
    foreach my $read (@reads) {
        $i++;
        my $readname = $read->getReadName();
        $readversionhash->{$readname} = [];
        $readversionhash->{$readname}->[0] = {};
        my $seq_hash = $read->getSequenceHash();
	my $qual_hash = $read->getBaseQualityHash();
        if ($modify && $i%$modify == 0) {
	    print STDERR "changing readversion $readname ($i)\n";
            chop $seq_hash;
            chop $qual_hash;
	}
        $readversionhash->{$readname}->[0]->{seq_hash}  = $seq_hash;
        $readversionhash->{$readname}->[0]->{qual_hash} = $qual_hash;
        $readversionhash->{$readname}->[0]->{read_id} = $i;
        $readversionhash->{$readname}->[0]->{seq_id} = $offset+$i;
    }  
    return $readversionhash;
}

sub showreadinventory {
    my $contigname_arrayref = shift;

    my @reads;
    foreach my $contigname (@$contigname_arrayref) {
	my $report = ContigFactory->listInventoryForObject($contigname);
        print STDOUT "$report\n";
        my $contig = ContigFactory->extractContig($contigname,0,addreads=>1);
        my $reads = $contig->getReads() || next;
        push @reads,@$reads;
    }

    foreach my $read (@reads) {
	my $readname = $read->getReadName();
	my $report = ContigFactory->listInventoryForObject($readname);
        print STDOUT "$report\n";
    }  
}

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

sub testmappingsequenceids {
# test if all mappings have a unique name, and if all have a unique sequence ID
    my $mappings = shift;
    my $reads = shift; # optional

    return -1,'not passed and array' unless (ref($mappings) eq 'ARRAY'); 

    my $nmissing = 0;
    my $smissing = 0;
    my $nreport = '';
    my $sreport = '';
    my $duplicates = 0;
    my $readnamehash = {};
    my $sequencehash = {};
    foreach my $mapping (@$mappings) {
        return -2,'not (Regular)Mapping instance: '.(ref($mapping) || $mapping) 
          unless (ref($mapping) eq 'Mapping' || ref($mapping) eq 'RegularMapping');
        my $readname = $mapping->getMappingName();
        if (!$readname) {
            $nmissing++;
	}
        elsif ($readnamehash->{$readname}++) {
            $nreport = "duplicated readnames " unless $nreport;
	    $nreport .= "$readname ";
	    $duplicates++;
	}
        my $seq_id   = $mapping->getSequenceID();
        if (!$seq_id) {
            $smissing++;
	}
        elsif ($sequencehash->{$seq_id}++) {
            $sreport = "duplicated sequence IDs " unless $sreport;
	    $sreport .= "$seq_id ";
	    $duplicates++;
        }            
    }

    my $report = '';
    $report .= "$nmissing missing mapping names " if $nmissing;
    $report .= "$smissing missing sequence IDs "  if $smissing;
    $report .= $nreport if $nreport;
    $report .= $sreport if $sreport;

    my $problems = $nmissing+$smissing+$duplicates;
    return $problems,$report if ($problems || $report);

    return 0,'OK' unless $reads;

# check that the readnames and sequence IDs match those of the mappings

    return -1,'not passed and array' unless (ref($reads) eq 'ARRAY'); 

    foreach my $read (@$reads) {
        return -3,'not returned Read instances: '.(ref($read) || $read)
            unless (ref($read) eq 'Read');
        my $readname = $read->getReadName() || 'undef';
        my $seq_id = $read->getSequenceID() || 'undef';
        $readnamehash->{$readname}--;
        $sequencehash->{$seq_id}--; 
    }

# all hash entries should be 0

    my $ereadname = 0;
    foreach my $readname (keys %$readnamehash) {
        $ereadname++ if $readnamehash->{$readname};
    }
    my $esequence = 0;
    foreach my $sequence (keys %$sequencehash) {
        $esequence++ if $sequencehash->{$sequence};
    }

    $problems = $ereadname + $esequence;
    $report .= "$ereadname errors " if $ereadname;
    $report .= "$esequence errors " if $esequence;
    $report .= "when comparing reads and mapping" if $report;

    return $problems,$report if $problems;

    return 0, 'OK';
}
