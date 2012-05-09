#!/usr/local/bin/perl

use strict;

use Net::LDAP;
use Term::ReadKey;
use DBI;

my $server;
my $base;
my $instance;
my $organism;
my $listall = 0;
my $verbose = 0;
my $newhost;
my $newport;
my $newuser;
my $newpass;
my $showurl = 0;
my $testurl = 0;
my $update = 0;
my $principal;

while (my $nextword = shift @ARGV) {
    $server = shift @ARGV if ($nextword eq '-server');

    $base = shift @ARGV if ($nextword eq '-base');

    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $listall = 1 if ($nextword eq '-listall');

    $verbose = 1 if ($nextword eq '-verbose');

    $newhost = shift @ARGV if ($nextword eq '-newhost');

    $newport = shift @ARGV if ($nextword eq '-newport');

    $newuser = shift @ARGV if ($nextword eq '-newuser');

    $newpass = shift @ARGV if ($nextword eq '-newpass');

    $showurl = 1 if ($nextword eq '-showurl');

    $testurl = 1 if ($nextword eq '-testurl');

    $update = 1 if ($nextword eq '-update');

    $principal = shift @ARGV if ($nextword eq '-principal');

    if ($nextword eq '-help') {
	showUsage();
	exit(0);
    }
}

$server = 'ldap.internal.sanger.ac.uk' unless defined($server);

$base = "cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk" unless defined($base);

$base = "cn=$instance," . $base if defined($instance);

$listall = 1 unless defined($organism);

my $filter = $listall ?
    'objectClass=javaNamingReference' : "&(objectClass=javaNamingReference)(cn=$organism)";

my $ldap = Net::LDAP->new($server) or die "$@";

my $password;

if (defined($principal)) {
    print "Password: ";
    ReadMode 'noecho';
    $password = ReadLine 0;
    ReadMode 'normal';
    chop $password;
}
 
my $mesg = (defined($principal) && defined($password)) ?
    $ldap->bind($principal, password => $password) : $ldap->bind;
 
$mesg = $ldap->search( # perform a search
		       base   => $base,
		       scope => 'sub',
		       filter => "($filter)"
		       );
 
$mesg->code && die $mesg->error;
 
foreach my $entry ($mesg->all_entries) {
    #$entry->dump;
    my $dn = $entry->dn;
    my @items = $entry->get_value('javaClassName');
    my $classname = shift @items;
    @items = $entry->get_value('javaFactory');
    my $factory = shift @items;
    @items = $entry->get_value('javaReferenceAddress');

    print "$dn\n";

    if ($verbose) {
	print "    ClassName=$classname\n" if defined($classname);
	print "    Factory=$factory\n" if defined($factory);
    }

    my @datasourcelist = split(/\./, $classname);

    my $datasourcetype = pop @datasourcelist;

    my $datasource = {};

    while (my $item = shift @items) {
	my ($id,$key,$value) = $item =~ /\#(\d+)\#(\w+)\#(\S+)/;
	$datasource->{$key} = $value;
	print "        $key=$value\n" if $verbose;
    }

    &changeHost($datasource, $newhost) if defined($newhost);
    &changePort($datasource, $newport) if defined($newport);

    &changeUsername($datasource, $newuser) if defined($newuser);
    &changePassword($datasource, $newpass) if defined($newpass);

    if (($testurl || $showurl) && defined($datasourcetype)) {
	my ($url, $username, $password) = &buildUrl($datasourcetype, $datasource);
	if (defined($url)) {
	    print "        URL=$url\n";
	    if ($testurl) {
		my $dbh = DBI->connect($url, $username, $password, {RaiseError => 0, PrintError => 0});
		if (defined($dbh)) {
		    print "        CONNECT OK\n";
		} else {
		    print "        CONNECT FAILED: : $DBI::errstr\n";
		}
		$dbh->disconnect if defined($dbh);
	    }
	} else {
	    print "        Unable to build URL\n";
	}
    }

    if (defined($update) && (defined($newport) || defined($newhost) || defined($newuser) || defined($newpass))) {
	my $refaddr = &createReferenceAddress($datasource);

	print STDERR join("\n", @{$refaddr}), "\n\n";

	my $msg2 = $ldap->modify($dn, replace => [ 'javaReferenceAddress' => $refaddr ]);

	print STDERR "Failed to update javaReferenceAddress for $dn: " . $msg2->error . "\n"
	    if $msg2->code;
    }

    print "\n";
}

$mesg = $ldap->unbind;   # take down session

exit(0);

sub buildUrl {
    my ($dstype, $dshash, $junk) = @_;

    return buildMySQLUrl($dshash) if ($dstype =~ /mysqldatasource/i);

    return buildOracleUrl($dshash) if ($dstype =~ /oracledatasource/i);

    return undef;
}

sub buildMySQLUrl {
    my $dshash = shift;

    my $username = $dshash->{'user'};
    my $password = $dshash->{'password'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'port'};

    my $database = $dshash->{'databaseName'};

    return ("DBI:mysql:$database:$hostname:$portnumber", $username, $password);
}

sub buildOracleUrl {
    my $dshash = shift;

    my $username = $dshash->{'userName'};
    my $password = $dshash->{'passWord'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'portNumber'};

    my $database = $dshash->{'databaseName'};

    my $url = "DBI:Oracle:host=$hostname;port=$portnumber;sid=$database";

    return ($url, $username, $password);
}

sub changeHost {
    my $dshash = shift;
    my $newhost = shift;

    $dshash->{'serverName'} = $newhost if defined($newhost);
}

sub changePort {
    my $dshash = shift;
    my $newport = shift;

    return unless defined($newport);

    $dshash->{'port'} = $newport if defined($dshash->{'port'});             # MySQL style
    $dshash->{'portNumber'} = $newport if defined($dshash->{'portNumber'}); # Oracle style
}

sub changeUsername {
    my $dshash = shift;
    my $newuser = shift;

    return unless defined($newuser);

    $dshash->{'user'} = $newuser if defined($dshash->{'user'});             # MySQL style
    $dshash->{'userName'} = $newuser if defined($dshash->{'userName'});     # Oracle style
}

sub changePassword {
    my $dshash = shift;
    my $newpass = shift;

    return unless defined($newpass);

    $dshash->{'password'} = $newpass if defined($dshash->{'password'});     # MySQL style
    $dshash->{'passWord'} = $newpass if defined($dshash->{'passWord'});     # Oracle style
}

sub createReferenceAddress {
    my $dshash = shift;

    my $strings = [];
    my $idx = 0;

    foreach my $key (keys %{$dshash}) {
	next if ($key eq 'url');
	my $value = $dshash->{$key};

	$value = 'false' if ($key eq 'explicitUrl');

	push @{$strings}, "#" . $idx . "#" . $key . "#" . $value;
	$idx++;
    }

    return $strings;
}

sub showUsage {
    my @text = ("Usage",
		"-----",
		"",
		"MANDATORY PARAMETERS",
		"(none)",
		"",
		"OPTIONAL PARAMETERS",
		"-server\t\tName of LDAP server",
		"\t\t[default: ldap.internal.sanger.ac.uk]",
		"",
		"-base\t\tRoot of LDAP tree to modify",
		"\t\t[default: cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk]",
		"",
		"-instance\tArcturus instance name",
		"",
		"-organism\tArcturus organism name (to list/modify a specific organism)",
		"-listall\tList/modify all entries (this is the default option)",
		"",
		"-verbose\tProduce verbose output",
		"",
		"-newhost\tName of new MySQL host",
		"-newport\tPort number of new MySQL host",
		"",
		"-newuser\tNew MySQL username",
		"-newpass\tNew MySQL password",
		"",
		"-update\t\tUpdate the tree with the new host, port, username and/or password",
		"",
		"-showurl\tDisplay the DBI URL for each entry",
		"-testurl\tTest the DBI URL for each entry",
		"",
		"-principal\tName of the LDAP manager (if -update is specified)",
		);

    foreach my $line (@text) {
	print STDERR $line,"\n";
    }
}
