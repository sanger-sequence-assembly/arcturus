#!/usr/local/bin/perl

use CGI;

$cgi = new CGI;

print "Content-type: text/plain","\n\n";

$signal = $cgi->param('signal') || 'TERM';

$pid = $$;
$ppid = getppid();
$pgrp = getpgrp();

print "PID is $pid\nParent PID is $ppid\nGroup PID is $pgrp\n\n";

print "Preparing to send $signal signal to $pgrp\n\n";

kill($signal, $pgrp);

print "Signal sent.\n";

exit(0);
