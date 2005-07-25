#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $history = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $history = 1 if ($nextword eq '-history');
}

unless (defined($instance) && defined($organism)) {
    &showUsage();
    exit(0);
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my ($query, $stmt);

unless ($history) {
    $query = "create temporary table currentcontigs" .
	" as select CONTIG.contig_id,gap4name,nreads,length,created,updated,project_id" .
	" from CONTIG left join C2CMAPPING" .
	" on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    my $ncontigs = $stmt->execute();
    &db_die("Failed to execute query \"$query\"");
}

$query = "select project_id, name from PROJECT";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

my %projectid2name;

while (my ($projid,$projname) = $stmt->fetchrow_array()) {
    $projectid2name{$projid} = $projname;
}

$stmt->finish();

$query = "select seq_id from READS left join SEQ2READ using(read_id) where readname = ?";

my $stmt_read2seq = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $contigtable = $history ? "CONTIG" : "currentcontigs";

$query = "select $contigtable.contig_id,gap4name,nreads,length,created,updated,project_id,cstart,cfinish,direction" .
    " from MAPPING left join $contigtable using(contig_id) where seq_id = ? and gap4name is not null";

my $stmt_seq2contig = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

while (my $line = <STDIN>) {
    my ($readname) = $line =~ /\s*(\S+)/;

    my $oligocontig = &read2contig($readname);

    next unless (scalar(@{$oligocontig}) > 0);

    my ($readstem, $readextension) = split(/\./, $readname);

    my ($exta, $extb) = ($readextension =~ /^p2k/) ? ('p1k','q1k') : ('q1k','p1k');

    my $readnamea = $readstem . '.' . $exta;
    my $readnameb = $readstem . '.' . $extb;

    my $readacontig = &read2contig($readnamea);
    my $readbcontig = &read2contig($readnameb);

    next unless (scalar(@{$readacontig}) > 0 && scalar(@{$readbcontig}) > 0);

    foreach my $xctg (@{$oligocontig}) {
	foreach my $actg (@{$readacontig}) {
	    foreach my $bctg (@{$readbcontig}) {
		printf "%-25s %-25s %6d %6d %6d %3s %-25s %6d %6d %6d %3s %-25s %6d %6d %6d\n",
		$readname,
		$xctg->[1], $xctg->[4], $xctg->[2], $xctg->[3],
		$exta,
		$actg->[1], $actg->[4], $actg->[2], $actg->[3],
		$extb,
		$bctg->[1], $bctg->[4], $bctg->[2], $bctg->[3];
	    }
	}
    }
}


$dbh->disconnect();

exit(0);

sub read2contig {
    my $readname = shift;

    my $results = [];

    $stmt_read2seq->execute($readname);

    if (my ($seqid) = $stmt_read2seq->fetchrow_array()) {
	$stmt_seq2contig->execute($seqid);

	my $ctgcount = 0;

	while (my ($contig_id,$gap4name,$nreads,$ctglen,$created,$updated,$projid,$cstart,$cfinish,$direction) =
	       $stmt_seq2contig->fetchrow_array()) {

	    ($cstart,$cfinish) = ($cfinish, $cstart) if ($direction eq 'Reverse');

	    push @{$results}, [$contig_id, $gap4name, $cstart, $cfinish, $ctglen, $nreads, $projid, $created, $updated];
	}
    }

    $stmt_read2seq->finish();

    return $results;
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-history\t\tSearch for the read in all contigs, not just the current contig set\n";
}
