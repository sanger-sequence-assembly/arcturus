#!/usr/local/bin/perl

use strict;

use Socket;
use Net::LDAP;

my $name = shift @ARGV || "ldap.internal.sanger.ac.uk";

print "Testing $name\n";

my ($hostname, $aliases, $addrtype, $infolength, @addrs)= gethostbyname($name);

foreach my $addr (@addrs) {
    my $url = inet_ntoa($addr);
    
    print $url," : ";

    my $ldap = Net::LDAP->new($url);
    
    print defined($ldap) ? " OK" : " $@";
    
    print "\n";
}

exit(0);

