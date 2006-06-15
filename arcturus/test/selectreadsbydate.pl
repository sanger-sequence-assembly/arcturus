#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance = 'dev';
my $organism;
my $aspedbefore;
my $aspedafter;
my $qualitymask;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $aspedbefore = shift @ARGV if ($nextword eq '-aspedbefore');
    $aspedafter = shift @ARGV if ($nextword eq '-aspedafter');
    $qualitymask = 1 if ($nextword eq '-qualitymask');
}

die "No organism specified" unless defined($organism);
die "No cutoff date specified" unless (defined($aspedbefore) ||
				       defined($aspedafter));

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $reads;

my @params;


push @params, '-aspedbefore', $aspedbefore if defined($aspedbefore);
push @params, '-aspedafter', $aspedafter if defined($aspedafter);

$reads = $adb->getReadsByAspedDate(@params);

if (defined($reads)) {
    print STDERR "There are ",scalar(@{$reads})," reads\n";
}

my $stdout = new FileHandle('>&STDOUT');

my @params = ();

push @params, "qualitymask", "X" if $qualitymask;

foreach my $read (@{$reads}) {
    $read->writeToCaf($stdout, @params);
}

exit(0);
