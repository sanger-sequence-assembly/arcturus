package ReadFactory;

use strict;

sub new {

    my $class = shift;

    my $this = {};

    $this->{excludeList} = {};
    $this->{readlist} = [];

    bless $this, $class;

    return $this;
}

#----------------------------------------------------------------
# handling (error) logging
#----------------------------------------------------------------

sub setLogging {
# takes an instance of the Logging class
    my $this = shift;
    my $Logging = shift;

    if (ref($Logging) ne 'Logging') {
        print STDERR "setLogging expects an instance of the Logging class\n";
        return undef;
    }

    $this->{Logging} = $Logging;

    return 1;
}

sub logerror {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->severe($text);
}

sub logwarning {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->warning($text);
}

sub loginfo {
# send input text to the current logger, if any
    my $this = shift;
    my $text = shift;

    my $Logging = $this->{Logging} || return; # exit if absent
   
    $Logging->info($text);
}

#----------------------------------------------------------------
# add the next readname and attribute to the internal list
#----------------------------------------------------------------

sub addReadToList {
# add the input readname to the internal list
    my $this = shift;
    my ($readname, $object) = @_;

    my $list = $this->{readlist};

    push @$list, [$readname,$object];
    
    return 1;
} 

#----------------------------------------------------------------
# return the next readname and attribute
#----------------------------------------------------------------

sub getNextReadName {
# returns the next readname by shifting the internal list
    my $this = shift;

    my $list = $this->{readlist};

# shift the next readname off the list and put into local buffer

    $this->{readname} = shift @$list;

# return readname or undef if no next readname found

    return $this->getCurrentReadName();

#    return undef unless $this->{readname}; 

# else return the readname 

#    return $this->{readname}->[0];
}

sub getCurrentReadName {
# return the readname in the local buffer (after getNextReadName)
    my $this = shift;

    return undef unless $this->{readname}; 

    return $this->{readname}->[0];
}

sub getNextReadAuxiliaryData {
# returns the auxilliary information stored in the local buffer
    my $this = shift;

# return undef if no data in local buffer found

    return undef unless $this->{readname}; 

# else return the Read, Oracle number or ExpFile name

    return $this->{readname}->[1];
}

#----------------------------------------------------------------

1;
