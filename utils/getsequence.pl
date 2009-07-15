#!/usr/local/bin/perl
#
# This script extracts a sequence from Arcturus

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

my $raw = 0;
my $mask = 1;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $seqid = shift @ARGV if ($nextword eq '-seqid');

    $raw = 1 if ($nextword eq '-raw');

    $mask = 0 if ($nextword eq '-nomask');

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

$sth->finish();

if (defined($sequence)) {
    $sequence = uncompress($sequence);

    if ($mask) {
	$query = "SELECT qleft,qright from QUALITYCLIP where seq_id = ?";

	$sth = $dbh->prepare($query);
	&db_die("prepare($query) failed on $dsn");

	$sth->execute($seqid);

	my ($qleft, $qright) = $sth->fetchrow_array();

	if (defined($qleft) && defined($qright)) {
	    my $left = substr($sequence, 0, $qleft);
	    my $middle = substr($sequence, $qleft, $qright - $qleft + 1);
	    my $right = substr($sequence, $qright);

	    $left =~ tr/[ACGTNacgtn]/X/;
	    $right =~ tr/[ACGTNacgtn]/X/;

	    $sequence = $left . $middle . $right;
	}

	$sth->finish();

	$query = "SELECT svleft,svright from SEQVEC where seq_id = ?";

	$sth = $dbh->prepare($query);
	&db_die("prepare($query) failed on $dsn");

	$sth->execute($seqid);

	while (my ($svleft, $svright) = $sth->fetchrow_array()) {
	    my $left = substr($sequence, 0, $svleft);
	    my $middle = substr($sequence, $svleft, $svright - $svleft + 1);
	    my $right = substr($sequence, $svright);

	    $middle =~ tr/[ACGTNacgtn]/X/;

	    $sequence = $left . $middle . $right;
	}

	$sth->finish();
    }

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
