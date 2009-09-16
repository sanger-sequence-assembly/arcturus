#!/usr/local/bin/perl
#
# contig-digest
#
# This script calculates restriction digest fragment sizes from contigs
# in Arcturus

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
my $fastafile;
my $contigids;
my $pinclude;
my $pexclude;
my $digest;
my $positions = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');

    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $pinclude = shift @ARGV if ($nextword eq '-include');

    $pexclude = shift @ARGV if ($nextword eq '-exclude');

    $digest = shift @ARGV if ($nextword eq '-digest');

    $positions = 1 if ($nextword eq '-positions');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	(defined($digest))) {
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

my $fields = "C.contig_id,C.length,CS.sequence";
my $tables = (defined($contigids) ? "CONTIG" : "CURRENTCONTIGS") .
    " C left join CONSENSUS CS using(contig_id)";

my @conds;

if (defined($contigids)) {
    push @conds, "C.contig_id in ($contigids)";
} else {
    push @conds, "C.length > $minlen" if defined($minlen);

    push @conds, "project_id in ($pinclude)" if defined($pinclude);

    push @conds, "project_id not in ($pexclude)" if defined($pexclude);
}

my $query = "select $fields from $tables";
$query .= " where " . join(" and ",@conds) if (@conds);

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my $deltapos = 1 + int(length($digest)/2);

$digest = transformDigest($digest);

study($digest);

while(my @ary = $sth->fetchrow_array()) {
    my ($contigid, $contiglength,$compressedsequence) = @ary;

    unless (defined($compressedsequence)) {
	print STDERR "WARNING: Some contigs have no consensus sequence.\n";
	print STDERR "Please run the calculateconsensus script first, then re-run this command\n";

	$sth->finish();
	$dbh->disconnect();

	exit(2);
    }

    my $sequence = uc(uncompress($compressedsequence));

    $sequence =~ s/[NnXx\*\-]//g;

    next if (defined($minlen) && length($sequence) < $minlen);

    my $sites = &digestSequence($sequence, $digest);

    my $num_sites = scalar(@{$sites});

    if ($positions) {
	for my $pos (@{$sites}) {
	    $pos += $deltapos;
	    print "$contigid\t$pos\n";
	}
    } else {
	if ($num_sites > 1) {
	    for (my $i = 0; $i < $num_sites - 1; $i++) {
		my $fragment_size = $sites->[$i + 1] - $sites->[$i];
		next unless ($fragment_size  > 0);
		print "$contigid\t$fragment_size\n";
	    }
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
    exit(1);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "    -digest\t\tRestriction digest sequence\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum length for contigs [default: 1000]\n";
    print STDERR "    -contigs\t\tComma-separated list of contig IDs [implies -minlen 0]\n";
    print STDERR "    -include\t\tInclude contigs in these projects\n";
    print STDERR "    -exclude\t\tExclude contigs in these projects\n";
    print STDERR "\n";
    print STDERR "    -positions\tList positions of digest sites\n";
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

sub transformDigest {
    my $digest = shift;

    $digest = uc($digest);

    # IUPAC-IUB/GCG ambiguity codes taken from:
    #
    # http://wwwold.hgu.mrc.ac.uk/Softdata/Misc/ambcode.html

    my %ambiguity = (
		     'M' => '[AC]',
		     'R' => '[AG]',
		     'W' => '[AT]',
		     'S' => '[CG]',
		     'Y' => '[CT]',
		     'K' => '[GT]',

		     'V' => '[ACG]',
		     'H' => '[ACT]',
		     'D' => '[AGT]',
		     'B' => '[CGT]',

		     'X' => '[ACGT]',
		     'N' => '[ACGT]'
		     );

    foreach my $ambg (keys %ambiguity) {
	my $value = $ambiguity{$ambg};

	$digest =~ s/$ambg/$value/g;
    }

    return $digest;
}

sub digestSequence {
    my $sequence = shift;
    my $digest = shift;

    my $sites = [];

    while ($sequence =~ /$digest/g) {
	push @{$sites}, $-[0];
    }

    return $sites;
}
