#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigid;
my $clonename;
my $minlen;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $contigid = shift @ARGV if ($nextword eq '-contig');

    $clonename = shift @ARGV if ($nextword eq '-clone');

    $minlen = shift @ARGV if ($nextword eq '-minlen');
}

unless (defined($instance) &&
	defined($organism) &&
	defined($clonename)) {
    &showUsage();
    exit(0);
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my ($query, $stmt);

my @contigs;

if (defined($contigid)) {
    push @contigs, $contigid;
} else {
    $query =  "select CONTIG.contig_id from CONTIG left join C2CMAPPING" .
	" on CONTIG.contig_id = C2CMAPPING.parent_id" .
	" where C2CMAPPING.parent_id is null";

    $query .= " and length > $minlen" if defined($minlen);

    $query .= " order by length desc";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $stmt->execute();
    &db_die("Failed to execute query \"$query\"");

    while (($contigid) = $stmt->fetchrow_array()) {
	push @contigs, $contigid;
    }

    $stmt->finish();
}

my @conditions = ("MAPPING.seq_id = SEQ2READ.seq_id",
		  "SEQ2READ.read_id = READINFO.read_id",
		  "READINFO.template_id = TEMPLATE.template_id",
		  "TEMPLATE.ligation_id = LIGATION.ligation_id",
		  "LIGATION.clone_id = CLONE.clone_id");

my $conditions = join(' and ', @conditions);

$query = "select TEMPLATE.template_id,READINFO.read_id,readname,cstart,cfinish,direction,LIGATION.sihigh" .
    " from MAPPING,SEQ2READ,READINFO,TEMPLATE,LIGATION,CLONE" .
    " where contig_id = ?" .
    " and $conditions and CLONE.name=? order by template_id asc,cstart asc";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

foreach $contigid (@contigs) {
    $stmt->execute($contigid, $clonename);
    &db_die("Failed to execute query \"$query\" for contig $contigid");
    
    my $last_templateid = -1;
    my ($last_readname, $last_cstart, $last_cfinish, $last_direction);

    while (my ($templateid, $readid, $readname, $cstart, $cfinish, $direction, $sihigh) =
	   $stmt->fetchrow_array()) {
	if ($templateid == $last_templateid) {
	    if ($last_direction eq 'Forward' && $direction eq 'Reverse') {
		printf "%8d %8d  %8d  %8d  %-30s  %-30s\n",$contigid,
		$last_cstart, $cfinish, ($cfinish-$last_cstart-$sihigh),
		$last_readname, $readname;
	    } else {
		print STDERR "Inconsistent: $contigid $last_readname $last_direction $last_cstart to $last_cfinish <-->" .
		    " $readname $direction $cstart $cfinish\n";
	    }
	}
	
	($last_templateid, $last_readname, $last_cstart, $last_cfinish, $last_direction) =
	    ($templateid, $readname, $cstart, $cfinish, $direction);
    }
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
    print STDERR "  -instance\t\tName of instance\n";
    print STDERR "  -organism\t\tName of organism\n";
    print STDERR "  -clone\t\tName of clone for BAC/fosmid ends\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "  -contig\t\tID of contig to analyse\n";
    print STDERR "  -minlen\t\tMinimum length for contigs scan\n";
}
