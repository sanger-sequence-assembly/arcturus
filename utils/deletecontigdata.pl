#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $confirm;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $confirm = 1 if ($nextword eq '-confirm');
}

unless (defined($instance) && defined($organism)) {
    &showUsage();
    exit(0);
}

unless ($confirm) {
    print "***********************************************************\n";
    print "*** YOU ARE ABOUT TO DELETE ALL CONTIGS IN THE DATABASE ***\n";
    print "***********************************************************\n";
    print "\n";
    print "Please confirm that you wish to do this by typing YES: ";
    my $reply = <STDIN>;

    die "No response!" unless defined($reply);

    chop($reply);

    die "This operation has been abandoned" unless (lc($reply) eq 'yes');
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my @tablesfordeletion = ('CONTIG', 'CONSENSUS', 'MAPPING',
			 'SEGMENT', 'C2CMAPPING', 'C2CSEGMENT',
			 'CONTIGTAG');

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

$query = "DELETE FROM SEQ2READ WHERE version != 0";

$delete_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $nrows = $delete_stmt->execute();

print STDERR "$nrows rows deleted from table SEQ2READ.\n";

$delete_stmt->finish();

print STDERR "Preparing to truncate CONTIG table.\n";

$query = "TRUNCATE TABLE CONTIG";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

print STDERR "Table CONTIG has been truncated\n";

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(1);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-confirm\tForce the operation without a prompt\n";
}
