#!/user/local/bin/perl5

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

