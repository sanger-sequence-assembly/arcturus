#!/usr/local/bin/perl
#
# extractSequence
#
# This script extracts sequences

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $instance;
my $organism;
my $seqids;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $seqids = shift @ARGV if ($nextword eq '-seqids');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($seqids)) {
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

my $query = "select seqlen,seq_hash,sequence from SEQUENCE where seq_id = ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

foreach my $seq_id (split(/,/, $seqids)) {
    $sth->execute($seq_id);

    my ($seqlen, $seqhash, $sequence) = $sth->fetchrow_array();

    if (defined($seqlen)) {
	my $clength = length($sequence);
	$sequence = uncompress($sequence);
	my $truelen = length($sequence);

	print "$seq_id (compressed: $clength, claimed: $seqlen, actual: $truelen)\n";
	
	while (length($sequence)) {
	    print substr($sequence, 0, 50),"\n";
	    $sequence = substr($sequence, 50);
	}
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
    print STDERR "    -seqids\t\tComma-separated list of sequence IDs\n";
}
