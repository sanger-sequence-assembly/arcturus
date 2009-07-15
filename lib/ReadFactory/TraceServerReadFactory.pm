package TraceServerReadFactory;

use strict;

use TraceServer;
use ReadFactory;

use Read;
use Tag;

use vars qw(@ISA);

@ISA = qw(ReadFactory);

sub new {
    my $type = shift;

    my $this = $type->SUPER::new();

    my ($group, $minreadid, $maxreads, $status, $filter);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$group = shift if ($nextword eq 'group');

	$minreadid = shift if ($nextword eq 'minreadid');

	$maxreads = shift if ($nextword eq 'maxreads');

	$status = shift if ($nextword eq 'status');

	$filter = shift if ($nextword eq 'readnamelike');
    }

    die "No group specified" unless defined($group);

    $this->{group} = $group;

    my $ts = TraceServer->new(TS_DIRECT, TS_READ_ONLY, "");

    die "Unable to connect to the trace server" unless defined($ts);

    $this->{traceserver} = $ts;

    my $tsgroup = $ts->get_group($group, 'PASS');

    die "Group $group not in trace server" unless defined($tsgroup);

    $this->{minreadid} = $minreadid;

    $this->{maxreads} = $maxreads;

    $this->{status} = defined($status) ? $status : "PASS";

    $this->{filter} = $filter if defined($filter);

    $this->{readcount} = 0;

    return $this;
}

sub getReadNamesToLoad {
    my $this = shift;

    my $ts = $this->{traceserver};

    my $group = $this->{group};

    my $tsgroup = $ts->get_group($group, $this->{'status'});

    my $grit = $tsgroup->get_iterator(1);

    my $minreadid = $this->{minreadid};

    my $filter = $this->{filter};

    $grit->set($minreadid) if defined($minreadid);

    my $readnames = [];

    while (my $seq_id = $grit->next()) {
	my $read = $ts->get_read_by_seq_id($seq_id);
        next if (defined($filter) && $read->get_name() !~ /$filter/);       
	push @{$readnames}, $read->get_name();
    }

    return $readnames;
}

sub getReadByName {
    my $this = shift;

    my $readname = shift;

    my $ts = $this->{traceserver};

    my $tsread = $ts->get_read_by_name($readname);

    return undef unless defined($tsread);

    my $seq = $tsread->get_sequence();

    my $traceid = $seq->get_id();

    my $read = new Read($readname);

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

    if (defined($asped)) {
	my @asped = gmtime($asped);

	$asped = sprintf("%04d-%02d-%02d", 1900+$asped[5],1+$asped[4],$asped[3]);

	$read->setAspedDate($asped);
    } else {
	print STDERR "Read $readname ($traceid) has no RUN_DATETIME\n";
    }

    # Basecaller

    $read->setBaseCaller("phred");

    # Process status

    my $pstatus = $tsread->get_attribute(TSR_STATUS_DESCRIPTION);

    $read->setProcessStatus($pstatus);

    # Trace archive identifier

    $read->setTraceArchiveIdentifier($traceid);

    # Ligation and clone data

    my ($clone, $ligation, $seqvec, $template, $libsize, $libsigma, $clonevec);

    for (my $dnasrc = $tsread->get_dnasource();
	 defined($dnasrc);
	 $dnasrc = $dnasrc->get_parent()) {
	my ($srcclass,$srcname) = split(/::/, $dnasrc->get_name());

	my $srctype = $dnasrc->get_type(); 

	if ($srctype eq 'clone') {
	    my ($srclibclass,$srclibname) = split(/::/, $dnasrc->get_library_name());

	    if ($srcclass eq 'SUBCLONE' && !defined($template)) {
		$template = $srcname;
		$ligation = $srclibname;
		$libsize = $dnasrc->get_library_size();
		$libsigma = $dnasrc->get_library_stddev();
		$seqvec = $dnasrc->get_library_vector();
	    } elsif ($srcclass eq 'CLONE') {
		$clone = $srcname;
		$clonevec = $dnasrc->get_library_vector();
	    }
	} elsif ($srctype eq 'pcr') {
	    my ($srclibclass,$srclibname) = split(/::/, $dnasrc->get_pcr_name());
	    $ligation = $srclibname unless defined($ligation);
	    $libsize = 0 unless defined($libsize);
	    $read->setPrimer("Custom");
	    my $junk;
	    ($template, $junk) = split(/\./, $readname);
	}
    }

    if (defined($template)) {
	$read->setTemplate($template);
    } else {
	print STDERR "Read $readname ($traceid) has no template\n";
    }

    if (defined($ligation)) {
	$read->setLigation($ligation);
    } else {
	print STDERR "Read $readname ($traceid) has no ligation\n";
    }

    if (defined($clone)) {
	$read->setClone($clone);
    } else {
	print STDERR "Read $readname ($traceid) has no clone\n";
    }
 
    if (defined($libsize)) {
	my $imin = $libsize;
	my $imax = $libsize;

	if (defined($libsigma)) {
	    $imin -= $libsigma;
	    $imax += $libsigma;
	}

	$read->setInsertSize([$imin, $imax]);
    } else {
	print STDERR "Read $readname ($traceid) has no insert size\n";
    }

    # DNA and quality

    my $dna = $seq->get_dna();

    my $seqlen = 0;

    if (defined($dna)) {
	$read->setSequence($dna);
	$seqlen = length($dna);
    } else {
	print STDERR "Read $readname ($traceid) has no DNA\n";
    }

    my $qual = $tsread->get_confidence()->get_phred();

    if (defined($qual)) {
	$read->setBaseQuality([unpack("c*", $qual)]);
    } else {
	print STDERR "Read $readname ($traceid) has no DNA\n";
    }

    # Clipping

    my $numclips = $seq->get_num_clips();

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
