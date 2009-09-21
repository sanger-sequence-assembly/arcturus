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

use constant NONE => 0;
use constant DEPAD => 1;
use constant PAD_IS_STAR => 2;
use constant PAD_IS_DASH => 3;
use constant PAD_IS_N => 4;
use constant PAD_IS_X => 5;

use constant FASTA_CHUNK_SIZE => 50;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $minlen;
my $verbose;
my $fastafile;
my $destdir;
my $paddingmode = NONE;
my $fastafh;
my $contigids;
my $allcontigs = 0;
my $maxseqperfile;
my $seqfilenum;
my $totseqlen;
my $pinclude;
my $pexclude;
my $projectprefix = 0;
my $usegapname = 0;
my $ends = 0;
my $padmapfile;
my $ascaf = 0;

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

    $paddingmode = PAD_IS_N    if ($nextword eq '-padton');
    $paddingmode = PAD_IS_X    if ($nextword eq '-padtox');
    $paddingmode = PAD_IS_DASH if ($nextword eq '-padtodash');
    $paddingmode = PAD_IS_STAR if ($nextword eq '-padtostar');

    $paddingmode = DEPAD       if ($nextword eq '-depad');

    $padmapfile = shift @ARGV if ($nextword eq '-padmap');

    $usegapname = 1 if ($nextword eq '-usegap4name');

    $projectprefix = 1 if ($nextword eq '-projectprefix');

    $ascaf = 1 if ($nextword eq '-ascaf');

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
my $projectid2name;

while (my ($projid,$projname) = $sth->fetchrow_array()) {
    $projectname2id->{$projname} = $projid;
    $projectid2name->{$projid} = $projname;
}

$sth->finish();

$pinclude = &getProjectIDs($pinclude, $projectname2id) if defined($pinclude);
$pexclude = &getProjectIDs($pexclude, $projectname2id) if defined($pexclude);

$minlen = 1000 unless (defined($minlen) || defined($contigids));

my $fields = "gap4name,project_id,C.contig_id,C.length,sequence" . ($ascaf ? ",quality" : "");
my $tables = (defined($contigids) || $allcontigs ? "CONTIG" : "CURRENTCONTIGS") .
    " C left join CONSENSUS CS using(contig_id)";

my @conds;

if (defined($contigids)) {
    push @conds, "C.contig_id in ($contigids)";
} elsif ($allcontigs) {
    push @conds, "C.length > $minlen" if defined($minlen);
} else {
    push @conds, "C.length > $minlen" if defined($minlen);

    push @conds, "project_id in ($pinclude)" if defined($pinclude);

    push @conds, "project_id not in ($pexclude)" if defined($pexclude);
}

my $query = "select $fields from $tables";
$query .= " where " . join(" and ",@conds) if (@conds);

print STDERR $query,"\n";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$totseqlen = 0;

while(my @ary = $sth->fetchrow_array()) {
    my ($gap4name, $projectid, $contigid, $contiglength,$compressedsequence, $compressedquality) = @ary;

    my $projectname = $projectid2name->{$projectid};

    unless (defined($compressedsequence)) {
	print STDERR "WARNING: Some contigs have no consensus sequence.\n";
	print STDERR "Please run the calculateconsensus script first, then re-run this command\n";

	$sth->finish();
	$dbh->disconnect();

	exit(2);
    }

    my $sequence = uncompress($compressedsequence);

    my $quality = $ascaf ? uncompress($compressedquality) : undef;

    if ($contiglength != length($sequence)) {
	print STDERR "Sequence length mismatch for contig $contigid: $contiglength vs ",
	length($sequence),"\n";
    }

    my $contigname = $projectprefix ? $projectname . "_contig_" . $contigid : 
	$instance . "_" . $organism . "_contig_" . $contigid;

    $contigname = $gap4name if ($usegapname && defined($gap4name));

    if (defined($padfh)) {
	my $mappings = &padMap($sequence, '*');

	print $padfh $contigname;

	foreach my $segment (@{$mappings}) {
	    my ($starta, $startb, $seglen) = @{$segment};
	    print $padfh ";$starta,$startb,$seglen";
	}

	print $padfh "\n";
    }

    if ($paddingmode == DEPAD) {
	# Depad
	$sequence =~ s/[NnXx\*\-]//g;
    } elsif ($paddingmode == PAD_IS_N) {
	# Convert pads to N ...
	$sequence =~ s/[\*\-]/N/g;
    } elsif ($paddingmode == PAD_IS_X) {
	# Convert pads to X ...
	$sequence =~ s/[\*\-]/X/g;
    } elsif ($paddingmode == PAD_IS_DASH) {
	# Convert pads to dash
	$sequence =~ s/\*/\-/g;
    } elsif ($paddingmode == PAD_IS_STAR) {
	# Convert pads to star
	$sequence =~ s/\-/\*/g;
    }

    next if ($paddingmode == DEPAD && defined($minlen) && length($sequence) < $minlen);

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

    if ($ascaf) {
	$contigname = $organism . "_" . $contigname;
	&writeAsCAF($fastafh, $contigname, $sequence, $quality);
    } else {
	printf $fastafh ">$contigname\n";
	&writeSequence($fastafh, $sequence);
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
    exit(1);
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

sub writeSequence {
    my $fh = shift;
    my $sequence = shift;

    my $seqlen = length($sequence);

    for (my $offset = 0; $offset < $seqlen; $offset += FASTA_CHUNK_SIZE) {
	my $chunk_length = $seqlen > $offset + FASTA_CHUNK_SIZE ?
	    FASTA_CHUNK_SIZE : $seqlen - $offset;

	print $fh substr($sequence, $offset, $chunk_length),"\n";
    }
}

sub writeQuality {
    my $fh = shift;
    my $quality = shift;

    my $qlen = scalar(@{$quality});

    for (my $i = 0; $i < $qlen; $i++) {
	print $fh (($i % 50) > 0) ? " " : "", $quality->[$i];
	print $fh "\n" if (($i % 50) == 49);
    }

    print $fh "\n" if (($qlen % 50) > 0);
}

sub writeAsCAF {
    my $fh = shift;
    my $seqname = shift;
    my $sequence = shift;
    my $quality = shift;

    my $seqlen = length($sequence);

    print $fh "Sequence : $seqname\n";
    print $fh "Is_read\nPadded\nPrimer unknown\nStrand unknown\nDye unknown\n";
    print $fh "Clipping QUAL 1 $seqlen\n";
    print $fh "Tag ARCT 1 $seqlen \"Consensus read\"\n";
    print $fh "\n";

    print $fh "DNA : $seqname\n";
    &writeSequence($fh, $sequence);
    print $fh "\n";

    my @bq = unpack("c*", $quality);

    print $fh "BaseQuality : $seqname\n";
    &writeQuality($fh, \@bq);
    print $fh "\n";

    my $contigname = "Contig_" . $seqname;

    print $fh "Sequence : $contigname\n";

    print $fh "Is_contig\nPadded\n";
    print $fh "Assembled_from $seqname 1 $seqlen 1 $seqlen\n";
    print $fh "\n";

    print $fh "DNA : $contigname\n";
    &writeSequence($fh, $sequence);
    print $fh "\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
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
    print STDERR "    -maxseqperfile\tMaximum sequence length per file\n";
    print STDERR "    -include\t\tInclude contigs in these projects\n";
    print STDERR "    -exclude\t\tExclude contigs in these projects\n";
    print STDERR "    -usegap4name\tUse Gap4 name instead of contig ID\n";
    print STDERR "    -ends\t\tMask out the middle of the contig except for this many bp at either end\n";
    print STDERR "    -ascaf\t\tGenerate a CAF file containing each contig as a consensus read\n";
    print STDERR "\n";
    print STDERR "PADDING OPTIONS:\n";
    print STDERR "    -depad\t\tRemove pad characters from sequence\n";
    print STDERR "    -padmap\t\tName of file for depadded-to-padded coordinate mapping\n";
    print STDERR "\n";
    print STDERR "    -padton\t\tConvert pads to N\n";
    print STDERR "    -padtox\t\tConvert pads to X\n";
    print STDERR "    -padtodash\t\tConvert pads to dashes\n";
    print STDERR "    -padtostar\t\tConvert pads to stars\n";
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
