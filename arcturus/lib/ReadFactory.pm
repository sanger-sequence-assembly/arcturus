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
   
    $Logging->error($text);
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
# return the next readname and attribute
#----------------------------------------------------------------

sub addReadToList {
# add the input readname to the internal list
    my $this = shift;
    my ($readname, $object) = @_;

    if (!defined($object) or ref($object) ne 'Read') {
        print STDERR "addReadNameToList requires a readname and an object reference\n";
        return undef;
    }

    my $list = $this->{readlist};

    push @$list, [$readname,$object];
    
    return 1;
} 

sub getNextReadName {
# returns the next readname
    my $this = shift;

    my $list = $this->{readlist};

# shift the next readname off the list and put into local buffer

    $this->{readname} = shift @$list;

# return undef if no next readname found

    return undef unless $this->{readname}; 

# else return the readname 

    return $this->{readname}->[0];
}

sub getNextReadAuxiliaryData {
# returns the information stored in the local buffer
    my $this = shift;

# return undef if no data in local buffer found

    return undef unless $this->{readname}; 

# else return the Read, Oracle number or File name

    return $this->{readname}->[1];
}

#----------------------------------------------------------------

1;














