#!/usr/local/bin/perl
#
# contig-gc-content
#
# This script calculates the G+C content for one or more contigs

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $minlen;
my $verbose;
my $contigids;
my $allcontigs = 0;
my $pinclude;
my $pexclude;
my $usegapname = 1;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');

    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $allcontigs = 1 if ($nextword eq '-allcontigs');

    $pinclude = shift @ARGV if ($nextword eq '-include');

    $pexclude = shift @ARGV if ($nextword eq '-exclude');

    $usegapname = 0 if ($nextword eq '-nogap4name');

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

my $projectname2id;

while (my ($projid,$projname) = $sth->fetchrow_array()) {
    $projectname2id->{$projname} = $projid;
}

$sth->finish();

$pinclude = &getProjectIDs($pinclude, $projectname2id) if defined($pinclude);
$pexclude = &getProjectIDs($pexclude, $projectname2id) if defined($pexclude);

$minlen = 1000 unless (defined($minlen) || defined($contigids));

if (defined($contigids)) {
    $query = "select gap4name,contig_id,length,cover from CONTIG where contig_id in ($contigids)";
} elsif ($allcontigs) {
    $query = "select gap4name,contig_id,length,cover from CONTIG";
    $query .= " where length > $minlen" if defined($minlen);
} else {
    $query = "select gap4name,CONTIG.contig_id,length,cover from CONTIG left join C2CMAPPING" .
	" on CONTIG.contig_id = C2CMAPPING.parent_id" .
	    " where C2CMAPPING.parent_id is null";

    $query .= " and length > $minlen" if defined($minlen);

    $query .= " and project_id in ($pinclude)" if defined($pinclude);

    $query .= " and project_id not in ($pexclude)" if defined($pexclude);
}

print STDERR $query,"\n";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$query = "select sequence from CONSENSUS where contig_id = ?";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

while(my @ary = $sth->fetchrow_array()) {
    my ($gap4name, $contigid, $contiglength, $cover) = @ary;

    $sth_sequence->execute($contigid);

    my ($compressedsequence) = $sth_sequence->fetchrow_array();

    $sth_sequence->finish();

    next unless defined($compressedsequence);

    my $sequence = uncompress($compressedsequence);

    if ($contiglength != length($sequence)) {
	print STDERR "Sequence length mismatch for contig $contigid: $contiglength vs ",
	length($sequence),"\n";
    }

    my $contigname = $usegapname && defined($gap4name) ? $gap4name : sprintf("contig%06d", $contigid);

    $sequence =~ s/[GC]+//gi;

    my $at = length($sequence);

    my $gc = 100.0 * ($contiglength - $at)/$contiglength;

    printf "%-30s %6.2f %6.2f\n", $contigname, $cover, $gc;
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
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum length for contigs [default: 1000]\n";
    print STDERR "    -contigs\t\tComma-separated list of contig IDs [implies -minlen 0]\n";
    print STDERR "    -allcontigs\t\tSelect all contigs, not just from current set\n";
    print STDERR "    -include\t\tInclude contigs in these projects\n";
    print STDERR "    -exclude\t\tExclude contigs in these projects\n";
    print STDERR "    -nogap4name\t\tUse contig ID as name, not Gap4 name\n";
}

sub getProjectIDs {
    my $pnames = shift;
    my $name2id = shift;

    my @projects = split(/,/, $pnames);

    my @projectids;

    foreach my $pname (@projects) {
	my $pid = $name2id->{$pname};
	if (defined($pid)) {
	    push @projectids, $pid;
	} else {
	    print STDERR "Unknown project name: $pname\n";
	}
    }

    my $projectlist = scalar(@projectids) > 0 ? join(',', @projectids) : undef;

    return $projectlist;
}
