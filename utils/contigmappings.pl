#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigid;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigid = shift @ARGV if ($nextword eq '-contig');
}

unless (defined($instance) && defined($organism) && defined($contigid)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $query = "SELECT seq_id,mapping_id,cstart,cfinish,direction FROM MAPPING WHERE contig_id = ? ORDER BY cstart ASC";

my $seq_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$seq_stmt->execute($contigid);
&db_die("Failed to execute query \"$query\"");

$query = "SELECT cstart,rstart,length FROM SEGMENT WHERE mapping_id = ? ORDER BY rstart ASC";

my $seg_stmt =  $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "SELECT readname,READINFO.read_id FROM SEQ2READ LEFT JOIN READINFO USING(read_id) WHERE seq_id = ?";

my $read_stmt =  $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

while (my ($seqid,$mappingid,$cstart,$cfinish,$direction) = $seq_stmt->fetchrow_array()) {
    $read_stmt->execute($seqid);
    my ($readname, $readid) = $read_stmt->fetchrow_array();
    $read_stmt->finish();

    printf "%-20s (READID %8d, SEQID %8d)  %8d : %8d  %s\n\n", $readname, $readid, $seqid, $cstart, $cfinish, $direction;

    $seg_stmt->execute($mappingid);

    while (my ($segcstart, $segrstart, $seglength) = $seg_stmt->fetchrow_array()) {
	my $segcfinish = $segcstart + $seglength - 1;

	my $segrfinish;

	if ($direction eq 'Forward') {
	    $segrfinish = $segrstart + ($seglength - 1);
	} else {
	    $segrfinish = $segrstart - ($seglength - 1);
	}

	printf "%8d : %8d  ==>  %8d : %8d\n", $segcstart, $segcfinish, $segrstart, $segrfinish;
    }

    $seg_stmt->finish();

    print "\n";
}

$seq_stmt->finish();

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
    print STDERR "-contig\t\tID of contig\n";
}
