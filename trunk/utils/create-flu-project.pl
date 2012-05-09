#!/usr/local/bin/perl
#
# create-flu-project
#
# This script sets up a flu project

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use File::Basename;

my $cmd = $0;

my $verbose = 0;

my $instance;
my $organism;
my $strain;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $strain   = shift @ARGV if ($nextword eq '-strain');


    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	defined($strain)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $creator = $ENV{'USER'};

die "Could not determine username" unless defined($creator);

my $directory = `pfind -q -u $strain`;

die "Could not determine directory for $strain"
    unless (defined($directory) && length($directory) > 0);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

$dbh->begin_work;

print STDERR "Creating an assembly for $strain ...\n";

my $query = "insert into ASSEMBLY(name,creator,created) values (?,?,now())";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $assembly = uc($strain);

$sth->execute($assembly, $creator);
&db_die("execute($query) failed");

my $assembly_id = $dbh->{'mysql_insertid'};

$sth->finish();

print STDERR "Done: assembly ID is $assembly_id.\n";

print STDERR "Creating a project for $strain ...\n";

$query = "insert into PROJECT(name,creator,assembly_id,directory,created)" .
    " values(?,?,?,?,now())";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $project = $assembly;

$sth->execute($project, $creator, $assembly_id, $directory);
&db_die("execute($query) failed");

my $project_id = $dbh->{'mysql_insertid'};

print STDERR "Done: project ID is $project_id.\n";

print STDERR "Importing reads for $strain ...\n";

my $read_loader_cmd = dirname($cmd) . "/read-loader -instance $instance -organism $organism" .
    " -source traceserver -group $strain";

my $rc = system($read_loader_cmd);

print STDERR "Done: return code is $rc.\n";

die "Read loader command failed with error code $rc" unless $rc == 0;

print STDERR "Updating information in CLONE table ...\n";

$query = "update CLONE set assembly_id = ? where name like ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $clone_name = $strain . '%';

$rc = $sth->execute($assembly_id, $clone_name);
&db_die("execute($query) failed");

print STDERR "Done.  $rc clone records were changed.\n";

$dbh->commit;

$dbh->disconnect();

print STDERR "Loading contigs ...\n";

chdir($directory);

my $padded = "/tmp/$project.$$.caf";
my $depadded = "/tmp/$project.$$.depadded.caf";

$rc = system("gap2caf -project ASSEMBLY -ace $padded");

die "gap2caf failed" unless $rc == 0;

$rc = system("caf_depad < $padded > $depadded");

die "caf_depad failed" unless $rc == 0;

unlink $padded if $rc == 0;

my $contig_loader_cmd = dirname($cmd) . "/new-contig-loader -instance $instance -organism $organism" .
    " -caf $depadded -project $project -crn all";

$rc = system($contig_loader_cmd);

print STDERR "contig loader finished with return code $rc\n";

unlink $depadded if $rc == 0;

print STDERR "ALL DONE.\n";

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
    print STDERR "    -strain\t\tName of strain\n";
    print STDERR "\n";
}
