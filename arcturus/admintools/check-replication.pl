#!/usr/local/bin/perl

use strict;

use DBI;

my $master = { 'host' => 'mcs3a',
	       'port' => 15001,
	       'username' => 'monitor',
	       'password' => 'WhoWatchesTheWatchers' };

my $slaves = [
	      { 'host' => 'mcs1a',
		'port' => 15002,
		'username' => 'monitor',
		'password' => 'WhoWatchesTheWatchers' },

	      { 'host' => 'mcs2a',
		'port' => 15002,
		'username' => 'monitor',
		'password' => 'WhoWatchesTheWatchers' }
	      ];

&checkMaster($master);

foreach my $slave (@{$slaves}) {
    print "\n";
    &checkSlave($slave);
}

exit(0);

sub getConnection {
    my $ds = shift;

    my $host = $ds->{'host'};
    my $port = $ds->{'port'};
    my $username = $ds->{'username'};
    my $password = $ds->{'password'};

    my $url = "DBI:mysql::$host:$port";

    my $options = {RaiseError => 1, PrintError => 1};

     my $dbh = DBI->connect($url, $username, $password, $options);

    return $dbh;
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub checkMaster {
    my $master = shift;

    my $name = $master->{'host'} . ":" . $master->{'port'};

    my $dbh = &getConnection($master);

    my $query = "SHOW MASTER STATUS";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $row = $sth->fetchrow_hashref();

    if (defined($row)) {
	print "MASTER STATUS FOR $name\n";
	print "\tMaster log file ", $row->{'File'}, " at position ", $row->{'Position'},"\n";
    } else {
	&db_die("Failed to get master status from $name");
    }

    $sth->finish();

    $dbh->disconnect();
}

sub checkSlave {
    my $slave = shift;

    my $name = $slave->{'host'} . ":" . $slave->{'port'};

    my $dbh = &getConnection($slave);
 
    my $query = "SHOW SLAVE STATUS";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $row = $sth->fetchrow_hashref();

    if (defined($row)) {
	print "SLAVE STATUS FOR $name\n";

	print "\tMaster: ",$row->{'Master_Host'},":",$row->{'Master_Port'},"\n";

	print "\tMaster log file ", $row->{'Master_Log_File'},
	" read to ",$row->{'Read_Master_Log_Pos'},
	", executed to ", $row->{'Exec_Master_Log_Pos'}, "\n";

	my $iostatus = $row->{'Slave_IO_Running'};

	if ($iostatus eq 'Yes') {
	    print "\tIO thread is running\n";
	} else {
	    print "\t***** IO thread is NOT running *****\n";
	}

	my $sqlstatus = $row->{'Slave_SQL_Running'};

	if ($sqlstatus eq 'Yes') {
	    print "\tSQL thread is running\n";
	} else {
	    print "\t***** SQL thread is NOT running *****\n";
	}

	my $errno = $row->{'Last_Errno'};
	my $errmsg = $row->{'Last_Error'};

	if ($errno != 0 || (defined($errmsg) && length($errmsg) > 0)) {
	    print "\t***** Last error: ($errno) $errmsg\n";
	}

	my $lag = $row->{'Seconds_Behind_Master'};
	if ($lag == 0) {
	    print "\tSlave is in synch with master\n";
	} else {
	    print "\tSlave is $lag seconds behind master\n";
	}
    } else {
	&db_die("Failed to get slave status from $name");
    }

    $sth->finish();
   

    $dbh->disconnect();
}
