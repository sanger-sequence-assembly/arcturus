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


my @array = (
	["apple"], 
	["banana, berry"], 
	["carrot"], 
	["date, dough"],
	["egg"]);

my $csvfile = "kate.csv";

print "Array holds: @array\n";
my $status = printCSV($csvfile, \@array);
exit($status);

sub printCSV {
	my ($csvfile, $csvlines) = @_;

	my $csvlinesref = ref($csvlines);
	my $ret;

	unless ($csvlinesref eq 'ARRAY') {
		$ret = -1;
	}

  print "Filename passed in holds: $csvfile\n";
  print "Array passed in holds: @$csvlines\n";

	open($csvhandle, "> $csvfile") or die "Cannot open filehandle to $csvfile : $!";

	foreach my $csvline (@{$csvlines}){
print "line $i is *@$csvline* \n";

	foreach my $csvitem (@{$csvline}){
			print $csvhandle "$csvitem,";
		}
		$i++;
		print $csvhandle "@$csvline[$i]\n";
	}

	$ret = close $csvhandle;
	return $ret;
	}

