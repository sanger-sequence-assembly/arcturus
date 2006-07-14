package TraceServerReadFactory;

use strict;
use DataSource;
use DBI;
use TraceServer;
use ReadFactory;

use Read;

use vars qw(@ISA);

@ISA = qw(ReadFactory);

sub new {
    my $type = shift;

    my $this = $type->SUPER::new();

    my ($organism, $minreadid, $maxreads);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$organism = shift if ($nextword eq 'organism');

	$minreadid = shift if ($nextword eq 'minreadid');

	$maxreads = shift if ($nextword eq 'maxreads');
    }

    die "No organism specified" unless defined($organism);

    $this->{organism} = $organism;

    my $ts = TraceServer->new(TS_DIRECT, TS_READ_ONLY, "");

    die "Unable to connect to the trace server" unless defined($ts);

    $this->{traceserver} = $ts;

    my $group = $ts->get_group($organism, 'PASS');

    die "Organism $organism not in trace server" unless defined($group);

    my $grit = $group->get_iterator(1);

    $grit->set($minreadid) if defined($minreadid);

    $this->{iterator} = $grit;

    $this->{maxreads} = $maxreads;

    $this->{readcount} = 0;

    return $this;
}

sub getNextReadName {
    my $this = shift;

    undef($this->{read});

    return undef if (defined($this->{maxreads}) &&
		     ($this->{readcount} >= $this->{maxreads}));

    my $seq_id = $this->{iterator}->next();

    return undef unless defined($seq_id);

    $this->{seq_id} = $seq_id;

    my ($read, $index) = $this->{traceserver}->get_read_by_seq_id($seq_id);

    $this->{read} = $read;

    $this->{readcount}++;

    return $read->get_name();
}

sub getNextRead {
    my $this = shift;

    my $tsread = $this->{read};

    return undef unless defined($tsread);

    my $read = new Read($tsread->get_name());

    # Strand

    my $strand = $tsread->get_direction();

    if ($strand == TSR_FORWARD) {
	$strand = 'Forward'
	} elsif ($strand == TSR_REVERSE) {
	    $strand = 'Reverse';
	} else {
	    $strand = 'Unknown';
	}

    $read->setStrand($strand);

    # Primer

    my $universal_primer = $tsread->get_attribute(TSR_UNIVERSAL_PRIMER);

    if ($universal_primer) {
	$read->setPrimer("Universal_primer");
    } else {
	$read->setPrimer("Unknown_Primer");
    }

    # Chemistry

    my $chemistry = $tsread->get_attribute(TSR_CHEMISTRY);

    if ($chemistry =~ /^TRM_/) {
	$read->setChemistry("Dye_terminator");
    } elsif ($chemistry =~ /^PRI_/) {
	$read->setChemistry("Dye_primer");
    }

    # Asped date

    my $asped = $tsread->get_attribute(TSR_RUN_DATETIME);

    my @asped = gmtime($asped);

    my $asped = sprintf("%04d-%02d-%02d", 1900+$asped[5],1+$asped[4],$asped[3]);

    $read->setAspedDate($asped);

    # Basecaller

    $read->setBaseCaller("phred");

    # Process status

    $read->setProcessStatus("PASS");

    # Sequence attributes

    my $seq = $tsread->get_sequence();

    # Trace archive identifier

    $read->setTraceArchiveIdentifier($this->{seq_id});

    # Ligation and clone data

    my ($clone, $ligation, $seqvec, $template, $libsize, $libsigma, $clonevec);

    for (my $dnasrc = $tsread->get_dnasource();
	 defined($dnasrc);
	 $dnasrc = $dnasrc->get_parent()) {
	my ($srcclass,$srcname) = split(/::/, $dnasrc->get_name());

	my $srctype = $dnasrc->get_type(); 

	if ($srctype eq 'clone') {
	    my ($srclibclass,$srclibname) = split(/::/, $dnasrc->get_library_name());

	    if ($srcclass eq 'SUBCLONE') {
		$template = $srcname;
		$ligation = $srclibname;
		$libsize = $dnasrc->get_library_size();
		$libsigma = $dnasrc->get_library_stddev();
		$seqvec = $dnasrc->get_library_vector();
	    } elsif ($srcclass eq 'CLONE') {
		$clone = $srcname;
		$clonevec = $dnasrc->get_library_vector();
	    }
	}
    }

    $read->setTemplate($template) if defined($template);
    $read->setLigation($ligation) if defined($ligation);
    $read->setClone($clone) if defined($clone);
 
    if (defined($libsize)) {
	my $imin = $libsize;
	my $imax = $libsize;

	if (defined($libsigma)) {
	    $imin -= $libsigma;
	    $imax += $libsigma;
	}

	$read->setInsertSize([$imin, $imax]);
    }

    # DNA and quality

    my $dna = $seq->get_dna();

    my $qual = $tsread->get_confidence()->get_phred();

    $read->setSequence($dna);

    $read->setBaseQuality([unpack("c*", $qual)]);

    my $seqlen = length($dna);

    # Clipping

    my $numclips = $seq->get_num_clips();

    print "\n\tCLIPPING\n" if ($numclips > 0);

    for (my $jclip = 0; $jclip < $numclips; $jclip++) {
	my $clip = $seq->get_clip($jclip);

	my $cliptype = $clip->get_type();
	my $clipstart = $clip->get_start();
	my $clipend = $clip->get_end();

	if ($cliptype eq 'QUAL') {
	    $read->setLowQualityLeft($clipstart - 1);
	    $read->setLowQualityRight($clipend + 1);
	} elsif ($cliptype eq 'SVEC') {
	    $seqvec = 'Unknown' unless defined($seqvec);

	    $read->addSequencingVector([$seqvec, 1, $clipstart - 1])
		if ($clipstart != 0);

	    $read->addSequencingVector([$seqvec, $clipend + 1, $seqlen])
		if ($clipend != 0);
	} elsif ($cliptype eq 'CVEC') {
	    $clonevec = 'Unknown' unless defined($clonevec);

	    $read->addCloningVector([$clonevec, 1, $clipstart - 1])
		if ($clipstart != 0);

	    $read->addCloningVector([$clonevec, $clipend + 1, $seqlen])
		if ($clipend != 0);
	}
    }

    # Tags

    my $numtags = $seq->get_num_tags();

    print "\n\tTAGS\n" if ($numtags > 0);

    for (my $jtag = 0; $jtag < $numtags; $jtag++) {
	my $tstag = $seq->get_tag($jtag);

	my $tagtype = $tstag->get_type();
	my $tagdirection = $tstag->get_direction();
	my $tagstart = $tstag->get_start();
	my $tagend = $tstag->get_end();
	my $tagtext = $tstag->get_text();

	my $tag = new Tag();

	$tag->setPosition($tagstart, $tagend);
	$tag->setStrand($tagdirection);
	$tag->setType($tagtype);
	$tag->setTagComment($tagtext);

	$read->addTag($tag);
    }


    return $read;
}
