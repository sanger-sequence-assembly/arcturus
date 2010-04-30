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

my $query = "select M.contig_id,M.seq_id,M.mapping_id,M.direction" .
    " from MAPPING M left join SEQ2CONTIG SC" .
    " on (M.contig_id = SC.contig_id and M.seq_id = SC.seq_id)" .
    " where SC.mapping_id is null";

$query .= " limit $limit" if defined($limit);

my $sth_get_mappings = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by rstart asc";

my $sth_get_segments = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select mapping_id from CANONICALMAPPING where checksum = ?";

my $sth_find_canonical_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into SEQ2CONTIG(contig_id,seq_id,mapping_id,direction,coffset,roffset) value (?,?,?,?,?,?)";

my $sth_insert_seq_to_contig = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CANONICALMAPPING(cspan,rspan,checksum) values (?,?,?)";

my $sth_insert_canonical_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CANONICALSEGMENT(mapping_id,cstart,rstart,length) values (?,?,?,?)";

my $sth_insert_canonical_segment = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $canonicalmappings = {};

$query = "select mapping_id,checksum from CANONICALMAPPING";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();

while (my ($mappingid, $checksum) = $sth->fetchrow_array()) {
    $canonicalmappings->{$checksum} = $mappingid;
}

$sth->finish();

$sth_get_mappings->execute();

while (my ($contigid,$seqid,$mappingid,$direction) = $sth_get_mappings->fetchrow_array()) {
    my $forward = $direction eq 'Forward';

    my $dirn = $forward ? 'F' : 'R';

    $sth_get_segments->execute($mappingid);

    my $coffset = undef;
    my $roffset = undef;

    my @segments;

    while (my ($cstart,$rstart,$seglen) = $sth_get_segments->fetchrow_array()) {

	($cstart,$rstart) = ($cstart+$seglen-1, $rstart-$seglen+1) unless $forward;	

	push @segments, [$cstart,$rstart,$seglen];
    }

    my ($cs0, $rs0, $dummy) = @{$segments[0]};

    my $coffset = $forward ? $cs0 - 1 : $cs0 + 1;
    my $roffset = $rs0 - 1;

    my $signature = '';

    my $cspan = 0;
    my $rspan = 0;

    foreach my $segment (@segments) {
	my ($cstart,$rstart,$seglen) = @{$segment};
	
	my $czero = $forward ? $cstart - $coffset : $coffset - $cstart;
	my $rzero = $rstart - $roffset;

	$signature .= ':' if ($cstart != $cs0);

	$signature .= "$czero,$rzero,$seglen";

	my $cmax = $czero + $seglen - 1;
	my $rmax = $rzero + $seglen - 1;

	$cspan = $cmax if ($cmax > $cspan);
	$rspan = $rmax if ($rmax > $rspan);
    }

    my $sighash_hex = md5_hex($signature);

    printf "%8d %8d %8d %8d %1s %32s %s\n",$contigid,$seqid,$coffset,$roffset,$dirn,$sighash_hex,$signature;

    my $sighash = md5($signature);

    $dbh->begin_work();

    my $new_mapping_id = $canonicalmappings->{$sighash};

    if (!defined($new_mapping_id)) {
	$sth_find_canonical_mapping->execute($sighash);

	($new_mapping_id) = $sth_find_canonical_mapping->fetchrow_array();

	$canonicalmappings->{$sighash} = $new_mapping_id if (defined($new_mapping_id));
    }

    unless (defined($new_mapping_id)) {
	$sth_insert_canonical_mapping->execute($cspan, $rspan, $sighash);

	$new_mapping_id = $dbh->{'mysql_insertid'};

	foreach my $segment (@segments) {
	    my ($cstart,$rstart,$seglen) = @{$segment};
	
	    my $czero = $forward ? $cstart - $coffset : $coffset - $cstart;
	    my $rzero = $rstart - $roffset;

	    $sth_insert_canonical_segment->execute($new_mapping_id, $czero, $rzero, $seglen);
	}

	$canonicalmappings->{$sighash} = $new_mapping_id;
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
