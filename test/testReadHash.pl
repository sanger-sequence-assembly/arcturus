#!/user/local/bin/perl5

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

