#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;

use DataSource;

my $instance;
my $organism;
my $limit;
my $verbose = 0;
my $firstparent;
my $lastparent;

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $firstparent   = shift @ARGV if ($nextword eq '-firstparent');
    $lastparent    = shift @ARGV if ($nextword eq '-lastparent');

    $limit         = shift @ARGV if ($nextword eq '-limit');

    $verbose       = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => { RaiseError => 1, PrintError => 1});

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my %consensus;

my $query;
my $sth;

unless (defined($firstparent) && defined($lastparent)) {
    print STDERR "Determining range of parent contig IDs ... ";

    $query = "select min(parent_id),max(parent_id) from C2CMAPPING";

    if (defined($firstparent)) {
	$query .= " where parent_id >= $firstparent";
    } elsif (defined($lastparent)) {
	$query .= " where parent_id <= $lastparent";
    }

    $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();

    ($firstparent, $lastparent) = $sth->fetchrow_array();

    $sth->finish();

    print STDERR "$firstparent $lastparent\n";
}

print STDERR "Determining range of child contig IDs ... ";

$query = "select min(contig_id),max(contig_id) from C2CMAPPING where parent_id between ? and ?";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($firstparent, $lastparent);

my ($firstchild, $lastchild) = $sth->fetchrow_array();

$sth->finish();

if (defined($firstchild) && defined($lastchild)) {
    print STDERR "$firstchild $lastchild\n";
} else {
    $dbh->disconnect();
    print STDERR " NO CHILDREN ... EXITING\n";
    exit(1);
}

print STDERR "Fetching consensus sequences for contigs ... ";

my $query = "select contig_id,sequence from CONSENSUS where contig_id between ? and ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($firstparent, $lastchild);

my $ncontigs = 0;
my $nseqlen = 0;

while (my ($contig_id,$sequence) = $sth->fetchrow_array()) {
    $sequence = uc(uncompress($sequence));
    $consensus{$contig_id} = $sequence;
    $ncontigs++;
    $nseqlen += length($sequence);
}

$sth->finish();

print STDERR " got $nseqlen bp from $ncontigs contigs\n";

print STDERR "Checking contig-to-contig segments ...\n";

$query = "select parent_id,contig_id,direction,S.pstart,S.cstart,S.length" .
    " from C2CMAPPING M left join C2CSEGMENT S using (mapping_id)" .
    " where parent_id between ? and ?" .
    " order by parent_id asc,contig_id asc,M.pstart asc";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($firstparent, $lastparent);

while (my ($parent_id,$child_id,$direction,$pstart,$cstart,$seglen) =
       $sth->fetchrow_array()) {
    $pstart -= $seglen - 1 if ($direction eq 'Reverse');
    
    my $pseq = substr($consensus{$parent_id}, $pstart - 1, $seglen);
    my $cseq = substr($consensus{$child_id}, $cstart - 1, $seglen);

    if ($direction eq 'Reverse') {
	$pseq = reverse($pseq);
	$pseq =~ tr/ACGT/TGCA/;
    }

    print "$parent_id,$child_id,$direction,$pstart,$cstart,$seglen\n$pseq\n$cseq\n\n"
	if ($pseq ne $cseq);
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
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-firstcontig\tID of first parent contig to check\n";
    print STDERR "-lastcontig\tID of last parent contig to check\n";
    print STDERR "\n";
    print STDERR "-limit\t\tShow only the first N contigs\n";
    print STDERR "-verbose\tProduce verbose output\n";
}
