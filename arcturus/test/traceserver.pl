#!/usr/local/bin/perl
#
# traceserver.pl
#
# This server fetches traces on request from a MySQL database

use strict;

use DBI;
use DataSource;
use FileHandle;

use Compress::Zlib;

use IO::Socket;
use IO::Select;

my $instance;
my $organism;
my $num;
my $addr;
my $port;
my $verbose;
my $blocksize = 8192;

while (my $nextword = shift @ARGV) {
    $addr = shift @ARGV if ($nextword eq '-addr');
    $port = shift @ARGV if ($nextword eq '-port');
    $verbose = 1 if ($nextword eq '-verbose');
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $blocksize = shift @ARGV if ($nextword eq '-blocksize');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($addr) && defined($port)) {
    print STDERR "*** ERROR *** One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

die "Port argument ($port) is not numeric" unless $port =~ /^\d+$/;
die "Port argument is non-positive" unless $port > 0;

my $main_sock;

die "Cannot open socket" unless $main_sock = IO::Socket::INET->new(
    LocalAddr => $addr,
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => 5,
    Reuse     => 1);

my $nCalls = 0;
my $nActive = 0;

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select READINFO.read_id,trace from READINFO left join TRACE using(read_id) where readname = ?";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $rh = new IO::Select();

$SIG{'HUP'}  = sub { $sth->finish(); $dbh->disconnect(); exit(0) };

$rh->add($main_sock);

my %caller;
my %reqcount;

while (1) {
    my ($new_read) = IO::Select->select($rh,undef,undef);

    my $rc;

    foreach my $sock (@$new_read) {
	if ($sock == $main_sock) {
	    my $new_sock = $main_sock->accept();
	    binmode($new_sock);
	    $rh->add($new_sock);
	    $nCalls++;
	    $nActive++;
	    my $peername = gethostbyaddr($new_sock->peeraddr(),2);
	    print STDERR "Accepted incoming call (serial $nCalls) from ", $peername, " on port ",
	    $new_sock->peerport()," [$nActive active]\n" if $verbose;
	    $caller{$new_sock} = $nCalls;
	    $reqcount{$new_sock} = 0;
	} else {
	    my $buf = <$sock>;
	    if ($buf) {
		chop($buf);
		$reqcount{$sock}++;
		my $j = $reqcount{$sock};
		my $sentbytes = &ProcessRequest($sock, $buf, $sth, $blocksize);
		print STDERR "Request $j from caller ",$caller{$sock}, ": ",
		" \"$buf\"",
		" [$sentbytes sent] \n" if $verbose;

		$rh->remove($sock);
		close($sock);
		$nActive--;
		print STDERR "Closed ",$caller{$sock},
		" [$nActive active]\n" if $verbose;
	    } else {
		$rh->remove($sock);
		close($sock);
		$nActive--;
		print STDERR "Caller ",$caller{$sock}," rang off after ",$reqcount{$sock},
		" requests [$nActive active]\n" if $verbose;
	    }
	}
    }
}

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
    print STDERR "    -addr\t\tServer address\n";
    print STDERR "    -port\t\tServer port\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -verbose\t\t[Boolean] Display operational information\n";
    print STDERR "    -blocksize\t\tBlock size for sending data to client\n";
}

sub ProcessRequest {
  my ($sock, $line, $sth, $blocklen, $junk) = @_;

  my @words = split(/\s+/, $line);

  my $readname = pop @words;

  $readname = substr($readname, 0, length($readname) - 3)
      if ($readname =~ /SCF$/);

  $sth->execute($readname);
  &db_carp("executing trace query for readname $readname");

  my ($readid, $trace) = $sth->fetchrow_array();
  &db_carp("fetching trace for readname $readname");

  if (defined($trace)) {
      $trace = uncompress($trace);

      my $tracelen = length($trace);

      while (length($trace) > 0) {
	  my $sendlen = length($trace);
	  $sendlen = $blocklen if ($sendlen > $blocklen);
	  print $sock substr($trace, 0, $sendlen);
	  print STDERR "[$sendlen] ";
	  $trace = substr($trace, $blocklen);
      }
      print STDERR "\n";

      return $tracelen;
  } else {
      print $sock "no match";
      return 8;
  }
}
