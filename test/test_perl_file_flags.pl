#!/usr/bin/perl -w
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
