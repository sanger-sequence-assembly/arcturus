#!/usr/local/bin/perl
#
# Arcturus MySQL backup script
# ----------------------------
#
# This script can perform two functions.
#
# 1. It can make a full backup dump of the data directory of a running MySQL
#    server, using 'tar' after flushing and locking the tables.
#
# 2. It can flush the binary log of a running server.
#
# Optionally, it can also copy the recent binary logs and/or the tarball of the
# data directory to a 'safe' location, typically a filesystem which is physically
# separate from the one on which the server's data and binary log files reside.

use DBI;
use Cwd;
use Mail::Send;

###
### Recipients of fatal error message
###

$rcpts = ['adh@sanger.ac.uk', 'ejz@sanger.ac.uk'];

###
### Argument parsing
###

while ($nextword = shift @ARGV) {
    $port = shift @ARGV if ($nextword eq '-port');
    $host = shift @ARGV if ($nextword eq '-host');

    $dbname = shift @ARGV if ($nextword eq '-database');
    $username = shift @ARGV if ($nextword eq '-username');
    $password = shift @ARGV if ($nextword eq '-password');

    $flushlogs = 1 if ($nextword eq '-flushlogs');

    $dumpfiles = 1 if ($nextword eq '-dumpfiles');

    $automode = 1 if ($nextword eq '-auto');

    $testmode = 1 if ($nextword eq '-test');

    $gzip = 1 if ($nextword eq '-gzip');

    $dumpdir = shift @ARGV if ($nextword eq '-dumpdir');

    $safedumpdir = shift @ARGV if ($nextword eq '-safedumpdir');

    $binlogdir = shift @ARGV if ($nextword eq '-binlogdir');

    $cp = shift @ARGV if ($nextword eq '-cp');

    $sleeptime = shift @ARGV if ($nextword eq '-sleeptime');

    $forcereport = 1 if ($nextword eq '-forcereport');

    if ($nextword eq '-help') {
	&doHelp();
	exit(0);
    }
}

###
### This is the command we shall use to copy files to the safe location.
### In the real world, this is more likely to be rcp than cp, and the
### destination directory will be specified as hostname:/directory/name
###

$cp = '/bin/cp' unless (defined($cp) && -x $cp);

###
### Check that we have the hostname and port number of the server
###

die "No host specified" unless defined($host);
die "No port specified" unless defined($port);

###
### This parameter defines the pause between flushing the binary log and trying
### to backup the old log file
###

$sleeptime = 10 unless (defined($sleeptime) && $sleeptime =~ /^\d+$/ && $sleeptime > 0);

###
### Get the components of the current date and time
###

($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
 $tm_wday, $tm_yday, $tm_isdst, $junk) = localtime();

$tm_mon += 1;
$tm_year += 1900;

###
### In auto mode, we flush logs every day of the week, but we only do a
### full data dump on Fridays
###

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

$dbname = 'arcturus' unless defined($dbname);

unless (defined($username) && defined($password)) {
    $username = 'arcturus';
    $password = '***REMOVED***';
}

###
### Establish a connection to the MySQL server
###

$dsn = 'DBI:mysql:' . $dbname . ';host=' . $host . ';port=' . $port;

$dbh = DBI->connect($dsn, $username, $password,
		     {PrintError => 0, RaiseError => 0});

die "connect($dsn, user=$username) failed: $DBI::errstr" unless $dbh;

###
### Send a query to find the name of the data directory for this instance
###

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

$now = localtime();

###
### Execute a query to flush the tables and acquire a lock on them
###

$flushlockquery = 'FLUSH TABLES WITH READ LOCK';

print STDERR "Trying to lock tables at $now ...\n";

$dbh->do($flushlockquery);
&db_die("do($flushlockquery) failed on $dsn");

$then = localtime();

print STDERR "Lock acquired at $then\n";

###
### This section of code performs a backup dump of the entire data directory
### on the specified server and (optionally) copies the resulting tarball to
### the safe location
###

if ($dumpfiles) {
    $filename = sprintf('%04d-%02d-%02d-%02d%02d%02d.tar',
			$tm_year, $tm_mon, $tm_mday,
			$tm_hour, $tm_min, $tm_sec);
    
    $filename = "$dumpdir/$filename" if (defined($dumpdir) && -d $dumpdir);

    print STDERR "tar file will be named $filename\n";

    $home = cwd();

    die "Cannot chdir to $datadir" unless chdir($datadir);

    $cmd = "tar cf $filename *";

    $cmd = "echo $cmd" if $testmode;

    print STDERR "Executing '$cmd' ... \n";

    $rc = system($cmd);

    print STDERR "Done with status=$rc\n";

    if ($rc != 0 || $forcereport) {
        $subject = "Fatal error in Arcturus MySQL backup script";
        $msg = ["A serious problem has occurred during the running of the MySQL backup script\n",
                "on the $host cluster.\n\n",
                "The script was attempting to backup $datadir to $filename when\n",
                "it encountered error code $rc whilst executing the command\n\n",
                "    $cmd\n\n",
                "*****\n",
                "***** The data files in $datadir have NOT been backed up!\n",
                "*****\n\n",
                "This almost certainly indicates a more serious underlying problem\n",
                "such as a full disk. Please investigate as soon as possible.\n"];
        &SendFatalErrorMessage($rcpts, $subject, $msg);
    }

    if ($rc == 0 && $gzip) {
        $cmd = "gzip $filename";
        
        print STDERR "Executing '$cmd' ... \n";
        
        $rc = system($cmd);

        print STDERR "Done with status=$rc\n";

        if ($rc != 0 || $forcereport) {
            $subject = "Fatal error in Arcturus MySQL backup script";
            $msg = ["A serious problem has occurred during the running of the MySQL backup script\n",
                    "on the $host cluster.\n\n",
                    "The script was attempting to backup $datadir to $filename when\n",
                    "it encountered error code $rc whilst executing the command\n\n",
                    "    $cmd\n\n",
                    "This almost certainly indicates a more serious underlying problem\n",
                    "such as a full disk. Please investigate as soon as possible.\n"];
            &SendFatalErrorMessage($rcpts, $subject, $msg);
        }

        $filename .= '.gz' if ($rc == 0);
    }

    if ($rc == 0 && defined($safedumpdir)) {
        $cmd = "$cp $filename $safedumpdir";
        print STDERR "Executing '$cmd' ... \n";
        $rc = system($cmd);
        print STDERR "Done with status=$rc\n";

        if ($rc != 0 || $forcereport) {
            $subject = "Fatal error in Arcturus MySQL backup script";
            $msg = ["A serious problem has occurred during the running of the MySQL backup script\n",
                    "on the $host cluster.\n\n",
                    "The script was attempting to backup $datadir to $filename when\n",
                    "it encountered error code $rc whilst executing the command\n\n",
                    "    $cmd\n\n",
                    "This almost certainly indicates a more serious underlying problem\n",
                    "such as a full disk. Please investigate as soon as possible.\n"];
            &SendFatalErrorMessage($rcpts, $subject, $msg);
        }
    }
}

###
### This section of code flushes the binary logs and (optionally) copies all
###  recent log files to the safe data directory
###

if ($flushlogs) {
    $flushquery = 'FLUSH LOGS';

    print STDERR "Flushing binary logs ...\n";

    unless ($testmode) {
	$dbh->do($flushquery);
	&db_die("do($flushquery) failed on $dsn");
    }

    $allrc = 0;

    if (defined($binlogdir) && defined($safedumpdir)) {
        sleep($sleeptime);

        if (-d $binlogdir) {
            die "Unable to chdir to $binlogdir" unless chdir($binlogdir);
            $newfiles = `/bin/find . -type f -newer LASTLOGDUMP -name 'mysql.???'`;
            print STDERR "Log file(s) to be copied:\n$newfiles\n";
        } else {
            print STDERR "*** WARNING: -binlogdir option \"$binlogdir\" is not a directory.\n";
        }
    }


    foreach $logfile (split("\n", $newfiles)) {
        if (-f $logfile) {
            $logdumpname = "$safedumpdir/";
            $logdumpname .= $logfile;
            
            $cmd = "$cp $logfile $logdumpname";

            print STDERR "Executing '$cmd' ... \n";

            $rc = system($cmd);

            print STDERR "Done with status=$rc\n";

            $allrc |= $rc;
        } else {
            print STDERR "*** WARNING: binary log file $logfile does not seem to exist.\n";
            $allrc |= 1;
        }
    }

    if ($allrc == 0) {
        print STDERR "touching LASTLOGDUMP\n";
        `touch LASTLOGDUMP`;
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
    print STDERR "DATABASE ACCESS\n";
    print STDERR "  -host hostname\tName of host on which the server is running.\n";
    print STDERR "  -port number\t\tPort number of the instance.\n";
    print STDERR "\n";
    print STDERR "  -username\t\tUsername to access the server.\n";
    print STDERR "  -password\t\tPassword to access the server.\n";
    print STDERR "  -database\t\tInitial database name.\n";
    print STDERR "\n";
    print STDERR "MODE SELECTION\n";
    print STDERR "  -auto\t\t\tUse 'auto' mode to decide what action(s) to take.\n";
    print STDERR "\n";
    print STDERR "  -flushlogs\t\tFlush and rotate the binary logs of this instance.\n";
    print STDERR "  -dumpfiles\t\tLock tables and make a tar file of the data directory.\n";
    print STDERR "\n";
    print STDERR "FILE DUMP OPTIONS\n";
    print STDERR "  -binlogdir\t\tThe location of this server's binary logs.\n";
    print STDERR "  -dumpdir\t\tThe directory into which to put the tar file.\n";
    print STDERR "  -safedumpdir\t\tThe safe directory into which to copy the tar file.\n";
    print STDERR "  -gzip\t\t\tCompress the tar file using gzip.\n";
    print STDERR "  -cp\t\t\tThe command to copy files to the safe directory.\n";
}

sub SendFatalErrorMessage {
    my ($recipients, $subject, $msglines, $junk) = @_;

    my $msg = new Mail::Send;

    foreach $rcpt (@{$recipients}) {
        my $msg = new Mail::Send;
        $msg->to($rcpt);

        $msg->subject($subject);

        my $fh = $msg->open;

        foreach $line (@{$msglines}) {
            print $fh $line;
        }

        $fh->close;
    }
}
