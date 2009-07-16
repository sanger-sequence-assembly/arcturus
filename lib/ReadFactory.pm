package ReadFactory;

use strict;

sub new {

    my $class = shift;

    my $this = {};

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

# Sub-classes MUST override this method

sub getReadNamesToLoad {
    die "Sub-class did not override getReadNamesToLoad";
}

# Sub-classes MUST override this method

sub getReadByName {
    die "Sub-class did not overrdide getReadByName";
}

1;
