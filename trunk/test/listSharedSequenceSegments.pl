#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;

use DataSource;

my $instance;
my $organism;

my $parent_id;
my $child_id;

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $parent_id     = shift @ARGV if ($nextword eq '-parent');
    $child_id      = shift @ARGV if ($nextword eq '-child');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($parent_id) && defined($child_id)) {
    &showUsage("One or more mandatory parameters missing");
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

my $query = "select M1.seq_id,M1.cstart,M1.cfinish,M1.direction,M2.cstart,M2.cfinish,M2.direction" .
    " from MAPPING M1 left join MAPPING M2 using(seq_id)" .
    " where M1.contig_id = ? and M2.contig_id = ? order by M1.cstart asc";

my $sth_get_shared_seqs = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select S.rstart,S.cstart,S.length from MAPPING M left join SEGMENT S using(mapping_id)" .
    " where seq_id = ? and contig_id = ? order by rstart asc";

my $sth_get_segments =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth_get_shared_seqs->execute($parent_id, $child_id);

while (my ($seqid,$pstart,$pfinish,$pdirection,$cstart,$cfinish,$cdirection) =
       $sth_get_shared_seqs->fetchrow_array()) {
    printf "%8d  %8d %8d  %7s  %8d %8d %7s\n", $seqid,$pstart,$pfinish,$pdirection,$cstart,$cfinish,$cdirection;

    $sth_get_segments->execute($seqid, $parent_id);

    print "\nIn contig $parent_id:\n";

    while (my ($rstart, $cstart, $seglen) = $sth_get_segments->fetchrow_array()) {
	my $offset = $cstart - $rstart;

	if ($pdirection eq 'Reverse') {
	    $rstart = $rstart - $seglen + 1;
	    $cstart = $cstart + $seglen - 1;

	    $offset = $cstart + $rstart;
	}

	printf "%6d  %6d  %6d\n", $rstart, $seglen, $offset;
    }

    $sth_get_segments->execute($seqid, $child_id);

    print "\nIn contig $child_id:\n";

    while (my ($rstart, $cstart, $seglen) = $sth_get_segments->fetchrow_array()) {
	my $offset = $cstart - $rstart;

	if ($cdirection eq 'Reverse')  {
	    $rstart = $rstart - $seglen + 1;
	    $cstart = $cstart + $seglen - 1;

	    $offset = $cstart + $rstart;
	}

	printf "%6d  %6d  %6d\n", $rstart, $seglen, $offset;
    }

    print "\n----------------------------------------------------------------------\n";
}

$sth_get_shared_seqs->finish();

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
    print STDERR "-parent\t\tParent contig ID\n";
    print STDERR "-child\t\tChild contig ID\n";
#    print STDERR "\n";
#    print STDERR "OPTIONAL PARAMETERS:\n";
#    print STDERR "\n";
}
