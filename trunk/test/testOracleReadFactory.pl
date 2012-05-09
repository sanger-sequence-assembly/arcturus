#!/usr/local/bin/perl

use OracleReadFactory;

print STDERR "Creating OracleReadFactory ...\n";

$orf = new OracleReadFactory(@ARGV);

#$orf = new OracleReadFactory(schema => 'SHISTO',
#			     readnamelike => 'shisto8407%',
#			     aspedafter => '15-mar-04');

print STDERR "Done\n";

$nreads = 0;

while ($readname = $orf->getNextReadName()) {
    $read = $orf->getNextRead();
    $read->setReadName($readname);
    print STDERR "$readname\n";
    $read->dump();
    print STDERR "\n";
    $nreads++;
}

$orf->close();

print STDERR "Processed $nreads reads.\n";

exit(0);
