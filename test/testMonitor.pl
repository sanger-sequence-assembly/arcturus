#!/usr/local/bin/perl

use strict;

use Linux::Monitor;

my $pid = shift;

my $monitor = new Linux::Monitor($pid);

my $stathash = $monitor->getStat();

die "getStat returned null" unless defined($stathash);

print "STAT\n\n";

foreach my $key (sort keys %{$stathash}) {
    my $val = $stathash->{$key};
    printf "%-20s %s\n", $key, $val;
}

$stathash = $monitor->getStatm();

die "getStatm returned null" unless defined($stathash);

print "\nSTATM\n\n";

foreach my $key (sort keys %{$stathash}) {
    my $val = $stathash->{$key};
    printf "%-20s %s\n", $key, $val;
}

exit(0);
