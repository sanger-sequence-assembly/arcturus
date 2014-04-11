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


use DataSource;
use DBI;
use Compress::Zlib;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');

    $organism = shift @ARGV if ($nextword eq '-organism');
}

$debug = 0 unless defined($debug);

die "You must specify the organism" unless defined($organism);

$instance = 'prod' unless defined($instance);
$schema = $organism unless defined($schema);

$mysqlds = new DataSource(-instance => $instance,
			  -organism => $organism);

$url = $mysqlds->getURL();
print STDERR "The MySQL URL is $url\n";

$dbh = $mysqlds->getConnection();

unless (defined($dbh)) {
    print STDERR "MySQL: CONNECT FAILED: $DBI::errstr\n";
    exit(1);
}

$query = "update TEMPLATE set forward=0,reverse=0";
$sth = $dbh->prepare($query);
$sth->execute();

$query = "select template_id,STRANDS.direction from READINFO left join STRANDS" .
    " using (strand) where pstatus=0";

$sth = $dbh->prepare($query);
$sth->execute();

$fwdquery = "update TEMPLATE set forward=forward+1 where template_id=?";
$fwdsth = $dbh->prepare($fwdquery);

$revquery = "update TEMPLATE set reverse=reverse+1 where template_id=?";
$revsth = $dbh->prepare($revquery);

$fwdcount = 0;
$revcount = 0;
$badcount = 0;
$count = 0;

$fmt = "%8d %8d %8d";

$eight = "\010\010\010\010\010\010\010\010";
$bs = "\010";
$format = $eight . $bs . $eight . $bs . $eight . $fmt;

printf STDERR $fmt, $fwdcount, $revcount, $badcount;

while (@ary = $sth->fetchrow_array()) {
    ($template_id, $direction) = @ary;

    if ($direction eq 'forward') {
	$fwdsth->execute($template_id);
	$fwdcount++;
    } elsif ($direction eq 'reverse') {
	$revsth->execute($template_id);
	$revcount++;
    } else {
	$badcount++;
    }

    $count++;

    printf STDERR $format,  $fwdcount, $revcount, $badcount
	if (($count % 50) == 0);
}

printf STDERR $format,  $fwdcount, $revcount, $badcount;
print STDERR "\n";

$sth->finish();
$fwdsth->finish();
$revsth->finish();

$dbh->disconnect();

exit(0);
