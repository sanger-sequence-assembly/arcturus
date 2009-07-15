#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

use Compress::Zlib;

my $swprog;
my $instance;
my $organism;
my $fofn;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $swprog = shift @ARGV if ($nextword eq '-swprog');
    $fofn = shift @ARGV if ($nextword eq '-fofn');
}

unless (defined($instance) && defined($organism) && defined($swprog)) {
    &showUsage("One or more mandatory parameters are missing");
    exit(1);
}

die "\"$swprog\" is not an executable program"
    unless (-x $swprog);

pipe(PARENT_RDR, CHILD_WTR);
pipe(CHILD_RDR, PARENT_WTR);

my $pid;

if ($pid = fork) {
    close PARENT_RDR;
    close PARENT_WTR;

    select CHILD_WTR;

    $| = 1;
} else {
    close CHILD_RDR;
    close CHILD_WTR;

    open(STDIN, "<&PARENT_RDR");
    open(STDOUT, ">&PARENT_WTR");

    exec($swprog);

    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
                               -organism => $organism);

my $dbh = $adb->getConnection();

my @queries = (
	       "create temporary table CURCTG as" .
	       " select CONTIG.contig_id from CONTIG left join C2CMAPPING" .
	       " on CONTIG.contig_id = C2CMAPPING.parent_id" .
	       " where C2CMAPPING.parent_id is null",

	       "create temporary table CURSEQ" .
	       " (seq_id integer not null, contig_id integer not null, key (contig_id)) as" .
	       " select seq_id,CURCTG.contig_id from CURCTG left join MAPPING using(contig_id)",

	       "create temporary table CURREAD" .
	       " (read_id integer not null, seq_id integer not null, contig_id integer not null," .
	       " key (read_id)) as" .
	       " select read_id,SEQ2READ.seq_id,contig_id from CURSEQ left join SEQ2READ" .
	       " using(seq_id)",

	       "create temporary table FREEREAD as" .
	       " select READINFO.read_id from READINFO left join CURREAD using(read_id)" .
	       " where seq_id is null"
	       );

print STDERR "Generating temporary tables ...\n";

foreach my $query (@queries) {
    print STDERR "Executing $query\n";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();
    &db_die("execute($query) failed");

    $sth->finish();
}

my @finishing_reads;

if ($fofn) {
    die "Unable to open $fofn for reading" unless open(FOFN, $fofn);

    while (my $line = <FOFN>) {
	my ($readname) = $line =~ /\s*(\S+)\s*/;

	push @finishing_reads, $readname if defined($readname);
    }

    close(FOFN);
} else {
    my $query =  "select readname from FREEREAD left join READINFO using(read_id)" .
	" where readname like '%.____%'";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();
    &db_die("execute($query) failed");

    while (my @ary = $sth->fetchrow_array()) {
	my ($readname) = @ary;

	push @finishing_reads, $readname;
    }

    $sth->finish();
}

my $nreads = scalar(@finishing_reads);

my $query = "select read_id from READINFO where readname = ?";

my $sth_readid = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select seq_id from READINFO left join SEQ2READ using(read_id) where readname = ?";

my $sth_seqid = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select SEQ2READ.seq_id, contig_id, mapping_id, cstart, cfinish, direction" .
    " from SEQ2READ left join MAPPING" .
    " using(seq_id) where read_id = ? and contig_id is not null";

#" order by contig_id desc limit 1";

my $sth_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select min(rstart),max(rstart+length-1) from SEGMENT where mapping_id = ?";

my $sth_fwd_readextents =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select max(rstart),min(rstart-length+1) from SEGMENT where mapping_id = ?";

my $sth_rev_readextents =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select length from CONTIG where contig_id = ?";

my $sth_contig = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select sequence from SEQUENCE where seq_id = ?";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select qleft,qright from QUALITYCLIP where seq_id = ?";

my $sth_qualityclip = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select svleft,svright from SEQVEC where seq_id = ?";

my $sth_vectorclip = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select sequence from CONSENSUS where contig_id = ?";

my $sth_consensus = $dbh->prepare($query);
&db_die("prepare($query) failed");

my %consensus_by_id;

my $nfound = 0;

foreach my $finishing_readname (@finishing_reads) {
    $sth_seqid->execute($finishing_readname);

    my ($finishing_seqid) = $sth_seqid->fetchrow_array();

    $sth_seqid->finish();

    my ($finishing_sequence,
	$finishing_clipleft,
	$finishing_clipright) = &getSequenceAndClipping($finishing_seqid,
							$sth_sequence,
							$sth_qualityclip,
							$sth_vectorclip);

    my $seqf = substr($finishing_sequence,
		      $finishing_clipleft - 1,
		      $finishing_clipright - $finishing_clipleft + 1);

    my ($stem, $suffix) = split(/\./, $finishing_readname);

    my $shotgun_readname = $stem . '.' . substr($suffix, 0, 3);

    $sth_readid->execute($shotgun_readname);

    if (my ($readid) = $sth_readid->fetchrow_array()) {
	$sth_mapping->execute($readid);

	if (my ($seqid, $contigid, $mappingid, $cstart, $cfinish, $direction) =
	    $sth_mapping->fetchrow_array()) {

	    $sth_contig->execute($contigid);
	    my ($ctglen) = $sth_contig->fetchrow_array();
	    $sth_contig->finish();

	    my $sth = ($direction eq 'Forward') ? $sth_fwd_readextents : $sth_rev_readextents;
		
	    $sth->execute($mappingid);
	    my ($rstart, $rfinish) = $sth->fetchrow_array();
	    $sth->finish();

	    print STDOUT "$finishing_readname $contigid $ctglen $direction $cstart:$cfinish $rstart:$rfinish";

	    my ($shotgun_sequence,
		$shotgun_clipleft,
		$shotgun_clipright) = &getSequenceAndClipping($seqid,
							      $sth_sequence,
							      $sth_qualityclip,
							      $sth_vectorclip);
	    
	    my $seqs = substr($shotgun_sequence,
			      $shotgun_clipleft - 1,
			      $shotgun_clipright - $shotgun_clipleft + 1);

	    print STDOUT " ", length($shotgun_sequence), ",", $shotgun_clipleft, ",", $shotgun_clipright;
	    #print STDOUT $seqs,"\n";
	    print STDOUT " ", length($finishing_sequence), "," , $finishing_clipleft, ",", $finishing_clipright;
	    #print STDOUT $seqf,"\n";

	    my $sequence = $finishing_sequence;

	    while (length($sequence) > 0) {
		print substr($sequence, 0, 50),"\n";
		$sequence = substr($sequence, 50);
	    }

	    print ".\n";

	    $sequence = $shotgun_sequence;

	    while (length($sequence) > 0) {
		print substr($sequence, 0, 50),"\n";
		$sequence = substr($sequence, 50);
	    }

	    print ".\n";

	    my $goodread = 0;

	    while (my $line = <CHILD_RDR>) {
		last if ($line =~ /^\./);
		my @words = split(';', $line);
		my ($score, $smap, $fmap, $segs) = split(',', $words[0]);

		if ($segs > 0 && $score > 50) {
		    print STDOUT " // $score $fmap $smap $segs";
		    $goodread = 1;
		}
	    }

	    if ($goodread) {
		my $consensus = $consensus_by_id{$contigid};

		unless (defined($consensus)) {
		    $consensus = &getConsensus($contigid, $sth_consensus);
		    $consensus_by_id{$contigid} = $consensus;
		}
		
		my $seqlen = length($consensus);

		if ($seqlen <= 10000) {
		    if ($direction eq 'Reverse') {
			$consensus = reverse($consensus);
			$consensus =~ tr/ACGTacgt/TGCAtgca/;
		    }

		    $sequence = $consensus;
		    
		    while (length($sequence) > 0) {
			print substr($sequence, 0, 50),"\n";
			$sequence = substr($sequence, 50);
		    }
		    
		    print ".\n";
		    
		    $sequence = $finishing_sequence;
		    
		    while (length($sequence) > 0) {
			print substr($sequence, 0, 50),"\n";
			$sequence = substr($sequence, 50);
		    }
		    
		    print ".\n";
		    
		    while (my $line = <CHILD_RDR>) {
			last if ($line =~ /^\./);
			my @words = split(';', $line);
			my ($score, $fmap, $cmap, $segs) = split(',', $words[0]);
			
			if ($segs > 0 && $score > 50) {
			    if ($direction eq 'Reverse') {
				my ($cs,$cf) = split(/:/, $cmap);
				($cs, $cf) = ($seqlen - $cf + 1, $seqlen - $cs + 1);
				$cmap = "$cs:$cf";

				my ($rs,$rf) = split(/:/, $fmap);
				$fmap = "$rf:$rs";
			    }

			    print STDOUT " ## $score $cmap $fmap $segs";
			}
		    }
		}
	    }

	    print STDOUT "\n";
	    
	    $nfound++;
	}

	$sth_mapping->finish();
    }

    $sth_readid->finish();
}

print STDERR "\nFound $nfound finishing read partners out of $nreads\n";

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    #exit(0);
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

sub showUsage {
    my $msg = shift;
    print STDERR "ERROR: $msg\n\n" if defined($msg);

    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-swprog\t\tName of Smith-Waterman binary\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-fofn\t\tFile containing a list of finishing read names\n";

}
