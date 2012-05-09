#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;
use Compress::Zlib;

use strict;

my $nextword;
my $instance;
my $organism;
my $history = 0;
my $verbose = 0;
my $finishing = 0;
my $exclude;
my $tolerance = 2000;
my $dir;
my $namelike;
my $touchfiles = 0;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $exclude = shift @ARGV if ($nextword eq '-exclude');
    $tolerance = shift @ARGV if ($nextword eq '-tolerance');
    $dir = shift @ARGV if ($nextword eq '-dir');
    $namelike = shift @ARGV if ($nextword eq '-namelike');
    $touchfiles = 1 if ($nextword eq '-touchfiles');
    $verbose = 1 if ($nextword eq '-verbose');
}

unless (defined($instance) && defined($organism) &&
	(defined($dir) || defined($namelike))) {
    &showUsage();
    exit(0);
}

my $adb;

$adb = new ArcturusDatabase(-instance => $instance,
			    -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

print STDERR "Creating current contig temporary table\n" if $verbose;

my $query = "create temporary table currentcontigs as" .
    " select CONTIG.contig_id,gap4name,nreads,length,created,updated,project_id" .
    " from CONTIG left join C2CMAPPING" .
    " on CONTIG.contig_id = C2CMAPPING.parent_id where C2CMAPPING.parent_id is null";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

my $ncontigs = $stmt->execute();
&db_die("Failed to execute query \"$query\"");

$stmt->finish();

print STDERR "Found $ncontigs contigs\n" if $verbose;

my %queries = ("candidatereads",
	       "select readname from READINFO where readname like ?",

	       "targetreadmapping",
	       "select MAPPING.contig_id,MAPPING.seq_id,cstart,cfinish,direction" .
	       " from currentcontigs,MAPPING,SEQ2READ,READINFO" .
	       " where currentcontigs.contig_id = MAPPING.contig_id and MAPPING.seq_id = SEQ2READ.seq_id" .
	       " and SEQ2READ.read_id = READINFO.read_id and readname = ?",
    
	       "overlapmappings",
	       "select readname,cstart,cfinish,direction from MAPPING,SEQ2READ,READINFO" .
	       " where contig_id = ? and MAPPING.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id" .
	       " and ((cstart>? and cstart<?) or (cfinish>? and cfinish<?) or (cstart<=? and cfinish>=?))" .
	       " order by cstart asc"
	       );

my $statements;

foreach my $qkey (keys %queries) {
    $statements->{$qkey} = $dbh->prepare($queries{$qkey});
    &db_die("Preparing " . $queries{$qkey});
}

my @readlist;

if (defined($dir)) {
    die "$dir is not a directory" unless -s $dir;
    opendir(DIR, $dir);
    @readlist = readdir(DIR);
    closedir(DIR);
} else {
   $statements->{'candidatereads'}->execute($namelike); 
   while (my ($readname) = $statements->{'candidatereads'}->fetchrow_array()) {
       push @readlist, $readname;
   }
   $statements->{'candidatereads'}->finish();
   $touchfiles = 0;
}

study($exclude) if defined($exclude);

foreach my $readname (@readlist) {
    $statements->{'targetreadmapping'}->execute($readname);

    my ($contigid,$seqid,$cstart,$cfinish,$direction) =
	$statements->{'targetreadmapping'}->fetchrow_array();

    next unless defined($contigid);

    print STDERR "$readname in contig $contigid at $cstart to $cfinish in $direction sense\n" if $verbose;

    $statements->{'overlapmappings'}->execute($contigid,
					      $cstart, $cfinish,
					      $cstart, $cfinish,
					      $cstart, $cfinish);

    my $bestname;
    my $bestscore = -1;
    my $offset;
    my $sense;

    while (my ($ovreadname,$ovcstart,$ovcfinish,$ovdirection) =
	   $statements->{'overlapmappings'}->fetchrow_array()) {
	next if ($ovreadname eq $readname);
	next if (defined($exclude) && $ovreadname =~ /$exclude/);

	my $overlap = 0;
	my $ovtype;

	if ($ovcfinish < $cfinish) {
	    $overlap = $ovcfinish - $cstart + 1;
	    $ovtype = 'L';
	} elsif ($ovcstart > $cstart) {
	    $overlap = $cfinish - $ovcstart + 1;
	    $ovtype = 'R';
	} else {
	    $overlap = $cfinish - $cstart + 1;
	    $ovtype = 'C';
	}

	if ($overlap > $bestscore) {
	    $bestscore = $overlap;
	    $bestname = $ovreadname;
	    $offset = $cstart - $ovcstart;
	    $sense = ($direction eq $ovdirection) ? '+' : '-';
	}

	print STDERR "\t$ovreadname at $ovcstart to $ovcfinish in $ovdirection sense ($overlap $ovtype)\n" if $verbose;
    }

    if (defined($bestname)) {
	print STDERR "\t\tBest: $bestname with a score of $bestscore\n" if $verbose;

	printf "%-24s %8d %8d %8d %-24s %8d %s\n", $readname,$contigid,$cstart,$cfinish,$bestname,$offset,$sense;

	if ($touchfiles) {
	    my $filename = "$dir/$readname";

	    if (-w $filename) {
		my $fh = new FileHandle($filename, "a");
		print $fh "AP $bestname $sense $offset $tolerance\n";
		$fh->close();
	    } else {
		print STDERR "Unable to modify $filename, not writeable\n";
	    }
	}
    }
}

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "-dir\t\t\tDirectory to search for experiment files\n";
    print STDERR "-namelike\t\tPattern to match for candidate read names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "-verbose\t\tShow verbose output\n";
    print STDERR "-exclude\t\tReadname regexp to exclude\n";
    print STDERR "-tolerance\t\tTolerance for Gap4 directed assembly [default: 2000]\n";
    print STDERR "-touchfiles\t\tModify the experiment files by adding an AP record\n";
}
