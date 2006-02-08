#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $history = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $history = 1 if ($nextword eq '-history');
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

my ($query, $stmt);

unless ($history) {
    $query = "create temporary table currentcontigs" .
	" as select CONTIG.contig_id,gap4name,nreads,length,created,updated,project_id" .
	" from CONTIG left join C2CMAPPING" .
	" on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    my $ncontigs = $stmt->execute();
    &db_die("Failed to execute query \"$query\"");
}

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

$query = "select readname,seq_id from READS left join SEQ2READ using(read_id) where readname like ? order by readname asc";

my $stmt_read2seq = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $contigtable = $history ? "CONTIG" : "currentcontigs";

$query = "select $contigtable.contig_id,gap4name,nreads,length,created,updated,project_id,cstart,cfinish,direction" .
    " from MAPPING left join $contigtable using(contig_id) where seq_id = ? and gap4name is not null";

my $stmt_seq2contig = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

while (my $line = <STDIN>) {
    my ($readlike) = $line =~ /\s*(\S+)/;

    $readlike =~ s/\*/%/g;

    $stmt_read2seq->execute($readlike);

    my $ctgcount = 0;
    my $seqcount = 0;

    while (my ($readname,$seqid) = $stmt_read2seq->fetchrow_array()) {
	$seqcount++;

	$stmt_seq2contig->execute($seqid);

	while (my ($contig_id,$gap4name,$nreads,$ctglen,$created,$updated,$projid,$cstart,$cfinish,$direction) =
	       $stmt_seq2contig->fetchrow_array()) {
	    $ctgcount++;

	    my $projname = $projectid2name{$projid};
	    $projname = $organism . "/" . $projid unless defined($projname);

	    ($cstart,$cfinish) = ($cfinish, $cstart) if ($direction eq 'Reverse');

	    print "\n$readname is in $gap4name in $projname at $cstart..$cfinish\n" .
		"(contig_id=$contig_id length=$ctglen reads=$nreads created=$created updated=$updated)\n",
	}

	$stmt_seq2contig->finish();

	if ($ctgcount < 1) {
	    print "\n$readname is free\n\n";
	}
    }

    if ($seqcount == 0) {
	print "$readlike NOT KNOWN\n";
    }

    $stmt_read2seq->finish();

    print "\n";
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
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-history\t\tSearch for the read in all contigs, not just the current contig set\n";
}
