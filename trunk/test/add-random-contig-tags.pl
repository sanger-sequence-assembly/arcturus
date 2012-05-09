#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $organism;
my $instance;
my $howmany;
my $tagname;
my $tagtext;
my $nextword;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $howmany = shift @ARGV if ($nextword eq '-howmany');
    $tagname = shift @ARGV if ($nextword eq '-tagname');
    $tagtext = shift @ARGV if ($nextword eq '-tagtext');
}

unless (defined($instance) && defined($organism) && defined($howmany) && defined($tagname)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

$tagtext = "Random test tag" unless defined($tagtext);

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase for $organism" unless $adb;

my $dbh = $adb->getConnection();

my $query = "select CONTIG.contig_id,nreads,length" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id" .
    " where C2CMAPPING.parent_id is null";

my $sth = $dbh->prepare($query);
&db_die("Failed to prepare query \"$query\"");

$sth->execute();
&db_die("Failed to execute query \"$query\"");

my @contiginfo;

my $totreads = 0;
my $totlen = 0;

while (my ($contigid, $nreads, $ctglen) = $sth->fetchrow_array()) {
    push @contiginfo, [$contigid, $nreads, $ctglen];
    $totreads += $nreads;
    $totlen += $ctglen;
}

$sth->finish();

$query = "insert into CONTIGTAG(contig_id,tagtype,pstart,pfinal,strand,comment)" .
    " values(?,?,?,?,?,?)";

$sth = $dbh->prepare($query);
&db_die("Failed to prepare query \"$query\"");

my $ncontigs = scalar(@contiginfo);

print STDERR "Found $ncontigs current contigs, $totlen bp, $totreads reads\n";

for (my $tagcount = 0; $tagcount < $howmany; $tagcount++) {
    my $ctgindex = int(rand($ncontigs));

    my ($contigid, $nreads, $ctglen) = @{$contiginfo[$ctgindex]};

    my $pstart = 1 + int(rand($ctglen));
    my $pfinal = 1 + int(rand($ctglen));

    my $tagcomment = $tagtext . sprintf(" #%06d", $tagcount);

    if ($pstart < $pfinal) {
	$sth->execute($contigid, $tagname, $pstart, $pfinal, 'F', $tagcomment);
    } else {
	$sth->execute($contigid, $tagname, $pfinal, $pstart, 'R', $tagcomment);
    }

    &db_die("Failed to execute query \"$query\"");
}

$sth->finish();

$dbh->disconnect();

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-howmany\tThe number of tags to add\n";
    print STDERR "-tagname\tThe tag name to use\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-tagtext\tThe tag text to use\n";
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}
