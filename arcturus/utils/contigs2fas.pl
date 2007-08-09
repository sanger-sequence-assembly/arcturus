#!/usr/local/bin/perl
#
# contigs2fas
#
# This script extracts one or more contigs and generates a FASTA file

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
my $destdir;
my $padton;
my $padtox;
my $depad;
my $fastafh;
my $contigids;
my $allcontigs = 0;
my $maxseqperfile;
my $seqfilenum;
my $totseqlen;
my $pinclude;
my $pexclude;
my $usegapname = 0;
my $ends = 0;
my $padmapfile;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');

    $fastafile = shift @ARGV if ($nextword eq '-fasta');

    $destdir = shift @ARGV if ($nextword eq '-destdir');

    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $maxseqperfile = shift @ARGV if ($nextword eq '-maxseqperfile');

    $allcontigs = 1 if ($nextword eq '-allcontigs');

    $pinclude = shift @ARGV if ($nextword eq '-include');

    $pexclude = shift @ARGV if ($nextword eq '-exclude');

    $ends = shift @ARGV if ($nextword eq '-ends');

    $padton = 1 if ($nextword eq '-padton');
    $padtox = 1 if ($nextword eq '-padtox');

    $depad = 1 if ($nextword eq '-depad');

    $padmapfile = shift @ARGV if ($nextword eq '-padmap');

    $usegapname = 1 if ($nextword eq '-usegap4name');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	(defined($fastafile) || defined($destdir))) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$depad = 0 unless defined($depad);

$padton = 0 unless defined($padton);
$padton = 0 if $depad;

$padtox = 0 unless defined($padtox);
$padtox = 0 if $depad;

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

if (defined($fastafile)) {
    my $filename = $fastafile;
    if (defined($maxseqperfile)) {
	$seqfilenum = 1;
	$filename .= sprintf("%04d", $seqfilenum) . ".fas";
    }

    $fastafh = new FileHandle($filename, "w");
    die "Unable to open FASTA file \"$filename\" for writing" unless $fastafh;
} else {
    if (! -d $destdir) {
	die "Unable to create directory \"$destdir\"" unless mkdir($destdir);
    }
}

my $padfh;

if (defined($padmapfile)) {
    $padfh = new FileHandle($padmapfile, "w");
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
    $query = "select gap4name,contig_id,length from CONTIG where contig_id in ($contigids)";
} elsif ($allcontigs) {
    $query = "select gap4name,contig_id,length from CONTIG";
    $query .= " where length > $minlen" if defined($minlen);
} else {
    $query = "select gap4name,contig_id,length from CURRENTCONTIGS";

    my @conds;

    push @conds, "length > $minlen" if defined($minlen);

    push @conds, "project_id in ($pinclude)" if defined($pinclude);

    push @conds, "project_id not in ($pexclude)" if defined($pexclude);

    if (@conds) {
	$query .= " where " . join(" and ",@conds);
    }
}

print STDERR $query,"\n";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$query = "select sequence from CONSENSUS where contig_id = ?";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

$totseqlen = 0;

while(my @ary = $sth->fetchrow_array()) {
    my ($gap4name, $contigid, $contiglength) = @ary;

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

    if (defined($padfh)) {
	my $mappings = &padMap($sequence, 'N');

	print $padfh $contigname;

	foreach my $segment (@{$mappings}) {
	    my ($starta, $startb, $seglen) = @{$segment};
	    print $padfh ";$starta,$startb,$seglen";
	}

	print $padfh "\n";
    }

    if ($depad) {
	# Depad
	$sequence =~ s/[NnXx\*\-]//g;
    } elsif ($padton) {
	# Convert pads to N ...
	$sequence =~ s/[\*\-]/N/g;
    } elsif ($padtox) {
	# Convert pads to X ...
	$sequence =~ s/[\*\-]/X/g;
    }

    if ($ends && length($sequence) > 2 * $ends) {
	my $leftend = substr($sequence, 0, $ends);
	my $midlen = length($sequence) - 2 * $ends;
	my $middle = substr($sequence, $ends, $midlen);
	my $rightend = substr($sequence, $midlen + $ends);

	$middle = substr($middle, 0, 2 * $ends) if ($midlen > 2 * $ends);

	$middle =~ s/[^X]/X/g;

	$sequence = $leftend . $middle . $rightend;
    }

    if ($destdir) {
	my $filename = "$destdir/$contigname" . ".fas";
	$fastafh = new FileHandle("$filename", "w");
	die "Unable to open new file \"$filename\"" unless $fastafh;
    }

    if (defined($maxseqperfile)) {
	$totseqlen += length($sequence);

	if ($totseqlen > $maxseqperfile) {
	    $fastafh->close();
	    $totseqlen = length($sequence);
	    $seqfilenum++;

	    my $filename = $fastafile . sprintf("%04d", $seqfilenum) . ".fas";

	    $fastafh = new FileHandle("$filename", "w");
	    die "Unable to open new file \"$filename\"" unless $fastafh;
	}
    }

    printf $fastafh ">$contigname\n";

    while (length($sequence) > 0) {
	print $fastafh substr($sequence, 0, 50), "\n";
	$sequence = substr($sequence, 50);
    }

    if ($destdir) {
	$fastafh->close();
	undef $fastafh;
    }
}

$sth->finish();

$dbh->disconnect();

$fastafh->close() if defined($fastafh);
$padfh->close() if defined($padfh);

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub padMap {
    my $string = shift;
    my $pad = shift;

    my $offset = 0;
    my $delta = 0;
    my $strlen = length($string);

    my $mappings = [];

    while (1) {
	my $padpos = index($string, $pad, $offset);

	if ($padpos < 0) {
	    push @{$mappings}, [$offset+1, $offset-$delta+1, $strlen - $offset];

	    return $mappings;
	} else {
	    push @{$mappings}, [$offset+1, $offset-$delta+1, $padpos - $offset]
		if ($padpos > $offset);
	    $offset = $padpos + 1;
	    $delta++;
	}
    }

    die "We should never get to this point";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "    -fasta\t\tName of output FASTA file\n";
    print STDERR "    -- OR --\n";
    print STDERR "    -destdir\t\tDirectory for individual FASTA files\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum length for contigs [default: 1000]\n";
    print STDERR "    -contigs\t\tComma-separated list of contig IDs [implies -minlen 0]\n";
    print STDERR "    -allcontigs\t\tSelect all contigs, not just from current set\n";
    print STDERR "    -depad\t\tRemove pad characters from sequence\n";
    print STDERR "    -padmap\t\tName of file for depadded-to-padded coordinate mapping\n";
    print STDERR "    -padton\t\tConvert pads to N\n";
    print STDERR "    -padtox\t\tConvert pads to X\n";
    print STDERR "    -maxseqperfile\tMaximum sequence length per file\n";
    print STDERR "    -include\t\tInclude contigs in these projects\n";
    print STDERR "    -exclude\t\tExclude contigs in these projects\n";
    print STDERR "    -usegap4name\t\tUse Gap4 name instead of contig ID\n";
    print STDERR "    -ends\t\tMask out the middle of the contig except for this many bp at either end\n";
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
