package WrapMySQL;

# Based upon a module of the same name by Rob Davies
# of the Wellcome Trust Sanger Institute

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

    $dbname = $info->{'dbname'};

    $server = $info->{'server'};

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
