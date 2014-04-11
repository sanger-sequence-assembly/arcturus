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


$fastafile = shift;

die "No FASTA file specified" unless $fastafile;

die "File $fastafile does not exist" unless -f $fastafile;

die "Unable to open file $fastafile" unless open(FASTA, $fastafile);

while ($line = <FASTA>) {
    chop($line);

    if ($line =~ /^>(\S+)/) {
	$seqname = $1;
	$sequence{$lastname} = $seq if defined($lastname);
	$seq = '';
	$lastname = $seqname;
    } else {
	$line =~ s/[^ACGTNacgtn]//g;
	$seq .= $line;
    }
}

$sequence{$lastname} = $seq if defined($lastname);

close(FASTA);

$seqnum = 0;

while ($line = <STDIN>) {
    ($seqname, $start, $seqlen) = $line =~ /^(\S+)\s+(\d+)\s+(\d+)/;

    $seq = $sequence{$seqname};

    next unless defined($seq);

    $repname = "$seqname-$start-$seqlen";

    $subseq = substr($seq, $start-1, $seqlen);

    print ">$repname\n";

    for ($j = 0; $j < length($subseq); $j += 50) {
	print substr($subseq, $j, 50),"\n";
    }
}

exit(0);
