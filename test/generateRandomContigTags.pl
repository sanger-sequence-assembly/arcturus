#!/usr/local/bin/perl
#
# generateRandomContigTags
#
# This script generates a set of random contig tags as a
# test data set for the add-contig-tag-via-http.pl script

use strict;

use DBI;
use DataSource;

my $instance;
my $organism;
my $minlen = 5000;
my $tagtype = 'RNDM';
my $howmany;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $tagtype = shift @ARGV if ($nextword eq '-tagtype');

    $howmany = shift @ARGV if ($nextword eq '-howmany');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($howmany)) {
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

my $query = "select contig_id,length from CURRENTCONTIGS where length >= ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($minlen);
&db_die("execute($query) failed");

my @contiginfo = ();

while (my ($contig_id, $ctglen) = $sth->fetchrow_array()) {
    push @contiginfo, [$contig_id, $ctglen];
}

$sth->finish();
$dbh->disconnect();

my $ncontigs = scalar(@contiginfo);

for (my $tagcount = 0; $tagcount < $howmany; $tagcount++) {
    my $ctgindex = int(rand($ncontigs));

    my ($contig_id, $ctglen) = @{$contiginfo[$ctgindex]};
    
    my $pstart = 1 + int(rand($ctglen));
    my $pfinal = 1 + int(rand($ctglen));

    my $strand = ($pstart < $pfinal) ? 'F' : 'R';

    ($pstart, $pfinal) = ($pfinal, $pstart) if ($pstart > $pfinal);
    
    my $systematic_id = $tagtype . sprintf("_%06d", $tagcount);

    printf "$contig_id,$tagtype,$systematic_id,$pstart,$pfinal,$strand\n";
}

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
    print STDERR "    -howmany\t\tHow many random tags to generate\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum contig length [default: 5000]\n";
    print STDERR "    -tagtype\t\tTag type [default: RNDM]\n";
}
