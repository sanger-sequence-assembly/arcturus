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

my $host;
my $port;
my $username;
my $password;
my $since;
my $hideidle = 0;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
    } elsif ($nextword eq '-since') {
	$since = shift;
    } elsif ($nextword eq '-hideidle') {
	$hideidle = 1;
    } elsif ($nextword eq '-help') {
	&showHelp();
	exit(0);
    } else {
	die "Unknown option: $nextword";
    }
}

$username = $ENV{'MYSQL_USERNAME'} unless defined($username);
$password = $ENV{'MYSQL_PASSWORD'} unless defined($password);

unless (defined($host) && defined($port) &&
	defined($username) && defined($password)) {
    &showHelp("One or more mandatory options were missing");
    exit(1);
}

$since = 28 unless (defined($since) && $since =~ /^\d+$/);

my $dbname = 'arcturus';

my $url = "DBI:mysql:$dbname;host=$host;port=$port";

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 0});

my $query = 'select table_schema from information_schema.tables where table_name = ?'
    . ' order by table_schema asc';

my $sth = $dbh->prepare($query);

$sth->execute('CONTIG');

my @dblist;

while (my ($schema) = $sth->fetchrow_array()) {
    push @dblist, $schema;
}

$sth->finish();

printf "%-20s %20s  %10s %10s %10s %10s\n", 'SCHEMA', 'UPDATED', 'IMPORTS', 'CONTIGS', 'READS', 'SEQLEN';

foreach my $schema (@dblist) {
		#print STDERR "Looking at schema $schema\n";
    $query = "select max(created) from " . $schema . ".CONTIG";

    $sth = $dbh->prepare($query);
    $sth->execute();
    my ($created) = $sth->fetchrow_array();
    $sth->finish();

    $created = "0000-00-00 00:00:00" unless defined($created);

    $query = "select count(*) from $schema.IMPORTEXPORT where action = ? and starttime > date_sub(now(), interval $since day)";

    $sth = $dbh->prepare($query);
    $sth->execute('import');
    my ($imports) = $sth->fetchrow_array();
    $sth->finish();

    $query = "select count(*),sum(nreads),sum(length) from " . $schema . ".CONTIG" .
	" where created > date_sub(now(), interval $since day)";

    $sth = $dbh->prepare($query);
    $sth->execute();
    my ($ncontigs,$nreads,$totlen) = $sth->fetchrow_array();
    $sth->finish();

    next if ($hideidle && $imports == 0 && $ncontigs == 0);

    printf "%-20s %20s  %10d %10d %10d %10d\n", $schema, $created, $imports, $ncontigs, $nreads, $totlen;
}

$dbh->disconnect();

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-username\tUsername to connect to server (overrides ENV\{MYSQL_USERNAME\})\n";
    print STDERR "\t-password\tPassword to connect to server (overrides ENV\{MYSQL_PASSWORD\})\n";

    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";

    print STDERR "\t-since\t\tNumber of days before present for import summary [default: 28]\n";
    print STDERR "\t-hideidle\tShow only the projects that have been active recently\n";
}
