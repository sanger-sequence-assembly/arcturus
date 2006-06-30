#!/usr/local/bin/perl
#
# find-project-for-finishing-read.pl
#
# This script takes a list of finishing read names on STDIN and
# determines which project they should be allocated to, based on
# which contig(s) their shotgun predecessors are in.

use DBI;
use DataSource;

use strict;

my $verbose = 0;
my $instance;
my $organism;
my $anystrand = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $verbose = 1 if ($nextword eq '-verbose');

    $anystrand = 1 if ($nextword eq '-anystrand');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism)) {
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

my $query = "select project_id, name from PROJECT";

my $sth = $dbh->prepare($query);
&db_die("failed to prepare \"$query\"");

$sth->execute();
&db_die("failed to execute \"$query\"");

my %projectid2name;

while (my ($projid, $projname) = $sth->fetchrow_array()) {
    $projectid2name{$projid} = $projname;
}

$sth->finish();

$query = "create temporary table currentcontigs (" .
    " contig_id mediumint unsigned not null," .
    " project_id int unsigned not null," .
    " primary key (contig_id)," .
    " key (project_id))";

my $rc = $dbh->do($query);
&db_die("failed to create temporary table currentcontigs");

$query = "insert into currentcontigs(contig_id,project_id)" .
    " select CONTIG.contig_id,project_id" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id" .
    " where C2CMAPPING.parent_id is null";

$rc = $dbh->do($query);
&db_die("failed to populate temporary table currentcontigs");

print STDERR "temporary table currentcontigs created with $rc rows\n" if $verbose;

$query = "select read_id,template_id,strand from READS where readname = ?";

my $sth_read2template = $dbh->prepare($query);
&db_die("failed to prepare \"$query\"");

$query = "select READS.read_id,seq_id,readname" .
    " from READS left join SEQ2READ using(read_id)" .
    " where template_id = ?";

my $sth_template2readseq_loose =  $dbh->prepare($query);
&db_die("failed to prepare \"$query\"");

$query .= " and strand=?";

my $sth_template2readseq_strict =  $dbh->prepare($query);
&db_die("failed to prepare \"$query\"");

$query = "select currentcontigs.contig_id,project_id" .
    " from MAPPING left join currentcontigs using(contig_id)" .
    " where seq_id = ? and project_id is not null";

my $sth_seq2contig = $dbh->prepare($query);
&db_die("failed to prepare \"$query\"");

while (my $line = <STDIN>) {
    my ($finreadname) = $line =~ /^\s*(\S+)/;

    next unless defined($finreadname);

    print STDERR "Finishing read $finreadname" if $verbose;

    $sth_read2template->execute($finreadname);

    my ($finreadid,$templateid,$strand) = $sth_read2template->fetchrow_array();

    unless (defined($finreadid) && defined($templateid)) {
	print STDERR $verbose ? " not found\n" : "Unable to find read $finreadname\n";
	next;
    }

    print STDERR "  (read_id $finreadid, template_id $templateid)\n" if $verbose;

    my $votes = {};
    my $allvotes = 0;

    for (my $pass = 1; $pass < 3; $pass++) {
	my $sth;

	if ($pass == 1) {
	    $sth_template2readseq_strict->execute($templateid, $strand);
	    $sth = $sth_template2readseq_strict;
	} else {
	    $sth_template2readseq_loose->execute($templateid);
	    $sth = $sth_template2readseq_loose;
	    print STDERR "---- Commencing loose pass, no matches found in strict pass ----\n";
	}

	while (my ($readid, $seqid, $readname) = $sth->fetchrow_array()) {
	    next if ($readid == $finreadid);

	    print STDERR "    Shotgun read $readname (read_id $readid, seq_id $seqid)"
		if $verbose;

	    $sth_seq2contig->execute($seqid);

	    my ($contigid, $projectid) = $sth_seq2contig->fetchrow_array();

	    if (defined($contigid) && defined($projectid)) {
		my $project = $projectid2name{$projectid};
		print STDERR " in contig $contigid, project $project\n"
		    if $verbose;
	    
		if (defined($votes->{$project})) {
		    $votes->{$project}++;
		} else {
		    $votes->{$project} = 1;
		}

		$allvotes++;
	    } else {
		print STDERR ", unallocated\n" if $verbose;
	    }
	}

	last if (($allvotes > 0) || !$anystrand);
    }

    my $bestproject;
    my $bestscore = 0;

    if ($allvotes > 0) {
	my @projects = keys(%{$votes});
	if (scalar(@projects) == 1) {
	    $bestproject = $projects[0];
	} else {
	    print STDERR "Votes:" if $verbose;
	    foreach my $project (@projects) {
		if ($votes->{$project} > $bestscore) {
		    $bestproject = $project;
		    $bestscore = $votes->{$project};
		    print STDERR " $project=" . $votes->{$project} if $verbose;
		}
	    }
	    print STDERR "\n" if $verbose;
	}
	
	print "$finreadname $bestproject\n";
	print STDERR "$finreadname $bestproject by ", $votes->{$bestproject}, " votes\n"
	    if $verbose;
    } else {
	print STDERR "Unable to allocate $finreadname to a project\n";
    }

    print STDERR "\n\n" if $verbose;
}

$sth_read2template->finish();
$sth_template2readseq_loose->finish();
$sth_template2readseq_strict->finish();
$sth_seq2contig->finish();

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
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\tVerbose output\n";
    print STDERR "    -anystrand\t\tAllow finishing read to be placed with read from\n";
    print STDERR "\t\t\topposite strand if no match can be found to same strand\n";
}
