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
use DBI;

use constant DEFAULT_URL => 'ldap.internal.sanger.ac.uk';
use constant DEFAULT_BASE => 'cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk';

while ($nextword = shift @ARGV) {
    $url = shift @ARGV if ($nextword eq '-url');

    $base = shift @ARGV if ($nextword eq '-base');

    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');

    $listall = 1 if ($nextword eq '-listall');

    $verbose = 1 if ($nextword eq '-verbose');

    $showurl = 1 if ($nextword eq '-showurl');

    $testurl = 1 if ($nextword eq '-testurl');

    if ($nextword eq '-help') {
	&showHelp();
	exit 0;
    }
}

$url = DEFAULT_URL unless defined($url);

$base = DEFAULT_BASE unless defined($base);

$base = "cn=$instance," . $base if defined($instance);

$listall = 1 unless defined($organism);

if ($listall) {
    $filter = 'objectClass=javaNamingReference';
} else {
    $filter = "&(objectClass=javaNamingReference)(cn=$organism)";
}

$ldap = Net::LDAP->new($url) or die "$@";
 
$mesg = $ldap->bind ;    # an anonymous bind
 
$mesg = $ldap->search( # perform a search
		       base   => $base,
		       scope => 'sub',
		       deref => 'always',
		       filter => "($filter)"
		       );
 
$mesg->code && die $mesg->error;
 
foreach $entry ($mesg->all_entries) {
    #$entry->dump;
    $dn = $entry->dn;
    @items = $entry->get_value('javaClassName');
    $classname = shift @items;
    @items = $entry->get_value('javaFactory');
    $factory = shift @items;
    @items = $entry->get_value('javaReferenceAddress');

    print "$dn\n";

    if ($verbose) {
	print "    ClassName=$classname\n" if defined($classname);
	print "    Factory=$factory\n" if defined($factory);
    }

    @datasourcelist = split(/\./, $classname);

    $datasourcetype = pop @datasourcelist;

    $datasource = {};

    while ($item = shift @items) {
	($id,$key,$value) = $item =~ /\#(\d+)\#(\w+)\#(\w+)/;
	$datasource->{$key} = $value;
	print "        $key=$value\n" if $verbose;
    }

    if (($testurl || $showurl) && defined($datasourcetype)) {
	($url, $username, $password) = &buildUrl($datasourcetype, $datasource);
	if (defined($url)) {
	    print "        URL=$url\n";
	    if ($testurl) {
		$dbh = DBI->connect($url, $username, $password, {RaiseError => 0, PrintError => 0});
		if (defined($dbh)) {
		    print "        CONNECT OK\n";
		} else {
		    print "        CONNECT FAILED: : $DBI::errstr\n";
		}
		$dbh->disconnect if defined($dbh);
	    }
	} else {
	    print "        Unable to build URL\n";
	}
    }

    print "\n";
}

$mesg = $ldap->unbind;   # take down session

exit(0);

sub buildUrl {
    my ($dstype, $dshash, $junk) = @_;

    return buildMySQLUrl($dshash) if ($dstype =~ /mysqldatasource/i);

    return buildOracleUrl($dshash) if ($dstype =~ /oracledatasource/i);

    return undef;
}

sub buildMySQLUrl {
    my $dshash = shift;

    my $username = $dshash->{'user'};
    my $password = $dshash->{'password'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'port'};

    my $database = $dshash->{'databaseName'};

    return ("DBI:mysql:$database:$hostname:$portnumber", $username, $password);
}

sub buildOracleUrl {
    my $dshash = shift;

    my $username = $dshash->{'userName'};
    my $password = $dshash->{'passWord'};

    my $hostname = $dshash->{'serverName'};
    my $portnumber = $dshash->{'portNumber'};

    my $database = $dshash->{'databaseName'};

    my $url = "DBI:Oracle:host=$hostname;port=$portnumber;sid=$database";

    return ($url, $username, $password);
}

sub showHelp {
    my @message = (
	"OPTIONS",
	"\t-url\t\tURL of the LDAP server\n\t\t\t[default: " . DEFAULT_URL . "]",
	"\t-base\t\tBase of the LDAP tree to scan\n\t\t\t[default: " . DEFAULT_BASE . "]",
	"",
	"\t-instance\tName of the Arcturus instance",
	"\t-organism\tName of the Arcturus organism",
	"",
	"\t-showurl\tDisplay the database connection URL",
	"\t-testurl\tTest the database connection URL",
	"",
	"\t-listall\tList all of the database connections within the tree",
	"\t-verbose\tMore detailed output"
	);

    foreach my $line (@message) {
	print STDERR $line,"\n";
    }
}
