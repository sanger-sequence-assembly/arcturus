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


use Net::LDAP;

while ($nextword = shift @ARGV) {
    $ldap_url = shift @ARGV if ($nextword eq '-ldapurl');
    $ldap_user = shift @ARGV if ($nextword eq '-ldapuser');
    $ldap_pass = shift @ARGV if ($nextword eq '-ldappass');

    $rootdn = shift @ARGV if ($nextword eq '-rootdn');

    $host = shift @ARGV if ($nextword eq '-host');

    $port = shift @ARGV if ($nextword eq '-port');

    $user = shift @ARGV if ($nextword eq '-user');

    $pass = shift @ARGV if ($nextword eq '-pass');

    $database = shift @ARGV if ($nextword eq '-database');

    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');
}

unless (defined($ldap_url) && defined($ldap_user) && defined($ldap_pass) && defined($rootdn) &&
	defined($host) && defined($port) && defined($user) && defined($pass) &&
	defined($database) && defined($instance) && defined($organism)) {
    &ShowUsage;
    exit(1);
}

$ldap = Net::LDAP->new($ldap_url) or die "$@";
 
$mesg = $ldap->bind($ldap_user, password => $ldap_pass);
$mesg->code && die $mesg->error;

$result = $ldap->add("cn=$organism,cn=$instance,$rootdn",
		     attr => ['cn' => $organism,
			      'javaClassName' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
			      'javaFactory' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSourceFactory',
			      'javaReferenceAddress' => ["#0#user#$user",
							 "#1#password#$pass",
							 "#2#serverName#$host",
							 "#3#port#$port",
							 "#4#databaseName#$database",
							 "#5#profileSql#false",
							 "#6#explicitUrl#false"],
			      'objectClass' => ['top',
						'javaContainer',
						'javaNamingReference']
			      ]
		     );

$result->code && warn "failed to add entry: ", $result->error;  

$mesg = $ldap->unbind;

exit(0);

sub ShowUsage {
    print STDERR "Some arguments were missing.\n";
}
