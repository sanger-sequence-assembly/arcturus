#!/usr/local/bin/perl

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use Digest::MD5 qw(md5);

my $instance;
my $organism;
my $seqids;
my $dumpseqs = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $seqids   = shift @ARGV if ($nextword eq '-seqids');

    $dumpseqs = 1 if ($nextword eq '-dumpseqs');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) && defined($seqids)) {
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

my $query = "select R.readname, SR.version from SEQ2READ SR left join READINFO R using(read_id) where seq_id = ?";
		
my $sth_read_name_and_version = $dbh->prepare($query);
&db_die("prepare($query) failed");
		
$query = "select seqlen,seq_hash,qual_hash,sequence,quality from SEQUENCE where seq_id = ?";

my $sth_sequence_data =  $dbh->prepare($query);
&db_die("prepare($query) failed");

foreach my $seq_id (split(/,/, $seqids)) {
    $sth_read_name_and_version->execute($seq_id);

    my ($readname, $version) = $sth_read_name_and_version->fetchrow_array();

    unless (defined($readname) && defined($version)) {
	print STDERR "***** Invalid sequence ID : $seq_id\n";
	next;
    }

    $sth_sequence_data->execute($seq_id);

    my ($seqlen,$seq_hash,$qual_hash,$sequence,$quality) = $sth_sequence_data->fetchrow_array();

    my $sequence = uncompress($sequence);
    my $quality = uncompress($quality);

    my $my_seq_hash = md5($sequence);
    my $my_qual_hash = md5($quality);

    print "##### Sequence $seq_id\n";
    print "##### Read     $readname\n";
    print "##### Version  $version\n";
    print "##### Length   $seqlen\n";

    print "\n";
    &showHash("Sequence hash in database ", $seq_hash);
    &showHash("Sequence hash recalculated", $my_seq_hash);
    
    print "\n";
    &showHash("Quality hash in database ", $qual_hash);
    &showHash("Quality hash recalculated", $my_qual_hash);
    
    print "\n";

    if ($dumpseqs) {
	my $filename = $organism . "_" . $seq_id . ".dmp";
	open(DUMPFILE, "> $filename");
	print DUMPFILE $sequence;
	close(DUMPFILE);
    }
}


$sth_read_name_and_version->finish;
$sth_sequence_data->finish;

$dbh->disconnect();

exit(0);

sub showHash {
    my $message = shift;
    my $hash = shift;

    print $message,"\n";

    my @bytes = unpack("C*", $hash);

    my $first = 1;

    foreach my $byte (@bytes) {
	print " " unless $first;
	printf "%02X", $byte;
	$first = 0;
    }

    print "\n";
}

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
    print STDERR "    -seqids\t\tComma-separated list of sequence IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -dumpseqs\t\tDump sequence strings to files\n";
}
