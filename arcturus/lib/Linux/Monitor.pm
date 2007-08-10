package Linux::Monitor;

use strict;

sub new {
    my $type = shift;
    my $pid = shift || 'self';

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
    
    return &makeHash($columns, $values);
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

1;
