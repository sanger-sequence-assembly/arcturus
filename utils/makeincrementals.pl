#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $increment;
my $queue;
my $resources;
my $scriptname;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $increment = shift @ARGV if ($nextword eq '-increment');
    $queue = shift @ARGV if ($nextword eq '-q');
    $resources = shift @ARGV if ($nextword eq '-R');
    $scriptname = shift @ARGV if ($nextword eq '-script');
}

unless (defined($instance) && defined($organism)) {
    &showUsage();
    exit(0);
}

my $bsub;

if (defined($queue) && defined($scriptname)) {
    $bsub = "bsub -q $queue";

    $bsub .= " -R '$resources'" if defined($resources);
}

$increment = 10000 unless defined($increment);

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $query = "select date_add(asped, interval 1 day) as thedate,count(*) from READINFO group by thedate order by thedate asc";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

my $sum = 0;
my $cumulative = 0;
my $asped;
my $count;
my $lastasped;
my $jobname;
my $njobs = 0;

while (($asped, $count) = $stmt->fetchrow_array()) {
    $sum += $count;
    $cumulative += $count;

    if ($cumulative > $increment) {
	if ($bsub) {
	    $jobname = "$organism-$asped";
	    my $prejob = defined($lastasped) ? "-w $organism-$lastasped" : "";
	    print "$bsub -J $jobname -N -o '/pathdb2/arcturus/$jobname.out' $prejob $scriptname $organism $asped\n";
	    $njobs++;
	} else {
	    printf "%10s %8d %8d\n", $asped, $cumulative, $sum;
	}
	$cumulative = 0;
	$lastasped = $asped;
    }
}

$asped = &today();

if ($bsub) {
    $jobname = "$organism-$asped";
    my $prejob = defined($lastasped) ? "-w $organism-$lastasped" : "";
    print "$bsub -J $jobname -N -o '/pathdb2/arcturus/$jobname.out' $prejob $scriptname $organism $asped\n";
    $njobs++;
    print STDERR "There are $njobs jobs.\n";
} else {
    printf "%10s %8d %8d\n", $asped, $cumulative, $sum;
}

$stmt->finish();


$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-increment\tNumber of new reads per incremental assembly\n";
    print STDERR "\n";
    print STDERR "BATCH-JOB PARAMETERS:\n";
    print STDERR "-q\t\tName of batch queue\n";
    print STDERR "-R\t\tBatch job resources [optional]\n";
    print STDERR "-script\t\tName of batch job script\n";
}

sub today {
    my $t = time;
    my @td = localtime($t);

    return sprintf("%04d-%02d-%02d", 1900+$td[5], 1+$td[4], $td[3]);
}
