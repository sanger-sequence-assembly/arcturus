#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $aspedbefore;
my $aspedafter;
my $qualitymask;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
}

unless (defined($instance) && defined($organism)) {
    &showUsage();
    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my @tablesfordeletion = ('CONTIG', 'CONSENSUS', 'MAPPING',
			 'SEGMENT', 'C2CMAPPING', 'C2CSEGMENT');

foreach my $table (@tablesfordeletion) {
    my $query = "DELETE FROM $table";

    my $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    my $nrows = $stmt->execute();
    &db_die("Failed to execute query \"$query\"");

    print STDERR "$nrows rows deleted from table $table.\n";

    $stmt->finish();
}

my $query = "SELECT seq_id,read_id,version FROM SEQ2READ WHERE version != 0";

my $seqid_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "DELETE FROM SEQUENCE WHERE seq_id = ?";

my $delete_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$seqid_stmt->execute();

while (my ($seq_id, $read_id, $version) = $seqid_stmt->fetchrow_array()) {
    print STDERR "READ $read_id, SEQUENCE $seq_id, VERSION $version";

    my $nrows = $delete_stmt->execute($seq_id);

    if ($nrows == 1) {
	print STDERR " --DELETED--\n";
    } else {
	print STDERR " >> ERROR: $DBI::err ($DBI::errstr) <<\n";
    }
}

$seqid_stmt->finish();
$delete_stmt->finish();

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
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
}
