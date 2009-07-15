#!/usr/local/bin/perl
#
# testSequenceAndQuality
#
# This script checks the sequence and base quality data

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $instance;
my $organism;
my $min_seq_id;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $min_seq_id = shift @ARGV if ($nextword eq '-min_seq_id');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
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

my $query = "select readname,version from SEQ2READ left join READINFO using (read_id) where seq_id = ?";

my $sth_seq2read = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select seq_id,seqlen,sequence,quality from SEQUENCE";

$query .= " where seq_id >= $min_seq_id" if defined($min_seq_id);

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

while (my ($seq_id, $seqlen, $sequence, $quality) = $sth->fetchrow_array()) {
    my $zseqlen = length($sequence);
    my $zqlen = length($quality);

    $sequence = uncompress($sequence);
    $quality = uncompress($quality);

    my $badseq = $seqlen != length($sequence);
    my $badqual = $seqlen != length($quality);

    if ($badseq || $badqual) {
	$sth_seq2read->execute($seq_id);
	my ($readname, $version) = $sth_seq2read->fetchrow_array();
	$sth_seq2read->finish();

	print "$seq_id ($readname version $version)";

	print " SEQUENCE LENGTH MISMATCH: $seqlen vs ",length($sequence), " ($zseqlen compressed)" if $badseq;
	print " QUALITY LENGTH MISMATCH: $seqlen vs ",length($quality), " ($zqlen compressed)" if $badqual;
	print "\n";
    }
}

$sth->finish();

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
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -min_seq_id\tMinimum sequence ID to check\n";
}
