#!/usr/local/bin/perl
#
# remove-read-from-contig.pl
#
# This script creates a new contig from a specified contig, with one or more
# specified reads removed.

use strict;

use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use DataSource;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $old_contig_id;
my $readnames;
my $commit = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $old_contig_id = shift @ARGV if ($nextword eq '-contig');

    $readnames = shift @ARGV if ($nextword eq '-readnames');

    $commit = 1 if ($nextword eq '-commit');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	(defined($old_contig_id) || defined($readnames))) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection(-options => {RaiseError => 1, PrintError => 1});

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

&beginTransaction($dbh);

&confirmIsCurrentContig($dbh, $old_contig_id) || die "Contig $old_contig_id is not a current contig";

my $seqids = &getSequenceIDsForReadnames($dbh, $old_contig_id, $readnames);

my $new_contig_id = &copyContig($dbh, $old_contig_id);

&copyMappings($dbh, $old_contig_id, $new_contig_id);

&removeSelectedSequences($dbh, $new_contig_id, $seqids);

unless (&confirmContigIntegrity($dbh, $new_contig_id)) {
    &report("\n*****\n*****\n***** The new contig contains one or more zero-depth regions\n*****");
    &report("***** ROLLING BACK CHANGES\n*****\n*****");
    $dbh->rollback();
    $dbh->disconnect();
    exit(1);
}

my ($left,$right) = &determineNewContigExtents($dbh, $new_contig_id);

&adjustMappings($dbh, $new_contig_id, $left) if ($left > 1);

&copySegments($dbh, $old_contig_id, $new_contig_id);

&adjustSegments($dbh, $new_contig_id, $left) if ($left > 1);

&copyTagMappings($dbh, $old_contig_id, $new_contig_id);

&adjustTagMappings($dbh, $new_contig_id, $left) if ($left > 1);

my $new_contig_length = 1 + $right - $left;

&removeInvalidTagMappings($dbh, $new_contig_id, $new_contig_length);

&createContigToContigMapping($dbh, $old_contig_id, $left, $right, $new_contig_id);

&fixNewContigRecord($dbh, $new_contig_id);

if ($commit) {
    &report("##### COMMITTING CHANGES #####");
    $dbh->commit() or die $dbh->errstr;
    &report("\n#####\n#####\n##### The new contig $new_contig_id replaces contig $old_contig_id\n#####\n#####");
} else {
    &report("##### ROLLING BACK CHANGES #####");
    $dbh->rollback() or die $dbh->errstr;
}

$dbh->disconnect();

exit(0);

sub beginTransaction {
    &report("=== beginTransaction ===");

    my $dbh = shift;

    my $query = "set autocommit = 0";

    $dbh->do($query);

    $dbh->begin_work();
}

sub confirmIsCurrentContig {
    my $dbh = shift;
    my $old_contig_id = shift;

    &report("=== confirmIsCurrentContig($old_contig_id) ===");

    my $query = "select count(*) from CURRENTCONTIGS where contig_id = ?";

    my $sth = $dbh->prepare($query);

    $sth->execute($old_contig_id);

    my ($rc) = $sth->fetchrow_array();

    &report("\tFound $rc current contigs with ID $old_contig_id");

    $sth->finish();

    return $rc;
}

sub getSequenceIDsForReadnames {
    my $dbh = shift;
    my $old_contig_id = shift;
    my $readnames = shift;

    &report("=== getSequenceIDsForReadnames($old_contig_id, [$readnames]) ===");

    my $seqids = [];

    my $query = "select R.readname,M.seq_id" .
	" from MAPPING M,SEQ2READ SR,READINFO R" .
	" where M.contig_id = ? and M.seq_id = SR.seq_id and SR.read_id = R.read_id" .
	" and R.readname like ?";

    my $sth = $dbh->prepare($query);

    foreach my $readnamelike (split(/,/, $readnames)) {
	$readnamelike =~ tr/*/%/;

	$sth->execute($old_contig_id, $readnamelike);

	my $hits = 0;

	while (my ($readname,$seqid) = $sth->fetchrow_array()) {
	    push @{$seqids}, $seqid;

	    &report("\tRead $readname --> sequence $seqid");

	    $hits++;
	}

	die "Read $readnamelike is not in contig $old_contig_id" unless $hits;
    }

    $sth->finish();

    return $seqids;
}

sub copyContig {
    my $dbh = shift;
    my $old_contig_id = shift;

    &report("=== copyContig($old_contig_id) ===");

    my $query = "insert into CONTIG(project_id,origin,userid,created)" .
	" select project_id,origin,userid,now() from CONTIG where contig_id = ?";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($old_contig_id);

    my $new_contig_id = $rc > 0 ? $dbh->{'mysql_insertid'} : -1;

    &report("\tNew contig ID is $new_contig_id");

    $sth->finish();

    return $new_contig_id;
}

sub copyMappings {
    my $dbh = shift;
    my $old_contig_id = shift;
    my $new_contig_id = shift;

    &report("=== copyMappings($old_contig_id, $new_contig_id) ===");

    my $query = "insert into MAPPING(contig_id,seq_id,cstart,cfinish,direction)" .
	" select ?,seq_id,cstart,cfinish,direction from MAPPING where contig_id = ?";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($new_contig_id, $old_contig_id);

    $sth->finish();

    &report("\tInserted $rc new rows into MAPPING");
}

sub removeSelectedSequences {
    my $dbh = shift;
    my $new_contig_id = shift;
    my $seqids = shift;

    &report("=== removeSelectedSequences($new_contig_id, [" . join(",",@{$seqids}) . "]) ===");

    my $query = "delete from MAPPING where contig_id = ? and seq_id = ?";

    my $sth = $dbh->prepare($query);

    foreach my $seqid (@{$seqids}) {
	my $rc = $sth->execute($new_contig_id, $seqid);

	&report("\tRemoved sequence $seqid");
    }

    $sth->finish();
}

sub confirmContigIntegrity {
    my $dbh = shift;
    my $new_contig_id = shift;

    &report("=== confirmContigIntegrity($new_contig_id) ===");

    my $query = "SELECT cstart,cfinish from MAPPING where contig_id = ? order by cstart asc";

    my $sth = $dbh->prepare($query);

    $sth->execute($new_contig_id);

    my $right = -1;

    my $gaps = 0;

    while (my ($cstart,$cfinish) = $sth->fetchrow_array()) {
	if ($right > 0 && $cstart > $right) {
	    $gaps++;
	    &report("\t***** Gap from " . ($right + 1) . " to " . ($cstart - 1) . " *****");
	}

	$right = $cfinish if ($cfinish > $right);
    }

    return $gaps == 0;
}

sub determineNewContigExtents {
    my $dbh = shift;
    my $new_contig_id = shift;

    &report("=== determineNewContigExtents($new_contig_id) ===");

    my $query = "select min(cstart),max(cfinish) from MAPPING where contig_id = ?";

    my $sth = $dbh->prepare($query);

    $sth->execute($new_contig_id);

    my ($a,$b) = $sth->fetchrow_array();

    &report("\tNew contig bounds are $a, $b");

    $sth->finish();

    return ($a, $b);
}

sub adjustMappings {
    my $dbh = shift;
    my $new_contig_id = shift;
    my $left = shift;

    &report("=== adjustMappings($new_contig_id, $left) ===");

    if ($left > 1) {
	my $offset = $left - 1;

	my $query = "update MAPPING set cstart=cstart-?, cfinish=cfinish-? where contig_id = ?";

	my $sth = $dbh->prepare($query);

	my $rc = $sth->execute($offset, $offset, $new_contig_id);

	$sth->finish();

	&report("\tAdjusted $rc rows in MAPPING");
    }

    &determineNewContigExtents($dbh, $new_contig_id);
}

sub copySegments {
    my $dbh = shift;
    my $old_contig_id = shift;
    my $new_contig_id = shift;

    &report("=== copySegments($old_contig_id, $new_contig_id) ===");

    my $query = "insert into SEGMENT(mapping_id,cstart,rstart,length)" .
	" select M2.mapping_id,S.cstart,S.rstart,S.length from MAPPING M1,MAPPING M2,SEGMENT S" .
	" where M1.contig_id = ? and M2.contig_id = ?" .
	" and M1.seq_id=M2.seq_id and M1.mapping_id=S.mapping_id";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($old_contig_id, $new_contig_id);

    $sth->finish();

    &report("\tInserted $rc new rows into SEGMENT");
}

sub adjustSegments {
    my $dbh = shift;
    my $new_contig_id = shift;
    my $left = shift;

    &report("=== adjustSegments($new_contig_id, $left) ===");

    if ($left > 1) {
	my $offset = $left - 1;

	my $query = "update MAPPING M left join SEGMENT S using(mapping_id)" .
	    " set S.cstart=S.cstart-? where contig_id = ?";

	my $sth = $dbh->prepare($query);

	my $rc = $sth->execute($offset, $new_contig_id);

	$sth->finish();

	&report("\tAdjusted $rc rows in SEGMENT");
    }
}

sub copyTagMappings {
    my $dbh = shift;
    my $old_contig_id = shift;
    my $new_contig_id = shift;

    &report("=== copyTagMappings($old_contig_id, $new_contig_id) ===");

    my $query = "insert into TAG2CONTIG(parent_id,contig_id,tag_id,cstart,cfinal,strand,comment)" .
	" select id as parent_id,?,tag_id,cstart,cfinal,strand,comment" .
	" from TAG2CONTIG where contig_id = ?";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($new_contig_id, $old_contig_id);

    $sth->finish();

    $rc = "no" unless $rc > 0;

    &report("\tInserted $rc new rows into TAG2CONTIG");
}

sub adjustTagMappings {
    my $dbh = shift;
    my $new_contig_id = shift;
    my $left = shift;

    &report("=== adjustTagMappings($new_contig_id, $left) ===");

    if ($left > 1) {
	my $offset = $left - 1;

	my $query = "update TAG2CONTIG set cstart=cstart-?, cfinal=cfinal-? where contig_id = ?";

	my $sth = $dbh->prepare($query);

	my $rc = $sth->execute($offset, $offset, $new_contig_id);

	$sth->finish();

	&report("\tAdjusted $rc rows in TAG2CONTIG");
    }
}

sub removeInvalidTagMappings {
    my $dbh = shift;
    my $new_contig_id = shift;
    my $new_contig_length = shift;

    &report("=== removeInvalidTagMappings($new_contig_id, $new_contig_length) ===");

    my $query = "delete from TAG2CONTIG where contig_id = ? and (cstart < 1 or cfinal > ?)";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($new_contig_id, $new_contig_length);
    
    $sth->finish();

    $rc = "no" unless $rc > 0;

    &report("\tRemoved $rc invalid rows from TAG2CONTIG");
}

sub createContigToContigMapping {
    my $dbh = shift;
    my $old_contig_id = shift;
    my $left = shift;
    my $right = shift;
    my $new_contig_id = shift;

    &report("=== createContigToContigMapping($old_contig_id, $left, $right, $new_contig_id) ===");

    my $query = "insert into C2CMAPPING(contig_id,parent_id,cstart,cfinish,pstart,pfinish,direction)" .
	" values(?,?,?,?,?,?,?)";

    my $sth = $dbh->prepare($query);

    my $new_contig_length = 1 + $right - $left;

    my $rc = $sth->execute($new_contig_id, $old_contig_id, 1, $new_contig_length, $left, $right, 'Forward');

    my $mapping_id = $dbh->{'mysql_insertid'};

    &report("\tInserted $rc rows into C2CMAPPING, mapping_id is $mapping_id");
    
    $sth->finish();

    $query = "insert into C2CSEGMENT(mapping_id,cstart,pstart,length) values(?,?,?,?)";

    $sth = $dbh->prepare($query);

    $rc = $sth->execute($mapping_id,1,$left,$new_contig_length);

    &report("\tInserted $rc rows into C2CSEGMENT");

    $sth->finish();
}

sub fixNewContigRecord {
    my $dbh = shift;
    my $new_contig_id = shift;

    &report("=== fixNewContigRecord($new_contig_id) ===");

    my $gap4name = &getLeftmostReadnameForContig($dbh, $new_contig_id);

    my ($nreads,$ctglen,$cover) = &getReadCountLengthAndCoverForContig($dbh, $new_contig_id);

    my $query = "update CONTIG set gap4name = ?, nreads = ?, length = ?, ncntgs = ?, cover = ?" .
	" where contig_id = ?";

    my $sth = $dbh->prepare($query);

    my $rc = $sth->execute($gap4name, $nreads, $ctglen, 1, $cover, $new_contig_id);

    &report("\tUpdated $rc rows in CONTIG");

    $sth->finish();
}

sub getLeftmostReadnameForContig {
    my $dbh = shift;
    my $new_contig_id = shift;

    &report("=== getLeftmostReadnameForContig($new_contig_id) ===");

    my $query = "select R.readname from MAPPING M,SEQ2READ SR,READINFO R" .
	" where M.contig_id = ? and M.seq_id = SR.seq_id and SR.read_id = R.read_id" .
	" order by M.cstart asc limit 1";

    my $sth = $dbh->prepare($query);

    $sth->execute($new_contig_id);

    my ($readname) = $sth->fetchrow_array();

    $sth->finish();

    &report("\tLeftmost read in contig $new_contig_id is $readname");

    return $readname;
}

sub getReadCountLengthAndCoverForContig {
    my $dbh = shift;
    my $new_contig_id = shift;

    &report("=== getReadCountLengthAndCoverForContig($new_contig_id) ===");

    my $query = "select count(*),max(cfinish),sum(1+cfinish-cstart)/max(cfinish)" .
	" from MAPPING where contig_id = ?";

    my $sth = $dbh->prepare($query);

    $sth->execute($new_contig_id);

    my ($readcount, $ctglen, $cover) = $sth->fetchrow_array();

    $sth->finish();

    &report("\tContig $new_contig_id has $readcount reads, length $ctglen and cover = $cover");

    return ($readcount, $ctglen, $cover);
}

sub report {
    my $msg = shift;

    if (defined($msg)) {
	print "\n" if ($msg =~ /^(===|\#\#\#) /);
	print STDERR $msg,"\n";
    }
}

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
    print STDERR "    -contig\t\tID of contig\n";
    print STDERR "    -readnames\t\tComma-separated list of readnames to be removed\n";
}
