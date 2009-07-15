#!/usr/local/bin/perl
#
# This script changes stars to dashes in consensus sequences

use strict;

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

my $instance;
my $organism;

my $verbose = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

if (defined($dbh)) {
    if ($verbose) {
	print STDERR "Connected to DataSource(instance=$instance, organism=$organism)\n";
	print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    }
} else {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "SELECT contig_id,length,sequence from CONSENSUS";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "UPDATE CONSENSUS SET sequence = ? WHERE contig_id = ?";

my $update_sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();

my $all_contigs = 0;
my $fixed_contigs = 0;
my $all_length = 0;
my $fixed_length = 0;

while (my ($contig_id, $seqlen, $sequence) = $sth->fetchrow_array()) {
    $sequence = uncompress($sequence);

    my $count = $sequence =~ s/\*/\-/g;

    $all_contigs++;
    $all_length += $seqlen;

    next unless ($count > 0);

    $sequence = compress($sequence);

    $update_sth->execute($sequence, $contig_id);

    printf STDERR "%8d %8d %8d\n", $contig_id, $seqlen, $count if $verbose;

    $fixed_contigs++;
    $fixed_length += $count;
}

print STDERR "Scanned $all_contigs contigs ($all_length bp).";
print STDERR "  Fixed $fixed_length pads in $fixed_contigs contigs." if ($fixed_length > 0);
print STDERR "\n";

$sth->finish();
$update_sth->finish();

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
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\tFor verbose output\n";

}
