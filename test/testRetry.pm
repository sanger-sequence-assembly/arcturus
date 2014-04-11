#!/user/local/bin/perl5

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


# shisto 1 fails on both
# shisto 2 imports the read mapping but fails on the contig mapping
# shisto 3 imports successfully

@contigs = ("shisto1", "shisto2", "shisto3");

foreach $contig (@contigs) {
	print "\nStarting work on contig $contig\n";
	print "\tMaking a savepoint before starting read mappings\n";
  print "\tSTART TRANSACTION: insert metatdata for  $contig\n";
	if (putMappingsForContig($contig, "read")) {
	  if (putMappingsForContig($contig, "contig")) {
		  print "\tSuccessfully imported $contig\n";
		}
		else {
		  # have done the read mapping but unable to do the contig mapping after three retries 
		  print "\tReverting to savepoint to skip import of $contig\n";
		}
	}
	else {
		# unable to do the read mapping after three retries 
		print "\tReverting to savepoint to skip import of $contig\n";
		next;
	}
	print "\tEND TRANSACTION\n";
}

print "\nRaised RT ticket to list contig(s) not imported\n";

exit;

sub putMappingsForContig {
  my $contig = shift;
  my $option = shift;

#$retry_in_secs = 1 * 60;
# for testing, use one hundreth of real values

$retry_in_secs = 0.01 * 60;
$retry_counter = 0.25;
$counter = 1;
$max_retries = 4;

  if ($contig eq "shisto3") {return 1};

  while ($counter < ($max_retries + 1)) {
    $retry_counter = $retry_counter * 4;
		# to mimic that the insert succeeds
		# until ({$counter > 4}) {
      print "\tAttempt $counter for the insert statement for $option mapping for contig $contig\n";
      if ($contig eq "shisto2" && $counter == 3 && $option eq "read") {return 1};
      # Execute the statement
      $retry_in_secs = $retry_in_secs * $retry_counter;
			if ($counter < $max_retries) {
        print "\tStatement has failed so wait for $retry_in_secs seconds\n"; 
        sleep($retry_in_secs);
			}
			$counter++;
		#}
  }
  print "\tStatement has failed $counter times so give up:  some other process has locked $contig\n";
  return 0;
}

