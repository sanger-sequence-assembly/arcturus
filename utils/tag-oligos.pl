#!/usr/local/bin/perl
#
# tag-oligos
#
# This script finds oligo sequences in read sequences, and tags them.

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $verbose = 0;

my $instance;
my $organism;
my $oligofile;
my $tagtype = 'OLIG';
my $noinsert = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $oligofile = shift @ARGV if ($nextword eq '-oligos');

    $tagtype = shift @ARGV if ($nextword eq '-tagtype');

    $noinsert = 1 if ($nextword eq '-noinsert');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	(defined($oligofile))) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

die "File $oligofile does not exist" unless -f $oligofile;

die "Cannot read file $oligofile" unless -r $oligofile;

my @oligos;

open(OLIGOS, $oligofile);

while (my $line = <OLIGOS>) {
    chop($line);

    my ($oligoname, $oligoseq) = $line =~ /^(\S+)\s+([ACGT]+)/;

    if (defined($oligoname) && defined($oligoseq)) {
	$oligoseq = uc($oligoseq);
	my $revseq = &reverseComplement($oligoseq);

	push @oligos,[$oligoname, $oligoseq, $revseq];
    }
}

close(OLIGOS);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => { RaiseError => 1, PrintError => 1});

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select seq_id,seqlen,sequence from SEQUENCE";

my $sth = $dbh->prepare($query);

$query = "insert into READTAG(seq_id,tagtype,pstart,pfinal,strand,comment) values(?,?,?,?,?,?)";

my $sth_add_tag = $dbh->prepare($query);

$sth->execute();

while (my ($seqid,$seqlen,$sequence) = $sth->fetchrow_array()) {
    $sequence = uncompress($sequence);

    foreach my $oligo (@oligos) {
	my ($oligoname, $fwdseq, $revseq) = @{$oligo};

	foreach my $oligoseq ($fwdseq, $revseq) {
	    if ($sequence =~ /$oligoseq/) {
		my $rstart = $-[0] + 1;
		my $rfinish = $rstart + length($oligoseq) - 1;

		my $match = $&;

		my $strand = ($match eq $fwdseq) ? 'F' : 'R';

		print "$seqid\t$oligoname\t$rstart\t$rfinish\n";

		my $comment = "$oligoname sequence=$fwdseq";

		$sth_add_tag->execute($seqid,$tagtype,$rstart,$rfinish,$strand,$comment)
		    unless $noinsert;
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
    print STDERR "    -oligos\t\tFile of oligo sequences\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -tagtype\t\tTag type [default: OLIG]\n";
    print STDERR "    -noinsert\t\tDo not add tag to database\n";
}

sub reverseComplement {
    my $seq = shift;

    $seq = reverse(uc($seq));

    $seq =~ tr/ACGT/TGCA/;

    return $seq;
}
