package ArcturusDatabase;

use strict;

use DBI;
use DataSource;
use ArcturusDatabase::ADBAssembly;

our @ISA = qw(ArcturusDatabase::ADBAssembly);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    $this->open(@_); # get the data source

    return undef unless $this->{DataSource}; # test it

    $this->init(); # get the database connection

    return undef unless $this->{Connection}; # test it

    $this->populateDictionaries();

    $this->putArcturusUser(); # establish the username

# define roles for the managers

    $this->setArcturusUserRole('adh','dba');
    $this->setArcturusUserRole('ejz','dba');

    return $this;
}

sub open {
# open the data source
    my $this = shift;

    my $ds = $_[0];

    if (defined($ds) && ref($ds) && ref($ds) eq 'DataSource') {
	$this->{DataSource} = $ds;
    }
    else {
	$this->{DataSource} = new DataSource(@_);
    }

    return undef unless $this->{DataSource};

    $this->init(); 

    return $this;
}

sub init {
    my $this = shift;

    return if defined($this->{inited});

    my $ds = $this->{DataSource} || return; 

    $this->{Connection} = $ds->getConnection();

    return unless $this->{Connection};

    $this->{inited} = 1;
}

sub getConnection {
    my $this = shift;

    if (!defined($this->{Connection})) {
	my $ds = $this->{DataSource};
	$this->{Connection} = $ds->getConnection(@_) if defined($ds);
    }

    return $this->{Connection};
}

sub getURL {
    my $this = shift;

    my $ds = $this->{DataSource};

    if (defined($ds)) {
	return $ds->getURL();
    }
    else {
	return undef;
    }
}

sub errorStatus {
# returns DBI::err  or 0
    my $this = shift;

    return "Can't get a database handle" unless $this->getConnection();

    return $DBI::err || 0;
}

sub disconnect {
# disconnect from the database
    my $this = shift;

    my $dbh = $this->{Connection};

    if (defined($dbh)) {
        $dbh->disconnect;
        undef $this->{Connection};
    }
}

#-----------------------------------------------------------------------------
# arcturus user information
#-----------------------------------------------------------------------------

sub putArcturusUser {
# determine the username from the system data
    my $this = shift;

    $this->{ArcturusUser} = getpwuid($<);

# test against prohibited names (force login with own user name)

    foreach my $forbidden ('pathdb','pathsoft','yeasties','othernames') {

        if ($this->{ArcturusUser} eq $forbidden) {

            $this->disconnect();

	    die "You cannot access Arcturus under username $forbidden";
	}
    }
}

sub getArcturusUser {
# return the username (as is)
    my $this = shift;

    return $this->{ArcturusUser} || ''; 
}

#-------------------------------------------------------------------------
# "roles" using USER table data TO BE DEVELOPED

sub setArcturusUserRole {
    my $this = shift;
    my ($user,$role) = @_;

    $this->{userroles} = {} unless defined $this->{userroles};

    my $userrolehash = $this->{userroles};

    $userrolehash->{$user} = $role if $role;    
}

sub getArcturusUserRoles {
    my $this = shift;

    $this->{userroles} = {} unless defined $this->{userroles};
 
    return $this->{userroles};
}

sub userCanCreateProject {
    my $this = shift;
    return 1; # temporary
}

sub userCanAssignProject {
    my $this = shift;
}

sub userCanMoveAnyContig {
    my $this = shift;
}

sub userCanGrantPrivilege {
    my $this = shift;
}

#-----------------------------------------------------------------------------

sub logMessage {
    my $this = shift;
    my $user = shift;
    my $project = shift; # project name
    my $text = shift; # the message

print STDOUT "message for user $user: $text \n";

    $this->{messages} = [] unless defined $this->{messages};

    my $log = $this->{messages};

    push @$log, [($user,$project,$text)]; # array of arrays
}

sub getMessage {
# returns the next message (to be processed by calling script)
    my $this = shift;

    return undef unless $this->{messages};

    my $log = $this->{messages};

    return 0 unless @$log;

    return shift @$log; # array ref (user, project, text)
}
    
#-----------------------------------------------------------------------------

sub logQuery {
# keep a query log for debugging purposes
    my $this = shift;
    my @entry = @_;

# each entry consists of: subroutine of origin, query and possibly @data

    $this->{querylog} = [] unless $this->{querylog};

    my $log = $this->{querylog};

    unless (@entry >= 2) { # retrieval mode
        my $logentry = $entry[0] || 1;
        $logentry = $log->[$logentry-1]; # the query data
        return undef unless $logentry;
        @entry = @$logentry;
        $entry[1] =~ s/(\s*(where|from|and|order|group))/\n         $1/gi;
        my $output = "method : $entry[0]\nquery  : $entry[1]\n";
        splice @entry,0,2;
# if any data given, substitute wildcards
        my $length = length(@entry); 
        while ($length-- > 0) {
            my $datum = shift @entry || 'null';
            $datum = "'$datum'" if ($datum =~ /\D/);
            $output =~ s/\?/$datum/;
        }
 	return $output;
    }

    push @$log, [@entry]; # build array of arrays
}

#-----------------------------------------------------------------------------

1;
