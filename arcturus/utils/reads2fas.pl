#!/usr/local/bin/perl
#
# reads2fas.pl
#
# This script extracts reads and generates one or more FASTA files

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

use strict;

my $verbose = 0;
my $instance;
my $organism;
my $readsperfile = 10000;
my $filename;
my $clip = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $filename = shift @ARGV if ($nextword eq '-filename');

    $readsperfile = shift @ARGV if ($nextword eq '-readsperfile');

    $clip = 1 if ($nextword eq '-clip');

    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($filename)) {
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

my @queries = ('create temporary table clipping like QUALITYCLIP',
	       'insert into clipping select * from QUALITYCLIP',
	       'update clipping,SEQVEC set qleft=svright where clipping.seq_id=SEQVEC.seq_id and svleft=1',
	       'update clipping,SEQVEC set qright=svleft where clipping.seq_id=SEQVEC.seq_id and svleft>1');

my $query;

foreach $query (@queries) {
    my $rc = $dbh->do($query);
    &db_die("do($query) failed");
    $rc = "no" unless ($rc > 0);
    print STDERR "Executed \"$query\", $rc rows changed\n" if $verbose;
}

my $ndone = 0;
my $nfile = 1;

$query = "SELECT SEQUENCE.seq_id,sequence,qleft,qright from SEQUENCE left join clipping using(seq_id)";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

printf STDERR "%8d", $ndone if $verbose;
my $format = "\010\010\010\010\010\010\010\010\010%8d";

my $fasfilename = $filename . sprintf("%04d", $nfile) . ".fas";

my $fasfh = new FileHandle($fasfilename, "w");

while (my ($seqid, $sequence, $qleft, $qright) = $sth->fetchrow_array()) {
    $ndone++;

    if (($ndone % $readsperfile) == 0) {
	$fasfh->close();
	$nfile++;
	$fasfilename = $filename . sprintf("%04d", $nfile) . ".fas";
	$fasfh = new FileHandle($fasfilename, "w");
    }

    $sequence = uncompress($sequence);

    printf $fasfh ">%s%06d:%d-%d\n", $organism, $seqid, $qleft+1, $qright-1;

    $sequence = substr($sequence, $qleft, $qright-$qleft-1) if ($clip);

    while (length($sequence)) {
	print $fasfh substr($sequence, 0, 50),"\n";
	$sequence = substr($sequence, 50);
    }

    printf STDERR $format, $ndone if ($verbose && ($ndone % 50) == 0);
}

$fasfh->close();

if ($verbose) {
    printf STDERR $format, $ndone;
    print STDERR "\n";
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
    print STDERR "    -filename\t\tBase name of output FASTA file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\tVerbose output\n";
    print STDERR "    -readsperfile\tMaximum number of reads per file\n";
    print STDERR "    -clip\t\tClip sequences before writing to file\n";
}