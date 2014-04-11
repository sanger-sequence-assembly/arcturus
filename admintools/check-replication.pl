#!/usr/local/bin/perl

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


use strict;

use DBI;

my $slaves = [
	      { 'host' => 'mcs14',
		'port' => 15003,
		'username' => 'monitor',
		'password' => 'WhoWatchesTheWatchers' },

	      { 'host' => 'mcs14',
		'port' => 15001,
		'username' => 'monitor',
		'password' => 'WhoWatchesTheWatchers' },

              { 'host' => 'mcs3a',
                'port' => 15005,
	        'username' => 'monitor',
	        'password' => 'WhoWatchesTheWatchers' }

	      ];

foreach my $slave (@{$slaves}) {
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

    my $options = {RaiseError => 0, PrintError => 1};

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

    unless (defined($dbh)) {
	print "    ***** Failed to connect to master: $DBI::errstr *****\n";
	return;
    }

    my $query = "SHOW MASTER STATUS";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $row = $sth->fetchrow_hashref();

    if (defined($row)) {
	printf "   Current log file on master:   %-20s at position %10d\n", $row->{'File'}, $row->{'Position'};
    } else {
	print "   ***** Failed to get master status from $name: $DBI::errstr *****\n"
    }

    $sth->finish();

    $dbh->disconnect();
}

sub checkSlave {
    my $slave = shift;

    my $name = $slave->{'host'} . ":" . $slave->{'port'};

    print "SLAVE STATUS FOR $name\n";

    my $dbh = &getConnection($slave);

    unless (defined($dbh)) {
	print "    ***** Failed to connect to slave: $DBI::errstr *****\n";
	return;
    }
 
    my $query = "SHOW SLAVE STATUS";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $row = $sth->fetchrow_hashref();

    if (defined($row)) {
	print "   Master is ",$row->{'Master_Host'},":",$row->{'Master_Port'},"\n";

	my $master = { 'host' => $row->{'Master_Host'},
		       'port' => $row->{'Master_Port'},
		       'username' => $slave->{'username'},
		       'password' => $slave->{'password'}
		   };

	&checkMaster($master);

	printf "   I/O thread log file on slave: %-20s read to     %10d\n",
        $row->{'Master_Log_File'}, $row->{'Read_Master_Log_Pos'};

	printf "   SQL thread log file on slave: %-20s executed to %10d\n",
	$row->{'Relay_Master_Log_File'}, $row->{'Exec_Master_Log_Pos'};

	my $iostatus = $row->{'Slave_IO_Running'};

	if ($iostatus eq 'Yes') {
	    print "   I/O thread is running\n";
	} else {
	    print "   ***** I/O thread is NOT running *****\n";
	}

	my $sqlstatus = $row->{'Slave_SQL_Running'};

	if ($sqlstatus eq 'Yes') {
	    print "   SQL thread is running\n";
	} else {
	    print "   ***** SQL thread is NOT running *****\n";
	}

	my $errno = $row->{'Last_Errno'};
	my $errmsg = $row->{'Last_Error'};

	if ($errno != 0 || (defined($errmsg) && length($errmsg) > 0)) {
	    print "   ***** Last error: ($errno) $errmsg\n";
	}

	my $lag = $row->{'Seconds_Behind_Master'};

	if (defined($lag)) {
	    if ($lag == 0) {
		print "   Slave is in synch with master\n";
	    } else {
		print "   Slave is $lag seconds behind master\n";
	    }
	} else {
	    print "   ***** Unable to determine slave's time lag behind master *****\n";
	}
	print "\n";
    } else {
	print "    ***** Failed to get slave status from $name *****\n";
    }

    $sth->finish();
   

    $dbh->disconnect();
}
