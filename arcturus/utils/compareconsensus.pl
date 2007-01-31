#!/usr/local/bin/perl

use ArcturusDatabase;
use Compress::Zlib;
use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $verbose = 0;
my $fastafile;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $fastafile = shift @ARGV if ($nextword eq '-fasta');
    $verbose = 1 if ($nextword eq '-verbose');
}

unless (defined($instance) && defined($organism) && defined($fastafile)) {
    &showUsage();
    exit(0);
}

die "File \"$fastafile\" does not exist" unless (-f $fastafile);

my $fh = new FileHandle($fastafile, "r");

die "Unable to open \"$fastafile\" for reading" unless defined($fh);

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

$query = "select readname,read_id from READINFO where readname = ?";

my $stmt_readname = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select seq_id from SEQ2READ where read_id = ?";

my $stmt_read2seq = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select currentcontigs.contig_id,gap4name,nreads,length,created,updated,project_id" .
    " from MAPPING left join currentcontigs using(contig_id) where seq_id = ? and gap4name is not null";

my $stmt_seq2contig = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select sequence,quality from CONSENSUS where contig_id = ?";

my $stmt_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

while (1) {
    my ($ctgname, $ctgseq) = &getNextSequence($fh);

    last unless defined($ctgname);

    print "$ctgname: ",length($ctgseq), " bp";

    $stmt_readname->execute($ctgname);

    my $ctgcount = 0;
    my $seqcount = 0;

    my ($readname,$readid) = $stmt_readname->fetchrow_array();

    $ctgcount = 0;

    $stmt_read2seq->execute($readid);

    while (my ($seqid) = $stmt_read2seq->fetchrow_array()) {
	$seqcount++;

	$stmt_seq2contig->execute($seqid);

	while (my ($contig_id,$gap4name,$nreads,$ctglen,$created,$updated,$projid) =
	       $stmt_seq2contig->fetchrow_array()) {
	    $ctgcount++;

	    my $projname = $projectid2name{$projid};
	    $projname = $organism . "/" . $projid unless defined($projname);

	    print ": contig $contig_id, project $projname, reads $nreads\n";

	    $stmt_sequence->execute($contig_id);

	    my ($compressedsequence, $compressedquality) = $stmt_sequence->fetchrow_array();

	    if (!defined($compressedsequence)) {
		print STDERR "ERROR, no consensus stored for \"$ctgname\" (ID $contig_id)\n";
		next;
	    }

	    my $sequence = uc(uncompress($compressedsequence));

	    my $quality = uncompress($compressedquality);

	    my @qual = unpack("c*", $quality);

	    my $faslen = length($ctgseq);
	    my $seqlen = length($sequence);

	    if ($faslen != $seqlen) {
		print "ERROR, sequence length mismatch for \"$ctgname\" (ID $contig_id):",
		" $faslen in FASTA file, $seqlen in database\n";
		next;
	    }

	    if ($ctgseq ne $sequence) {
		print "ERROR, sequence mismatch for \"$ctgname\" (ID $contig_id)\n";
		my @fas = unpack('c*', $ctgseq);
		my @arc = unpack('c*', $sequence);

		for (my $i = 0; $i < $faslen; $i++) {
		    if ($fas[$i] != $arc[$i]) {
			my $q = $qual[$i];
			print "\tAt ", ($i+1), " ", chr($fas[$i]), " versus ", chr($arc[$i]), " [Q=$q]\n";
		    }
		}
	    }
	}
    }

    print "\n" if ($ctgcount == 0);

    print STDERR "ERROR, failed to find contig with read \"$ctgname\"\n" if ($ctgcount == 0);
}

$stmt_readname->finish();
$stmt_read2seq->finish();
$stmt_seq2contig->finish();
$stmt_sequence->finish();

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
    print STDERR "-fasta\t\t\tName of input FASTA file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-verbose\t\tVerbose output\n";
}

sub getNextSequence {
    my $fh = shift;

    my $pos;
    my $seqname;
    my @dna;

    while (1) {
	$pos = $fh->tell();

	my $line = <$fh>;

	if (!defined($line)) {
	    return (undef,undef);
	}

	if ($line =~ /^>(\S+)\s*/) {
	    if (defined($seqname)) {
		$fh->seek($pos, 0);
		return ($seqname, uc(join('', @dna)));
	    } else {
		$seqname = $1;
	    }
	} else {
	    chop($line);
	    $line =~ s/[\*\-]/N/g;
	    push @dna, $line;
	}
    }
}
