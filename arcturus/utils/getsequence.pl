#!/usr/local/bin/perl
#
# reads2fas
#
# This script extracts one or more reads and generates a FASTA file

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

my $raw = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $seqid = shift @ARGV if ($nextword eq '-seqid');

    $raw = 1 if ($nextword eq '-raw');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) &&
	defined($organism) &&
	defined($seqid)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$ds = new DataSource(-instance => $instance, -organism => $organism);

$dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

$query = "SELECT sequence from SEQUENCE where seq_id = ?";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed on $dsn");

$sth->execute($seqid);

($sequence) = $sth->fetchrow_array();

if (defined($sequence)) {
    $sequence = uncompress($sequence);

    if ($raw) {
	print $sequence,"\n";
    } else {
	print ">seq$seqid\n";
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
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -seqid\t\tSequence ID to extract\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -raw\t\tDisplay sequence as a single line\n";
    print STDERR "\n";
}
