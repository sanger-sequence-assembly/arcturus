#!/user/local/bin/perl5

#$retry_in_secs = 1 * 60;
# for testing, use one hundreth of real values

$retry_in_secs = 0.01 * 60;
$retry_counter = 0.25;
$counter = 1;
$max_retries = 4;

while ($counter < ($max_retries + 1)) {
    $retry_counter = $retry_counter * 4;
		# to mimic that the insert succeeds
		# until ({$counter > 4}) {
      print "Attempt $counter for the insert statement\n";
      # Execute the statement
      $retry_in_secs = $retry_in_secs * $retry_counter;
			if ($counter < $max_retries) {
        print "Statement has failed so wait for $retry_in_secs seconds\n"; 
        sleep($retry_in_secs);
			}
			$counter++;
		#}
}
print "Statement has failed $counter times so send an email\n";

