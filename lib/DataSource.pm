package DataSource;

use strict;

use Net::LDAP;
use DBI;

sub new {
    my $type = shift;

    my ($url, $base, $instance, $organism, $newUsername, $newPassword);
    my ($ldapuser, $ldappass);

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
    }

    $url = 'ldap.internal.sanger.ac.uk' unless defined($url);

    $instance = 'pathogen' unless defined($instance);

    $base = "cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk" unless defined($base);

    $base = "cn=$instance," . $base if defined($instance);

    return undef unless defined($organism);

    my $this = {};
    bless $this, $type;

    $this->{'instance'} = $instance;
    $this->{'organism'} = $organism;

    my $filter = "&(objectClass=javaNamingReference)(cn=$organism)";

    my $ldap = Net::LDAP->new($url) or die "Cannot connect to LDAP server: $@";

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

    return $found ? $this : undef;
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
