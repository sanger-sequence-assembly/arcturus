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

my $dbhost;
my $dbport;
my $dbname;

my $ldapurl;
my $ldapuser;

my $template;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $dbhost = shift @ARGV if ($nextword eq '-host');
    $dbport = shift @ARGV if ($nextword eq '-port');
    $dbname = shift @ARGV if ($nextword eq '-db');

    $ldapurl = shift @ARGV if ($nextword eq '-ldapurl');
    $ldapuser = shift @ARGV if ($nextword eq '-ldapuser');

    $template = shift @ARGV if ($nextword eq '-template');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($dbhost)
	&& defined($dbport) && defined($dbname) && defined($ldapurl)
	&& defined($ldapuser) && defined($template)) {
    &showUsage("One or more mandatory parameters are missing");
    exit(1);
}

my $dsn = "DBI:mysql:database=arcturus;host=$dbhost;port=$dbport";

my $dbpw = &getPassword("Enter password for root MySQL user");

if (!defined($dbpw) || length($dbpw) == 0) {
    print STDERR "No password was entered\n";
    exit(2);
}

my $dbh = DBI->connect($dsn, "root", $dbpw);

unless (defined($dbh)) {
    print STDERR "Failed to connect to $dsn as root\n";
    print STDERR "DBI error is $DBI::errstr\n";
    exit(3);
}

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

print STDERR "\n";

print STDERR "### Granting privileges to user arcturus ... ";

$query = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES," .
    " LOCK TABLES, EXECUTE ON \`$dbname\`.* TO 'arcturus'\@'\%'";

$sth = $dbh->prepare($query);
&db_die("Failed to prepare query \"$query\"");

$sth->execute();
&db_die("Failed to execute query \"$query\"");

print STDERR "OK\n\n";

print STDERR "### Granting privileges to user arcturus_dba ... ";

$query = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER," .
    " CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW," .
    " CREATE ROUTINE, ALTER ROUTINE ON \`$dbname\`.* TO 'arcturus_dba'\@'\%'";

$sth = $dbh->prepare($query);
&db_die("Failed to prepare query \"$query\"");

$sth->execute();
&db_die("Failed to execute query \"$query\"");

print STDERR "OK\n\n";

$dbh->disconnect();

$dbpw = &getPassword("Enter password for MySQL user arcturus_dba");

if (!defined($dbpw) || length($dbpw) == 0) {
    print STDERR "No password was entered\n";
    exit(2);
}

print STDERR "### Creating views ... ";

my $command = "cat /software/arcturus/sql/views/*.sql | mysql -h $dbhost -P $dbport -u arcturus_dba --password=$dbpw $dbname";

my $rc = system($command);

unless ($rc == 0) {
    print STDERR "Command \"$command\"\nfailed with return code $rc\n";
    exit(3);
}

print STDERR "OK\n\n";

print STDERR "### Creating stored procedures ... ";

$command = "cat /software/arcturus/sql/procedures/*.sql | mysql -h $dbhost -P $dbport -u arcturus_dba --password=$dbpw $dbname";

$rc = system($command);

unless ($rc == 0) {
    print STDERR "Command \"$command\"\nfailed with return code $rc\n";
    exit(3);
}

print STDERR "OK\n\n";

exit(0);

sub getPassword {
    my $prompt = shift || "Enter password:";

    print "$prompt ";

    ReadMode 'noecho';

    my $password = ReadLine 0;

    ReadMode 'normal';

    print "\n";

    chop($password);

    return $password;
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
    print STDERR "    -db\t\t\tMySQL database to create\n";
    print STDERR "\n";
    print STDERR "    -ldapurl\t\tLDAP URL\n";
    print STDERR "    -ldapuser\t\tLDAP username\n";
    print STDERR "\n";
    print STDERR "    -template\t\tMySQL database to use as template\n";
}
