#!/usr/local/bin/perl

use strict;

use Compress::Zlib;

use ArcturusDatabase;
use DBI;

my $nextword;
my $instance;
my $organism;
my $oligo;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $oligo = shift @ARGV if ($nextword eq '-oligo');
}

die "You must specify the instance and organism and oligo"
    unless (defined($organism) && defined($instance) && defined($oligo));

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

my $dbh = $adb->getConnection();

$oligo = uc($oligo);
my $revoligo = reverse($oligo);
$revoligo =~ tr/ACGTacgt/TGCAtgca/;

&findOligoInReads($dbh, $oligo, $revoligo);

&findOligoInContigs($dbh, $oligo, $revoligo);

$dbh->disconnect();

exit(0);

sub findOligoInReads {
    my $dbh = shift;
    my $oligo = shift;
    my $revoligo = shift;

    print STDERR "Searching reads ...\n";

    my $query = "select readname,sequence from READS,SEQ2READ,SEQUENCE where" .
	" READS.read_id = SEQ2READ.read_id and SEQ2READ.seq_id = SEQUENCE.seq_id";

    my $sth = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $sth->execute();
    &db_die("Failed to execute query \"$query\"");

    while (my ($readname, $sequence) = $sth->fetchrow_array()) {
	$sequence = uc(uncompress($sequence));

	my $offset = index($sequence, $oligo);

	printf "%-30s %d\n", $readname, $offset if ($offset >= 0);

	$offset = index($sequence, $revoligo);

	printf "%-30s %d (REVERSED)\n", $readname, $offset if ($offset >= 0);
    }
    
    $sth->finish();
}

sub findOligoInContigs {
    my $dbh = shift;
    my $oligo = shift;
    my $revoligo = shift;

    print STDERR "Searching contigs ...\n";

    my $query = "select CONSENSUS.contig_id,sequence,length" .
	" from CONSENSUS left join C2CMAPPING" .
	" on CONSENSUS.contig_id = C2CMAPPING.parent_id" .
	" where C2CMAPPING.parent_id is null";

    my $sth = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $sth->execute();
    &db_die("Failed to execute query \"$query\"");

    while (my ($contigid, $sequence, $seqlen) = $sth->fetchrow_array()) {
	$sequence = uc(uncompress($sequence));

	my $offset = index($sequence, $oligo);

	printf "CONTIG%06d %d\n", $contigid, $offset if ($offset >= 0);

	$offset = index($sequence, $revoligo);

	printf "CONTIG%06d %d (REVERSED)\n", $contigid, $offset if ($offset >= 0);
    }
    
    $sth->finish();
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}
