#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $instance = 'dev';
my $organism = 'EIMER';

my $adb = new ArcturusDatabase(-instance => $instance,
                               -organism => $organism);

my $dbh = $adb->getConnection();

my @queries = (
	       "create temporary table CURCTG as" .
	       " select CONTIG.contig_id from CONTIG left join C2CMAPPING" .
	       " on CONTIG.contig_id = C2CMAPPING.parent_id" .
	       " where C2CMAPPING.parent_id is null",

	       "create temporary table CURSEQ" .
	       " (seq_id integer not null, contig_id integer not null, key (contig_id)) as" .
	       " select seq_id,CURCTG.contig_id from CURCTG left join MAPPING using(contig_id)",

	       "create temporary table CURREAD" .
	       " (read_id integer not null, seq_id integer not null, contig_id integer not null," .
	       " key (read_id)) as" .
	       " select read_id,SEQ2READ.seq_id,contig_id from CURSEQ left join SEQ2READ" .
	       " using(seq_id)",

	       "create temporary table FREEREAD as" .
	       " select READS.read_id from READS left join CURREAD using(read_id)" .
	       " where seq_id is null"
	       );

foreach my $query (@queries) {
    print STDERR "Executing $query\n";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();
    &db_die("execute($query) failed");

    $sth->finish();
}

my $query =  "select READS.read_id,readname from FREEREAD left join READS using(read_id)" .
    " where readname like '%.____%'";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my %finishing_reads;

while (my @ary = $sth->fetchrow_array()) {
    my ($readid, $readname) = @ary;

    $finishing_reads{$readname} = $readid;
}

my $nreads = scalar(keys %finishing_reads);

$sth->finish();

$query = "select read_id from READS where readname = ?";

my $sth_readid = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select SEQ2READ.seq_id, contig_id, mapping_id, cstart, cfinish, direction" .
    " from SEQ2READ left join MAPPING" .
    " using(seq_id) where read_id = ? and contig_id is not null";

#" order by contig_id desc limit 1";

my $sth_mapping = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select min(rstart),max(rstart+length-1) from SEGMENT where mapping_id = ?";

my $sth_fwd_readextents =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select max(rstart),min(rstart-length+1) from SEGMENT where mapping_id = ?";

my $sth_rev_readextents =  $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "select length from CONTIG where contig_id = ?";

my $sth_contig = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $nfound = 0;

foreach my $finishing_readname (keys %finishing_reads) {
    my ($stem, $suffix) = split(/\./, $finishing_readname);

    my $shotgun_readname = $stem . '.' . substr($suffix, 0, 3);

    $sth_readid->execute($shotgun_readname);

    if (my ($readid) = $sth_readid->fetchrow_array()) {
	$sth_mapping->execute($readid);

	if (my ($seqid, $contigid, $mappingid, $cstart, $cfinish, $direction) =
	    $sth_mapping->fetchrow_array()) {

	    $sth_contig->execute($contigid);
	    my ($ctglen) = $sth_contig->fetchrow_array();
	    $sth_contig->finish();

	    $sth = ($direction eq 'Forward') ? $sth_fwd_readextents : $sth_rev_readextents;
		
	    $sth->execute($mappingid);
	    my ($rstart, $rfinish) = $sth->fetchrow_array();
	    $sth->finish();

	    print "$finishing_readname $contigid $ctglen $direction $cstart:$cfinish $rstart:$rfinish\n";

	    $nfound++;
	}

	$sth_mapping->finish();
    }

    $sth_readid->finish();
}

print "\nFound $nfound finishing read partners out of $nreads\n";

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    #exit(0);
}
