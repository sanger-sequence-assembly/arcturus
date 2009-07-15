#!/usr/local/bin/perl
#
# traceloader.pl
#
# This script loads traces into a MySQL database

use strict;

use DBI;
use DataSource;
use FileHandle;

use Compress::Zlib;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $dir;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $dir = shift @ARGV if ($nextword eq '-dir');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($dir)) {
    print STDERR "*** ERROR *** One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

unless (-d $dir) {
    print STDERR "*** ERROR *** \"$dir\" is not a directory.\n\n";
    exit(2);
}

opendir(DIR, $dir);

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select read_id from READINFO where readname = ?";

my $sth_readid = $dbh->prepare($query);
&db_die("prepare($query) failed");

$query = "insert into TRACE(read_id, trace) values (?,?)";

my $sth_put_trace = $dbh->prepare($query);
&db_die("prepare($query) failed");

while (my $filename = readdir(DIR)) {
    next unless ($filename =~ /SCF$/);

    my $readname = substr($filename, 0, length($filename) - 3);

    $filename = "$dir/$filename";

    $sth_readid->execute($readname);
    &db_carp("Executing seek readid on $readname");

    my ($readid) = $sth_readid->fetchrow_array();
    &db_carp("Fetching data from seek readid on $readname");

    next unless defined($readid);

    my @statinfo = stat($filename);

    my $filesize = $statinfo[7];

    my $readbuffersize = 5 * $filesize;

    if (open(FILE, "gunzip -c $filename|")) {
	my $content='';
	my $buffer;

	my $bytesread = 0;

	while ($bytesread = read(FILE, $buffer, $filesize)) {
	    $content .= $buffer;
	}

	close(FILE);

	my $readlen = length($content);

	$content = compress($content);

	my $clen = length($content);

	my $rc = $sth_put_trace->execute($readid, $content);
	&db_carp("Inserting trace for $readname ($readid)");

	printf "%-30s %6d %6d %6d\n", $readname, $filesize, $readlen, $clen if ($rc == 1);
    } else {
	print STDERR "Unable to open $filename for reading\n";
    }
}

closedir(DIR);

$sth_readid->finish();
$sth_put_trace->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub db_carp {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -dir\t\tName of the source directory\n";
}
