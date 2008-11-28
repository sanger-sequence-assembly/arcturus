#!/usr/local/bin/perl
#
# This script creates a new Arcturus organism database and
# its corresponding LDAP entry.

use strict;

use DBI;
use Net::LDAP;
use Term::ReadKey;

my $instance;
my $organism;
my $subdir;

my $dbhost;
my $dbport;
my $dbname;

my $ldapurl;
my $ldapuser;
my $rootdn;

my $description;

my $template;

my $projects;
my $directory;

my $nocreatedatabase = 0;
my $skipdbsteps = 0;

my $mysql_admin_username = "arcturus_dba";

my $mysql_normal_username = "arcturus";
my $mysql_normal_password = "***REMOVED***";

my $mysql_master_URL = "DBI:mysql:database=arcturus;host=mcs3a;port=15001";

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $dbhost = shift @ARGV if ($nextword eq '-host');
    $dbport = shift @ARGV if ($nextword eq '-port');
    $dbname = shift @ARGV if ($nextword eq '-db');

    $ldapurl = shift @ARGV if ($nextword eq '-ldapurl');
    $ldapuser = shift @ARGV if ($nextword eq '-ldapuser');
    $rootdn = shift @ARGV if ($nextword eq '-rootdn');

    $subdir = shift @ARGV if ($nextword eq '-subdir');

    $template = shift @ARGV if ($nextword eq '-template');

    $description = shift @ARGV if ($nextword eq '-description');

    $projects = shift @ARGV if ($nextword eq '-projects');

    $directory = shift @ARGV if ($nextword eq '-directory');

    $nocreatedatabase = 1 if ($nextword eq '-nocreatedatabase');
    $skipdbsteps = 1 if ($nextword eq '-skipdbsteps');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($dbhost)
	&& defined($dbport) && defined($description) && defined($ldapurl)
	&& defined($ldapuser) && defined($rootdn) && defined($subdir)) {
    &showUsage("One or more mandatory parameters are missing");
    exit(1);
}

unless (defined($template) || $nocreatedatabase  || $skipdbsteps) {
    &showUsage("You must specify either -template DBNAME or -nocreatedatabase or -skipdbsteps");
    exit(1);
}

unless (defined($dbname)) {
    $dbname = $organism;
    print STDERR "WARNING: No database name specified, using $organism as the default.\n\n";
}

unless ($skipdbsteps) {
    my $users_and_roles = &getUsersAndRoles($mysql_master_URL, $mysql_normal_username, $mysql_normal_password);

    my $dsn = "DBI:mysql:database=arcturus;host=$dbhost;port=$dbport";

    my $dbpw = &getPassword("Enter password for MySQL user $mysql_admin_username", "ARCTURUS_DBA_PW");
    
    if (!defined($dbpw) || length($dbpw) == 0) {
	print STDERR "No password was entered\n";
	exit(2);
    }
    
    my $dbh = DBI->connect($dsn, $mysql_admin_username, $dbpw);
    
    unless (defined($dbh)) {
	print STDERR "Failed to connect to $dsn as $mysql_admin_username\n";
	print STDERR "DBI error is $DBI::errstr\n";
	exit(3);
    }
    
    unless ($nocreatedatabase) { 
	my $query = "select table_name from information_schema.tables where table_schema = '" . $template .
	    "' and table_type = 'BASE TABLE'";
	
	my $sth = $dbh->prepare($query);
	&db_die("Failed to prepare query \"$query\"");
	
	$sth->execute();
	&db_die("Failed to execute query \"$query\"");
	
	my @tables;
	
	while (my ($tablename) = $sth->fetchrow_array()) {
	    push @tables, $tablename;
	}
	
	$sth->finish();
	
	print STDERR "### Creating a new database $dbname ... ";
	
	$query = "create database $dbname";
	
	$sth = $dbh->prepare($query);
	&db_die("Failed to prepare query \"$query\"");
	
	$sth->execute();
	&db_die("Failed to execute query \"$query\"");
	
	print STDERR "OK\n\n";
	
	print STDERR "### Switching to database $dbname ... ";
	
	$query = "use $dbname";
	
	$sth = $dbh->prepare($query);
	&db_die("Failed to prepare query \"$query\"");
	
	$sth->execute();
	&db_die("Failed to execute query \"$query\"");
	
	print STDERR "OK\n\n";
	
	print STDERR "### Creating tables ...\n";
	
	foreach my $tablename (@tables) {
	    $query = "create table $tablename like $template.$tablename";
	    
	    $sth = $dbh->prepare($query);
	    &db_die("Failed to prepare query \"$query\"");
	    
	    $sth->execute();
	    &db_die("Failed to execute query \"$query\"");
	    
	    print STDERR "\t$tablename\n";
	}

	print STDERR "\nOK\n\n";
    }
    
    print STDERR "### Granting privileges to user arcturus ... ";
    
    my $query = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES," .
	" LOCK TABLES, EXECUTE ON \`$dbname\`.* TO 'arcturus'\@'\%'";
    
    my $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute();
    &db_die("Failed to execute query \"$query\"");
    
    print STDERR "OK\n\n";
    
    print STDERR "### Granting privileges to user readonly ... ";
    
    $query = "GRANT SELECT, EXECUTE ON \`$dbname\`.* TO 'readonly'\@'\%'";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute();
    &db_die("Failed to execute query \"$query\"");
    
    print STDERR "OK\n\n";
    
    $dbh->disconnect();
    
    if (!defined($dbpw) || length($dbpw) == 0) {
	print STDERR "No password was entered\n";
	exit(2);
    }
    
    print STDERR "### Creating views ... ";
    
    my $command = "cat /software/arcturus/sql/views/*.sql | " .
	" mysql -h $dbhost -P $dbport -u $mysql_admin_username --password=$dbpw $dbname";
    
    my $rc = system($command);
    
    unless ($rc == 0) {
	print STDERR "Command \"$command\"\nfailed with return code $rc\n";
	exit(3);
    }
    
    print STDERR "OK\n\n";
    
    print STDERR "### Creating stored procedures ... ";
    
    $command = "cat /software/arcturus/sql/procedures/*.sql | " .
	" mysql -h $dbhost -P $dbport -u arcturus_dba --password=$dbpw $dbname";
    
    $rc = system($command);
    
    unless ($rc == 0) {
	print STDERR "Command \"$command\"\nfailed with return code $rc\n";
	exit(3);
    }
    
    print STDERR "OK\n\n";
    
    print STDERR "### Preparing to populate tables for $dbname ... ";
    
    $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$dbport";
    
    my $dbh = DBI->connect($dsn, "arcturus", "***REMOVED***");
    
    unless (defined($dbh)) {
	print STDERR "Failed to connect to $dsn as arcturus\n";
	print STDERR "DBI error is $DBI::errstr\n";
	exit(3);
    }
    
    print STDERR "OK\n\n";
    
    my @pwinfo = getpwuid($<);
    my $me = $pwinfo[0];
    
    print STDERR "### Creating the default assembly ... ";
    
    $query = "insert into ASSEMBLY(name,creator,created) values(?,?,now())";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute($organism, $me);
    &db_die("Failed to execute query \"$query\"");
    
    my $assembly_id = $dbh->{'mysql_insertid'};
    
    $sth->finish();
    
    print STDERR "OK\n\n";
    
    print STDERR "### Creating BIN and PROBLEMS projects ... ";
    
    $query = "insert into PROJECT(assembly_id,name,creator,created) values(?,?,?,NOW())";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute($assembly_id, 'BIN', $me);
    &db_die("Failed to execute query \"$query\" for BIN");
    
    $sth->execute($assembly_id, 'PROBLEMS', $me);
    &db_die("Failed to execute query \"$query\" for PROBLEMS");
    
    print STDERR "OK\n\n";
    
    if (defined($projects)) {
	print STDERR "### Creating user-specified projects ...\n";
	
	foreach my $project (split(/,/, $projects)) {
	    $sth->execute($assembly_id, $project, $me);
	    &db_die("Failed to execute query \"$query\" for $project");
	    print STDERR "\t$project\n";
	}
	
	print STDERR "\nOK\n\n";
    }
    
    $sth->finish();
    
    if (defined($directory)) {
	print STDERR "### Setting the directory for the projects ... ";
	
	$query = "update PROJECT set directory = concat('" . $directory . "/', name) where name != 'PROBLEMS'";
	
	$sth = $dbh->prepare($query);
	&db_die("Failed to prepare query \"$query\"");
	
	$sth->execute();
	&db_die("Failed to execute query \"$query\"");
	
	print STDERR "OK\n\n";
    }
    
    print STDERR "### Populating the USER table ... ";
    
    $query = "insert into USER(username,role) values(?,?)";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");

    foreach my $user_and_role (@{$users_and_roles}) {
	my ($user, $role) = @{$user_and_role};

	$sth->execute($user, $role);
	&db_die("Failed to execute query \"$query\" with user=\"$user\", role=\"$role\"");
    }

    $sth->finish();
    
    print STDERR "OK\n\n";
    
    print STDERR "### Populating the PRIVILEGE table ...\n";
    
    my %privileges = ('finisher' => ['create_project', 'lock_project', 'move_any_contig'],
		      'team leader' => ['assign_project', 'grant_privileges', 'create_project', 'lock_project', 'move_any_contig'],
		      'administrator' => ['assign_project', 'grant_privileges', 'create_project', 'lock_project', 'move_any_contig']
		      );
    
    $query = "select username,role from USER";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute();
    &db_die("Failed to execute query \"$query\"");
    
    my %roles;
    
    while (my ($user,$role) = $sth->fetchrow_array()) {
	$roles{$user} = $role;
    }
    
    $sth->finish();
    
    $query = "insert into PRIVILEGE(username,privilege) values (?,?)";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");

    foreach my $user (sort keys %roles) {
	my $role = $roles{$user};
	
	printf STDERR "\t%-8s %-20s\t", $user, $role;
	
	my $privs = $privileges{$role};
	
	if (defined($privs)) {
	    foreach my $priv (@{$privs}) {
		$sth->execute($user, $priv);
		&db_die("Failed to execute query \"$query\" with user=$user, privilege=$priv");
		print STDERR " $priv";
	    }
	} else {
	    print STDERR " *** NO PRIVILEGES DEFINED ***";
	}
	
	print STDERR "\n";
    }
    
    $sth->finish();
    
    print STDERR "\nOK\n\n";
    
    $dbh->disconnect();
}

my @reldn = ();

foreach my $dirname (split(/\//, $subdir)) {
    unshift @reldn, "cn=$dirname";
}

my $subdirdn = join(',', @reldn) . ",cn=$instance";

my $reldn = "cn=$organism," . $subdirdn;

my $dn = "$reldn,$rootdn";

print STDERR "### Creating an LDAP entry $dn ...\n";

my $ldappw = &getPassword("Enter password for LDAP user \"$ldapuser\"", "LDAP_ADMIN_PW");

if (!defined($ldappw) || length($ldappw) == 0) {
    print STDERR "No password was entered\n";
    exit(2);
}

my $ldap = Net::LDAP->new($ldapurl) or die "$@";
 
my $mesg = $ldap->bind($ldapuser, password => $ldappw);
$mesg->code && die $mesg->error;

&checkOrCreateLDAPNode($subdirdn, $rootdn, $ldap);

my $result = $ldap->add($dn,
		     attr => ['cn' => $organism,
			      'javaClassName' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
			      'javaFactory' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSourceFactory',
			      'javaReferenceAddress' => ["#0#user#" . $mysql_normal_username,
							 "#1#password#" . $mysql_normal_password,
							 "#2#serverName#$dbhost",
							 "#3#port#$dbport",
							 "#4#databaseName#$dbname",
							 "#5#profileSql#false",
							 "#6#explicitUrl#false"],

			      'description' => $description,

			      'objectClass' => ['top',
						'javaContainer',
						'javaNamingReference']
			      ]
		     );

if ($result->code) {
    print STDERR " FAILED: ", $result->error, "\n";
    exit(1);
} else {
    print STDERR " OK\n";
}

$mesg = $ldap->unbind;

print STDERR "\nTHE SCRIPT HAS COMPLETED\n";

exit(0);

sub checkOrCreateLDAPNode {
    my ($reldn, $rootdn, $ldap, $junk) = @_;

    my @dnparts = split(/,/, $reldn);

    my $base = $rootdn;

    while (my $part = pop @dnparts) {
	print STDERR "\nSearching $base for $part ... ";

	$mesg = $ldap->search(base   => $base,
			      scope => 'one',
			      deref => 'never',
			      filter => "($part)"
			      );

	die "LDAP search returned a null message" if !defined($mesg);

	$mesg->code && die $mesg->error;

	my @entries = $mesg->all_entries;

	if (scalar(@entries) > 0) {
	    print STDERR "OK\n";
	} else {
	    print STDERR "NOT FOUND\n";
	    
	    my $dn = $part . "," . $base;
	    print STDERR "Attempting to create $dn ... ";
	    
	    my ($lhs,$rhs) = split(/=/, $part);
	    
	    my $result = $ldap->add($dn,
				    attr => [ $lhs => $rhs,
					      'objectClass' => [ 'top', 'javaContainer' ]
					      ]
				    );
	    
	    if ($result->code) {
		print STDERR "FAILED: ", $result->error, "\n";
		exit(1);
	    } else {
		print STDERR "OK\n";
	    }
	}
	
	$base = $part . "," . $base;
    }

    print STDERR "\n";
}

sub getPassword {
    my $prompt = shift || "Enter password:";
    my $alias = shift;

    my $password = defined($alias) ? $ENV{$alias} : undef;

    return $password if defined($password);

    print "$prompt ";

    ReadMode 'noecho';

    $password = ReadLine 0;

    ReadMode 'normal';

    print "\n";

    chop($password);

    return $password;
}

sub getUsersAndRoles {
    my ($url, $username, $password, $junk) = @_;

    my $dbh = DBI->connect($url, $username, $password);

    unless (defined($dbh)) {
	print STDERR "Unable to connect to master Arcturus instance $url", 
	" to fetch list of users and roles\n";
	die "DBI->connect failed";
    }

    my $query = "select username,role from USER";

    my $sth = $dbh->prepare($query);
    &db_die("prepare($query) failed");

    $sth->execute();
    &db_die("execute($query) failed");

    my $list = [];

    while (my ($user, $role) =  $sth->fetchrow_array()) {
	push @{$list}, [$user, $role];
    }
 
    $sth->finish();

    $dbh->disconnect();

    return $list;
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(99);
}

sub showUsage {
    my $message = shift;

    print STDERR "$message\n\n" if defined($message);

    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "    -host\t\tMySQL host\n";
    print STDERR "    -port\t\tMySQL port\n";
    print STDERR "\n";
    print STDERR "    -ldapurl\t\tLDAP URL\n";
    print STDERR "    -ldapuser\t\tLDAP username\n";
    print STDERR "    -rootdn\t\tLDAP root DN\n";
    print STDERR "    -subdir\t\tSub-directory of LDAP tree (e.g. bacteria/Salmonella)\n";
    print STDERR "\n";
    print STDERR "    -description\tDescription for LDAP entry\n";
    print STDERR "\n";
    print STDERR "    -template\t\tMySQL database to use as template\n";
    print STDERR "\t\t\t[Unless -nocreatedatabase or -skipdbstepshas been specified]";
    print STDERR "\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -db\t\t\tMySQL database to create (default: organism name)\n";
    print STDERR "    -projects\t\tProjects to add to the database\n";
    print STDERR "    -directory\t\tBase directory for projects\n";
    print STDERR "    -nocreatedatabase\tDatabase already exists, do not create it\n";
    print STDERR "    -skipdbsteps\tSkip the MySQL steps\n";
}
