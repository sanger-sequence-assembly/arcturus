#!/usr/local/bin/perl
#
# testsolexarecall.pl
#
# This script extracts one or more Solexa reads

use strict;

use DBI;
use DataSource;

my $instance;
my $organism;
my $fetchall = 0;
my $lowmem = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $fetchall = 1 if ($nextword eq '-fetchall');
    $lowmem = 1 if ($nextword eq '-lowmem');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

die "Failed to create database object" unless defined($dbh);

if ($fetchall) {
    &fetchAll($dbh, $lowmem);
} else {
    &fetchNamedReads($dbh);
}

$dbh->disconnect();

exit(0);

sub fetchAll {
    my $dbh = shift;
    my $lowmem = shift;

    my $ndone = 0;

    printf STDERR "%8d", $ndone;
    my $format = "\010\010\010\010\010\010\010\010%8d";

    my $sth = $dbh->prepare("select id,name,sequence,quality from SOLEXA");

    $sth->{mysql_use_result} = 1 if $lowmem;

    $sth->execute();

    while (my ($readid,$name,$sequence,$quality) = $sth->fetchrow_array()) {
	$ndone++;
	printf STDERR $format, $ndone if (($ndone % 5) == 0);
    }

    print STDERR "\n";

    $sth->finish();
}

sub fetchNamedReads {
    my $dbh = shift;

    my $ndone = 0;

    printf STDERR "%8d", $ndone;
    my $format = "\010\010\010\010\010\010\010\010%8d";

    my $sth = $dbh->prepare("select id,sequence,quality from SOLEXA where name = ?");

    while (my $line = <STDIN>) {
	my ($readname) = $line =~ /^\s*(\S+)\s*/;

	next unless defined($readname);

	$sth->execute($readname);

	while (my ($readid,$sequence,$quality) = $sth->fetchrow_array()) {
	    $ndone++;
	    printf STDERR $format, $ndone if (($ndone % 5) == 0);
	}
    }

    print STDERR "\n";

    $sth->finish();
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -fetchall\t\tFetch all reads\n";
    print STDERR "    -lowmem\t\tUse techniques to reduce memory usage\n";
}
