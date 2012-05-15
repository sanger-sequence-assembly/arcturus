use strict;

my $min = 15;
my $max = 1000;
my $sequence_length = 0;

while (<STDIN>)
{
	if (/\>(.*)/) {
			print "$sequence_length\n"  if (($sequence_length >= $min) && ($sequence_length <= $max)) ;
			$sequence_length = 0;
	}
	elsif ((/\s*[atcgn]+$/) || (/\s*[ATCGN]+$/)) {
		$sequence_length = $sequence_length + length $_;
	}
	else {
   	print "This is not a valid fasta line:\n $_\n" 
	}
}

