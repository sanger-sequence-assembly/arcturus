#!/software/bin/perl

use strict;

use warnings;

use RegularMapping;

use MappingFactory::MappingFactory;

use Test::More tests=>19;

# we test Regular Mappings, Canonical Mappings and Segments

# first we do some tests no using the internal caching system

# test 1: build an example mappingmy @returns;

my @segmentlist;
push @segmentlist,[( 737,1414,124,801)];
push @segmentlist,[(1417,1430,802,815)];
push @segmentlist,[(1432,1440,816,824)];
push @segmentlist,[(1442,1448,825,831)];
push @segmentlist,[(1450,1455,832,837)];
push @segmentlist,[(1457,1464,838,845)];

my $mapping = new RegularMapping(); 
ok (ref($mapping) ne 'RegularMapping' , "Constructor fails as expected and returns $mapping: "
                                      . MappingFactory->getStatus());

$mapping = new RegularMapping(empty=>1); 
ok (ref($mapping) ne 'RegularMapping' , "Constructor fails as expected and returns $mapping: "
                                      . MappingFactory->getStatus());

$mapping = new RegularMapping(undef,empty=>1); 
ok (ref($mapping) eq 'RegularMapping' , "Constructor succeeds as expected and returns $mapping: "
                                      . MappingFactory->getStatus());

$mapping = new RegularMapping(@segmentlist);
ok (ref($mapping) ne 'RegularMapping' , "Constructor fails as expected and returns $mapping: "
                                      . MappingFactory->getStatus());

$mapping = new RegularMapping(\@segmentlist);
ok (ref($mapping) eq 'RegularMapping' , "Constructor succeeds as expected and returns $mapping");

# now modify the list to introduce errors

undef @segmentlist;
push @segmentlist,[( 737,1414,124,801)];
push @segmentlist,[(1417,1430,802,815)];
push @segmentlist,[(1432,1440,816,824)];
push @segmentlist,[(1442,1448,825,831)];
push @segmentlist,[(1442,1448,831,825)]; # test alignment direction
push @segmentlist,[(1450,1455,832,837)];
push @segmentlist,[(1457,1464,838,845)];

$mapping = new RegularMapping(\@segmentlist);
ok (ref($mapping) ne 'RegularMapping' , "Constructor fails as expected and returns $mapping: "
                                      . MappingFactory->getStatus());


undef @segmentlist;
push @segmentlist,[( 737,1414,124,801)];
push @segmentlist,[(1417,1430,802,815)];
push @segmentlist,[(1432,1440,816,824)];
push @segmentlist,[(1442,1448,825,831)];
push @segmentlist,[(1448,1448,831,831)]; # test alignment overlap
push @segmentlist,[(1450,1455,832,837)];
push @segmentlist,[(1457,1464,838,845)];

$mapping = new RegularMapping(\@segmentlist);
ok (ref($mapping) ne 'RegularMapping' , "Constructor fails as expected and returns $mapping: "
                                      . MappingFactory->getStatus());

undef @segmentlist;
push @segmentlist,[( 737,1414,124,801)];
push @segmentlist,[(1417,1430,802,815)];
push @segmentlist,[(1432,1440,816,824)];
push @segmentlist,[(1442,1448,825,831)];
push @segmentlist,[(1450,1455,832,837)];
push @segmentlist,[(1457,1464,838,845)];
push @segmentlist,[(1465,1469,846,850)]; # test collate

$mapping = new RegularMapping(\@segmentlist);
ok (ref($mapping) eq 'RegularMapping' , "Constructor succeeds as expected and returns $mapping");

# probe the number of segments

my $nrofsegments = $mapping->hasSegments();
ok ($nrofsegments == 6 , "Number of segments should be 6 ($nrofsegments)");

# probe the cache and disable it

my $cachesize = $mapping->getCanonicalMapping->cache();
ok ($cachesize == 3, "cache size should be 3 ($cachesize)");

# testing inverse (11 ....

undef my @forward;
push @forward,[(933,722, 61,272)];  
push @forward,[(720,522,273,471)];
push @forward,[(520,339,472,653)];
my $mforward = new RegularMapping(\@forward);

undef my @reverse;
push @reverse,[reverse(933,722, 61,272)];  
push @reverse,[reverse(720,522,273,471)];
push @reverse,[reverse(520,339,472,653)];
my $mreverse = new RegularMapping(\@reverse);

my $minverse = $mreverse->inverse();
my @isequal = $mforward->isEqual($minverse);
ok ($isequal[0], "default caching inverse comparison should detect identity @isequal"); 

# probe the cache and disable it

$cachesize = $mapping->getCanonicalMapping->cache();
ok ($cachesize == 5, "cache size should be 5 ($cachesize)");
$cachesize = $mapping->getCanonicalMapping->cache(disable=>1,reset=>1);

# repeat inverse test without cache

$mreverse = new RegularMapping(\@reverse);

$minverse = $mreverse->inverse();
@isequal = $mforward->isEqual($minverse,full=>1);
ok (!$isequal[0], "full inverse comparison should fail 0 (@isequal)"); 

# test the shifted mapping (14 ....

my $shift = 100;
my $mshifted = $mforward->copy();
$mshifted->applyShiftToContigPosition($shift);
@isequal = $mshifted->isEqual($mforward);
my $success = &isequal([@isequal],[(1,1,100)]);
ok ($success, "shifted mappings should be equal 1 1 $shift (@isequal)");

# generate a shifted mapping not using the shift function

$nrofsegments = $mforward->hasSegments();
undef my @reference;
foreach my $n (1 .. $nrofsegments) {
    my @segment = $mforward->getSegment($n);
    $segment[0] += $shift;
    $segment[1] += $shift;
    push @reference,[@segment];
}  
my $mreference = new RegularMapping(\@reference);

@isequal = $mreference->isEqual($mshifted,full=>0);
$success = &isequal([@isequal],[(1,1,0)]);
ok ($success, "mappings should be default equal 1 1 0 (@isequal)");

@isequal = $mreference->isEqual($mshifted,full=>1);
$success = &isequal([@isequal],[(1,1,0)]);
ok (!$success, "mappings should be not equal on full comparison 0 (@isequal)");


# test the mirrored mapping (17 ....

my $mirror = 1000;
my $mmirrored = $mforward->copy();
$mmirrored->applyMirrorTransform($mirror);
@isequal = $mmirrored->isEqual($mforward);
$success = &isequal([@isequal],[(1,-1,1000)]);
ok ($success, "mirrored mappings should be equal 1 -1 $mirror (@isequal)");

# generate a mirrored reference mapping not using the mirror function

$nrofsegments = $mforward->hasSegments();
undef @reference;
foreach my $n (1 .. $nrofsegments) {
    my @segment = $mforward->getSegment($n);
    $segment[0] = $mirror - $segment[0];
    $segment[1] = $mirror - $segment[1];
    push @reference,[@segment];
}  
$mreference = new RegularMapping(\@reference);
# test the reference against the mirrored mapping
@isequal = $mreference->isEqual($mmirrored,full=>0);
$success = &isequal([@isequal],[(1,1,0)]);
ok ($success, "mirrored and reference mappings should be identical 1 1 0 (@isequal)");

@isequal = $mreference->isEqual($mmirrored,full=>1);
$success = &isequal([@isequal],[(1,1,0)]);
ok (!$success, "mappings should be not equal on full comparison 0 (@isequal)");

# testing multiplication (20 ....
# test transformations using multiplication machinery


exit;

# subs

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
