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
# 'Men in Black': The Alien Encyclopedia                                    #
#############################################################################
my $DEBUG = 0;
#############################################################################
my %instances;
#############################################################################

sub new {
# constructor
    my $prototype = shift;
    my $dbasename = shift;
    my $options   = shift; # hash image with options (open reading, writing, with authorization)

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{database} = $dbasename; # test existence further down

    bless ($self, $class);

# import options specified in $options hash

    my %options = (HostAndPort   => '', # specify explicitly host:port; else use default on current server 
                   writeAccess   => '', # specify tablename (or array) to which write access is required
                   identify      => 0,  # required for write access 
                   username      => 0,  # (alternative for identify)
                   password      => 0,  # required for write access
                   newGateKeeper => 0,  # if true, forces new database connection; else spawn
                   dieOnError    => 1); # default die on any error; if 0, beware! unpredictable behaviour

    $self->importOptions (\%options,$options); # override with input options, if any

    $options{identify} = $options{username} if $options{username}; # to accommodate deprecated usage

# initialize gate keeper and get ArcturusTable handle

    my @instances = keys %instances;

    my $redirect = 2;
# (redirect flag set to build database connection in 'unchecked' mode if not on current server)
    if (!@instances || $options{newGateKeeper}) {
# open the first GateKeeper
        $self->{GateKeeper} = new GateKeeper('mysql',\%options);
    }
    else {
# spawn a new GateKeeper from an existing one (to use existing database connection)
        my $Bootean = $instances{$instances[0]};
        $self->{GateKeeper} = $Bootean->{GateKeeper}->spawn($dbasename,\%options);
        $redirect = 0; # disable redirect (should not be activated, but just in case)
    }

# test input database name

    $self->{GateKeeper}->dropDead("Undefined database name in Bootean constructor") if !$dbasename;    

print "Bootean: building table handle \n" if $DEBUG;

    my %gkoptions = (returnTableHandle => 1, defaultRedirect => $redirect);
    $self->{mother} = $self->{GateKeeper}->dbHandle($dbasename,\%gkoptions);

# make $dbasename default

print "Bootean: changing focus to $dbasename\n" if $DEBUG;

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
            $accessCode |= 1024 if ($table eq 'PENDING');
        }
# and test the authorisation
        $options{makeSession}  = 2;
        $options{closeSession} = 0;
        if ($self->{GateKeeper}->authorize($accessCode,\%options)) {
            $self->{session} = $self->{GateKeeper}->{SESSION};
print "Bootean access code $accessCode: authorization granted\n" if $DEBUG;
        }
        else {
            $self->{GateKeeper}->disconnect("authorization FAILED: $self->{GateKeeper}->{error}");
#            $self->{GateKeeper}->report("authorization FAILED: $self->{GateKeeper}->{error}");
            return 0;
        }
print "Bootean: session $self->{session} \n\n" if $DEBUG;
    }

    $instances{$dbasename} = $self;

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
# decoding/overwriting input options hash
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
        $output = $mother->associate('dbasename,residence','where',1); # array of hashes
#        print "output all:  $output  $mother->{lastQuery}\n";
#        foreach my $hash (@$output) {
#            print "$hash->{dbasename}  $hash->{residence} \n";
#        }
    }

    else { 
        $output = $mother->associate('residence',$database,'dbasename',{useCache=>1}); # host:port of instance
#        print "output:  $output  $mother->{query}\n";
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
# return current server, database port and (if any) cgi port
    my $self = shift;

    return $self->{GateKeeper}->currentResidence;
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
# test if the database is alive with a GateKeeper ping
    my $self = shift;

    return $self->{GateKeeper}->ping;
}
#--------------------------- documentation --------------------------
=pod

=head1 ping

=head2 Synopsis

Test if the database is alive

=head2 Parameters: none

=cut

#############################################################################

sub disconnect {
# disconnect current Bootean interface from database if it happens to
# be the only one on this GateKeeper, disconnect GateKeeper as well
    my $self = shift;
    my $text = shift || 0;
    my $full = shift || 0; # set true for unconditional disconnect

    my $GateKeeper = $self->{GateKeeper} || return;

# determine the number of interfaces connecting through this GateKeeper

    my %GKcount;
    foreach my $database (keys %instances) {
        $GKcount{$instances{$database}->{GateKeeper}}++;
    }

# do a full close down if this is the only connection

print "GKcount $GKcount{$GateKeeper} \n" if $DEBUG;
    $full = 1 if ($GKcount{$GateKeeper} == 1);

# put a time/user signature on modified database tables

    $GateKeeper->disconnect($text,$full);

    delete $self->{GateKeeper};
}

#--------------------------- documentation --------------------------
=pod

=head1 method disconnect

=head2 Synopsis

Disconnect the GateKeeper from the database

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
        updated =>    "17 Feb 2003",
    };
}

#############################################################################

1;
