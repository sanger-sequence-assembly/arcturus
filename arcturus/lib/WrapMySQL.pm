# WrapMySQL.pm
#
# Author
# ------
#
# David Harper <adh@sanger.ac.uk>
#
#
# Description
# -----------
#
# WrapMySQL is a wrapper around the DBI.pm module. It replaces the standard
# connect function with one which takes an alias for the database (which
# maps to a hostname, port number and default database) and a role name
# (which maps to a username and password).
#
# The aliases and roles are defined in a configuration file whose location
# is specified at run-time via the WRAPMYSQL_INI environment variable.
#
# The module was inspired by WrapDBI.pm, which performs a similar function
# for the Oracle instances at the Wellcome Trust Sanger Institute.
#
#
# Example
# -------
#
# $dbh = WrapMySQL->connect('payroll', 'read');
#
# print "Connect failed: ", WrapMySQL->getErrorString, "\n" if (!defined($dbh));
#
#
# Configuration file format
# -------------------------
#
# The configuration file follows a format similar to the MySQL .cnf files.
# For example:
#
# [payroll]
# host=payroll.example.com
# port=15000
# database=salaries
# role.read=username,password
# role.write=user2,passwd2

package WrapMySQL;

use strict;
use DBI;

@WrapMySQL::ISA = qw(DBI);

my $users;
my $errorstring;

BEGIN {
    $users = {};

    $errorstring = 'No error';

    my $inifile = $ENV{'WRAPMYSQL_INI'};

    if (defined($inifile) && open(INI, $inifile)) {
	my ($line, $instance, $name, $value, $roles, $username, $password);

	while ($line = <INI>) {
	    chop $line;

	    if ($line =~ /\[([\w\-\.]+)\]/) {
		$instance = $1;
		$users->{$instance} = {};
	    } elsif ($line =~ /([\w\-\.]+)=([\w\-\.\,]+)/) {
		($name, $value) = ($1, $2);
		if ($name =~ /^role\.(\w+)/) {
		    $name = $1;
		    ($username, $password) = split(/,/, $value);
		    $users->{$instance}->{'ROLE'} = {} unless
			defined($users->{$instance}->{'ROLE'});
		    $users->{$instance}->{'ROLE'}->{$name} = [$username, $password];
		} else {
		    $users->{$instance}->{$name} = $value;
		}
	    }
	}

	close(INI);
    }
}

sub connect {
    my ($type, $db, $mode, $attrs) = @_;

    $errorstring = 'No error';

    unless (defined($db)) {
	$errorstring = "No database specified";
	return undef;
    }

    unless (defined($mode))  {
	$errorstring = "No role specified";
	return undef;
    }

    $attrs = {RaiseError => 0, PrintError => 0} unless $attrs;

    my $info = $users->{$db};

    unless (defined($info)) {
	$errorstring = "Instance \"$db\" is not known";
	return undef;
    }

    my ($uname, $passwd, $dbname, $server, $dbport, $roledata);

    $dbname = $info->{'database'};

    $server = $info->{'host'};

    $dbport = $info->{'port'} || 3306;

    $roledata = $info->{'ROLE'}->{$mode};

    unless (defined($roledata)) {
	$errorstring = "Role \"$mode\" does not exist in instance \"$db\"";
	return undef;
    }

    ($uname, $passwd) = @{$roledata};

    my $dsn = "DBI:mysql:$dbname:$server:$dbport";

    my $dbh = DBI->connect($dsn, $uname, $passwd, $attrs);

    $errorstring = $DBI::errstr;

    return $dbh;
}

sub getErrorString {
    return $errorstring;
}
