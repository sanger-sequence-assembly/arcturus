#!/usr/local/bin/perl

print "Content-type: text/plain","\n\n";

$pid = $$;
$ppid = getppid();
$pgrp = getpgrp();

print "PID is $pid\nParent PID is $ppid\nGroup PID is $pgrp\n\n";

print "Preparing to send TERM signal to $pgrp\n\n";

kill('TERM', $pgrp);

print "Signal sent.\n";

exit(0);
