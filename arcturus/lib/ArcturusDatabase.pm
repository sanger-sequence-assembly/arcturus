package ArcturusDatabase;

use strict;

use DBI;
use Compress::Zlib;

use DataSource;
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

    $this->init();

    return $this;
}

sub init {
    my $this = shift;

    return if defined($this->{inited});

    my $ds = $this->{DataSource};

    $this->{Connection} = $ds->getConnection();

    $this->populateDictionaries();

    $this->{inited} = 1;
}

sub populateDictionaries {
    my $this = shift;

    my $dbh = $this->{Connection};

    $this->{Dictionary} = {};

    $this->{Dictionary}->{insertsize}   = &createDictionary($dbh, 'LIGATIONS', 'ligation', 'silow, sihigh');
    $this->{Dictionary}->{ligation}     = &createDictionary($dbh, 'LIGATIONS', 'ligation', 'identifier');
    $this->{Dictionary}->{clone}        = &createDictionary($dbh, 'CLONES', 'clone', 'clonename');
    $this->{Dictionary}->{primer}       = &createDictionary($dbh, 'PRIMERTYPES', 'primer', 'type');
    $this->{Dictionary}->{status}       = &createDictionary($dbh, 'STATUS', 'status', 'identifier');
    $this->{Dictionary}->{strand}       = &createDictionary($dbh, 'STRANDS', 'strand', 'direction');
    $this->{Dictionary}->{basecaller}   = &createDictionary($dbh, 'BASECALLER', 'basecaller', 'name');
    $this->{Dictionary}->{svector}      = &createDictionary($dbh, 'SEQUENCEVECTORS', 'svector', 'name');
    $this->{Dictionary}->{cvector}      = &createDictionary($dbh, 'CLONINGVECTORS', 'cvector', 'name');

    $this->{Dictionary}->{chemistry}    = &createDictionary($dbh, 'CHEMISTRY LEFT JOIN arcturus.CHEMTYPES',
							    'chemistry', 'type', 'USING(chemtype)');
}

sub createDictionary {
    my ($dbh, $table, $pkey, $vals, $where, $junk)  = @_;

    #print STDERR "createDictionary($table, $pkey, $vals)\n";

    my $query = "SELECT $pkey,$vals FROM $table";

    $query .= " $where" if defined($where);

    my $sth = $dbh->prepare($query);

    if ($DBI::err) {
	my $msg = "createDictionary: prepare($query) failed";
	print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
	return undef;
    }

    $sth->execute();

    if ($DBI::err) {
	my $msg = "createDictionary: execute($query) failed";
	print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
	return undef;
    }

    my $dict = {};

    while(my @ary = $sth->fetchrow_array()) {
	my $key = shift @ary;
	if (scalar(@ary) > 1) {
	    $dict->{$key} = [@ary];
	} else {
	    $dict->{$key} = shift @ary;
	}
    }

    $sth->finish();

    return $dict;
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

sub getReadByID {
    my $this = shift;

    my $readid = shift;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare("select * from READS where read_id=$readid");

    $sth->execute();

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {
	my $read = new Read();

	$this->processReadData($hashref);

	$read->importData($hashref);

	$read->setArcturusDatabase($this);

	return $read;
    } else {
	return undef;
    }
}

sub processReadData {
    my $this = shift;
    my $hashref = shift;

    $hashref->{'insertsize'} = $hashref->{'ligation'};

    foreach my $key (keys %{$hashref}) {
	my $dict = $this->{Dictionary}->{$key};
	my $value = $hashref->{$key};

	if (defined($dict)) {
	    $value = &dictionaryLookup($dict, $value);
	    if (ref($value) && ref($value) eq 'ARRAY') {
		$value = join(' ', @{$value});
	    }
	    $hashref->{$key} = $value;
	}
    }
}

sub dictionaryLookup {
    my ($dict, $pkey, $junk) = @_;

    if (defined($dict)) {
	my $value = $dict->{$pkey};
	return $value;
    } else {
	return undef;
    }
}

sub getSequenceAndBaseQualityForRead {
    my $this = shift;
    my ($key, $value, $junk) = @_;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from ";

    if ($key eq 'id') {
	$query .= "SEQUENCE where read_id=?";
    } elsif ($key eq 'name' || $key eq 'readname') {
	$query .= "READS left join SEQUENCE using(read_id) where readname=?";
    }

    my $sth = $dbh->prepare($query);

    $sth->execute($value);

    my ($sequence, $quality);

    while(my @ary = $sth->fetchrow_array()) {
	($sequence, $quality) = @ary;
    }

    $sth->finish();

    $sequence = uncompress($sequence) if defined($sequence);

    if (defined($quality)) {
	$quality = uncompress($quality);
	my @qualarray = unpack("c*", $quality);
	$quality = [@qualarray];
    }

    return ($sequence, $quality);
}

1;
