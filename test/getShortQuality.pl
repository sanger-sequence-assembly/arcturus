#!/usr/local/bin/perl5.8.0

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

use Compress::Zlib;

use ArcturusDatabase;
use DBI;

my $nextword;
my $instance;
my $organism;
my $maxlen = 32;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $maxlen = shift @ARGV if ($nextword eq '-maxlen');
}

die "You must specify the instance and organism"
    unless (defined($organism) && defined($instance));

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

my $dbh = $adb->getConnection();

&getShorties($dbh, $maxlen);

$dbh->disconnect();

exit(0);

sub getShorties {
    my $dbh = shift;
    my $maxlen = shift;

    my $query = "select QUALITYCLIP.seq_id,qleft,qright,quality" .
	" from QUALITYCLIP left join SEQUENCE using(seq_id)" .
	" where qright-qleft <= $maxlen and quality is not null" ;

    my $sth = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    $sth->execute();
    &db_die("Failed to execute query \"$query\"");

    while (my ($seqid, $qleft, $qright, $quality_c) = $sth->fetchrow_array()) {
	if (defined($quality_c)) {
	    my $quality = uncompress($quality_c);
	    
	    my @qualarray_c = map { $_ < 0 ? 256+$_ : $_ } unpack("c*", substr($quality, $qleft-1, $qright-$qleft+1));

	    print $seqid,": ",join(' ',@qualarray_c),"\n";	    
	} else {
	    print STDERR "  --- Quality was null for sequence $seqid ---\n";
	}
    }
    
    $sth->finish();
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}
