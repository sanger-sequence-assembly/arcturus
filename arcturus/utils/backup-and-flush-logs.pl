#!/usr/local/bin/perl

use DBI;
use Cwd;

while ($nextword = shift @ARGV) {
    $port = shift @ARGV if ($nextword eq '-port');
    $host = shift @ARGV if ($nextword eq '-host');

    $flushlogs = 1 if ($nextword eq '-flushlogs');

    $dumpfiles = 1 if ($nextword eq '-dumpfiles');

    $automode = 1 if ($nextword eq '-auto');

    $testmode = 1 if ($nextword eq '-test');

    $dumpdir = shift @ARGV if ($nextword eq '-dumpdir');

    $label = shift @ARGV if ($nextword eq '-label');

    if ($nextword eq '-help') {
	&doHelp();
	exit(0);
    }
}

die "No host specified" unless defined($host);
die "No port specified" unless defined($port);

($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
 $tm_wday, $tm_yday, $tm_isdst, $junk) = localtime();

$tm_mon += 1;
$tm_year += 1900;

if ($automode) {
    die "You cannot specify -auto with an explicit mode"
	if (defined($flushlogs) || defined($dumpfiles));

    $flushlogs = 1;
    $dumpfiles = ($tm_wday == 5) ? 1 : 0;

    $wday = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
	     'Friday', 'Saturday')[$tm_wday];

    print STDERR "Auto mode selection: today is $wday ($tm_wday) ==>";
    print STDERR " -flushlogs" if $flushlogs;
    print STDERR " -dumpfiles" if $dumpfiles;
    print STDERR "\n";
}

die "You must specify at least one of -dumpfiles or -flushlogs"
    unless (defined($flushlogs) || defined($dumpfiles));

$dumpdir = cwd() unless $dumpdir;

$dbname = 'arcturus';
$username = 'arcturus';
$password = '***REMOVED***';

$dsn = 'DBI:mysql:' . $dbname . ';host=' . $host . ';port=' . $port;

$dbh = DBI->connect($dsn, $username, $password,
		     {PrintError => 0, RaiseError => 0});

die "connect($dsn, user=$username) failed: $DBI::errstr" unless $dbh;

$varquery = "SHOW VARIABLES LIKE 'datadir'";

$sth = $dbh->prepare($varquery);
&db_die("prepare($varquery) failed");

$sth->execute();
&db_die("execute($varquery) failed");

while(@ary = $sth->fetchrow_array()) {
    ($varname, $varvalue) = @ary;
    $datadir = $varvalue if ($varname eq 'datadir');
}

$sth->finish();

unless (defined($datadir)) {
    $dbh->disconnect();
    die "Could not determine name of data directory";
}

print STDERR "Data directory is $datadir\n";

$flushlockquery = 'FLUSH TABLES WITH READ LOCK';

$now = localtime();

print STDERR "Trying to lock tables at $now ...\n";

$dbh->do($flushlockquery);
&db_die("do($flushlockquery) failed on $dsn");

$then = localtime();

print STDERR "Lock acquired at $then\n";

if ($dumpfiles) {

    $filename = sprintf('%04d-%02d-%02d-%02d%02d%02d.tar',
			$tm_year, $tm_mon, $tm_mday,
			$tm_hour, $tm_min, $tm_sec);

    $filename = $label . '-' . $filename if defined($label);
    $filename = "$dumpdir/$filename" if (defined($dumpdir) && -d $dumpdir);

    print STDERR "tar file will be named $filename\n";

    $home = cwd();

    die "Cannot chdir to $datadir" unless chdir($datadir);

    $cmd = "tar cf $filename *";

    $cmd = "echo $cmd" if $testmode;

    print STDERR "Executing '$cmd' ... \n";

    $rc = system($cmd);

    print STDERR "Done with status=$rc\n";
}

if ($flushlogs) {
    $flushquery = 'FLUSH LOGS';

    print STDERR "Flushing binary logs ...\n";

    unless ($testmode) {
	$dbh->do($flushquery);
	&db_die("do($flushquery) failed on $dsn");
    }
}

$unlockquery = 'UNLOCK TABLES';

$dbh->do($unlockquery);
&db_die("do($unlockquery) failed on $dsn");

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub doHelp {
    print STDERR "backup-and-flush-logs.pl\n\n";
    print STDERR "A script to backup the data files and/or flush the binary logs\n";
    print STDERR "of a running MySQL instance.\n\n";
    print STDERR "OPTIONS\n-------\n\n";
    print STDERR "  -host hostname\tName of host on which the server is running.\n";
    print STDERR "  -port number\t\tPort number of the instance.\n";
    print STDERR "\n";
    print STDERR "  -flushlogs\t\tFlush and rotate the binary logs of this instance.\n";
    print STDERR "  -dumpfiles\t\tLock tables and make a tar file of the data directory.\n";
    print STDERR "\n";
    print STDERR "  -dumpdir\t\tThe directory into which to put the tar file.\n";
    print STDERR "  -label string\t\tLabel to prefix to tar file.\n";
}
