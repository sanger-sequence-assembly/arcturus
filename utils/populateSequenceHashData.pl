#!/usr/local/bin/perl

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use Digest::MD5 qw(md5);

my $instance;
my $organism;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance)) {
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

my $query = "select count(*) from SEQUENCE where seq_hash is null or qual_hash is null";
my $sth =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my ($count) = $sth->fetchrow_array();

if ($count == 0) {
    print STDERR "Nothing to update for $organism\n";
    $sth->finish();
    $dbh->disconnect();
    exit(0);
}

$sth->finish();

print STDERR "There are $count sequences to update\n";

$query = "update SEQUENCE set seq_hash = ?, qual_hash = ? where seq_id = ?";
my $sth_update = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select seq_id, sequence, quality from SEQUENCE where seq_hash is null or qual_hash is null";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my $done = 0;

while (my ($seq_id, $zsequence, $zquality) = $sth->fetchrow_array()) {
    my $sequence = uncompress($zsequence);
    my $quality = uncompress($zquality);

    my $seq_hash = md5($sequence);
    my $qual_hash = md5($quality);

    my $rc = $sth_update->execute($seq_hash, $qual_hash, $seq_id);
    &db_die("update failed for sequence $seq_id");

    $done++;

    print STDERR "Done $done\n" if (($done % 1000) == 0);
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
}
