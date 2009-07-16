#!/usr/local/bin/perl

use DBI;
use DBI qw(:sql_types);

use strict;

my $url;
my $username;
my $password;
my $table;
my $maxcount = 5000;
my $batchsize = 0;
my $usebatch = 0;

while (my $nextword = shift @ARGV) {
    $url = shift @ARGV if ($nextword eq '-url');

    $username = shift @ARGV if ($nextword eq '-username');

    $password = shift @ARGV if ($nextword eq '-password');

    $table = shift @ARGV if ($nextword eq '-table');

    $maxcount = shift @ARGV if ($nextword eq '-maxcount');

    $batchsize = shift @ARGV if ($nextword eq '-batchsize');
}

$usebatch = 1 if ($batchsize > 0);

die "One or more of: url, username, password, table name were missing"
    unless (defined($url) && defined($username) && defined($password) && defined($table));

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 });

my $query = "insert into $table(seq_id,seqlen,seq_hash,qual_hash,sequence,quality)"
    . " values(?,?,?,?,?,?)";

my $sth = $dbh->prepare($query);

my @bytes;

for (my $i = 0; $i < 1000; $i++) {
    push @bytes, int(rand(256));
}

my $randstr = pack('C*', @bytes);

my $seq_id_list = [];
my $seqlen_list = [];
my $seq_hash_list = [];
my $qual_hash_list = [];
my $sequence_list = [];
my $quality_list = [];

my $count = 0;

print STDERR "Writing $maxcount rows in ";
print STDERR $usebatch ? "BATCH" : "ROW-BY-ROW";
print STDERR " mode";
print STDERR " with batchsize $batchsize" if $usebatch;
print STDERR "\n";

my $types = [SQL_INTEGER,
	     SQL_INTEGER,
	     SQL_VARBINARY,
	     SQL_VARBINARY,
	     SQL_VARBINARY,
	     SQL_VARBINARY];

my $seq_hash = substr($randstr, 0, 16);
my $qual_hash = substr($randstr, 16, 16);

for (my $row = 0; $row < $maxcount; $row++) {
    $count++;

    my $seq_id = $count;

    my $seqlen = 450 + int(rand(100));
    my $qlen = 550 + int(rand(100));

    my $sequence = substr($randstr, 0, $seqlen);
    my $quality = substr($randstr, 0, $qlen);

    if ($usebatch) {
	push @{$seq_id_list}, $seq_id;
	push @{$seqlen_list}, $seqlen;
	push @{$seq_hash_list}, $seq_hash;
	push @{$qual_hash_list}, $qual_hash;
	push @{$sequence_list}, $sequence;
	push @{$quality_list}, $quality;
    }

    if ($usebatch) {
	if ($count%$batchsize == 0) {
	    &executeBatchUpdate($sth,
				[$seq_id_list,
				 $seqlen_list,
				 $seq_hash_list,
				 $qual_hash_list,
				 $sequence_list,
				 $quality_list],
				$types);
	    
	    ($seq_id_list,
	     $seqlen_list,
	     $seq_hash_list,
	     $qual_hash_list,
	     $sequence_list,
	     $quality_list) = ([], [], [], [], [], []);
	}
    } else {
	&executeUpdate($sth,
		       [$seq_id, $seqlen, $seq_hash, $qual_hash, $sequence, $quality],
		       $types);

    }

    if ($count%10000 == 0) {
	print STDERR '+';
    } elsif ($count%1000 == 0) {
	print STDERR '.';
    }
}

if ($usebatch && ($count%$batchsize > 0)) {
    &executeBatchUpdate($sth,
			[$seq_id_list,
			 $seqlen_list,
			 $seq_hash_list,
			 $qual_hash_list,
			 $sequence_list,
			 $quality_list],
			$types);
}

print STDERR "\n";

$sth->finish();

$dbh->disconnect();

exit(0);

sub executeUpdate {
    my $stmt = shift;
    my $values = shift;
    my $types = shift;

    my $col = 1;

    while (my $value = shift @{$values}) {
	my $type = @{$types}[$col - 1];
	$stmt->bind_param($col, $value, { TYPE => $type });
	$col++;
    }

    $stmt->execute();
}

sub executeBatchUpdate {
    my $stmt = shift;
    my $lists = shift;
    my $types = shift;

    my $col = 1;

    while (my $column = shift @{$lists}) {
	my $type = @{$types}[$col - 1];
	$stmt->bind_param_array($col, $column, { TYPE => $type });
	$col++;
    }

    $stmt->execute_array( { ArrayTupleStatus => \my @tuple_status } );
}
