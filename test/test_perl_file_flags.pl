#!/usr/bin/perl -w

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
use warnings;
use Getopt::Long;
use File::Basename;
use File::Compare;
use POSIX;
use Fcntl qw(:flock);
 
#system('touch file_no_lines.txt') or die "Cannot create test file with no lines\n";

my $file_does_not_exist = "non-existant-file.txt";
my $file_no_lines = "file_no_lines.txt";
  
system ('ls -la *.txt');
print "File $file_no_lines has size 0\n" if !(-s $file_no_lines); 
print "File $file_no_lines has size > 0\n" if (-s $file_no_lines); 
print "File $file_no_lines has zero lines\n" if (-z $file_no_lines); 
print "File $file_no_lines does not have zero lines\n" if !(-z $file_no_lines); 

print "File $file_does_not_exist has size 0 \n" if !(-s $file_does_not_exist);
print "File $file_does_not_exist has size > 0 \n" if (-s $file_does_not_exist);
print "File $file_does_not_exist has zero lines\n" if (-z $file_does_not_exist); 
print "File $file_does_not_exist does not have zero lines\n" if !(-z $file_does_not_exist); 
