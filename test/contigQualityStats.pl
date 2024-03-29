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

#
# contigQualityStats
#
# This script analyses the quality stats for one or more contigs

use strict;

use DBI;
use DataSource;
use Compress::Zlib;
use FileHandle;

my $verbose = 0;
my @dblist = ();

my $instance;
my $organism;
my $minlen;
my $contigids;
my $allcontigs = 0;
my $pinclude;
my $pexclude;
my $percontig = 0;
my $usegap4name = 0;
my $rawfilename;
my $showpadrate = 0;
my $depad = 0;
my $projects;

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');

    $contigids = shift @ARGV if ($nextword eq '-contigs');

    $allcontigs = 1 if ($nextword eq '-allcontigs');

    $pinclude = shift @ARGV if ($nextword eq '-include');

    $pexclude = shift @ARGV if ($nextword eq '-exclude');

    $percontig = 1 if ($nextword eq '-percontig');

    $usegap4name = 1 if ($nextword eq '-usegap4name');

    $rawfilename = shift @ARGV if ($nextword eq '-raw');

    $showpadrate = 1 if ($nextword eq '-showpadrate');

    $depad = 1 if ($nextword eq '-depad');

    $projects = shift @ARGV if ($nextword eq '-projects');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) &&
	defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select project_id,name from PROJECT";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

my $projectname2id;

while (my ($projid,$projname) = $sth->fetchrow_array()) {
    $projectname2id->{$projname} = $projid;
}

$sth->finish();

$pinclude = &getProjectIDs($pinclude, $projectname2id) if defined($pinclude);
$pexclude = &getProjectIDs($pexclude, $projectname2id) if defined($pexclude);

$minlen = 1000 unless (defined($minlen) || defined($contigids));

if (defined($contigids)) {
    $query = "select gap4name,contig_id,length from CONTIG where contig_id in ($contigids)";
} elsif ($allcontigs) {
    $query = "select gap4name,contig_id,length from CONTIG";
    $query .= " where length > $minlen" if defined($minlen);
} else {
    $query = "select gap4name,contig_id,length from CURRENTCONTIGS";

    my @conditions = ();

    if (defined($projects)) {
	$query .= " left join PROJECT using(project_id)";

	my @plist;

	foreach my $pname (split(/,/, $projects)) {
	    push @plist, "'" . $pname . "'";
	}

	push @conditions, "name in (" . join(",", @plist) . ")";
    }

    push @conditions, "length > $minlen" if defined($minlen);

    push @conditions, "project_id in ($pinclude)" if defined($pinclude);

    push @conditions, "project_id not in ($pexclude)" if defined($pexclude);

    $query .= " where " . join(" and ", @conditions) if (@conditions);
}

print STDERR $query,"\n" if $verbose;

$sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

$query = "select sequence,quality from CONSENSUS where contig_id = ?";

my $sth_sequence = $dbh->prepare($query);
&db_die("prepare($query) failed");

my $rawfh;

$rawfh = new FileHandle($rawfilename, "w") if defined($rawfilename);

my $qstats = {};
my $cqstats;

while(my @ary = $sth->fetchrow_array()) {
    my ($gap4name, $contigid, $contiglength) = @ary;

    $sth_sequence->execute($contigid);

    my ($compressedsequence, $compressedquality) = $sth_sequence->fetchrow_array();

    $sth_sequence->finish();

    next unless (defined($compressedsequence) && defined($compressedquality));

    my $sequence = uc(uncompress($compressedsequence));
	
    my $quality = uncompress($compressedquality);
	
    my $slen = length($sequence);
    my $qlen = length($quality);
	
    my @qdata = unpack("c*", $quality);
    my @cdata = unpack("c*", $sequence);

    if ($contiglength != $slen) {
	print STDERR "Sequence length mismatch for contig $contigid: $contiglength vs $slen\n";
	next;
    }

    if ($contiglength != $qlen) {
	print STDERR "Quality length mismatch for contig $contigid: $contiglength vs $qlen\n";
	next;
    }

    my $contigname = $usegap4name ? $gap4name : sprintf("contig%06d", $contigid);

    $cqstats = {} if $percontig;

    while (my $base = shift(@cdata)) {
	my $qual = shift(@qdata);

	unless ($depad && uc($base) eq 'N') {
	    &registerBaseAndQuality($base, $qual, $qstats);

	    &registerBaseAndQuality($base, $qual, $cqstats) if $percontig;

	    print $rawfh chr($base)," ",$qual,"\n" if defined($rawfh);
	}
    }

    &reportStats($contigname, $cqstats, $showpadrate) if $percontig;
}

$rawfh->close() if defined($rawfh);

&reportStats("ALL CONTIGS", $qstats, $showpadrate);

$sth->finish();

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub registerBaseAndQuality {
    my ($base, $qual, $hash, $junk) = @_;

    $hash->{$base} = {} unless defined($hash->{$base});

    $hash->{$base}->{$qual} = 0 unless defined($hash->{$base}->{$qual});

    $hash->{$base}->{$qual} += 1;
}

sub reportStats {
    my ($name, $hash, $showpadrate, $junk) = @_;
    my $padcount = 0;
    my $nonpadcount = 0;
    my $allbases = {};

    foreach my $basecode (sort numeric keys(%{$hash})) {
	my $base = chr($basecode);

	my $sum = 0;
	my $sumsq = 0;
	my $n = 0;

	foreach my $qual (sort numeric keys(%{$hash->{$basecode}})) {
	    my $qualcount = $hash->{$basecode}->{$qual};

	    $allbases->{$qual} = 0 unless defined($allbases->{$qual});

	    $allbases->{$qual} += $qualcount;

	    printf "#%-20s %s %3d %8d\n", $name, $base, $qual, $qualcount;

	    $sum += $qualcount * $qual;
	    $sumsq += $qualcount * $qual * $qual;
	    $n += $qualcount;
	}

	my $avg = $sum/$n;
	my $rms = sqrt($sumsq/$n - $avg * $avg);

	printf "%-20s %s %8d %4.1f %4.1f\n", $name, $base, $n, $avg, $rms;

	if ($base eq 'N') {
	    $padcount = $n;
	} else {
	    $nonpadcount += $n;
	}
    }

    my $base = '*';

    foreach my $qual (sort numeric keys(%{$allbases})) {
	my $qualcount = $allbases->{$qual};
	printf "#%-20s %s %3d %8d\n", $name, $base, $qual, $qualcount;
    }

    if ($showpadrate) {
	my $padrate = ($padcount > 0) ? sprintf("%.2lf", $nonpadcount/$padcount) : "INFINITY";
	printf "%-20s PAD RATE = %s\n", $name, $padrate;
    }
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance [default: prod]\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minlen\t\tMinimum length for contigs [default: 1000]\n";
    print STDERR "    -contigs\t\tComma-separated list of contig IDs [implies -minlen 0]\n";
    print STDERR "    -allcontigs\t\tSelect all contigs, not just from current set\n";
    print STDERR "    -include\t\tInclude contigs in these projects\n";
    print STDERR "    -exclude\t\tExclude contigs in these projects\n";
    print STDERR "    -percontig\t\tDisplay statistics per contig\n";
    print STDERR "    -usegap4name\tUse Gap4 names for contigs\n";
    print STDERR "    -showpadrate\tShow the pad rate i.e. ratio non-pads:pads\n";
}

sub numeric($$) {
    my ($a, $b) = @_;

    $a <=> $b;
}

sub getProjectIDs {
    my $pnames = shift;
    my $name2id = shift;

    my @projects = split(/,/, $pnames);

    my @projectids;

    foreach my $pname (@projects) {
	my $pid = $name2id->{$pname};
	if (defined($pid)) {
	    push @projectids, $pid;
	} else {
	    print STDERR "Unknown project name: $pname\n";
	}
    }

    my $projectlist = join(',', @projectids);

    return $projectlist;
}
