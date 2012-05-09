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

use strict;

my $port;
my $host;
my $dbname;
my $username;
my $password;
my $flushlogs = 0;
my $dumpfiles = 0;
my $automode = 0;
my $testmode = 0;
my $gzip = 0;
my $dumpdir;
my $safedumpdir;
my $binlogdir;
my $cp;
my $rsh;
my $cleanup = 0;
my $olderthan;
my $sleeptime;
my $rcpts;
my $forcereport = 0;

###
### Argument parsing
###

while (my $nextword = shift @ARGV) {
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

    $rsh = shift @ARGV if ($nextword eq '-rsh');

    $cleanup = 1 if ($nextword eq '-cleanup');

    $olderthan = shift @ARGV if ($nextword eq '-olderthan');

    $sleeptime = shift @ARGV if ($nextword eq '-sleeptime');

    $rcpts = shift @ARGV if ($nextword eq '-alerts');

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

my ($tm_sec, $tm_min, $tm_hour, $tm_mday, $tm_mon, $tm_year,
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

    my $wday = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
		'Friday', 'Saturday')[$tm_wday];

    print STDERR "Auto mode selection: today is $wday ($tm_wday) ==>";
    print STDERR " -flushlogs" if $flushlogs;
    print STDERR " -dumpfiles" if $dumpfiles;
    print STDERR "\n";
}

die "You must specify at least one of -dumpfiles or -flushlogs or -cleanup"
    unless (defined($flushlogs) || defined($dumpfiles) || defined($cleanup));

$dumpdir = cwd() unless $dumpdir;

$dbname = 'arcturus' unless defined($dbname);

unless (defined($username) && defined($password)) {
    $username = 'flusher';
    $password = 'FlushedWithPride';
}

###
### Establish a connection to the MySQL server
###

my $dsn = 'DBI:mysql:' . $dbname . ';host=' . $host . ';port=' . $port;

my $dbh = DBI->connect($dsn, $username, $password,
		       {PrintError => 0, RaiseError => 0});

die "connect($dsn, user=$username) failed: $DBI::errstr" unless $dbh;

###
### Send a query to find the name of the data directory for this instance
###

my $varquery = "SHOW VARIABLES LIKE 'datadir'";

my $sth = $dbh->prepare($varquery);
&db_die("prepare($varquery) failed");

$sth->execute();
&db_die("execute($varquery) failed");

my $datadir;

while (my @ary = $sth->fetchrow_array()) {
    my ($varname, $varvalue) = @ary;
    $datadir = $varvalue if ($varname eq 'datadir');
}

$sth->finish();

unless (defined($datadir)) {
    $dbh->disconnect();
    die "Could not determine name of data directory";
}

print STDERR "Data directory is $datadir\n";

my $now = localtime();

###
### Execute a query to flush the tables and acquire a lock on them
###

my $flushlockquery = 'FLUSH TABLES WITH READ LOCK';

print STDERR "Trying to lock tables at $now ...\n";

$dbh->do($flushlockquery);
&db_die("do($flushlockquery) failed on $dsn");

my $then = localtime();

print STDERR "Lock acquired at $then\n";

my $rc = 0;
my $cmd;
my $subject;
my $msg;

###
### This section of code performs a backup dump of the entire data directory
### on the specified server and (optionally) copies the resulting tarball to
### the safe location
###

if ($dumpfiles) {
    my $filename = sprintf('%04d-%02d-%02d-%02d%02d%02d.tar',
			   $tm_year, $tm_mon, $tm_mday,
			   $tm_hour, $tm_min, $tm_sec);

    my $tmptarfile = "/tmp/arcturus." . $$ . ".tar";

    print STDERR "Temporary tar file will be named $tmptarfile\n";
    print STDERR "Permanent tar file will be named $filename\n";

    my $home = cwd();

    die "Cannot chdir to $datadir" unless chdir($datadir);

    print STDERR "CWD is now $datadir\n";

    $cmd = "tar cf $tmptarfile *";

    $rc = &mySystem($cmd, $testmode);

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
        $cmd = "gzip $tmptarfile";

        $rc = &mySystem($cmd, $testmode);

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

	$tmptarfile .= '.gz' if ($rc == 0);
        $filename .= '.gz' if ($rc == 0);
    }

    if ($rc == 0) {
        $cmd = "$cp $tmptarfile $dumpdir/$filename";
        $rc = &mySystem($cmd, $testmode);

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

    if ($rc == 0 && defined($safedumpdir)) {
        $cmd = "$cp $tmptarfile $safedumpdir/$filename";
        $rc = &mySystem($cmd, $testmode);

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
### This section of code removes all files older than a specified number of days
### from the directories specified by the -dumpdir and/or -safedumpdir options.
###

if ($rc == 0 && $cleanup) {
    $olderthan = 15 if (!defined($olderthan) || !($olderthan =~ /^\d+$/));

    if (defined($dumpdir) && -d $dumpdir) {
        $cmd = "find $dumpdir -type f -mtime +$olderthan -exec /bin/rm -f {} \\;";
        $rc = &mySystem($cmd, $testmode);
    }

    if ($safedumpdir) {
        my ($safehost, $safedir) = split(/:/, $safedumpdir);
        if (!defined($safedir)) {
            $safedir = $safehost;
            undef $safehost;
        }
        
        $cmd = "find $safedir -type f -mtime +$olderthan -exec /bin/rm -f {} \\;";

        if ($safehost) {
            if (defined($rsh) && -x $rsh) {
                $cmd = "$rsh $safehost \"$cmd\"";
            } else {
                print STDERR "Unable to execute \"$cmd\" on remote host $safehost.\n";
                print STDERR "No remote shell command (-rsh option) was specified.\n";
            }
        }

        $rc = &mySystem($cmd, $testmode);
    }
}

###
### This section of code flushes the binary logs and (optionally) copies all
###  recent log files to the safe data directory
###

if ($flushlogs) {
    my $flushquery = 'FLUSH LOGS';

    print STDERR "Flushing binary logs ...\n";

    unless ($testmode) {
	$dbh->do($flushquery);
	&db_die("do($flushquery) failed on $dsn");
    }

    my $allrc = 0;
    my $newfiles;

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


    foreach my $logfile (split("\n", $newfiles)) {
        if (-f $logfile) {
            my $logdumpname = "$safedumpdir/";
            $logdumpname .= $logfile;
            
            $cmd = "$cp $logfile $logdumpname";

            $rc = &mySystem($cmd, $testmode);

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

my $unlockquery = 'UNLOCK TABLES';

$dbh->do($unlockquery);
&db_die("do($unlockquery) failed on $dsn");

print STDERR "Lock released.\n";

$dbh->disconnect();

print STDERR "DBI Connection closed.\n";

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
    print STDERR "  -rsh\t\t\tThe command to run a command remotely.\n";
    print STDERR "  -cleanup\t\tRemove old files from dumpdir and/or safedumpdir\n";
    print STDERR "  -olderthan\t\tThe minimum age (in days) for the -cleanup option\n\t\t\t[DEFAULT: 15]\n";
}

sub SendFatalErrorMessage {
    my ($recipients, $subject, $msglines, $junk) = @_;

    my $msg = new Mail::Send;

    foreach my $rcpt (@{$recipients}) {
        my $msg = new Mail::Send;
        $msg->to($rcpt);

        $msg->subject($subject);

        my $fh = $msg->open;

        foreach my $line (@{$msglines}) {
            print $fh $line;
        }

        $fh->close;
    }
}

sub mySystem {
    my ($cmd, $testmode, $junk) = @_;

    my $rc = 0;

    if (defined($testmode)) {
        $rc = 0;
        print STDERR "TESTING: $cmd\n";
    } else {
        print STDERR "Executing \"$cmd\"\n";
        $rc = system($cmd);
        print STDERR "Done with status=$rc\n";
    }

    return $rc;
}
