package WrapMySQL;

# Based upon a module of the same name by Rob Davies
# of the Wellcome Trust Sanger Institute

use strict;
use DBI;

@WrapMySQL::ISA = qw(DBI);

my $users;

BEGIN {
    $users = {
	'pcs3.prod' => {
	    'dbname' => 'arcturus',
	    'server' => 'pcs3',
	    'port'   => 14641,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
	'pcs3.dev' => {
	    'dbname' => 'arcturus',
	    'server' => 'pcs3',
	    'port'   => 14642,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
	'pcs3.test' => {
	    'dbname' => 'arcturus',
	    'server' => 'pcs3',
	    'port'   => 14651,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
	'babel.prod' => {
	    'dbname' => 'arcturus',
	    'server' => 'babel',
	    'port'   => 14641,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
	'babel.dev' => {
	    'dbname' => 'arcturus',
	    'server' => 'babel',
	    'port'   => 14642,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
	'babel.test' => {
	    'dbname' => 'arcturus',
	    'server' => 'babel',
	    'port'   => 14651,
	    'admin'  => ['arcturus',  '***REMOVED***'],
	    'write'  => ['arcturus',  '***REMOVED***'],
	    'read'   => ['analysedb', 'dbviewer']
	    },
    };
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
