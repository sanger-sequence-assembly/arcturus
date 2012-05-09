#!/usr/local/bin/perl

use strict;

use RepositoryManager;

my $rm = new RepositoryManager();

print STDERR "TESTING CONVERSION FROM META DIRECTORY TO ABSOLUTE PATH\n";

my $tmpxxx = "/tmp/XXXXXXXX";

my @testsets = ([":PROJECT:/subdir", 'project' => 'EMU'],
		[":ASSEMBLY:/subdir", 'assembly' => 'EMU'],
		[":PROJECT:/subdir", 'assembly' => 'EMU'],
		[":ASSEMBLY:/subdir", 'project' => 'EMU'],
		["$tmpxxx/subdir", 'assembly' => 'EMU'],
		["$tmpxxx/subdir", 'project' => 'EMU'],
		[":EMU:/subdir"]
		);

my $newdir;

foreach my $args (@testsets) {
    print "\nTEST: ",join(", ", @{$args}),"\n";
    eval {
	$newdir = $rm->convertMetaDirectoryToAbsolutePath(@{$args});
	print $newdir,"\n";
    };

    if ($@) {
	print STDERR "\nERROR: " . $@ . "\n";
    }
}

print STDERR "\n\nTESTING CONVERSION FROM ABSOLUTE PATH TO META DIRECTORY\n\n";

my $emuhome = $rm->convertMetaDirectoryToAbsolutePath(':ASSEMBLY:', 'assembly' => 'EMU');

print STDERR "EMU home is $emuhome\n";

@testsets = (["$emuhome/subdir", 'project' => 'EMU'],
	     ["$emuhome/subdir", 'assembly' => 'EMU'],
	     ["$emuhome/subdir", 'assembly' => 'XXX'],
	     ["$emuhome/subdir", 'project' => 'XXX'],
	     ["$emuhome/subdir"],

	     ["$tmpxxx/subdir", 'project' => 'EMU'],
	     ["$tmpxxx/subdir", 'assembly' => 'EMU'],
	     ["$tmpxxx/subdir", 'assembly' => 'XXX'],
	     ["$tmpxxx/subdir", 'project' => 'XXX'],
	     ["$tmpxxx/subdir"],
	     );


foreach my $args (@testsets) {
    print "\nTEST: ",join(", ", @{$args}),"\n";
    eval {
	$newdir = $rm->convertAbsolutePathToMetaDirectory(@{$args});
	print $newdir,"\n";
    };

    if ($@) {
	print STDERR "\nERROR: " . $@ . "\n";
    }
}

exit 0;
