#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $insertsize = 8000;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $insertsize = shift @ARGV if ($nextword eq '-insertsize');
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

$query = "create temporary table currentcontigs" .
    " as select CONTIG.contig_id,gap4name,nreads,length,created,updated,project_id" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $ncontigs = $stmt->execute();
&db_die("Failed to execute query \"$query\"");

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

$query = "select seq_id from READINFO left join SEQ2READ using(read_id) where readname = ?";

my $stmt_read2seq = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select currentcontigs.contig_id,gap4name,nreads,length,created,updated,project_id,cstart,cfinish,direction" .
    " from MAPPING left join currentcontigs using(contig_id) where seq_id = ? and gap4name is not null";

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
		# p1k and q1k reads must be in different contigs
		next unless ($actg->[1] ne $bctg->[1]);

		# The oligo read must be in the same read as either the p1k or q1k read
		next unless (($xctg->[1] eq $actg->[1]) || ($xctg->[1] eq $bctg->[1]));

		# The shotgun reads must be within a sub-clone length of the end of their respective
		# contigs and pointing outwards
		next unless (&nearEndAndPointingOut($actg->[4], $actg->[2], $actg->[3], $insertsize) &&
			     &nearEndAndPointingOut($bctg->[4], $bctg->[2], $bctg->[3], $insertsize));

		my $enda = &whichEnd($actg->[2], $actg->[3]);
		my $endb = &whichEnd($bctg->[2], $bctg->[3]);

		# Does one of the contigs need to be reversed?
		my $rev = ($enda eq $endb) ? 'R' : '';

		my @info = ();

		if ($xctg->[1] eq $actg->[1]) {
		    # The oligo read is in the same contig as its shotgun counterpart

		    # It should be within a sub-clone length of the end of its contig and pointing outwards
		    next unless &nearEndAndPointingOut($xctg->[4], $xctg->[2], $xctg->[3], $insertsize);

		    push @info, $readname, $actg->[4], $readnameb, $bctg->[4];
		} else {
		    # The oligo read is in the same contig as the mate of its shotgun counterpart

		    # It should be pointing into its contig and closer to the end than the mate of
		    # its shotgun counterpart
		    next unless &nearEndAndPointingIn($xctg->[4], $xctg->[2], $xctg->[3],
						      $bctg->[2], $bctg->[3], $insertsize);

		    push @info, $readname, $bctg->[4], $readnamea, $actg->[4];
		}

		push @info, $rev;

		printf "%-25s %8d  %-25s %8d %s\n", @info;
	    }
	}
    }
}


$dbh->disconnect();

exit(0);

sub nearEndAndPointingOut {
    my ($ctglen, $ctgstart, $ctgfinish, $insertsize, $junk) = @_;

    if ($ctgstart < $ctgfinish) {
	# Read is co-aligned with contig
	return ($ctgstart > $ctglen - $insertsize);
    } else {
	# read is counter-aligned with contig
	return ($ctgfinish < $insertsize);
    }
}

sub nearEndAndPointingIn {
    my ($ctglen, $ctgstart, $ctgfinish, $ctgstartb, $ctgfinishb, $insertsize, $junk) = @_;

    if ($ctgstartb < $ctgfinishb) {
	# Mate of shotgun read is co-aligned with contig, so it must be near the end
	return (($ctgstart > $ctgfinish) && ($ctgfinish > $ctgfinishb));
    } else {
	# Mate of shotgun read is counter-aligned with contig, so it must be near the start
	return (($ctgstart < $ctgfinish) && ($ctgfinish < $ctgfinishb));
    }
}

sub whichEnd {
    my ($ctgstart, $ctgfinish, $junk) = @_;

    return ($ctgstart < $ctgfinish) ? 'R' : 'L';
}

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
    print STDERR "-insertsize\t\tThe size of the sub-clones [default: 8000]\n";
}
