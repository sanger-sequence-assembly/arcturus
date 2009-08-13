#!/usr/local/bin/perl
#
# This script creates a new Arcturus organism database and
# its corresponding LDAP entry.

use strict;

use DBI;
use Net::LDAP;
use Term::ReadKey;

use DataSource;

my $instance;
my $organism;
my $repository;
my $subdir;

my $dbnode;
my $dbname;

my $ldapurl;
my $ldapuser;
my $rootdn;

my $description;

my $template;

my $projects;

my $appendtofile;

my $nocreatedatabase = 0;
my $skipdbsteps = 0;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $repository = shift @ARGV if ($nextword eq '-repository');

    $dbnode = shift @ARGV if ($nextword eq '-node');

    $dbname = shift @ARGV if ($nextword eq '-db');

    $ldapurl = shift @ARGV if ($nextword eq '-ldapurl');
    $ldapuser = shift @ARGV if ($nextword eq '-ldapuser');
    $rootdn = shift @ARGV if ($nextword eq '-rootdn');

    $subdir = shift @ARGV if ($nextword eq '-subdir');

    $template = shift @ARGV if ($nextword eq '-template');

    $description = shift @ARGV if ($nextword eq '-description');

    $projects = shift @ARGV if ($nextword eq '-projects');

    $appendtofile = shift @ARGV if ($nextword eq '-appendtofile');

    $nocreatedatabase = 1 if ($nextword eq '-nocreatedatabase');
    $skipdbsteps = 1 if ($nextword eq '-skipdbsteps');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

$ldapurl  = $ENV{'ARCTURUS_LDAP_URL'} unless defined($ldapurl);
$ldapuser = $ENV{'ARCTURUS_LDAP_USERNAME'} unless defined($ldapuser);
$rootdn   = $ENV{'ARCTURUS_LDAP_ROOT_DN'} unless defined($rootdn);

unless (defined($instance) && defined($organism) && defined($dbnode)
	&& defined($description) && defined($ldapurl)
	&& defined($ldapuser) && defined($rootdn) && defined($subdir) && defined($repository)) {
    &showUsage("One or more mandatory parameters are missing");
    exit(1);
}

unless (defined($template) || $nocreatedatabase  || $skipdbsteps) {
    &showUsage("You must specify either -template DBNAME or -nocreatedatabase or -skipdbsteps");
    exit(1);
}

unless (defined($dbname)) {
    $dbname = $organism;
    $dbname =~ tr/\-/_/;
    print STDERR "WARNING: No database name specified, using $organism as the default.\n\n";
}

my $dsa = new DataSource(-url => $ldapurl,
			 -base => $rootdn,
			 -instance => 'arcturus',
			 -node => 'arcturus');

die "Failed to create a DataSource for arcturus/arcturus" unless defined($dsa);

my $mysql_normal_username = $dsa->getAttribute("user");
my $mysql_normal_password = $dsa->getAttribute("password");

my $ldappass = &getPassword("Enter password for LDAP user \"$ldapuser\"", "ARCTURUS_LDAP_PASSWORD");

if (!defined($ldappass) || length($ldappass) == 0) {
    print STDERR "No password was entered\n";
    exit(2);
}

my $dsb = new DataSource(-url => $ldapurl,
			 -base => $rootdn,
			 -instance => 'admin',
			 -node => $dbnode,
			 -ldapuser => $ldapuser,
			 -ldappass => $ldappass);
   
die "Failed to create a DataSource for admin/$dbnode" unless defined($dsb);

my $dbhost = $dsb->getAttribute("serverName");
my $dbport = $dsb->getAttribute("port");
my $dbuser = $dsb->getAttribute("user");
my $dbpass = $dsb->getAttribute("password");

unless ($skipdbsteps) {
    my $users_and_roles = &getUsersAndRoles($dsa);
 
    my $dbh = $dsb->getConnection(-options => {RaiseError => 1, PrintError => 1});
    
    unless (defined($dbh)) {
	print STDERR "Failed to connect to MySQL node \"$dbnode\" as Arcturus DBA user\n";
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

	$sth->finish();

	$query = "select count(*) from information_schema.tables" .
	    " where table_schema = ? and table_type = ? and engine = ?";

	$sth = $dbh->prepare($query);
	&db_die("Failed to prepare query \"$query\"");
	
	$sth->execute($template, 'BASE TABLE', 'InnoDB');
	&db_die("Failed to execute query \"$query\"");

	my ($innodbcount) = $sth->fetchrow_array();

	$sth->finish();
	
	&createForeignKeyConstraints($dbh)
	    if ($innodbcount > 0);
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

    print STDERR "### Creating views ... ";
    
    my $command = "cat /software/arcturus/sql/views/*.sql | " .
	" mysql -h $dbhost -P $dbport -u $dbuser --password=$dbpass $dbname";
    
    my $rc = system($command);
    
    unless ($rc == 0) {
	print STDERR "Command \"$command\"\nfailed with return code $rc\n";
	exit(3);
    }
    
    print STDERR "OK\n\n";
    
    print STDERR "### Creating stored procedures ... ";
    
    $command = "cat /software/arcturus/sql/procedures/*.sql | " .
	" mysql -h $dbhost -P $dbport -u $dbuser --password=$dbpass $dbname";
    
    $rc = system($command);
    
    unless ($rc == 0) {
	print STDERR "Command \"$command\"\nfailed with return code $rc\n";
	exit(3);
    }
    
    print STDERR "OK\n\n";
    
    print STDERR "### Preparing to populate tables for $dbname ... ";
    
    my $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$dbport";
    
    my $dbh = DBI->connect($dsn, $mysql_normal_username, $mysql_normal_password);
    
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
    
    $query = "insert into PROJECT(assembly_id,name,creator,created,directory) values(?,?,?,NOW(),?)";
    
    $sth = $dbh->prepare($query);
    &db_die("Failed to prepare query \"$query\"");
    
    $sth->execute($assembly_id, 'BIN', $me, $repository . "/split/BIN");
    &db_die("Failed to execute query \"$query\" for BIN");
    
    $sth->execute($assembly_id, 'PROBLEMS', $me, undef);
    &db_die("Failed to execute query \"$query\" for PROBLEMS");
    
    print STDERR "OK\n\n";
    
    if (defined($projects)) {
	print STDERR "### Creating user-specified projects ...\n";
	
	foreach my $project (split(/,/, $projects)) {
	    $sth->execute($assembly_id, $project, $me, $repository . "/split/" . $project);
	    &db_die("Failed to execute query \"$query\" for $project");
	    print STDERR "\t$project\n";
	}
	
	print STDERR "\nOK\n\n";
    }
    
    $sth->finish();
        
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

my $ldap = Net::LDAP->new($ldapurl) or die "$@";
 
my $mesg = $ldap->bind($ldapuser, password => $ldappass);
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

if (defined($appendtofile)) {
    print STDERR "### Appending organism name to $appendtofile ...";

    eval {
	open(FILE, ">>$appendtofile");
	print FILE $organism,"\n";
	close(FILE);
	print STDERR " OK\n";
    };
    if ($@) {
	print STDERR " failed : $@\n";
    }
}

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
    my ($ds, $junk) = @_;

    my $dbh = $ds->getConnection(-options => {RaiseError => 1, PrintError => 1});

    unless (defined($dbh)) {
	print STDERR "Unable to connect to database to fetch list of users and roles\n";
	die "DBI->connect failed";
    }

    my $query = "select username,default_role from SESSION";

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

sub createForeignKeyConstraints {
    my $dbh = shift;

    my $constraints = 
	[
	 ["PROJECT","assembly_id","ASSEMBLY","assembly_id"],
	 
	 ["C2CMAPPING","contig_id","CONTIG","contig_id","CASCADE"],
	 ["C2CMAPPING","parent_id","CONTIG","contig_id"],
	 ["CONSENSUS","contig_id","CONTIG","contig_id","CASCADE"],
	 ["CONTIGORDER","contig_id","CONTIG","contig_id","CASCADE"],
	 ["CONTIGTRANSFERREQUEST","contig_id","CONTIG","contig_id","CASCADE"],
	 ["MAPPING","contig_id","CONTIG","contig_id","CASCADE"],
	 ["TAG2CONTIG","contig_id","CONTIG","contig_id","CASCADE"],

	 ["SCAFFOLD","import_id","IMPORTEXPORT","id"],

	 ["C2CSEGMENT","mapping_id","C2CMAPPING","mapping_id","CASCADE"],

	 ["CLONEVEC","cvector_id","CLONINGVECTOR","cvector_id"],
	 ["SEQVEC","svector_id","SEQUENCEVECTOR","svector_id"],

	 ["CONTIGTRANSFERREQUEST","old_project_id","PROJECT","project_id","RESTRICT","CASCADE"],
	 ["CONTIGTRANSFERREQUEST","new_project_id","PROJECT","project_id","RESTRICT","CASCADE"],
	 ["CONTIG","project_id","PROJECT","project_id","RESTRICT","CASCADE"],

	 ["READCOMMENT","read_id","READINFO","read_id","CASCADE"],
	 ["SEQ2READ","read_id","READINFO","read_id","CASCADE"],
	 ["TRACEARCHIVE","read_id","READINFO","read_id","CASCADE"],

	 ["CONTIGORDER","scaffold_id","SCAFFOLD","scaffold_id","CASCADE"],

	 ["ALIGN2SCF","seq_id","SEQUENCE","seq_id","CASCADE"],
	 ["CLONEVEC","seq_id","SEQUENCE","seq_id","CASCADE"],
	 ["MAPPING","seq_id","SEQUENCE","seq_id"],
	 ["QUALITYCLIP","seq_id","SEQUENCE","seq_id","CASCADE"],
	 ["READTAG","seq_id","SEQUENCE","seq_id","CASCADE"],
	 ["SEQ2READ","seq_id","SEQUENCE","seq_id","CASCADE"],
	 ["SEQVEC","seq_id","SEQUENCE","seq_id","CASCADE"],

	 ["SEGMENT","mapping_id","MAPPING","mapping_id","CASCADE"],

	 ["TAG2CONTIG","tag_id","CONTIGTAG","tag_id","CASCADE"],

	 ["SCAFFOLD","type_id","SCAFFOLDTYPE","type_id"]
	 ];

    print STDERR "### Creating foreign key constraints for InnoDB tables ...\n";

    foreach my $constraint (@{$constraints}) {
	my ($table,$column,$fk_table,$fk_column,$delete_op,$update_op) = @{$constraint};
	
	$delete_op = "RESTRICT" unless defined($delete_op);
	$update_op = "RESTRICT" unless defined($update_op);

	my $query = "alter table $table add constraint foreign key ($column)" .
	    " references $fk_table ($fk_column)" .
	    " on delete $delete_op" .
	    " on update $update_op";

	print STDERR "Executing: $query\n";

	$dbh->do($query);
	&db_die("Failed to execute query \"$query\"");
    }

    print STDERR "OK.\n";
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
    print STDERR "    -repository\t\tRepository directory location\n";
    print STDERR "\n";
    print STDERR "    -node\t\tArcturus MySQL instance name (arcp, hlmp, ...)\n";
    print STDERR "\n";
    print STDERR "    -ldapurl\t\tLDAP URL [Or set ARCTURUS_LDAP_URL]\n";
    print STDERR "    -ldapuser\t\tLDAP username [Or set ARCTURUS_LDAP_USERNAME]\n";
    print STDERR "    -rootdn\t\tLDAP root DN [Or set ARCTURUS_LDAP_ROOT_DN]\n";
    print STDERR "\n";
    print STDERR "    -subdir\t\tSub-directory of LDAP tree (e.g. bacteria/Salmonella)\n";
    print STDERR "\n";
    print STDERR "    -description\tDescription for LDAP entry\n";
    print STDERR "\n";
    print STDERR "    -template\t\tMySQL database to use as template\n";
    print STDERR "\t\t\t[Unless -nocreatedatabase or -skipdbsteps has been specified]";
    print STDERR "\n\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -db\t\t\tMySQL database to create (default: organism name)\n";
    print STDERR "    -projects\t\tProjects to add to the database\n";
    print STDERR "    -nocreatedatabase\tDatabase already exists, do not create it\n";
    print STDERR "    -skipdbsteps\tSkip the MySQL steps\n";
    print STDERR "    -appendtofile\tAppend the organism name to this file\n";
}
