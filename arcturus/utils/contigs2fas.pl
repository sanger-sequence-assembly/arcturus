#!/usr/local/bin/perl
#
# contigs2fas
#
# This script extracts one or more contigs and generates a FASTA file

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $minlen;
my $verbose;
my $fastafile;
my $destdir;
my $padton;
my $padtox;
my $depad;
my $fastafh;
my $contigids;
my $allcontigs = 0;
my $maxseqperfile;
my $seqfilenum;
my $totseqlen;
my $project_id;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');

    $fastafile = shift @ARGV if ($nextword eq '-fasta');

    $destdir = shift @ARGV if ($nextword eq '-destdir');

    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $maxseqperfile = shift @ARGV if ($nextword eq '-maxseqperfile');

    $allcontigs = 1 if ($nextword eq '-allcontigs');

    $project_id = shift @ARGV if ($nextword eq '-project');

    $padton = 1 if ($nextword eq '-padton');
    $padtox = 1 if ($nextword eq '-padtox');

    $depad = 1 if ($nextword eq '-depad');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	(defined($fastafile) || defined($destdir))) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$depad = 0 unless defined($depad);

$padton = 0 unless defined($padton);
$padton = 0 if $depad;

$padtox = 0 unless defined($padtox);
$padtox = 0 if $depad;

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

if (defined($fastafile)) {
    my $filename = $fastafile;
    if (defined($maxseqperfile)) {
	$seqfilenum = 1;
	$filename .= sprintf("%04d", $seqfilenum) . ".fas";
    }

    $fastafh = new FileHandle($filename, "w");
    die "Unable to open FASTA file \"$filename\" for writing" unless $fastafh;
} else {
    if (! -d $destdir) {
	die "Unable to create directory \"$destdir\"" unless mkdir($destdir);
    }
}

my $query;

$minlen = 1000 unless (defined($minlen) || defined($contigids));

if (defined($contigids)) {
    $query = "select contig_id,length from CONTIG where contig_id in ($contigids)";
} elsif ($allcontigs) {
    $query = "select contig_id,length from CONTIG";
    $query .= " where length > $minlen" if defined($minlen);
} else {
    $query = "select CONTIG.contig_id,length from CONTIG left join C2CMAPPING" .
	" on CONTIG.contig_id = C2CMAPPING.parent_id" .
	    " where C2CMAPPING.parent_id is null";

    $query .= " and length > $minlen" if defined($minlen);

    $query .= " and project_id = $project_id" if defined($project_id);
}

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$query = "select sequence from CONSENSUS where contig_id = ?";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

$totseqlen = 0;

while(my @ary = $sth->fetchrow_array()) {
    my ($contigid, $contiglength) = @ary;

    $sth_sequence->execute($contigid);

    my ($compressedsequence) = $sth_sequence->fetchrow_array();

    $sth_sequence->finish();

    next unless defined($compressedsequence);

    my $sequence = uncompress($compressedsequence);

    if ($contiglength != length($sequence)) {
	print STDERR "Sequence length mismatch for contig $contigid: $contiglength vs ",
	length($sequence),"\n";
    }

    if ($depad) {
	# Depad
	$sequence =~ s/[^\w\-]//g;
    } elsif ($padton) {
	# Convert pads to N ...
	$sequence =~ s/[^\w\-]/N/g;
    } elsif ($padtox) {
	# Convert pads to X ...
	$sequence =~ s/[^\w\-]/X/g;
    }

    if ($destdir) {
	my $filename = sprintf("%s/contig%04d.fas", $destdir, $contigid);
	$fastafh = new FileHandle("$filename", "w");
	die "Unable to open new file \"$filename\"" unless $fastafh;
    }

    if (defined($maxseqperfile)) {
	$totseqlen += length($sequence);

	if ($totseqlen > $maxseqperfile) {
	    $fastafh->close();
	    $totseqlen = length($sequence);
	    $seqfilenum++;

	    my $filename = $fastafile . sprintf("%04d", $seqfilenum) . ".fas";

	    $fastafh = new FileHandle("$filename", "w");
	    die "Unable to open new file \"$filename\"" unless $fastafh;
	}
    }

    printf $fastafh ">CONTIG%04d\n", $contigid;

    while (length($sequence) > 0) {
	print $fastafh substr($sequence, 0, 50), "\n";
	$sequence = substr($sequence, 50);
    }

    if ($destdir) {
	$fastafh->close();
	undef $fastafh;
    }
}

$sth->finish();

$dbh->disconnect();

$fastafh->close() if defined($fastafh);

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "    -fasta\t\tName of output FASTA file\n";
    print STDERR "    -- OR --\n";
    print STDERR "    -destdir\t\tDirectory for individual FASTA files\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum length for contigs [default: 1000]\n";
    print STDERR "    -contigs\t\tComma-separated list of contig IDs [implies -minlen 0]\n";
    print STDERR "    -allcontigs\t\tSelect all contigs, not just from current set\n";
    print STDERR "    -depad\t\tRemove pad characters from sequence\n";
    print STDERR "    -padton\t\tConvert pads to N\n";
    print STDERR "    -padtox\t\tConvert pads to X\n";
    print STDERR "    -maxseqperfile\tMaximum sequence length per file\n";
    print STDERR "    -project\t\tProject ID to export\n";
}
