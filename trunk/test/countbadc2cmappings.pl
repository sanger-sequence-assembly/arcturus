#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $organism;
my $instance;
my $usenew = 0;
my $nextword;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $usenew = 1 if ($nextword eq '-usenew');
}

unless (defined($instance) && defined($organism)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase for $organism" unless $adb;

my $dbh = $adb->getConnection();

my $mappingtable = $usenew ? 'NEWC2CMAPPING' : 'C2CMAPPING';
my $segmenttable = $usenew ? 'NEWC2CSEGMENT' : 'C2CSEGMENT';

my $query = "select contig_id,parent_id,mapping_id,direction from $mappingtable";

my $mapping_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$query = "select cstart,pstart,length from $segmenttable where mapping_id = ? order by cstart asc";

my $segment_stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$mapping_stmt->execute();

my $lastcstart;
my $lastpstart;
my $lastlength;

my $allerrors = 0;

while (my ($contigid, $parentid, $mappingid, $direction) =
       $mapping_stmt->fetchrow_array()) {
    my $reverse = $direction eq 'Reverse';

    $segment_stmt->execute($mappingid);

    undef $lastcstart;
    undef $lastpstart;
    undef $lastlength;

    my $errors = 0;

    while (my ($cstart, $pstart, $length) = $segment_stmt->fetchrow_array()) {
	my $problem = 0;

	$problem = 1 if (defined($lastcstart) &&
			 $cstart < $lastcstart + $lastlength);

	$problem = 1 if (defined($lastpstart) &&
			 ( (!$reverse && ($pstart < $lastpstart + $lastlength)) ||
			   ($reverse && ($pstart > $lastpstart - $lastlength))));

	if ($problem) {
	    $errors++;

	    print "Contig $contigid parent $parentid mapping $mappingid sense $direction\n"
		if ($errors == 1);

	    print "\n";

	    printf "  PREV: %8d %8d %8d\n",$lastcstart,$lastpstart,$lastlength;
	    printf "  THIS: %8d %8d %8d\n",$cstart,$pstart,$length;
	}

	($lastcstart, $lastpstart, $lastlength) = ($cstart, $pstart, $length);
    }

    print "\n\n" if $errors;

    $allerrors += $errors;

    $segment_stmt->finish();
}

$mapping_stmt->finish();

$dbh->disconnect();

print "In total, $allerrors errors were found.\n";

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

