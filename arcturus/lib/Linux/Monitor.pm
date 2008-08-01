package Linux::Monitor;

use strict;

my $usage = {}; # class variable

sub new {
    my $type = shift;
    my $pid = shift || 'self';

    $pid = $$ unless (-d "/proc/$pid"); # for alphas

    my $this = {};
    bless $this, $type;

    $this->{'pid'} = $pid;
    $this->{'procdir'} = "/proc/$pid";

    return $this;
}

sub getStat {
    my $this = shift;

    return undef unless ( -d $this->{'procdir'} );

    my $procfile = $this->{'procdir'} . "/stat";

    open(STATFILE, "< $procfile") || return undef;

    my $line = <STATFILE>;

    close(STATFILE);

    my $columns = [ 'pid', 'comm', 'state', 'ppid' , 'pgrp', 'session',
		    'tty_nr', 'tpgid', 'flags', 'minflt', 'cminflt',
		    'majflt', 'cmajflt', 'utime', 'stime', 'cutime', 'cstime',
		    'priority', 'nice', 'nexttimeout', 'nextalarm', 'starttime',
		    'vsize', 'rss', 'rlim', 'startcode', 'endcode', 'startstack',
		    'kstkesp', 'kstkeip', 'signal', 'blocked',
		    'sigignore', 'sigcatch', 'wchan', 'nswap', 'cnswap',
		    'exit_signal', 'processor'];
    
    my $values = [ split(/\s+/, $line) ];
    
    my $hash = &makeHash($columns, $values);

    return $hash;
}

sub getStatm {
    my $this = shift;

    return undef unless ( -d $this->{'procdir'} );

    my $procfile = $this->{'procdir'} . "/statm";

    open(STATFILE, "< $procfile") || return undef;

    my $line = <STATFILE>;

    close(STATFILE);

    my $columns = [ 'size', 'resident', 'share', 'trs', 'drs', 'lrs', 'dt' ];

    my $values = [ split(/\s+/, $line) ];
    
    return &makeHash($columns, $values);
}

sub makeHash {
    my $cols = shift;
    my $vals = shift;

    my $retval = {};

    while (my $colname = shift @{$cols}) {
	my $value = shift @{$vals};
	$retval->{$colname} = $value if defined($value);
    }

    return $retval;
}

sub toString {
    my $this = shift;

    my $hash = $this->getStat();

    return "not accessible" unless $hash;

    my $string = "pid $hash->{pid}";

    while (my $item = shift) {
        my $value = $hash->{$item};
        next unless defined $value;
        $value *= 4096 if ($item eq 'rss');
        $string .= ",  $item $value";
    }
    return $string;
}

sub usage {
    my $this = shift;
    return "memory usage : ".$this->toString('vsize','rss');
}

sub timer {
    my $this = shift;

    my $cptime = (times)[0]; # time spent in user code
    my $iotime = (times)[1]; # system cpu (not elapsed time, unfortunately)
    my $string = "timer : ";
    if (my $timer = $this->{timer}) {
        my $cpdiff = $cptime - $timer->[0];
        my $iodiff = $iotime - $timer->[1];
        $string .= "cptime $cptime ($cpdiff), iotime $iotime ($iodiff)";
    }
    else {
        $string .= "cptime $cptime, iotime $iotime";
    }
    $this->{timer} = [($cptime,$iotime)];
    return $string;
}

1;
