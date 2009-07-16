#!/usr/local/bin/perl
#
# c2cmappingtest
#
# This script tests the speed of constructing a graph of parent-to-child
# mappings for contigs in a CAF file

use strict;

use DBI;
use DataSource;

my $verbose = 0;

my $instance;
my $organism;

my $caf;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $caf  = shift @ARGV if ($nextword eq '-caf');
}


unless (defined($organism) &&
	defined($instance) &&
	defined($caf)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

die "File $caf does not exist" unless -f $caf;

die "Cannot read file $caf" unless -r $caf;

open(CAF, $caf);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select CURRENTCONTIGS.contig_id from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS"
    . " where READINFO.readname = ? "
    . " and READINFO.read_id = SEQ2READ.read_id"
    . " and SEQ2READ.seq_id = MAPPING.seq_id"
    . " and MAPPING.contig_id = CURRENTCONTIGS.contig_id";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

while (my $line = <CAF>) {
    if ($line =~ /^Sequence\s+:\s+(\S+)/) {
	my $seqname = $1;

	$line = <CAF>;

	next unless ($line =~ /^Is_contig/);

	my %af = ();

	while ($line = <CAF>) {
	    last if $line =~ /^\s*$/;

	    if ($line =~ /^Assembled_from\s+(\S+)\s+/) {
		$af{$1} = 1;
	    }
	}

	my @readnames = sort keys %af;

	print "$seqname has " . scalar(@readnames) . " reads\n";

	my %contigs;

	foreach my $readname (@readnames) {
	    $sth->execute($readname);
	    my ($contigid) = $sth->fetchrow_array();

	    next unless defined($contigid);

	    $contigs{$contigid} = 0 unless defined($contigs{$contigid});

	    $contigs{$contigid} += 1;
	}

	my @contigids = sort keys %contigs;

	print "$seqname is linked to " . scalar(@contigids) . " parents\n";

	foreach my $contigid (@contigids) {
	    print "\t$contigid\t", $contigs{$contigid}, "\n";
	}
    }
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
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -caf\t\tName of CAF file\n";
}
