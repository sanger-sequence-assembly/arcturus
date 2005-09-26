#!/usr/local/bin/perl
#
# readscheck
#
# This script extracts one or more reads and generates a CAF file

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

$verbose = 0;
@dblist = ();

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $readids = shift @ARGV if ($nextword eq '-readids');

    $outfile = shift @ARGV if ($nextword eq '-caf');

    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($outfile) &&
	defined($readids)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

$instance = 'prod' unless defined($instance);

$ds = new DataSource(-instance => $instance, -organism => $organism);

$dbh = $ds->getConnection();

if (defined($dbh)) {
    if ($verbose) {
	print STDERR "Connected to DataSource(instance=$instance, organism=$organism)\n";
	print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    }
} else {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

$outfh = new FileHandle($outfile, "w");

print STDERR "\n" if $verbose;

$dict_ligation   = &createDictionary($dbh, 'LIGATIONS', 'ligation_id', 'silow, sihigh');
$dict_clone      = &createDictionary($dbh, 'CLONES', 'clone', 'clonename');
$dict_status     = &createDictionary($dbh, 'STATUS', 'status', 'identifier');
$dict_basecaller = &createDictionary($dbh, 'BASECALLER', 'basecaller', 'name');
$dict_svector    = &createDictionary($dbh, 'SEQUENCEVECTORS', 'svector_id', 'name');
$dict_cvector    = &createDictionary($dbh, 'CLONINGVECTORS', 'cvector', 'name');

$readranges = &parseReadIDRanges($readids);

$ndone = 0;
$nfound = 0;

$query = "SELECT readname,asped,clone,strand,primer,chemistry,basecaller," .
    "pstatus,lqleft,lqright,svector,svleft,svright,cvector,cvleft,cvright," .
    "slength,sequence,quality FROM READS LEFT JOIN SEQUENCE USING (read_id) WHERE READS.read_id=? AND pstatus=0";

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed on $dsn");

$tmplquery = "SELECT name,ligation_id FROM READS LEFT JOIN TEMPLATE USING (template_id)" .
    " WHERE READS.read_id=?";

$tmplsth = $dbh->prepare($tmplquery);
&db_die("prepare($tmplquery) failed on $dsn");

printf STDERR "%8d %8d", $ndone, $nfound unless $verbose;
$format = "\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010%8d %8d";

foreach $readrange (@{$readranges}) {
    ($idlow, $idhigh) = @{$readrange};

    for ($readid = $idlow; $readid <= $idhigh; $readid++) {
	$ndone++;

	print STDERR "Read($readid)" if $verbose;

	$sth->execute($readid);

	$tmplsth->execute($readid);

	($template,$ligation) = $tmplsth->fetchrow_array();

	@ary = $sth->fetchrow_array();

	if (scalar(@ary) > 0) {
	    ($readname, $asped, $clone, $strand, $primer, $chemistry,
	     $basecaller, $pstatus, $qleft, $qright, $svector, $svleft, $svright,
	     $cvector, $cvleft, $cvright, $slength, $sequence, $quality) = @ary;

	    print STDERR " name=$readname" if ($verbose && defined($readname));
	    print STDERR " length=$slength" if ($verbose && defined($slength));

	    $sequence = uncompress($sequence);

	    $quality = uncompress($quality);

	    $slen = length($sequence);

	    @bq = unpack("c*", $quality);

	    print $outfh "Sequence : $readname\n";
	    print $outfh "Is_read\n";
	    print $outfh "Unpadded\n";

	    print $outfh "SCF_File $readname" . "SCF\n";

	    print $outfh "Template $template\n";

	    print $outfh "Asped $asped\n" if defined($asped);

	    ($silow, $sihigh) = &dictionaryLookup($dict_ligation, $ligation);

	    print $outfh "Insert_size $silow $sihigh\n" if (defined($silow) && defined($sihigh));

	    ($clonename) = &dictionaryLookup($dict_clone, $clone);

	    print $outfh "Clone $clonename\n" if defined($clonename);

	    print $outfh "Strand $strand\n" if defined($strand);

	    print $outfh "Primer $primer\n" if defined($primer);

	    print $outfh "Dye $chemistry\n" if defined($chemistry);

	    ($bc) = &dictionaryLookup($dict_basecaller, $basecaller);

	    print $outfh "Base_caller $bc\n"if defined($bc);

	    ($ps) = &dictionaryLookup($dict_status, $pstatus);

	    print $outfh "ProcessStatus $ps\n" if defined($ps);

	    if (defined($svleft) && defined($svright)) {
		($svector) = &dictionaryLookup($dict_svector, $svector);
		print $outfh "Seq_vec SVEC $svleft $svright \"$svector\"\n";
	    }

	    if (defined($cvleft) && defined($cvright)) {
		($cvector) = &dictionaryLookup($dict_cvector, $cvector);
		print $outfh "Clone_vec CVEC $cvleft $cvright \"$cvector\"\n";
	    }

	    print $outfh "Clipping QUAL $qleft $qright\n" if (defined($qleft) && defined($qright));

	    print $outfh "\n";

	    print $outfh "DNA : $readname\n";
	    while (length($sequence)) {
		print $outfh substr($sequence, 0, 50),"\n";
		$sequence = substr($sequence, 50);
	    }

	    print $outfh "\n";

	    print $outfh "BaseQuality : $readname\n";

	    while ($n = scalar(@bq)) {
		print $outfh join(' ',@bq[0..24]),"\n";
		@bq = @bq[25..$n];
	    }

	    print $outfh "\n";

	    $nfound++;

	    print STDERR "\n" if $verbose;
	} else {
	    print STDERR " not found.\n" if $verbose;
	}

	printf STDERR $format, $ndone, $nfound if (!$verbose && ($ndone % 50) == 0);
    }
}

unless ($verbose) {
    printf STDERR $format, $ndone, $nfound;
    print STDERR "\n";
}

$outfh->close();

$sth->finish();
$tmplsth->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub createDictionary {
    my ($dbh, $table, $pkey, $vals, $where, $junk)  = @_;

    print STDERR "createDictionary(dbh, $table, $pkey, $vals)\n";

    my $query = "SELECT $pkey,$vals FROM $table";

    $query .= " $where" if defined($where);

    my $sth = $dbh->prepare($query);
    &db_die("createDictionary: prepare($query) failed");

    $sth->execute();
    &db_die("createDictionary: execute($query) failed");

    my $dict = {};

    while(my @ary = $sth->fetchrow_array()) {
	$thiskey = shift @ary;
	$dict->{$thiskey} = [@ary];
    }

    $sth->finish();

    print STDERR "Found ",scalar(keys(%{$dict}))," entries\n\n";

    return $dict;
}

sub dictionaryLookup {
    my ($dict, $pkey, $junk) = @_;

    my $value = $dict->{$pkey};

    if (defined($value)) {
	return @{$value};
    } else {
	return ();
    }
}

sub parseReadIDRanges {
    my $string = shift;

    my @ranges = split(/,/, $string);

    my $result = [];

    foreach my $subrange (@ranges) {
	if ($subrange =~ /^\d+$/) {
	    push @{$result}, [$subrange, $subrange];
	}

	if ($subrange =~ /^(\d+)(\.\.|\-)(\d+)$/) {
	    push @{$result}, [$1, $3];
	}
    }

    return $result;
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -readids\t\tRange of read IDs to process\n";
    print STDERR "    -caf\t\tName of output CAF file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -verbose\t\tVerbose output\n";
    print STDERR "    -namelike\t\tSelect readnames like this from the database\n";
}
