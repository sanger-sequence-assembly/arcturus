#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;
use Compress::Zlib;

use strict;

my $nextword;
my $instance;
my $organism;
my $history = 0;
my $verbose = 0;
my $finishing = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $verbose = 1 if ($nextword eq '-verbose');
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

print STDERR "Enumerating current contigs\n" if $verbose;

my $query = "select CONTIG.contig_id,gap4name,nreads,length,created,updated,project_id" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $ncontigs = $stmt->execute();
&db_die("Failed to execute query \"$query\"");

my $contigdata;

while (my @ary = $stmt->fetchrow_array()) {
    my $contigid = shift @ary;
    $contigdata->{$contigid} = [@ary];
}

$stmt->finish();

print STDERR "Found ", scalar(keys %{$contigdata}), " contigs\n" if $verbose;

my $repeats = {};

$query = "select contig_id,cstart,cfinal,tagcomment from TAG2CONTIG left join CONTIGTAG using(tag_id)" .
    "  where tagtype='REPT' order by contig_id asc,cstart asc";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

print STDERR "Gathering repeats\n" if $verbose;

while (my ($contigid,$repstart, $repfinish, $repcomment) = $stmt->fetchrow_array()) {
    next unless defined($contigdata->{$contigid});

    $repeats->{$contigid} = [] unless defined($repeats->{$contigid});

    push @{$repeats->{$contigid}}, [$repstart, $repfinish, $repcomment];
}

$stmt->finish();

my %queries = ( "repeatreads",
		"select MAPPING.seq_id,cstart,cfinish,readname,READS.read_id,strand,template_id" .
		"  from MAPPING,SEQ2READ,READS" .
		"  where contig_id=? and cstart>=? and cfinish<=? and MAPPING.seq_id=SEQ2READ.seq_id" .
		"  and SEQ2READ.read_id=READS.read_id order by cstart asc",

		"partnerreads",
		"select readname,READS.read_id,seq_id from READS left join SEQ2READ using(read_id)" .
		"  where template_id=? and strand !=?",

		"ligations",
		"select sihigh from TEMPLATE left join LIGATION using(ligation_id)" .
		"  where template_id=?",

		"partnermappings",
		"select contig_id,cstart,cfinish,direction from MAPPING where seq_id=?",

		"consensus",
		"select sequence from CONSENSUS where contig_id=?",

		"readsequence",
		"select sequence from SEQUENCE where seq_id=?",

		"qualityclip",
		"select qleft,qright from QUALITYCLIP where seq_id=?",

		"vectorclip",
		"select svleft,svright from SEQVEC where seq_id=?"
		);

my $statements;

foreach my $qkey (keys %queries) {
    $statements->{$qkey} = $dbh->prepare($queries{$qkey});
    &db_die("Preparing " . $queries{$qkey});
}

foreach my $contigid (keys %{$repeats}) {
    my $ctglen = $contigdata->{$contigid}->[2];

    my $consensus = &getConsensus($contigid, $statements->{'consensus'});

    print STDERR "\n\nProcessing contig $contigid ($ctglen bp)\n" if $verbose;

    foreach my $reprange (@{$repeats->{$contigid}}) {
	my ($repstart, $repfinish, $repcomment) = @{$reprange};

	print STDERR "\n\n\tREPT: $repstart to $repfinish \"$repcomment\"\n" if $verbose;

	$statements->{"repeatreads"}->execute($contigid, $repstart, $repfinish);

	while (my ($seqid,$rstart, $rfinish, $readname, $readid, $strand, $templateid) =
	       $statements->{"repeatreads"}->fetchrow_array()) {
	    print STDERR "\n\t\tREAD $rstart to $rfinish $readname $readid $templateid\n" if $verbose;

	    $statements->{"ligations"}->execute($templateid);

	    my ($sihigh) = $statements->{"ligations"}->fetchrow_array();

	    $statements->{"partnerreads"}->execute($templateid, $strand);

	    while (my ($preadname, $preadid, $pseqid) =
		   $statements->{"partnerreads"}->fetchrow_array()) {
		print STDERR "\n\t\t\tPARTNER $preadname $preadid $pseqid" if $verbose;

		$statements->{"partnermappings"}->execute($pseqid);

		my $pfound = 0;

		while (my ($pcontigid, $pstart, $pfinish, $pdirection) =
		       $statements->{"partnermappings"}->fetchrow_array()) {
		    next unless defined($contigdata->{$pcontigid});

		    $pfound = 1;

		    if ($pcontigid == $contigid) {
			print STDERR " at $pstart to $pfinish $pdirection" if $verbose;

			my $inRepeat = &isInRepeat($pstart, $pfinish, $repeats->{$contigid});

			print STDERR " IN REPEAT" if ($verbose && $inRepeat);

			my ($newrstart, $newrfinish) = ($pdirection eq 'Forward') ?
			    ($pstart, $pstart+$sihigh) : ($pfinish-$sihigh, $pfinish);

			$inRepeat = &isInRepeat($newrstart, $newrfinish, $repeats->{$contigid});

			print STDERR "\n\t\t\t\tSEARCH RANGE $newrstart $newrfinish" if $verbose;
			print STDERR " IN REPEAT" if ($verbose && $inRepeat);

			#my ($sequence,
			#    $clipleft,
			#    $clipright) = &getSequenceAndClipping($seqid,
			#					  $statement->{'sequence'},
			#					  $statement->{'qualityclip'},
			#					  $statement->{'vectorclip'});

		    } else {
			print STDERR " in DIFFERENT contig ($pcontigid)" if $verbose;

			my $inRepeat = &isInRepeat($pstart, $pfinish, $repeats->{$pcontigid});
			print STDERR " IN REPEAT" if ($verbose && $inRepeat);

			print STDERR "\n" if $verbose;
		    }
		}
		
		print STDERR " NOT FOUND" if ($verbose && !$pfound);
		
		print STDERR "\n" if $verbose;
	    }
	}
    }
}

$dbh->disconnect();

exit(0);

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
    #print STDERR "\n";
    #print STDERR "OPTIONAL PARAMETERS:\n";
}

sub isInRepeat {
    my ($cs, $cf, $reps, $junk) = @_;

    foreach my $rep (@{$reps}) {
	my ($rs,$rf,$rc) = @{$rep};

	return 1 if (($cs >= $rs && $cs <= $rf) ||
		     ($cf >= $rs && $cf <= $rf));
    }

    return 0;
}

sub getSequenceAndClipping {
    my ($seqid, $sth_sequence, $sth_qualityclip, $sth_vectorclip) = @_;

    $sth_sequence->execute($seqid);

    my ($sequence) = $sth_sequence->fetchrow_array();

    $sth_sequence->finish();

    return undef unless defined($sequence);

    $sequence = uncompress($sequence);

    $sth_qualityclip->execute($seqid);

    my ($clipleft, $clipright) = $sth_qualityclip->fetchrow_array();

    $sth_qualityclip->finish();

    ($clipleft, $clipright) = (1, length($sequence))
	unless (defined($clipleft) && defined($clipright));

    $sth_vectorclip->execute($seqid);

    while (my ($svleft, $svright) = $sth_vectorclip->fetchrow_array()) {
	$clipleft = $svright if ($svleft == 1 && $svright > $clipleft);

	$clipright = $svleft if ($svleft > 1 && $svleft < $clipright);
    }

    $sth_vectorclip->finish();

    return ($sequence, $clipleft, $clipright);
}

sub getConsensus {
    my ($contigid, $sth_consensus) = @_;

    $sth_consensus->execute($contigid);

    my ($sequence) = $sth_consensus->fetchrow_array();

    $sth_consensus->finish();

    $sequence = uncompress($sequence) if defined($sequence);

    return $sequence;
}
