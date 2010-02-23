#!/usr/local/bin/perl
#
# assign-contigs-to-projects.pl
#
# This script assigns one or more contigs to specified projects.

use strict;

use DBI;
use DataSource;

my $verbose = 0;

my $instance;
my $organism;
my $mapfile;

my $testing = 0;

my @pwinfo = getpwuid($<);
my $me = $pwinfo[0];

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $mapfile  = shift @ARGV if ($nextword eq '-mapfile');

    $testing = 1 if ($nextword eq '-testing');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($mapfile)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

open(MAPFILE, $mapfile) || die "Failed to open map file $mapfile for reading";

my @assignments;

while (my $line = <MAPFILE>) {
    chop($line);
    my ($contig_id, $projectname) = split(/\s+/, $line);

    push @assignments, [$contig_id, $projectname];
}

close(MAPFILE);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select project_id,name from PROJECT";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my %project_name_to_id;

while (my ($project_id, $project_name) = $sth->fetchrow_array()) {
    $project_name_to_id{$project_name} = $project_id;
}

$sth->finish();

$query = "select CC.length,CC.nreads,CC.created,CC.project_id,P.name" .
    " from CURRENTCONTIGS CC left join PROJECT P using(project_id)" .
    " where contig_id = ?";

my $stmt_get_old_project_id = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "update CONTIG set project_id = ? where contig_id = ?";

my $stmt_update_contig = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into CONTIGTRANSFERREQUEST(contig_id,old_project_id,new_project_id,requester," .
    "opened,requester_comment,reviewer,reviewed,status,closed) values (?,?,?,?,now(),?,?,now(),?,now())";

my $stmt_insert_new_ctr = $dbh->prepare($query);
&db_die("prepare($query) failed");

$dbh->begin_work();

my $problems = 0;

my $comment = "Automated transfer using assign-contigs-to-projects.pl";

foreach my $mapping (@assignments) {
    my ($contig_id, $new_project_name) = @{$mapping};

    my $new_project_id = $project_name_to_id{$new_project_name};

    unless (defined($new_project_id)) {
	print STDERR "ERROR: Contig $contig_id: project $new_project_name does not exist.\n";
	$problems++;
	next;
    }

    $stmt_get_old_project_id->execute($contig_id);

    my ($contig_length,$contig_reads,$contig_created,$old_project_id, $old_project_name) =
	$stmt_get_old_project_id->fetchrow_array();

    unless (defined($contig_length)) {
	print STDERR "ERROR: Contig $contig_id is not a current contig.\n";
	$problems++;
	next;
    }

    my $rc = $stmt_update_contig->execute($new_project_id, $contig_id);

    if ($rc != 1) {
	print STDERR "ERROR; Failed to update project ID for contig $contig_id: $DBI::err ($DBI::errstr)\n";
	$problems++;
	next;
    }

    $rc = $stmt_insert_new_ctr->execute($contig_id,$old_project_id,$new_project_id,$me,$comment,,$me,'done');

    if ($rc != 1) {
	print STDERR "ERROR; Failed to create contig transfer request record for contig $contig_id:" .
	    " $DBI::err ($DBI::errstr)\n";
	$problems++;
	next;
    }

    print "Contig $contig_id was moved from $old_project_name to $new_project_name\n";
}

if ($testing || $problems > 0) {
    $dbh->rollback();
} else {
    $dbh->commit();
}

$stmt_get_old_project_id->finish();
$stmt_update_contig->finish();
$stmt_insert_new_ctr->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(1);
}


sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -mapfile\t\tName of file containing contig ID to project mappings\n";
}
