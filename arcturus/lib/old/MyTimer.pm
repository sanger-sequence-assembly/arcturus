package MyTimer;

#############################################################################
#
# ad hoc timing module
#
#############################################################################

use strict;

#############################################################################
# Global variables
#############################################################################

my $break = "\n";

my %timehash;
my $TIMER = 1;

#############################################################################

sub new {

    my $prototype = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $break = '<br>' if ($ENV{REQUEST_METHOD});

    bless ($self, $class);

    return $self;
}

#############################################################################

sub timer {
# ad hoc timing routine
    my $self   = shift;
    my $marker = shift;
    my $access = shift; # 0 for start, 1 for end

    my $cptime = (times)[0]; # time spent in user code
    my $iotime = (times)[1]; # system cpu (not elapsed time, unfortunately)
    $timehash{$marker}->[$access]->[0] += $cptime;
    $timehash{$marker}->[$access]->[1] += $iotime;
    my $localtime = localtime;
    $timehash{$marker}->[$access]->[2] = (split ' ',$localtime)[3];
}


#############################################################################

sub summary {

    my $list = "$break$break${break}breakdown of time usage:$break";

    foreach my $key (sort keys %timehash) {
# test all elements defined
        for my $i (0 .. 3) {
            my $j = int($i/2); my $k = $i - $j -$j;
            $list .= "warning: $key $j, $k UNDEFINED $break" if !defined($timehash{$key}->[$j]->[$k]);
        }
	my $cptime = $timehash{$key}->[1]->[0] - $timehash{$key}->[0]->[0];
	my $iotime = $timehash{$key}->[1]->[1] - $timehash{$key}->[0]->[1];
        $list .= sprintf ("%16s  ",$key);
        if ($timehash{$key}->[0]->[2] ne $timehash{$key}->[1]->[2]) {
            $list .= " from $timehash{$key}->[0]->[2] to $timehash{$key}->[1]->[2] ";
        }
        else {
            $list .= "                           ";
        }
        $list .= sprintf ("CPU:%10.2f  IO:%10.2f$break",$cptime,$iotime);
    } 
    print STDOUT $list;
    $TIMER = 0;
}

#############################################################################

sub DESTROY {

    &summary if $TIMER;    

}

