package WrapMySQL;

# Based upon a module of the same name by Rob Davies
# of the Wellcome Trust Sanger Institute

use strict;
use DBI;

@WrapMySQL::ISA = qw(DBI);

my $users;

BEGIN {
    $users = {};

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
		    $users->{$instance}->{$name} = [$username, $password];
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

    die "No database specified" unless $db;

    die "No mode specified" unless $mode;

    unless ($mode eq 'admin' || $mode eq 'read' || $mode eq 'write') {
	print STDERR "*** WrapMySQL->connect($db, $mode): Invalid access mode \"$mode\" ***\n";
	return undef;
    }

    $attrs = {RaiseError => 1, PrintError => 0} unless $attrs;

    my $info = $users->{$db};

    unless (defined($info)) {
	print STDERR "*** WrapMySQL->connect($db, $mode): Unknown meta-database \"$db\" ***\n";
	return undef;
    }

    my ($uname, $passwd, $dbname, $server, $dbport);

    $dbname = $info->{'dbname'};

    $server = $info->{'server'};

    $dbport = $info->{'port'} || 3306;

    ($uname, $passwd) = @{$info->{$mode}};

    my $dsn = "DBI:mysql:$dbname:$server:$dbport";

    my $dbh = DBI->connect($dsn, $uname, $passwd, $attrs);

    return $dbh;
}
