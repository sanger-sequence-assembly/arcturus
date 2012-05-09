package DataSource;

use strict;

use Socket;
use Net::LDAP;
use DBI;

use constant DEFAULT_URL => 'ldap.internal.sanger.ac.uk';
use constant DEFAULT_BASE => 'cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk';

sub new {
    my $type = shift;

    my ($url, $base, $instance, $organism, $newUsername, $newPassword);
    my ($ldapuser, $ldappass);
    my $verbose = 0;

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$url = shift if ($nextword eq 'url');

	$ldapuser = shift if ($nextword eq 'ldapuser');

	$ldappass = shift if ($nextword eq 'ldappass');

	$base = shift if ($nextword eq 'base');

	$instance = shift if ($nextword eq 'instance');

	$organism = shift if ($nextword eq 'organism' || $nextword eq 'node');

	$newUsername = shift if ($nextword eq 'username');

	$newPassword = shift if ($nextword eq 'password');

	$verbose = 1 if ($nextword eq 'verbose');
    }

    $url = DEFAULT_URL unless defined($url);

    $base = DEFAULT_BASE unless defined($base);

    die "Instance not specified in DataSource constructor" unless defined($instance);

    die "Organism not specified in DataSource constructor" unless defined($organism);

    die "Running in test mode but instance was not \"test\" in DataSource constructor"
	if (defined($ENV{ARCTURUS_ENV}) && $ENV{ARCTURUS_ENV} eq 'test' && $instance ne 'test');

    $base = "cn=$instance," . $base;

    my $this = {};
    bless $this, $type;

    $this->{'instance'} = $instance;
    $this->{'organism'} = $organism;

    my $filter = "&(objectClass=javaNamingReference)(cn=$organism)";

    my $ldap = &openLDAPConnection($url, $verbose);

    # Bind anonymously if no username and password were given
    my $mesg = (defined($ldapuser) && defined($ldappass)) ?
	$ldap->bind($ldapuser, password => $ldappass) : $ldap->bind;

    $mesg->code && die $mesg->error;

    # Perform the search
    $mesg = $ldap->search(base   => $base,
			  scope => 'sub',
			  deref => 'always',
			  filter => "($filter)"
			  );

    die "LDAP search returned a null message" if !defined($mesg);

    $mesg->code && die $mesg->error;

    my $found = 0;
 
    foreach my $entry ($mesg->all_entries) {
	my $dn = $entry->dn;

	$this->{'description'} = $entry->get_value('description');

	my @items = $entry->get_value('javaClassName');
	my $classname = shift @items;

	@items = $entry->get_value('javaFactory');
	my $factory = shift @items;

	@items = $entry->get_value('javaReferenceAddress');

	my @datasourcelist = split(/\./, $classname);

	my $datasourcetype = pop @datasourcelist;

	my $attributes = {};

	while (my $item = shift @items) {
	    my ($id,$key,$value) = $item =~ /\#(\d+)\#(\w+)\#(\w+)/;
	    $attributes->{$key} = $value;
	}
	
	my ($url, $username, $password) = &buildUrl($datasourcetype, $attributes);

	if (defined($newUsername) && defined($newPassword)) {
	    $username = $newUsername;
	    $password = $newPassword;
	}

	if (defined($url)) {
	    $this->{URL} = $url;
	    $this->{Username} = $username;
	    $this->{Password} = $password;
	    $this->{Attributes} = $attributes;
	    $found = 1;
	    last;
	}
    }

    # Close LDAP session
    $mesg = $ldap->unbind;

    return $this if $found;

    die "Failed to find DataSource for instance=$instance organism=$organism";
}

sub openLDAPConnection {
    my $hostname = shift;
    my $verbose = shift || 0;

    die "No hostname specified in openLDAPConnection" unless defined($hostname);

    my $ldap = Net::LDAP->new($hostname);

    return $ldap if defined($ldap);

    print STDERR "DataSource: initial attempt to connect to LDAP server at $hostname failed," .
	" trying alternate addresses.\n" if $verbose;

    my ($name, $aliases, $addrtype, $infolength, @addrs) = gethostbyname($hostname);

    foreach my $addr (@addrs) {
	my $name = inet_ntoa($addr);

	$ldap = Net::LDAP->new($name);
    
	return $ldap if defined($ldap);

	print STDERR "DataSource: $addr did not respond.\n" if $verbose;
    }

    die "Failed to find an LDAP server at $hostname: $@";
}

# Build a DBI URL from the parameters in the DataSource hash
sub buildUrl {
    my ($dstype, $dshash, $junk) = @_;

     if ($dstype =~ /mysqldatasource/i) { 
	 return buildMySQLUrl($dshash);
     } elsif ($dstype =~ /oracledatasource/i) {
	 return buildOracleUrl($dshash);
     } elsif ($dstype =~ /pgsimpledatasource/i) {
	 return buildPostgresUrl($dshash);
     } else {
	 return undef;
     }
}

# Build a MySQL URL
sub buildMySQLUrl {
    my $dshash = shift;

    my $username = $dshash->{'user'};
    my $password = $dshash->{'password'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'port'};

    my $database = $dshash->{'databaseName'};

    return ("DBI:mysql:$database:$hostname:$portnumber", $username, $password);
}

# Build an Oracle URL
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

# Build a PostgreSQL URL
sub buildPostgresUrl {
    my $dshash = shift;

    my $username = $dshash->{'user'};
    my $password = $dshash->{'password'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'portNumber'};

    my $database = $dshash->{'databaseName'};

    my $url = "DBI:Pg:dbname=$database;host=$hostname;port=$portnumber";

    return ($url, $username, $password);
}

sub getConnection {
    my $this = shift;

    my $url = $this->{URL};

    return undef unless defined($url);

    my $username = undef;
    my $password = undef;
    my $options = undef;

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$username = shift if ($nextword eq 'username');
	$password = shift if ($nextword eq 'password');
	$options = shift if ($nextword eq 'options');
    }

    unless (defined($username) && defined($password)) {
	$username = $this->{Username};
	$password = $this->{Password};
    }

    unless (defined($options) && ref($options) && ref($options) eq 'HASH') {
	$options = {RaiseError => 0, PrintError => 0};
    }

    my $dbh = DBI->connect($url, $username, $password, $options);

    return $dbh;
}

sub getURL {
    my $this = shift;

    my $url      = $this->{URL};

    return $url;
}

sub getInstance {
     my $this = shift;

     return $this->{'instance'};
 }


sub getOrganism {
     my $this = shift;

     return $this->{'organism'};
 }

sub getDescription {
    my $this = shift;

    return $this->{'description'};
}

sub getAttribute {
    my $this = shift;
    my $attrname = shift;

    return $this->{Attributes}->{$attrname};
}

1;
