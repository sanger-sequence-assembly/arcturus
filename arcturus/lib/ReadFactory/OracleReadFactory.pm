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

    my ($schema, $projid, $aspedafter, $aspedbefore,
	$readnamelike, $minreadid, $maxreadid);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$schema = shift if ($nextword eq 'schema');

	$this->{projid}       = shift if ($nextword eq 'projid');

	$this->{aspedbefore}  = shift if ($nextword eq 'aspedbefore');

	$this->{aspedafter}   = shift if ($nextword eq 'aspedafter');

	$this->{readnamelike} = shift if ($nextword eq 'readnamelike');

	$this->{minreadid}    = shift if ($nextword eq 'minreadid');
	$this->{maxreadid}    = shift if ($nextword eq 'maxreadid');

	$this->{status}       = shift if ($nextword eq 'status');
    }

    $this->{status} = 'PASS' unless defined($this->{status});

    die "No schema specified" unless defined($schema);

    $this->{schema} = $schema;

    my $datasource = new DataSource(instance => 'oracle',
				    organism => 'PATHLOOK');

    my $dbh = $datasource->getConnection();

    die "Unable to establish connection to Oracle" unless defined($dbh);

    $dbh->{'LongReadLen'} = 32768;

    $this->{connection} = $dbh;

    $this->setupPreparedStatements();

    return $this;
}

sub setupPreparedStatements {
    my $this = shift;

    my $dbh = $this->{connection};
    my $schema = $this->{schema};

    $this->{sth} = {};

    $this->{sth}->{read_info} = $dbh->prepare(qq[select
						 readid, clonename, lignumber, ligid,
						 platename, templatename,
						 strand, primer, dye, 
						 to_char(asped, 'YYYY-MM-DD'),
						 basecaller,
						 processstatus, scfdir, scffile
						 from $schema.extended_read
						 where readname = ?]);

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

    $this->{sth}->{tags} = $dbh->prepare(qq[select type, begin, end, text
					    from $schema.tag
					    where seqid = ?]);

    $this->{sth}->{scfdir} = $dbh->prepare(qq[select scfdir
					      from $schema.scfdirs
					      where scfdirid = ?]);
}

sub getReadNamesToLoad {
    my $this = shift;

    my $schema = $this->{schema};

    my $query = "select readname from $schema.EXTENDED_READ";

    my $pstatus = $this->{status} || 'PASS';

    my @conditions = $pstatus eq 'PASS' ? ("processstatus = '$pstatus'") : ("processstatus like '" . $pstatus . "%'");

    my $projid = $this->{projid};

    unshift @conditions, "projid = $projid"
	if defined($projid);

    my $minreadid = $this->{minreadid};

    unshift @conditions, "readid >= $minreadid"
	if defined($minreadid);

    my $maxreadid = $this->{maxreadid};

    unshift @conditions, "readid <= $maxreadid"
	if defined($maxreadid);

    my $aspedbefore = $this->{aspedbefore};

    unshift @conditions, "asped < '" . $aspedbefore . "'"
	if defined($aspedbefore);

    my $aspedafter = $this->{aspedafter};

    unshift @conditions, "asped > '" . $aspedafter . "'"
	if defined($aspedafter);

    my $readnamelike = $this->{readnamelike};

    unshift @conditions, "readname like '" . $readnamelike . "'"
	if defined($readnamelike); 

    $query .= " where " . join(' AND ', @conditions);

    my $dbh = $this->{connection};

    my $sth = $dbh->prepare($query);

    $sth->execute();

    my $readlist = [];

    while (my @ary = $sth->fetchrow_array()) {
	my ($readname) = @ary;

	push @{$readlist}, $readname;
    }

    $sth->finish();

    return $readlist;
}

sub getReadByName {
    my $this = shift;

    my $readname = shift;

    $this->{sth}->{read_info}->execute($readname);

    my ($readid, $clone, $lig, $ligid,
	$plate, $template, $strand,
	$primer, $dye, $asped, $caller,
	$ps, $scfdirid, $scf) = $this->{sth}->{read_info}->fetchrow_array();

    return undef unless defined($readid);

    $this->{sth}->{seq_id}->execute($readid);

    my ($seqid) = $this->{sth}->{seq_id}->fetchrow_array();

    return undef unless defined($seqid);

    my $read = new Read($readname);

    $read->setClone($clone);
    $read->setAspedDate($asped);
    $read->setBaseCaller($caller);
    $read->setTemplate($template);
    $read->setLigation($lig);
    $read->setStrand($strand);
    $read->setPrimer($primer);
    $read->setChemistry($dye);
    $read->setProcessStatus($this->{'status'});

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

    $read->setTraceArchiveIdentifier($traceref);

    $this->{sth}->{dna}->execute($seqid);

    my ($dna) = $this->{sth}->{dna}->fetchrow_array();

    $this->{sth}->{qual}->execute($seqid);

    my ($quality) = $this->{sth}->{qual}->fetchrow_array();

    $dna =~ s/\-/N/g;

    $read->setSequence($dna);
    $read->setBaseQuality([unpack("c*", $quality)]);

    $this->{sth}->{seqvecs}->execute($seqid);

    while (my ($seqleft, $seqright, $seqtext) = $this->{sth}->{seqvecs}->fetchrow_array()) {
	$read->addSequencingVector([$seqtext, $seqleft, $seqright]);
    }

    $this->{sth}->{clonevecs}->execute($seqid);

    while (my ($cloneleft, $cloneright, $clonetext) = $this->{sth}->{clonevecs}->fetchrow_array()) {
	$read->addCloningVector([$clonetext, $cloneleft, $cloneright]);
    }

    $this->{sth}->{clippings}->execute($seqid);

    while (my ($cliptype, $clipleft, $clipright, $cliptext) =
	   $this->{sth}->{clippings}->fetchrow_array()) {
	if ($cliptype eq 'QUAL') {
	    $read->setLowQualityLeft($clipleft);
	    $read->setLowQualityRight($clipright);
	}
    }


    $this->{sth}->{tags}->execute($seqid);

    while (my ($tagtype, $tagleft, $tagright, $tagtext) =
	   $this->{sth}->{tags}->fetchrow_array()) {
	my $tag = new Tag();

	$tag->setPosition($tagleft, $tagright);
	$tag->setStrand('Forward');
	$tag->setType($tagtype);
	$tag->setTagComment($tagtext);

	$read->addTag($tag);
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
