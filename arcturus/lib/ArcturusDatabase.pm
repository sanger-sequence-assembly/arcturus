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

sub putArcturusUser {
# determine the username from the system data
    my $this = shift;

    $this->{ArcturusUser} = getpwuid($<);

    foreach my $forbidden ('pathdb','othernames') {

        if ($this->{ArcturusUser} eq $forbidden) {

            $this->disconnect();

	    die "You cannot access Arcturus under username $forbidden";
	}
    }
}


sub getArcturusUser {
# determine the username from the system data
    my $this = shift;

    return $this->{ArcturusUser} || ''; 
}

#-----------------------------------------------------------------------------

sub message {
# message TO BE DEVELOPED
    my $this = shift;
    my $user = shift;
    my $pold = shift; # old project
    my $pnew = shift; # new project
    my $text = shift; # the message

    print STDOUT "message for user $user: '$text'\n";
}

sub messagemanager {
}

#-----------------------------------------------------------------------------

1;













