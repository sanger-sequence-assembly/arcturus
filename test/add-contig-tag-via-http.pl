#!/usr/local/bin/perl

use strict;

use LWP;

my $nextword;
my $instance;
my $organism;
my $contig_id;
my $tagtype;
my $systematic_id;
my $cstart;
my $cfinal;
my $strand;

while ($nextword = shift @ARGV) {
    $instance      = shift @ARGV if ($nextword eq '-instance');
    $organism      = shift @ARGV if ($nextword eq '-organism');

    $contig_id     = shift @ARGV if ($nextword eq '-contig_id');
    $tagtype       = shift @ARGV if ($nextword eq '-tagtype');
    $systematic_id = shift @ARGV if ($nextword eq '-systematic_id');
    $cstart        = shift @ARGV if ($nextword eq '-cstart');
    $cfinal        = shift @ARGV if ($nextword eq '-cfinal');
    $strand        = shift @ARGV if ($nextword eq '-strand');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($instance) && defined($organism) && defined($contig_id)
	&& defined($tagtype) && defined($systematic_id) && defined($cstart)
	&& defined($cfinal) && defined($strand)) {
    &showUsage("One or more mandatory parameters missing");
    exit(1);
}

my $browser = LWP::UserAgent->new;

my $url = "http://psd-dev.internal.sanger.ac.uk:15005/$instance/$organism/tag_mappings/create";

my $parameters = [
		  'contig_id' => $contig_id,
		  'tag_mapping[cstart]' => $cstart,
		  'tag_mapping[cfinal]' => $cfinal,
		  'tag_mapping[strand]' => $strand,
		  'contig_tag[tagtype]' => $tagtype,
		  'contig_tag[systematic_id]' => $systematic_id
		  ];

my $response = $browser->post($url, Accept => 'text/xml', Content => $parameters);

die "Error: ", $response->status_line
    unless $response->is_success;

print $response->content;

exit(0);

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\t\tName of instance\n";
    print STDERR "-organism\t\tName of organism\n";

    print STDERR "\n";

    print STDERR "-contig_id\t\tID of the contig\n";
    print STDERR "-tagtype\t\tTag type\n";
    print STDERR "-systematic_id\t\tSystematic ID of the tag\n";
    print STDERR "-cstart\t\t\tStart position of the tag on the contig\n";
    print STDERR "-cfinal\t\t\tEnd position of the tag on the contig\n";
    print STDERR "-strand\t\t\tStrand on which the tag lies [F,R or U]\n";
}
