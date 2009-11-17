#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;
use Digest::MD5 qw(md5_hex);

use DataSource;

my $instance;
my $organism;

my $seqid;
my $limit;

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $seqid         = shift @ARGV if ($nextword eq '-seqid');

    $limit         = shift @ARGV if ($nextword eq '-limit');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($seqid)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select contig_id,mapping_id,direction from MAPPING where seq_id = ? order by contig_id asc";

$query .= " limit $limit" if defined($limit);

my $sth_get_mappings = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select cstart,rstart,length from SEGMENT where mapping_id = ? order by rstart asc";

my $sth_get_segments =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth_get_mappings->execute($seqid);

while (my ($contigid,$mappingid,$direction) = $sth_get_mappings->fetchrow_array()) {
    print "Contig $contigid (mapping $mappingid) $direction\n\n";

    my $forward = $direction eq 'Forward';

    $sth_get_segments->execute($mappingid);

    my $coffset = undef;
    my $roffset = undef;

    my @segments;

    print "OLD SCHEMA\n\n";

    printf "%8s %8s %8s\n","cstart","rstart","length";
    print "-------- -------- --------\n";

    while (my ($cstart,$rstart,$seglen) = $sth_get_segments->fetchrow_array()) {
	printf "%8d %8d %8d\n", $cstart, $rstart, $seglen;

	($cstart,$rstart) = ($cstart+$seglen-1, $rstart-$seglen+1) unless $forward;	

	push @segments, [$cstart,$rstart,$seglen];
    }

    print "\n";

    my ($cs0, $rs0, $dummy) = @{$segments[0]};

    my $coffset = $forward ? $cs0 - 1 : $cs0 + 1;
    my $roffset = $rs0 - 1;

    print "NEW SCHEMA\n\n";

    print "coffset = $coffset\nroffset = $roffset\n\n";

    printf "%8s %8s %8s\n","cstart","rstart","length";
    print "-------- -------- --------\n";

    my $signature = '';

    foreach my $segment (@segments) {
	my ($cstart,$rstart,$seglen) = @{$segment};
	
	my $czero = $forward ? $cstart - $coffset : $coffset - $cstart;
	my $rzero = $rstart - $roffset;

	printf "%8d %8d %8d\n", $czero, $rzero, $seglen;

	$signature .= ':' if ($cstart != $cs0);

	$signature .= "$czero,$rzero,$seglen";
    }

    print "\nHash is ",md5_hex($signature),"\n";
    print "\n-----------------------------------------\n\n";
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
    print STDERR "-seqid\t\tSequence ID\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-limit\t\tShow only the first N contigs\n";
}
