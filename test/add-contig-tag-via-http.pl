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


use strict;

use LWP;

my $nextword;
my $instance;
my $organism;
my $host;
my $port;
my $depadded = 0;

my $verbose = 0;

my $contig_id;
my $tagtype;
my $systematic_id;
my $cstart;
my $cfinal;
my $strand;

while ($nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $host          = shift @ARGV if ($nextword eq '-host');
    $port          = shift @ARGV if ($nextword eq '-port');

    $verbose       = 1 if ($nextword eq '-verbose');
    $depadded      = 1 if ($nextword eq '-depadded');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($host)
	&& defined($port)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $api_key = $ENV{'ARCTURUS_API_KEY'};

die "You must set the environment variable ARCTURUS_API_KEY to your API key"
    unless defined($api_key);

my $browser = LWP::UserAgent->new;

my $url = "http://$host:$port/$instance/$organism/tag_mappings";

print STDERR "URL: $url\n";

while (my $line = <STDIN>) {
    chop $line;

    my ($contig_id,$tagtype,$systematic_id,$cstart,$cfinal,$strand) = split(/,/, $line);

    my $parameters = [
		      'api_key' => $api_key,
		      'contig_id' => $contig_id,
		      'tag_mapping[cstart]' => $cstart,
		      'tag_mapping[cfinal]' => $cfinal,
		      'tag_mapping[strand]' => $strand,
		      'contig_tag[tagtype]' => $tagtype,
		      'contig_tag[systematic_id]' => $systematic_id
		      ];

    push @{$parameters}, 'depadded' => 1 if $depadded;

    my $response = $browser->post($url, Accept => 'text/xml', Content => $parameters);

    die "Error processing tag $systematic_id (contig $contig_id $cstart:$cfinal) : " . $response->status_line
	unless $response->is_success;

    print STDERR "Tag $systematic_id (contig $contig_id $cstart:$cfinal) added OK\n" if $verbose;
}

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";

    print STDERR "\n";

    print STDERR "-host\t\t\tHostname of web service\n";
    print STDERR "-port\t\t\tPort number of web service\n";

    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-depadded\t\tTag positions are on depadded sequences\n";
    print STDERR "-verbose\t\tReport progress on stderr\n";
}
