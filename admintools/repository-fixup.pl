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
use OORepository;

my $host;
my $port;
my $username;
my $password;
my $verbose = 0;
my $fixit = 0;
my $databases;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
    } elsif ($nextword eq '-databases') {
	$databases = shift @ARGV;
    } elsif ($nextword eq '-verbose') {
	$verbose = 1;
    } elsif ($nextword eq '-fixit') {
	$fixit = 1;
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

my $url = "DBI:mysql:arcturus;host=$host;port=$port";

eval {
    my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 1});

    my $repos = new OORepository;

    my @dblist;

    if (defined($databases)) {
	@dblist = split(/,/, $databases);
    } else {
	print STDERR "Enumerating assembly databases ...";

	my $sth = $dbh->prepare("select table_schema from information_schema.tables where table_name='PROJECT'" .
			    " order by table_schema asc");

	$sth->execute();

	while (my ($dbname) = $sth->fetchrow_array()) {
	    push @dblist, $dbname;
	}

	$sth->finish();

	print STDERR " done.  Found " . scalar(@dblist) . ".\n";
    }

    my $sth_set_directory = $dbh->prepare("update PROJECT set directory = ? where project_id = ?");

    foreach my $dbname (@dblist) {
	print "\n===== Fixing database $dbname =====\n";

	$dbh->do("use $dbname");

	my $sth = $dbh->prepare("select project_id,P.name,A.name,directory from PROJECT P left join ASSEMBLY A using (assembly_id)" .
				" where directory is not null");

	$sth->execute();

	while (my ($projid, $pname, $aname, $pdir) =  $sth->fetchrow_array()) {
	    my $prefix = undef;

	    print "Directory for $aname/$pname (ID=$projid) is $pdir in Arcturus\n";

	    if ($pdir =~ /^:([\w\-]+):/) {
		print "\tAlready a meta-directory\n\n";
		next;
	    }

	    my $rdir = &getRepositoryName($repos, $pname);

	    $prefix = ":PROJECT:" if defined($rdir);

	    if (!defined($rdir)) {
		$rdir = &getRepositoryName($repos, $aname);
		$prefix = ":ASSEMBLY:" if defined($rdir);
	    }

	    if (defined($rdir)) {
		if ($pdir =~ /^$rdir/) {
		    $pdir =~ s/^$rdir/$prefix/;

		    print "\tMeta-directory is $pdir\n";

		    if ($fixit) {
			my $rc = $sth_set_directory->execute($pdir, $projid);

			print "\tDirectory has been converted to $rdir in Arcturus.\n";
		    } else {
			print "\tRe-run this script with the -fixit option to convert to meta-directory.\n";
		    }
		} else {
		    print "\t***** Cannot infer meta-directory *****\n";
		}
	    }

	    print "\n";
	}

	$sth->finish();
    }

    $sth_set_directory->finish();

    $dbh->disconnect();
};
if ($@) {
    print STDERR "Something bad happened: $@\n";
}

exit(0);

sub getRepositoryName {
    my $repos = shift;
    my $name = shift;

    $repos->get_online_path_from_project($name);

    my $path = $repos->{online_path};

    return $path if defined($path);

    # Try lowercase version of name

    $repos->get_online_path_from_project(lc($name));

    return $repos->{online_path};
}

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tMySQL server hostname\n";
    print STDERR "\t-port\t\tMySQL server port number\n";
    print STDERR "\t-username\tMySQL username [or set MYSQL_USERNAME]\n";
    print STDERR "\t-password\tMySQL password [or set MYSQL_PASSWORD]\n";

    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\t-databases\tAnalyse/fix only these databases\n";
    print STDERR "\t-fixit\t\tFix all incorrect directory locations\n";
    print STDERR "\t-verbose\tRun in verbose mode\n";
}
