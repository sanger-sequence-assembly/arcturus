package ArcturusDatabase;

use strict;

use DataSource;
use DBI;
use Read;

sub new {
    my $type = shift;

    my $this = {};
    bless $this, $type;

    my $ds = @_[0];

    if (defined($ds) && ref($ds) && ref($ds) eq 'DataSource') {
	$this->{DataSource} = $ds;
    } else {
	$this->{DataSource} = new DataSource(@_);
    }

    return $this;
}

sub getURL {
    my $this = shift;

    my $ds = $this->{DataSource};

    if (defined($ds)) {
	return $ds->getURL();
    } else {
	return undef;
    }
}

sub getConnection {
    my $this = shift;

    if (!defined($this->{Connection})) {
	my $ds = $this->{DataSource};
	$this->{Connection} = $ds->getConnection() if defined($ds);
    }

    return $this->{Connection};
}

sub getReadFromID {
    my $this = shift;

    my $readid = shift;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare("select * from READS where read_id=$readid");

    $sth->execute();

    my $arrayref = $sth->fetchrow_arrayref();

    $sth->finish();

    if (defined($arrayref)) {
	my $read = new Read();
	$read->importData(%{$arrayref});
	return $read;
    } else {
	return undef;
    }
}

1;
