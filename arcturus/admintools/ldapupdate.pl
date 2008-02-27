#!/usr/local/bin/perl

use Net::LDAP;
use Term::ReadKey;
use DBI;

while ($nextword = shift @ARGV) {
    $server = shift @ARGV if ($nextword eq '-server');

    $base = shift @ARGV if ($nextword eq '-base');

    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $listall = 1 if ($nextword eq '-listall');

    $verbose = 1 if ($nextword eq '-verbose');

    $newhost = shift @ARGV if ($nextword eq '-newhost');

    $newport = shift @ARGV if ($nextword eq '-newport');

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

if ($listall) {
    $filter = 'objectClass=javaNamingReference';
} else {
    $filter = "&(objectClass=javaNamingReference)(cn=$organism)";
}

$ldap = Net::LDAP->new($server) or die "$@";

if (defined($principal)) {
    print "Password: ";
    ReadMode 'noecho';
    $password = ReadLine 0;
    ReadMode 'normal';
    chop $password;
}
 
$mesg = (defined($principal) && defined($password)) ?
    $ldap->bind($principal, password => $password) : $ldap->bind;
 
$mesg = $ldap->search( # perform a search
		       base   => $base,
		       scope => 'sub',
		       filter => "($filter)"
		       );
 
$mesg->code && die $mesg->error;
 
foreach $entry ($mesg->all_entries) {
    #$entry->dump;
    $dn = $entry->dn;
    @items = $entry->get_value('javaClassName');
    $classname = shift @items;
    @items = $entry->get_value('javaFactory');
    $factory = shift @items;
    @items = $entry->get_value('javaReferenceAddress');

    print "$dn\n";

    if ($verbose) {
	print "    ClassName=$classname\n" if defined($classname);
	print "    Factory=$factory\n" if defined($factory);
    }

    @datasourcelist = split(/\./, $classname);

    $datasourcetype = pop @datasourcelist;

    $datasource = {};

    while ($item = shift @items) {
	($id,$key,$value) = $item =~ /\#(\d+)\#(\w+)\#(\S+)/;
	$datasource->{$key} = $value;
	print "        $key=$value\n" if $verbose;
    }

    &changeHost($datasource, $newhost) if defined($newhost);
    &changePort($datasource, $newport) if defined($newport);

    if (($testurl || $showurl) && defined($datasourcetype)) {
	($url, $username, $password) = &buildUrl($datasourcetype, $datasource);
	if (defined($url)) {
	    print "        URL=$url\n";
	    if ($testurl) {
		$dbh = DBI->connect($url, $username, $password, {RaiseError => 0, PrintError => 0});
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

    if (defined($update) && (defined($newport) || defined($newhost))) {
	$refaddr = &createReferenceAddress($datasource);

	print STDERR join("\n", @{$refaddr}), "\n\n";

	$msg2 = $ldap->modify($dn, replace => [ 'javaReferenceAddress' => $refaddr ]);

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
		"-update\t\tUpdate the tree with the new host and/or port",
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
