#!/usr/local/bin/perl

use strict;

use DBI;
use Compress::Zlib;
use FileHandle;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use DataSource;

# MySQL error code for an attempt to insert a primary key value that already exists
use constant MYSQL_ER_DUP_ENTRY => 1062;

my $queries =
{
    'get_pass_status',
    'select status_id from STATUS where name = ?',

    'insert_readinfo',
    'insert into READINFO(readname,status) values (?,?)',

    'insert_template',
    'insert into TEMPLATE(name) values (?)',

    'update_readinfo',
    'update READINFO set template_id = ? where read_id = ? and template_id is null',

    'insert_sequence',
    'insert into SEQUENCE(seqlen, seq_hash, qual_hash, sequence, quality) values (?,?,?,?,?)',

    'insert_seq2read',
    'insert into SEQ2READ(read_id, seq_id, version) values (?,?,1)',

    'insert_readtag',
    'insert into READTAG(seq_id,tagtype,pstart,pfinal,comment) values (?,?,?,?,?)',

    'insert_qualityclip',
    'insert into QUALITYCLIP(seq_id,qleft,qright) values (?,?,?)'
    };

my $instance;
my $organism;
my $fastafile;
my $verbose = 0;
my $qvalue = 2;
my $testing = 1;

my $tagtype = 'CONS';
my $tagcomment = 'Consensus read';

while (my $nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $fastafile     = shift @ARGV if ($nextword eq '-fastafile');

    $qvalue        = shift @ARGV if ($nextword eq '-qvalue');

    $verbose       = 1 if ($nextword eq '-verbose');

    $testing       = 0 if ($nextword eq '-notesting');

    $testing       = 1 if ($nextword eq '-testing');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($fastafile)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

die "File $fastafile does not exist" unless -f $fastafile;

my $fastafh = new FileHandle($fastafile, "r");

die "Failed to open file $fastafile" unless $fastafh;

my $sequences = &parseFastaFile($fastafh, $verbose);

$fastafh->close();

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $statements = &prepareStatements($dbh, $queries);

my $sth = $statements->{'get_pass_status'};

$sth->execute('PASS');

my ($pass) = $sth->fetchrow_array();

print STDERR "Pass status is $pass\n";

foreach my $readname (keys %{$sequences}) {
    my $dna = $sequences->{$readname};

    print STDERR "\nProcessing read $readname (" . length($dna) . " bp)\n";

    $dbh->begin_work();

    print STDERR "\tInserting $readname into READINFO ...\n" if $verbose;

    $statements->{'insert_readinfo'}->execute($readname, $pass);

    if ($DBI::err) {
	if ($DBI::err == MYSQL_ER_DUP_ENTRY) {
	    print STDERR "\t*** ERROR! *** A read named $readname already exists in the database.\n";
	} else {
	    &db_die("Failed to insert into READINFO");
	}
	$dbh->rollback();
	next;
    }

    my $read_id = $dbh->{'mysql_insertid'};

    print STDERR "\tRead ID is $read_id\n" if $verbose;

    my @parts = split(/\./, $readname);

    my $template = $parts[0];

    print STDERR "\n\tInserting $template into TEMPLATE ...\n" if $verbose;

    $statements->{'insert_template'}->execute($template);

    if ($DBI::err) {
	if ($DBI::err == MYSQL_ER_DUP_ENTRY) {
	    print STDERR "\t*** ERROR! *** A template named $template already exists in the database.\n";
	} else {
	    &db_die("Failed to insert into TEMPLATE");
	}
	$dbh->rollback();
	next;
    }

    my $template_id = $dbh->{'mysql_insertid'};

    print STDERR "\tTemplate ID is $template_id\n" if $verbose;

    print STDERR "\n\tUpdating READINFO ...\n";

    $statements->{'update_readinfo'}->execute($template_id, $read_id);

    &db_die("Failed to update READINFO") if $DBI::err;

    my $seqlen = length($dna);

    my $qualarray = &createQualityArray($seqlen, $qvalue);

    my $quality = pack("c*",@{$qualarray});

    my $seq_hash = md5($dna);
    my $qual_hash = md5($quality);

    $dna = compress($dna);
    $quality = compress($quality);

    print STDERR "\n\tInserting data into SEQUENCE ...\n" if $verbose;

    $statements->{'insert_sequence'}->execute($seqlen, $seq_hash, $qual_hash, $dna, $quality);

    &db_die("Failed to insert into SEQUENCE") if $DBI::err;

    my $seq_id = $dbh->{'mysql_insertid'};

    print STDERR "\tSequence ID is $seq_id\n" if $verbose;

    print STDERR "\n\tInserting data into SEQ2READ ...\n" if $verbose;

    $statements->{'insert_seq2read'}->execute($read_id, $seq_id);

    if ($DBI::err) {
	print STDERR "\t*** ERROR *** Failed to insert read_id = $read_id, seq_id = $seq_id into SEQ2READ\n";
	print STDERR "\t*** ERROR *** Error code $DBI::err ($DBI::errstr)\n";
	$dbh->rollback();
	next;
    }

    print STDERR "\n\tInserting data into READTAG ...\n" if $verbose;

    $statements->{'insert_readtag'}->execute($seq_id, $tagtype, 1, $seqlen, $tagcomment);

    &db_die("Failed to insert into READTAG") if $DBI::err;

    print STDERR "\n\tInserting data into QUALITYCLIP ...\n";

    $statements->{'insert_qualityclip'}->execute($seq_id, 1, $seqlen);

    &db_die("Failed to insert into QUALITYCLIP") if $DBI::err;

    if ($testing) {
	print STDERR "\n\tExecuting rollback ...\n" if $verbose;
	$dbh->rollback();
    } else {
	print STDERR "\n\tCommitting ...\n" if $verbose;
	$dbh->commit();
    }
}


&finishStatements($statements);

$dbh->disconnect();

exit(0);

sub prepareStatements {
    my $dbh = shift;
    my $queries = shift;

    my $statements = {};

    foreach my $queryname (keys %{$queries}) {
	my $query = $queries->{$queryname};

	$statements->{$queryname} = $dbh->prepare($query);

	&db_die("Failed to prepare statement $queryname (\"$query\")\n") if $DBI::err;
    }

    return $statements;
}

sub finishStatements {
    my $statements = shift;

    foreach my $queryname (keys %{$statements}) {
	my $statement = $statements->{$queryname};
	$statement->finish();
    }
}

sub createQualityArray {
    my $seqlen = shift;
    my $qvalue = shift;

    my $qdata = [];

    for (my $i = 0; $i < $seqlen; $i++) {
	push @{$qdata}, $qvalue;
    }

    return $qdata;
}

sub parseFastaFile {
    my $fh = shift;
    my $verbose = shift;

    my $sequences = {};

    my $seqname;
    my $dna;

    while (my $line = <$fh>) {
	chop($line);

	if ($line =~ />(\S+)/) {
	    if (defined($seqname) && defined($dna)) {
		$sequences->{$seqname} = $dna;
		print STDERR "$seqname (" . length($dna) . " bp) found\n";
	    }

	    $seqname = $1;
	    $dna = '';
	} elsif ($line =~ /^[ACGTNXacgtnx]+$/) {
	    $dna .= $line;
	}
    }

    $sequences->{$seqname} = $dna if (defined($seqname) && defined($dna));
    print STDERR "$seqname (" . length($dna) . " bp) found\n";

    return $sequences;
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "-fastafile\t\tName of input FASTA file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-verbose\t\tEnable verbose reporting\n";
}
