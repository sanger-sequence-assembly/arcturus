#!/usr/local/bin/perl

use ReadFactory::TraceServerReadFactory;
use strict;

print STDERR "Creating TraceServerReadFactory ...\n";

my $factory = new TraceServerReadFactory(@ARGV);

print STDERR "Done\n";

my $nreads = 0;

while (my $readname = $factory->getNextReadName()) {
    my $read = $factory->getNextRead();
    print STDERR "$readname\n";
    $read->dump();
    print STDERR "\n";
    $nreads++;
}

print STDERR "Processed $nreads reads.\n";

exit(0);
