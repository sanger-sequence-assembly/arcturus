#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $instance = 'dev';
my $organism;
my $contig_id;
my $contig_end;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $contig_id  = shift @ARGV if ($nextword eq '-contig');

    $contig_end = shift @ARGV if ($nextword eq '-end');
}

die "Organism not specified" unless defined($organism);
die "Contig not specified" unless defined($contig_id);
die "Contig end not specified" unless defined($contig_end);

die "Invalid end (should be left or right)" unless
    ($contig_end eq 'left' || $contig_end eq 'right');

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

my $dbh = $adb->getConnection();

my $query_ctglen = "SELECT length FROM CONTIG WHERE contig_id = ?";

my $sth_ctglen =  $dbh->prepare($query_ctglen);
&db_die("prepare($query_ctglen) failed");

$sth_ctglen->execute($contig_id);
&db_die("execute($query_ctglen) failed");

my $ctglen = 0;

while (my @ary = $sth_ctglen->fetchrow_array()) {
    ($ctglen) = @ary;
}

$sth_ctglen->finish();

die "Contig length was zero" unless ($ctglen > 0);

print "Contig $contig_id has length $ctglen.\nLooking for bridges off $contig_end end.\n\n";

# Query to find reads near the right-hand end of a contig

my $comparator = ($contig_end eq 'left') ? 'cfinish < ?' : 'cstart > ?';
my $direction = ($contig_end eq 'left') ? 'Reverse' : 'Forward';

my $query_endread = "SELECT read_id,cstart,cfinish,direction from MAPPING left join SEQ2READ using(seq_id)" .
    " where contig_id = ? and " . $comparator . " and direction = ?";

my $sth_endread =  $dbh->prepare($query_endread);
&db_die("prepare($query_endread) failed");

# Query to find the template and strand of a read

my $query_template = "SELECT template_id,strand FROM READS WHERE read_id = ?";

my $sth_template = $dbh->prepare($query_template);
&db_die($query_template);

# Query to find the insert size range of a template

my $query_ligation = "SELECT silow,sihigh FROM TEMPLATE LEFT JOIN LIGATION USING(ligation_id) WHERE template_id = ?";

my $sth_ligation = $dbh->prepare($query_ligation);
&db_die($query_ligation);

my $query_linkreads = "SELECT READS.read_id,seq_id FROM READS LEFT JOIN SEQ2READ USING(read_id)" .
    " WHERE template_id = ? and strand != ?";

my $sth_linkreads = $dbh->prepare($query_linkreads);
&db_die($query_linkreads);

my $query_mappings = "SELECT contig_id, cstart, cfinish, direction FROM MAPPING WHERE seq_id = ?";

my $sth_mappings = $dbh->prepare($query_mappings);
&db_die($query_mappings);

# Now begin processing ...

my $limit = ($contig_end eq 'left') ? 4000 : $ctglen - 4000;

$sth_endread->execute($contig_id, $limit, $direction);
&db_die("execute($query_endread) failed");

while (my @ary = $sth_endread->fetchrow_array()) {
    my ($read_id, $cstart, $cfinish, $direction) = @ary;

    $sth_template->execute($read_id);
    my ($template_id, $strand) = $sth_template->fetchrow_array();
    $sth_template->finish();

    $sth_ligation->execute($template_id);
    my ($silow, $sihigh) = $sth_ligation->fetchrow_array();
    $sth_ligation->finish();

    next if (($contig_end eq 'right' && $cstart + $sihigh < $ctglen) ||
	     ($contig_end eq 'left' && $cfinish > $sihigh));

    next unless ($sihigh < 10000);

    printf "READ %8d :  %8d %8d  %s\n", $read_id, $cstart, $cfinish, $direction;

    printf "  TEMPLATE %d  STRAND %s  INSERT_SIZE(%d, %d)\n", $template_id, $strand, $silow, $sihigh;

    $sth_linkreads->execute($template_id, $strand);

    while (my @linkary = $sth_linkreads->fetchrow_array()) {
	my ($link_read_id, $link_seq_id) = @linkary;

	$sth_mappings->execute($link_seq_id);

	while (my @mapary = $sth_mappings->fetchrow_array()) {
	    my ($link_contig, $link_cstart, $link_cfinish, $link_direction) = @mapary;

	    next if ($contig_id == $link_contig);

	    $sth_ctglen->execute($link_contig);
	    my ($link_ctglen) = $sth_ctglen->fetchrow_array();
	    $sth_ctglen->finish();

	    printf "    CONTIG %8d (%8d) READ %8d/%8d  POSITION %8d %8d  DIRECTION %s\n",
	    $link_contig, $link_ctglen, $link_read_id, $link_seq_id, $link_cstart, $link_cfinish, $link_direction;
	}

	$sth_mappings->finish();
    }

    $sth_linkreads->finish();

    print "\n";
}

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}
