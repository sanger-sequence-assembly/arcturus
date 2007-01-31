#!/usr/local/bin/perl
#
# readscheck
#
# This script extracts one or more reads and generates a CAF file

use strict;

use DBI;
use FileHandle;
use DataSource;
use Compress::Zlib;

my $verbose = 0;
my @dblist = ();
my $instance;
my $organism;
my $readids;
my $outfile;
my $verbose;
my $aspedafter;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $readids = shift @ARGV if ($nextword eq '-readids');

    $aspedafter = shift @ARGV if ($nextword eq '-aspedafter');

    $outfile = shift @ARGV if ($nextword eq '-caf');

    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance) &&
	defined($outfile) &&
	(defined($readids) || defined($aspedafter))) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

if (defined($readids) && defined($aspedafter)) {
    print STDERR "You can only specify ONE of -readids and -aspedafter";
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);
my $dsn = $ds->getURL();

my $dbh = $ds->getConnection();

if (defined($dbh)) {
    if ($verbose) {
	print STDERR "Connected to DataSource(instance=$instance, organism=$organism)\n";
	print STDERR "DataSource URL is $dsn\n";
    }
} else {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is $dsn\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $outfh = new FileHandle($outfile, "w");

print STDERR "\n" if $verbose;

my $dict_ligation   = &createDictionary($dbh, 'LIGATION', 'ligation_id', 'silow, sihigh,clone_id');
my $dict_clone      = &createDictionary($dbh, 'CLONE', 'clone_id', 'name');
my $dict_status     = &createDictionary($dbh, 'STATUS', 'status_id', 'name');
my $dict_basecaller = &createDictionary($dbh, 'BASECALLER', 'basecaller_id', 'name');
my $dict_svector    = &createDictionary($dbh, 'SEQUENCEVECTOR', 'svector_id', 'name');
my $dict_cvector    = &createDictionary($dbh, 'CLONINGVECTOR', 'cvector_id', 'name');

my $ndone = 0;
my $nfound = 0;

my $query = "SELECT read_id,readname,asped,strand,primer,chemistry,basecaller," .
    "status,lqleft,lqright,svector,svleft,svright,cvector,cvleft,cvright," .
    "slength,sequence,quality FROM READINFO LEFT JOIN SEQUENCE USING (read_id)";

$query .= defined($readids) ? " WHERE READINFO.read_id=?" : " WHERE asped > ?";

$query .= " AND pstatus=0";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed on $dsn");

my $tmplquery = "SELECT name,ligation_id FROM READINFO LEFT JOIN TEMPLATE USING (template_id)" .
    " WHERE READINFO.read_id=?";

my $tmplsth = $dbh->prepare($tmplquery);
&db_die("prepare($tmplquery) failed on $dsn");

printf STDERR "%8d %8d", $ndone, $nfound unless $verbose;
my $format = "\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010%8d %8d";

if (defined($readids)) {
    my $readranges = &parseReadIDRanges($readids);

    foreach my $readrange (@{$readranges}) {
	my ($idlow, $idhigh) = @{$readrange};
	
	for (my $readid = $idlow; $readid <= $idhigh; $readid++) {
	    print STDERR "Read($readid)" if $verbose;

	    $sth->execute($readid);
	    &db_die("execute failed on read query for readid=$readid");

	    if (&processOneRead($sth, $tmplsth, $outfh, $dict_ligation, $dict_clone,
				$dict_status, $dict_basecaller, $dict_svector, $dict_cvector)) {
		$ndone++;
		$nfound++;
		&reportProgress($format, $ndone, $nfound) unless $verbose;
		print STDERR "\n" if $verbose;
	    } else {
		print STDERR " not found.\n" if $verbose;
	    }
	}
    }
} else {
    $sth->execute($aspedafter);
    &db_die("execute failed on read query for aspedafter=$aspedafter");

    while (&processOneRead($sth, $tmplsth, $outfh, $dict_ligation, $dict_clone,
			   $dict_status, $dict_basecaller, $dict_svector, $dict_cvector)) {
	$ndone++;
	$nfound++;
	&reportProgress($format, $ndone, $nfound) unless $verbose;
    }
}

unless ($verbose) {
    &reportProgress($format, $ndone, $nfound);
    print STDERR "\n";
}

$outfh->close();

$sth->finish();
$tmplsth->finish();

$dbh->disconnect();

exit(0);

sub processOneRead {
    my ($sth, $tmplsth, $outfh, $dict_ligation, $dict_clone,
	$dict_status, $dict_basecaller, $dict_svector, $dict_cvector);

    my @ary = $sth->fetchrow_array();

    if (scalar(@ary) > 0) {
	my ($readid, $readname, $asped, $strand, $primer, $chemistry,
	    $basecaller, $pstatus, $qleft, $qright, $svector, $svleft, $svright,
	    $cvector, $cvleft, $cvright, $slength, $sequence, $quality) = @ary;
	
	$tmplsth->execute($readid);

	my ($template,$ligation) = $tmplsth->fetchrow_array();
	
	print STDERR " name=$readname" if ($verbose && defined($readname));
	
	print STDERR " length=$slength" if ($verbose && defined($slength));
	
	$sequence = uncompress($sequence);
	
	$quality = uncompress($quality);
	
	my $slen = length($sequence);
	
	my @bq = unpack("c*", $quality);
	
	print $outfh "Sequence : $readname\n";
	print $outfh "Is_read\n";
	print $outfh "Unpadded\n";
	
	print $outfh "SCF_File $readname" . "SCF\n";
	
	print $outfh "Template $template\n";
	
	print $outfh "Asped $asped\n" if defined($asped);
	
	my ($silow, $sihigh, $clone) = &dictionaryLookup($dict_ligation, $ligation);
	
	print $outfh "Insert_size $silow $sihigh\n" if (defined($silow) && defined($sihigh));
	
	my ($clonename) = &dictionaryLookup($dict_clone, $clone);
	
	print $outfh "Clone $clonename\n" if defined($clonename);
	
	print $outfh "Strand $strand\n" if defined($strand);
	
	print $outfh "Primer $primer\n" if defined($primer);
	
	print $outfh "Dye $chemistry\n" if defined($chemistry);
	
	my ($bc) = &dictionaryLookup($dict_basecaller, $basecaller);
	
	print $outfh "Base_caller $bc\n"if defined($bc);
	
	my ($ps) = &dictionaryLookup($dict_status, $pstatus);
	
	print $outfh "ProcessStatus $ps\n" if defined($ps);
	
	if (defined($svleft) && defined($svright)) {
	    my ($svector) = &dictionaryLookup($dict_svector, $svector);
	    print $outfh "Seq_vec SVEC $svleft $svright \"$svector\"\n";
	}
	
	if (defined($cvleft) && defined($cvright)) {
	    my ($cvector) = &dictionaryLookup($dict_cvector, $cvector);
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
	
	while (my $n = scalar(@bq)) {
	    print $outfh join(' ',@bq[0..24]),"\n";
	    @bq = @bq[25..$n];
	}
	
	print $outfh "\n";

	return 1;
    } else {
	return 0;
    }
}

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
	my $thiskey = shift @ary;
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
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -caf\t\tName of output CAF file\n";
    print STDERR "\n";
    print STDERR "EXCLUSIVE MANDATORY PARAMETERS:\n";
    print STDERR "    -readids\t\tRange of read IDs to process\n";
    print STDERR "    -aspedafter\t\tOutput all reads asped after this date\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\tVerbose output\n";
    print STDERR "    -namelike\t\tSelect readnames like this from the database\n";
}
