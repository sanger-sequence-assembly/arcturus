package DataSource;

use strict;

use Net::LDAP;
use DBI;

sub new {
    my $type = shift;

    my ($url, $base, $instance, $organism, $newUsername, $newPassword);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$url = shift if ($nextword eq 'url');

	$base = shift if ($nextword eq 'base');

	$instance = shift if ($nextword eq 'instance');

	$organism = shift if ($nextword eq 'organism');

	$newUsername = shift if ($nextword eq 'username');

	$newPassword = shift if ($nextword eq 'password');
    }

    $url = 'ldap.internal.sanger.ac.uk' unless defined($url);

    $instance = 'prod' unless defined($instance);

    $base = "cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk" unless defined($base);

    $base = "cn=$instance," . $base if defined($instance);

    return undef unless defined($organism);

    my $this = {};
    bless $this, $type;

    $this->{'instance'} = $instance;
    $this->{'organism'} = $organism;

    my $filter = "&(objectClass=javaNamingReference)(cn=$organism)";

    my $ldap = Net::LDAP->new($url) or die "Cannot connect to LDAP server: $@";

    # An anonymous bind
    my $mesg = $ldap->bind;

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
	my @items = $entry->get_value('javaClassName');
	my $classname = shift @items;
	@items = $entry->get_value('javaFactory');
	my $factory = shift @items;
	@items = $entry->get_value('javaReferenceAddress');

	my @datasourcelist = split(/\./, $classname);

	my $datasourcetype = pop @datasourcelist;

	my $datasource = {};

	while (my $item = shift @items) {
	    my ($id,$key,$value) = $item =~ /\#(\d+)\#(\w+)\#(\w+)/;
	    $datasource->{$key} = $value;
	}
	
	my ($url, $username, $password) = &buildUrl($datasourcetype, $datasource);

	if (defined($newUsername) && defined($newPassword)) {
	    $username = $newUsername;
	    $password = $newPassword;
	}

	if (defined($url)) {
	    $this->{URL} = $url;
	    $this->{Username} = $username;
	    $this->{Password} = $password;
	    $found = 1;
	    last;
	}
    }

    # Close LDAP session
    $mesg = $ldap->unbind;

    return $found ? $this : undef;
}

# Private function for use in the constructor
sub buildUrl {
    my ($dstype, $dshash, $junk) = @_;

    return buildMySQLUrl($dshash) if ($dstype =~ /mysqldatasource/i);

    return buildOracleUrl($dshash) if ($dstype =~ /oracledatasource/i);

    return undef;
}

# Private function for use in the constructor
sub buildMySQLUrl {
    my $dshash = shift;

    my $username = $dshash->{'user'};
    my $password = $dshash->{'password'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'port'};

    my $database = $dshash->{'databaseName'};

    return ("DBI:mysql:$database:$hostname:$portnumber", $username, $password);
}

# Private function for use in the constructor
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

1;
