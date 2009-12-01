#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex);

use DataSource;

my $instance;
my $organism;

my $seqid;
my $limit;

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $limit         = shift @ARGV if ($nextword eq '-limit');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => { RaiseError => 1, PrintError => 1});

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select contig_id,seq_id,mapping_id,direction from MAPPING order by contig_id asc";

$query .= " limit $limit" if defined($limit);

my $sth_get_mappings = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by rstart asc";

my $sth_get_segments =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select mapping_id from CANONICALMAPPING where checksum = ?";

my $sth_find_canonical_mapping =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into SEQ2CONTIG(contig_id,seq_id,mapping_id,direction,coffset,roffset) value (?,?,?,?,?,?)";

my $sth_insert_seq_to_contig =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CANONICALMAPPING(cspan,rspan,checksum) values (?,?,?)";

my $sth_insert_canonical_mapping =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CANONICALSEGMENT(mapping_id,cstart,rstart,length) values (?,?,?,?)";

my $sth_insert_canonical_segment =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth_get_mappings->execute();

while (my ($contigid,$seqid,$mappingid,$direction) = $sth_get_mappings->fetchrow_array()) {
    #print "Contig $contigid (mapping $mappingid) $direction\n\n";

    my $forward = $direction eq 'Forward';

    my $dirn = $forward ? 'F' : 'R';

    $sth_get_segments->execute($mappingid);

    my $coffset = undef;
    my $roffset = undef;

    my @segments;

    #print "OLD SCHEMA\n\n";

    #printf "%8s %8s %8s\n","cstart","rstart","length";
    #print "-------- -------- --------\n";

    while (my ($cstart,$rstart,$seglen) = $sth_get_segments->fetchrow_array()) {
	#printf "%8d %8d %8d\n", $cstart, $rstart, $seglen;

	($cstart,$rstart) = ($cstart+$seglen-1, $rstart-$seglen+1) unless $forward;	

	push @segments, [$cstart,$rstart,$seglen];
    }

    #print "\n";

    my ($cs0, $rs0, $dummy) = @{$segments[0]};

    my $coffset = $forward ? $cs0 - 1 : $cs0 + 1;
    my $roffset = $rs0 - 1;

    #print "NEW SCHEMA\n\n";

    #print "coffset = $coffset\nroffset = $roffset\n\n";

    #printf "%8s %8s %8s\n","cstart","rstart","length";
    #print "-------- -------- --------\n";

    my $signature = '';

    foreach my $segment (@segments) {
	my ($cstart,$rstart,$seglen) = @{$segment};
	
	my $czero = $forward ? $cstart - $coffset : $coffset - $cstart;
	my $rzero = $rstart - $roffset;

	#printf "%8d %8d %8d\n", $czero, $rzero, $seglen;

	$signature .= ':' if ($cstart != $cs0);

	$signature .= "$czero,$rzero,$seglen";
    }

    my $cspan = 0;
    my $rspan = 0;

    my $sighash_hex = md5_hex($signature);

    #print "\nHash is $sighash\n";
    #print "\n-----------------------------------------\n\n";

    printf "%8d %8d %8d %8d %1s %32s %s\n",$contigid,$seqid,$coffset,$roffset,$dirn,$sighash_hex,$signature;

    my $sighash = md5($signature);

    $dbh->begin_work();

    $sth_find_canonical_mapping->execute($sighash);

    my ($new_mapping_id) = $sth_find_canonical_mapping->fetchrow_array();

    unless (defined($new_mapping_id)) {
	$sth_insert_canonical_mapping->execute($cspan, $rspan, $sighash);

	$new_mapping_id = $dbh->{'mysql_insertid'};

	foreach my $segment (@segments) {
	    my ($cstart,$rstart,$seglen) = @{$segment};
	    $sth_insert_canonical_segment->execute($new_mapping_id, $cstart, $rstart, $seglen );
	}
    }

    $sth_insert_seq_to_contig->execute($contigid, $seqid, $new_mapping_id, $direction, $coffset, $roffset);

    $dbh->commit();
}

$sth_get_mappings->finish();
$sth_get_segments->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-limit\t\tShow only the first N contigs\n";
}
