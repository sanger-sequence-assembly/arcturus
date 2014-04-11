#!/usr/local/bin/perl -w

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


my $count = 1;

	while (my $line = <STDIN>) {
    #if ($line =~ /^\s*\d+\s+\d+\.\d+\s+\S+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+/) {
    # works if ($line =~ /^\s*\d/) {
    #  ($line =~ /^\s*\d+\s+\d+\.\d+/) {
    #if ($line =~ /^\s*\d+\s+\d+\.\d+\s+\S+\s+\S+\s+\d+\s+\d+/) {
    if ($line =~ /^\s*\d+\s+\d+\.\d+\s+\S+\s+\S+\s+\d+\s+\d+\s+\d+\s+\S+\s+\S+\s+\d+\s+\d+\s+\d+/) {
    # matches file format is  "%6d %4.2f %1s %-20s %6d %6d %6d   %1s %-20s %6d %6d %6d\n"
			print STDOUT "Line $count is valid\n";
		}
		else {
			print STDOUT "Line $count is invalid\n";
		}
		$count++;
	}
