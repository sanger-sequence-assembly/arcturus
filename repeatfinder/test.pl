#!/usr/local/bin/perl -w

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
