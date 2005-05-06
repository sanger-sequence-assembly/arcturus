#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
}

unless (defined($instance) && defined($organism)) {
    &showUsage();
    exit(0);
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $query = "create temporary table currentcontigs" .
    " as select CONTIG.contig_id,nreads,length,updated,project_id" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $ncontigs = $stmt->execute();
&db_die("Failed to execute query \"$query\"");

$query = "select project_id, name from PROJECT";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

my %projectid2name;

while (my ($projid,$projname) = $stmt->fetchrow_array()) {
    $projectid2name{$projid} = $projname;
}

$stmt->finish();

$query = "select seq_id from READS left join SEQ2READ using(read_id) where readname = ?";

my $stmt_read2seq = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select currentcontigs.contig_id,nreads,length,updated,project_id" .
    " from MAPPING left join currentcontigs using(contig_id) where seq_id = ?";

my $stmt_seq2contig = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

while (my $line = <STDIN>) {
    my ($readname) = $line =~ /\s*(\S+)/;

    $stmt_read2seq->execute($readname);

    if (my ($seqid) = $stmt_read2seq->fetchrow_array()) {
	$stmt_seq2contig->execute($seqid);

	my $ctgcount = 0;

	while (my ($contig_id,$nreads,$ctglen,$updated,$projid) =
	       $stmt_seq2contig->fetchrow_array()) {
	    $ctgcount++;

	    my $projname = $projectid2name{$projid};
	    $projname = $organism . "/" . $projid unless defined($projname);

	    print "$readname contig=$contig_id project=$projname contig_length=$ctglen" .
		" contig_reads=$nreads contig_updated=$updated\n",
	}

	if ($ctgcount < 1) {
	    print "$readname is free\n";
	}

	$stmt_seq2contig->finish();
    } else {
	printf "$readname NOT KNOWN\n";
    }

    $stmt_read2seq->finish();
}


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
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
}
