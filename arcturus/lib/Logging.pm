package Logging;

use strict;

use FileHandle;

#-------------------------------------------------------
# Class variable
#-------------------------------------------------------

my $linebreak;

#-------------------------------------------------------
# Constructor always defines a filehandle
#-------------------------------------------------------

sub new {
# second parameter passed on to setOutputDevice 
    my $class  = shift;

    my $this = {};

    bless $this, $class;

    $this->setOutputDevice(@_);

    $this->{filter} = 3; # default cut at warning level

    $linebreak = $ENV{REQUEST_METHOD} ? "<br>" : "\n";

    return $this;
}

sub setOutputDevice {

    my $this   = shift;
    my $output = shift;

    if (defined($output) && $output =~ /STDOUT|STDERR/) {
        $this->{output} = new FileHandle(">&${output}");
    }
    elsif (defined($output)) {
        $this->{output} = new FileHandle($output,"w");
#print "output device: $this->{output}\n";
    }
    else {
        $this->{output} = new FileHandle(">&STDERR");
    }
}

sub setFilter {

    my $this = shift;
    my $clip = shift;

    $this->{filter} = $clip;
}

sub log {

    my $this = shift;
    my $line = shift;
    my $clip = shift;

    $clip = 0 unless defined($clip);

    return if ($clip < $this->{filter});

    return unless (defined($line) && $line =~ /\S/);

    my $OUTPUT = $this->{output} || return; # the file handle

    $line =~ s/\s+$//; # remove trailing blank space

    print $OUTPUT "$line$linebreak";
}

sub skip {
    my $this = shift;

    my $OUTPUT = $this->{output} || return; # the file handle

    print $OUTPUT "$linebreak";
}

sub severe {
# level 4
    my $this = shift;

    $this->log(shift,4);
}

sub warning {
# level 3
    my $this = shift;

    $this->log(shift,3);
}

sub info {
# level 2
    my $this = shift;

    $this->log(shift,2);

}

sub fine {
# level 1
    my $this = shift;

    $this->log(shift,1);
}

sub finest {
# level 0
    my $this = shift;

    $this->log(shift,0);
}

sub close {
# close the file handle
    my $this = shift;

    my $OUTPUT = $this->{output} || return; # the file handle

    $OUTPUT->close();

    delete $this->{output};    
}

#-------------------------------------------------------

1;


