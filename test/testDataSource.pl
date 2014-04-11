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

use DataSource;
use DBI;

my ($instance, $organism, $username, $password, $ldapuser, $ldappass);

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism' || $nextword eq '-node');

    $username = shift @ARGV if ($nextword eq '-username');

    $password = shift @ARGV if ($nextword eq '-password');

    $ldapuser = shift @ARGV if ($nextword eq '-ldapuser');

    $ldappass = shift @ARGV if ($nextword eq '-ldappass');
}

die "You must specify the instance" unless defined($instance);
die "You must specify the organism" unless defined($organism);

$ldapuser = $ENV{'ARCTURUS_LDAP_USERNAME'} unless defined($ldapuser);
$ldappass = $ENV{'ARCTURUS_LDAP_PASSWORD'} unless defined($ldappass);

my $ds = (defined($ldapuser) && defined($ldappass)) ?
    new DataSource(-instance => $instance,
		   -organism => $organism,
		   -ldapuser => $ldapuser,
		   -ldappass => $ldappass) :
    new DataSource(-instance => $instance,
		   -organism => $organism);

if (!defined($ds)) {
    print STDERR "Failed to locate a datasource for instance=\"$instance\" and organism=\"$organism\"\n";
    exit(1);
}

my $url = $ds->getURL();
print "The URL is $url\n";

my $dbh;

if (defined($username) && defined($password)) {
    $dbh = $ds->getConnection(username => $username, password => $password);
} else {
    $dbh = $ds->getConnection();
}

if (defined($dbh)) {
    print "\tCONNECT OK\n";

    print "\thostname = ", $ds->getAttribute("serverName"),"\n";
    print "\tport     = ", $ds->getAttribute("port"),"\n";
    print "\tdatabase = ", $ds->getAttribute("databaseName"),"\n";
    print "\tusername = ", $ds->getAttribute("user"),"\n";
    print "\tpassword = ", $ds->getAttribute("password"),"\n";

    my $sth = $dbh->prepare("select user(),connection_id()");

    $sth->execute();

    my ($user,$connid) = $sth->fetchrow_array();

    $sth->finish();

    print "\tUSER: $user\n\tCONNECTION ID: $connid\n";

    $dbh->disconnect;
} else {
    print "\tCONNECT FAILED:";
    print " (with username=\"$username\" and password=\"$password\")"
	if (defined($username) && defined($password));
    print " : $DBI::errstr\n";
}

exit(0);
