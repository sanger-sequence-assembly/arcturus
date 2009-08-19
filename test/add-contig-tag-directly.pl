#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;

use DataSource;

my $nextword;
my $instance;
my $organism;
my $host;
my $port;
my $depadded = 0;
my $verbose = 0;

my $contig_id;
my $tagtype;
my $systematic_id;
my $cstart;
my $cfinal;
my $strand;

while ($nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $host          = shift @ARGV if ($nextword eq '-host');
    $port          = shift @ARGV if ($nextword eq '-port');

    $depadded      = 1 if ($nextword eq '-depadded');

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

unless (defined($organism) && defined($instance)) {
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

my $query = "select tag_id from CONTIGTAG where tagtype= ? and systematic_id = ?";

my $sth_get_contig_tag = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CONTIGTAG(tagtype,systematic_id) values(?,?)";

my $sth_insert_contig_tag = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into TAG2CONTIG(tag_id,contig_id,cstart,cfinal,strand) values(?,?,?,?,?)";
my $sth_insert_tag_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $sth_get_consensus;
my $last_contig_id = -1;
my $depadded_to_padded;

if ($depadded) {
    $query = "select sequence from CONSENSUS where contig_id = ?";
    $sth_get_consensus = $dbh->prepare($query);
    &db_die("prepare($query) failed");
}

while (my $line = <STDIN>) {
    chop $line;

    my ($contig_id,$tagtype,$systematic_id,$cstart,$cfinal,$strand) = split(/,/, $line);

    $sth_get_contig_tag->execute($tagtype, $systematic_id);
    my ($tag_id) = $sth_get_contig_tag->fetchrow_array();

    if (!defined($tag_id)) {
	$sth_insert_contig_tag->execute($tagtype, $systematic_id);
	&db_die("insert contig tag ($tagtype, $systematic_id) failed");

	$tag_id = $dbh->{'mysql_insertid'};
    }

    if ($depadded) {
	$depadded_to_padded = &get_depadded_to_padded_offsets($sth_get_consensus, $contig_id)
	    unless ($contig_id == $last_contig_id);
	
	$cstart += $depadded_to_padded->[$cstart - 1];
	$cfinal += $depadded_to_padded->[$cfinal - 1];
	
	$last_contig_id = $contig_id;
    }
    
    $sth_insert_tag_mapping->execute($tag_id,$contig_id,$cstart,$cfinal,$strand);
    &db_die("insert tag mapping ($tag_id,$contig_id,$cstart,$cfinal,$strand) failed");

    print STDERR "Tag $systematic_id (contig $contig_id $cstart:$cfinal) added OK\n" if $verbose;
}

$sth_get_contig_tag->finish();
$sth_insert_contig_tag->finish();
$sth_insert_tag_mapping->finish();

$sth_get_consensus->finish() if $depadded;

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub get_depadded_to_padded_offsets {
    my $sth = shift;
    my $contig_id = shift;

    $sth->execute($contig_id);

    my ($sequence) = $sth->fetchrow_array();

    $sequence = uncompress($sequence);

    my @bytes = unpack("C*", $sequence);

    my $dash = ord('-');

    @bytes = map { $_ == $dash ? undef : 0 } @bytes;

    my $nbytes = scalar(@bytes);

    my $d = 0;

    my @newbytes;

    for (my $i = 0; $i < $nbytes; $i++) {
	if (!defined($bytes[$i])) {
	    $d += 1;
	} else {
	    push @newbytes, $d;
	}
    }

    return [@newbytes];
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-depadded\t\tTag positions are on depadded sequences\n";
}
