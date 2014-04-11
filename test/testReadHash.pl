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


my %projectreadhash;

$projectreadhash{"Chr1"}{"SMIO719.q1k"} = "SMI0719.q1k";
$projectreadhash{"Chr2"}{"SMEE821.q1k"} = "SMEE821.q1k";
$projectreadhash{"Chr1"}{"SMIO999.p1k"} = "SMI0999.p1k";

print &printprojectreadhash();

#-------------------------------------------------------------------------------

sub printprojectreadhash {
# returns a message to warn the user before aborting the import

    my $message = "The import has NOT been started because some reads in the import file you are using already exist in other projects:\n";

    while (my ($project, $reads) = each %projectreadhash) {
    # each line has project -> (readname -> contig)*
      $message = $message."\nproject $project already holds: \n";
      while (my ($readname, $contigid) = each (%$reads)) {
        $message = $message."\tread $readname in contig $contigid\n";
      }
    }

    $message .= "\nThe import has NOT been started because some reads in the input file you are using already exist in these projects:\n";

    while (my ($project, $reads) = each %projectreadhash) {
			#my $readcount = map {$reads{$_} !~ /^$/;} keys(%$reads);
			#my $readcount = grep {$reads{$_} ne " "} keys(%$reads);
			my $readcount = scalar keys(%$reads);
			$message .= "\tproject $project has $readcount reads\n";
		}

    $message .= "\nThe import has NOT been started because some reads in the input file you are using already exist in the above projects\n";

	return $message;
}

