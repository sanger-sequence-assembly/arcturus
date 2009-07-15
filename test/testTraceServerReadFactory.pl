#!/usr/local/bin/perl

use strict;

use FileHandle;
use ReadFactory::TraceServerReadFactory;

print STDERR "Creating TraceServerReadFactory ...\n";

my $factory = new TraceServerReadFactory(@ARGV);

print STDERR "Done\n";

my $nreads = 0;

while (my $readname = $factory->getNextReadName()) {
    my $read = $factory->getNextRead();
    print STDERR "$readname\n";
    $read->writeToCaf(*STDOUT);
    print STDERR "\n";
    $nreads++;
}

print STDERR "Processed $nreads reads.\n";

exit(0);
