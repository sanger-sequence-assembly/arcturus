package OracleReadFactory;

use strict;
use DataSource;
use DBI;
use ReadFactory;

use Read;

use vars qw(@ISA);

@ISA = qw(ReadFactory);

sub new {
    my $type = shift;

    my $this = $type->SUPER::new();

    my ($schema, $projid, $aspedafter, $readnamelike, $includes, $excludes);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$schema = shift if ($nextword eq 'schema');

	$projid = shift if ($nextword eq 'projid');

	$aspedafter = shift if ($nextword eq 'aspedafter');

	$readnamelike = shift if ($nextword eq 'readnamelike');

	$includes = shift if ($nextword eq 'readnames' ||
			      $nextword eq 'include' ||
			      $nextword eq 'fofn');

	$excludes = shift if ($nextword eq 'exclude');
    }

    die "No schema specified" unless defined($schema);

    $this->{schema} = $schema;

    my $datasource = new DataSource(instance => 'oracle',
				    organism => 'PATHLOOK');

    my $dbh = $datasource->getConnection();

    die "Unable to establish connection to Oracle" unless defined($dbh);

    $dbh->{'LongReadLen'} = 32768;

    $this->{connection} = $dbh;

    my $includeset = {};

    if (defined($includes)) {
	while (my $readname = shift @{$includes}) {
	    $includeset->{$readname} = 1;
	}
    }

    undef $includeset unless scalar(%{$includeset});

    my $excludeset = {};

    if (defined($excludes)) {
	while (my $readname = shift @{$excludes}) {
	    $excludeset->{$readname} = 1;
	}
    }

    my $query = "select readname,readid from $schema.EXTENDED_READ";

    my @conditions = ("processstatus = 'PASS'");

    unshift @conditions, "projid = $projid"
	if defined($projid);

    unshift @conditions, "asped > '" . $aspedafter . "'"
	if defined($aspedafter);

    unshift @conditions, "readname like '" . $readnamelike . "'"
	if defined($readnamelike); 

    $query .= " where " . join(' AND ', @conditions);

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $readlist = [];

    while (my @ary = $sth->fetchrow_array()) {
	my ($readname, $readid) = @ary;

	next if defined($excludeset->{$readname});

	next if (defined($includeset) && !defined($includeset->{$readname}));

	#print STDERR "  Adding ($readname, $readid)\n";

	$this->addReadToList($readname, $readid);
    }

    $sth->finish();

    $this->setupPreparedStatements();

    return $this;
}

sub setupPreparedStatements {
    my $this = shift;

    my $dbh = $this->{connection};
    my $schema = $this->{schema};

    $this->{sth} = {};

    $this->{sth}->{read_info} = $dbh->prepare(qq[select
						 clonename, lignumber, ligid,
						 platename, templatename,
						 strand, primer, dye, 
						 to_char(asped, 'YYYY-MM-DD'),
						 basecaller,
						 processstatus, scfdir, scffile
						 from $schema.extended_read
						 where readid = ?]);

    $this->{sth}->{lig_info} = $dbh->prepare(qq[select insertsizemin, insertsizemax
						from $schema.ligation where ligid = ?]);

    $this->{sth}->{seq_id} = $dbh->prepare(qq[select seqid
					      from $schema.read2seq, $schema.assembly
					      where assembly.assemblynumber = 0
					      and assembly.assemblyid = read2seq.assemblyid
					      and read2seq.readid = ?]);
    
    $this->{sth}->{dna} = $dbh->prepare(qq[select DNA
					   from $schema.sequence
					   where seqid = ?]);

    $this->{sth}->{qual} = $dbh->prepare(qq[select qual
					    from $schema.basequality
					    where seqid = ?]);

    $this->{sth}->{seqvecs} = $dbh->prepare(qq[select begin, end, text
					       from $schema.seqvec
					       where seqid = ?]);

    $this->{sth}->{clonevecs} = $dbh->prepare(qq[select begin, end, text
						 from $schema.clonevec
						 where seqid = ?]);

    $this->{sth}->{clippings} = $dbh->prepare(qq[select type, begin, end, text
						 from $schema.clipping
						 where seqid = ?]);

    $this->{sth}->{scfdir} = $dbh->prepare(qq[select scfdir
					      from $schema.scfdirs
					      where scfdirid = ?]);
}

sub getNextRead {
    my $this = shift;

    my $readid = $this->getNextReadAuxiliaryData();

    $this->{sth}->{read_info}->execute($readid);
    $this->{sth}->{seq_id}->execute($readid);

    my ($clone, $lig, $ligid,
	$plate, $template, $strand,
	$primer, $dye, $asped, $caller,
	$ps, $scfdirid, $scf) = $this->{sth}->{read_info}->fetchrow_array();

    my ($seqid) = $this->{sth}->{seq_id}->fetchrow_array();

    return undef unless ($seqid);

    my $read = new Read();

    $read->setClone($clone);
    $read->setDate($asped);
    $read->setBaseCaller($caller);
    $read->setTemplate($template);
    $read->setLigation($lig);
    $read->setStrand($strand);
    $read->setPrimer($primer);
    $read->setChemistry($dye);

    my ($imin, $imax);
    if (exists($this->{ligations}->{$ligid})) {
	($imin, $imax) = @{$this->{ligations}->{$ligid}};
    } else {
	$this->{sth}->{lig_info}->execute($ligid);
	($imin, $imax) = $this->{sth}->{lig_info}->fetchrow_array();
	$this->{ligations}->{$ligid} = [$imin, $imax];
    }

    $read->setInsertSize([$imin, $imax]);

    $this->{sth}->{scfdir}->execute($scfdirid);

    my ($scfdir) = $this->{sth}->{scfdir}->fetchrow_array();

    my $traceref = "$scfdir/$scf";

    $this->{sth}->{dna}->execute($seqid);

    my ($dna) = $this->{sth}->{dna}->fetchrow_array();

    $this->{sth}->{qual}->execute($seqid);

    my ($quality) = $this->{sth}->{qual}->fetchrow_array();

    $read->setSequence($dna);
    $read->setQuality($quality);

    $this->{sth}->{seqvecs}->execute($seqid);

    my ($seqleft, $seqright, $seqtext) = $this->{sth}->{seqvecs}->fetchrow_array();

    $read->setSequencingVectorLeft($seqleft);
    $read->setSequencingVectorRight($seqright);
    $read->setSequencingVector($seqtext);

    $this->{sth}->{clonevecs}->execute($seqid);

    my ($cloneleft, $cloneright, $clonetext) = $this->{sth}->{clonevecs}->fetchrow_array();

    if (defined($cloneleft) && defined($cloneright)) {
	$read->setCloningVectorLeft($cloneleft);
	$read->setCloningVectorRight($cloneright);
	$read->setCloningVector($clonetext);
    }

    $this->{sth}->{clippings}->execute($seqid);

    while (my ($cliptype, $clipleft, $clipright, $cliptext) =
	   $this->{sth}->{clippings}->fetchrow_array()) {
	if ($cliptype eq 'QUAL') {
	    $read->setLowQualityLeft($clipleft);
	    $read->setLowQualityRight($clipright);
	}
    }

    return $read;
}

sub close {
    my $this = shift;

    foreach my $key (keys %{$this->{sth}}) {
	$this->{sth}->{$key}->finish();
	undef $this->{sth}->{$key};
    }

    $this->{connection}->disconnect();
    undef $this->{connection};
}

1;
