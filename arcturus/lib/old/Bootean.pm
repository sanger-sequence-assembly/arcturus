package Bootean;

# interface to Arcturus database

use strict;

use GateKeeper;

#############################################################################
# BOOTEANS                                                                  #
#                                                                           #
# Reptilians from the "Bootes" system. These, and reptilian entities from   #
# the "Draconis" system are allegedly involved with the 'Dulce' scenario as #
# well as the infiltration-implantation-control of human society on earth   #
# in anticipation of their planned takeover at some point in the future.    #
#                                                                           #
# 'Men in Black' Collectables Presents: The Alien Encyclopedia              #
#############################################################################
my $DEBUG = 1;
#############################################################################

sub new {
# constructor
    my $prototype = shift;
    my $dbasename = shift;
    my $options   = shift; # hash image with options (open reading, writing, with authorization)

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{database} = $dbasename;

    bless ($self, $class);

# import options specified in $options hash

    my %options = (HostAndPort   => '', # specify explicitly host:port; else use default on current server 
                   writeAccess   => '', # specify tablename (or array) to which write access is required
                   identify      => 0,  # required for write access 
                   username      => 0,  # (alternative for identify)
                   password      => 0,  # required for write access
                   dieOnError    => 1); # default die on any error; if 0, beware! unpredictable behaviour

    $self->importOptions (\%options,$options); # override with input options, if any

    $options{identify} = $options{username} if $options{username}; # to accommodate deprecated usage

# initialize gate keeper and get ArcturusTable handle

print "building GateKeeper \n" if $DEBUG;

    $self->{GateKeeper} = new GateKeeper('mysql',$options);

# set redirect flag to build database connection in 'unchecked' mode if not on current server

print "building table handle \n" if $DEBUG;

    my %gkoptions = (returnTableHandle => 1, defaultRedirect => 2);
    $self->{mother} = $self->{GateKeeper}->dbHandle($dbasename,\%gkoptions);

# make $dbasename default

print "changing focus to $dbasename\n" if $DEBUG;

    $self->{GateKeeper}->focus($options{dieOnError}); 

# prepare for write access 

    $self->{session} = 0; # acts also as default for NO write access

    if (my $tables = $options{writeAccess}) {
# setup access code for authorization; first get tables
        undef my @tables; $tables[0] = $tables;
        $tables = \@tables if (ref($tables) ne 'ARRAY');
        delete $options{writeAccess};
# build the accesscode        
        my $accessCode = 0;
        foreach my $table (@tables) {
            $accessCode |=   64 if ($table eq 'GENES');
            $accessCode |=   64 if ($table eq 'GENE2CONTIG');
            $accessCode |=  128 if ($table eq 'CONTIGS');
            $accessCode |= 1024 if ($table eq 'READS');
        }
# and test the authorisation
        $options{makeSession}  = 2;
        $options{closeSession} = 0;
print "access code $accessCode\n" if $DEBUG;
        if ($self->{GateKeeper}->authorize($accessCode,\%options)) {
            $self->{session} = $self->{GateKeeper}->{SESSION};
print "authorization granted\n" if $DEBUG;
        }
        else {
            $self->{GateKeeper}->disconnect("authorization FAILED: $self->{GateKeeper}->{error}");
            return 0;
        }
print "session $self->{session} \n" if $DEBUG;
    }

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 new (constructor)

=head2 Synopsis

Interface to Arcturus database

=head2 Parameters:

=over 2

=item database

The name of the Arcturus database to be used

=item options

Options communicated as a hash with the option names as keys:

=over 5

=item HostAndPort:

format "host:port"

=item writeAccess:

Tablename or reference to array of tablenames to which write access is requested.
Write access requires a username and password to be specified as well.

=item username (or, as alternnative, identify)

The Arcturus username

=item password

The password for the given username

=back

=back

=cut
#*******************************************************************************

sub importOptions {
# (private function) decoding/overwriting input options hash
    my $self    = shift;
    my $options = shift;
    my $hash    = shift;

    my $status = 0;
    if (ref($options) eq 'HASH' && ref($hash) eq 'HASH') {
        foreach my $option (keys %$hash) {
            $options->{$option} = $hash->{$option};
        }
        $status = 1;
    }

    $status;
}

#############################################################################

sub whereIs {
# find the server and port of the named database, or list all on this server
    my $self     = shift;
    my $database = shift; # undefined for list of instances

    my $mother = $self->{mother};

    undef my $output; # default unknown database

    if (!$database) {
        $output = $mother->associate('dbasename,residence'); # array ref of instances
    }

    else { 
        $output = $mother->associate('residence',$database); # host:port of instance
        print "Database $database is on server $output\n" if $output;
        print "Unknown database: $database\n" if !$output;
    }

    return $output;
}
#--------------------------- documentation --------------------------
=pod

=head1 method whereIs

=head2 Synopsis

Return host and port of a specified database on the current Arcturus instance.

=head2 Parameter: database name

If no database name is give, the call returns an array of all databases and 
(database server) ports on the current Arcturus instance. 

=cut

#############################################################################

sub whereAmI {
# return current server and port
    my $self = shift;

    return $self->{GateKeeper}->currentPort;
}
#--------------------------- documentation --------------------------
=pod

=head1 method whereAmI

=head2 Synopsis

Return current host and port 

=head2 Parameters: none

=cut
#############################################################################

sub dropDead {
# abort with error status
    my $self = shift;

    my $GateKeeper = $self->{GateKeeper} || return 0;
     
    $GateKeeper->dropDead(@_);
}
#--------------------------- documentation --------------------------
=pod

=head1 method dropDead

=head2 Synopsis

Close the database connection and exit; 

=head2 Parameters

Text to printed, e.g. an error message triggering the call

=cut
#############################################################################

sub allowTableAccess {
# test table write access permission via the GateKeeper
    my $self = shift;

    my $GateKeeper = $self->{GateKeeper} || return 0;
     
    return $GateKeeper->allowTableAccess(@_);
}
#--------------------------- documentation --------------------------
=pod

=head1 method allowTableAccess

=head2 Synopsis

Test if write access exists to a named table by the current user 

=head2 Parameters

database table name

=cut
#############################################################################

sub errors {
# return error status on GateKeeper or any open database table
    my $self = shift;

    undef my $error;

# first errors in Bootean interface

    $error = "$self->{error} \n" if $self->{error};

# test error status on GateKeeper 

    my $GateKeeper = $self->{GateKeeper};
    $error .= "$GateKeeper->{error} \n" if $GateKeeper->{error};

# test error status on each open database table

    my $mother = $self->{mother};
    my $tables = $mother->getInstanceOf(0);
    foreach my $instance (keys %$tables) {
        $error .= "$instance->{tablename}: $instance->{errors} \n" if $instance->{errors};
        $error .= "- $instance->{lastQuery} \n" if ($instance->{errors} && $instance->{lastQuery}); 
    }

    return $error;
}
#--------------------------- documentation --------------------------
=pod

=head1 errors

=head2 Synopsis

Return a summary of possible errors on, in this order, the Bootean interface,
the Arcturus GateKeeper module and all of the database table instances. 

=head2 Parameters: none

=cut
#############################################################################

sub ping {
# test if the database is alive
    my $self = shift;

    my $alive = 1;

    $alive = 0 if (!$self->{database} || !$self->{GateKeeper}->ping);

    return $alive;
}
=pod

=head1 ping

=head2 Synopsis

Test if the database is alive

=head2 Parameters: none

=cut

#############################################################################

sub DESTROY {
# force disconnect and close session, if not done previously
    my $self = shift;

    $self->disconnect if $self->{database};
}

#############################################################################

sub disconnect {
# cleanly disconnect from database
    my $self = shift;

    my $GateKeeper = $self->{GateKeeper} || return;
    my $database   = $self->{database}   || return;
    my $mother     = $self->{mother}     || return;
    my $session    = $self->{session};
    my $userid     = $GateKeeper->{USER};

# put a time/user signature on modified database tables

    $mother->signature($userid,'dbasename',$database);

# close current session 

    $GateKeeper->closeSession($session) if $session;

    $GateKeeper->disconnect;

    delete $self->{database};
}

#--------------------------- documentation --------------------------
=pod

=head1 method disconnect

=head2 Synopsis

Disconnect cleanly from the database. This method is invoked by DESTROY

=head2 Parameters

None

=cut
#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "07 Sep 2002",
        updated =>    "20 Jan 2003",
    };
}

#############################################################################

1;






