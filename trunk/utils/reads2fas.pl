#!/usr/local/bin/perl
#
# reads2fas.pl
#
# This script extracts reads in FASTA or FASTQ format

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

use strict;

my $verbose = 0;
my $instance;
my $organism;
my $filename;
my $clip = 0;
my $fastq = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $filename = shift @ARGV if ($nextword eq '-filename');

    $clip = 1 if ($nextword eq '-clip');

    $fastq = 1 if ($nextword eq '-fastq');

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

my $fields = "readname,sequence,qleft,qright";

$fields .= ",quality" if $fastq;

my $tables = "(READINFO left join " .
    "(SEQ2READ left join " .
    "(SEQUENCE left join QUALITYCLIP using(seq_id))".
    " using(seq_id))" .
    " using(read_id)) where version = 0";

$query = "SELECT $fields from $tables";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

printf STDERR "%8d", $ndone if $verbose;
my $format = "\010\010\010\010\010\010\010\010\010%8d";

my $fasfh = new FileHandle($filename, "w");

while (my ($readname, $sequence, $qleft, $qright, $quality) = $sth->fetchrow_array()) {
    $ndone++;

    $sequence = uncompress($sequence);

    if ($fastq) {
	printf $fasfh "@%s\n", $readname;
	print $fasfh $sequence,"\n+\n";

	my $quality = uncompress($quality);

	my @bq = unpack("c*", $quality);

	my @fq = map { ($_ <= 93? $_ : 93) + 33 } @bq;

	$quality = pack("c*", @fq);

	print $fasfh $quality,"\n";
    } else {
	printf $fasfh ">%s %d %d\n", $readname, $qleft+1, $qright-1;

	$sequence = substr($sequence, $qleft, $qright-$qleft-1) if ($clip);

	while (length($sequence)) {
	    print $fasfh substr($sequence, 0, 50),"\n";
	    $sequence = substr($sequence, 50);
	}
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
    print STDERR "    -filename\t\tName of output file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -fastq\t\tGenerate a FASTQ output file\n";
    print STDERR "    -verbose\t\tVerbose output\n";
    print STDERR "    -clip\t\tClip sequences before writing to file\n";
    print STDERR "\t\t\t(Not available in FASTQ mode)\n";
}
