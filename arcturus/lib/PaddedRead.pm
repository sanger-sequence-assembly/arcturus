package PaddedRead;

use strict;

use Read;

use Mapping;

our (@ISA);

@ISA = qw(Read);

my $DEBUG = 0;

#-------------------------------------------------------------------
# Constructor takes a mandatory Read instance
#-------------------------------------------------------------------

sub new {
    my $class = shift;
    my $read = shift; # mandatory Read instance

    die "Constructor of PaddedRead expects a Read instance as parameter"
    unless ($read && (ref($read) eq 'Read' || ref($read) eq 'PaddedRead'));


    my $this = $class->SUPER::new();

# copy the read contents into this

    &hcopy($read,$this);

    return $this;
}

sub hcopy {
# private: copy a hash structure
    my $hash = shift;
    my $copy = shift;

    foreach my $key (keys %$hash) {
        my $structure = $hash->{$key};
        if (ref($structure) eq 'HASH') {
            $copy->{$key} = {};
            &hcopy($structure,$copy->{$key});
        }
	elsif (ref($structure) eq 'ARRAY') {
            $copy->{$key} = [];
            &acopy($structure,$copy->{$key});
	}
	else {
            $copy->{$key} = $hash->{$key};
	}
    }
}

sub acopy {
# private: copy an array
    my $array = shift;
    my $copy = shift;

    for (my $i = 0 ; $i < scalar(@$array) ; $i++) {
        my $structure = $array->[$i];
        if (ref($structure) eq 'HASH') {
            $copy->[$i] = {};
            &hcopy($structure, $copy->[$i]);
        }
	elsif (ref($structure) eq 'ARRAY') {
            $copy->[$i] = [];
            &acopy($structure, $copy->[$i]);
	}
	else {
            $copy->[$i] = $structure;
	}
    }
}

#------------------------------------------------------------------------

sub toPadded {
    my $this = shift;
    my $mapping = shift;

# convert the contig-to-padded-read alignment into contig-to-SCF alignments
# given the input mapping (read-to-contig alignments) and read-to-SCF mappings

    return undef if ($this->{padstatus} eq 'Padded');

# get the mapping segments ordered with read position

    $mapping->analyseSegments();
    my $segments = $mapping->getSegments();

# get coefficients of the contig-to-read transform from the first segment

    my $firstsegment = $segments->[0];
    my $a = $firstsegment->getAlignment();
    my $b = $firstsegment->getOffset();
    my $lastsegment = $segments->[$#$segments];

# collect the padded-to-read alignments

    my $sequence = $this->getSequence();
    my $quality = $this->getBaseQuality();
    my $lgt = $this->getSequenceLength();

    my $padsadded = 0; 
    my $paddedsequence = '';
    my @paddedquality;
    my $paddedposition = 0;

    my $paddedtoread = new Mapping();

    my ($cstart, $rstart, $cfinal, $rfinal);

    foreach my $segment (@$segments) {
# pullout the old mapping (read-sequence-to-contig)
        my $cs = $segment->getXstart();
        $cstart = $cs unless defined $cstart;
        my $cf = $segment->getXfinis();
        $cfinal = $cf;
        my $rs = $segment->getYstart();
        my $rf = $segment->getYfinis();
# obtain the new read positions on the read by back-transform from contig
        my $nrs = $a * ($cs - $b);
        $rstart = $nrs unless defined($rstart);
        my $nrf = $a * ($cf - $b);
        $rfinal = $nrf;
# adjust the boundaries of first and last segment of the padded-to-read mapping
        if ($segment eq $firstsegment) {
            ($rs, $nrs) = (1,1);
        }
        if ($segment eq $lastsegment) {
            $rf = $lgt;
	}

# get the number of pads and insert in the sequence and quality data (if any)

        my $padstoinsert = $nrs - $paddedposition - 1;
# fill sequence and quality with pad symbols
        while ($padstoinsert--) {
            $paddedsequence .= "-";
            push @paddedquality, 0;
            $padsadded++;
        }
# and add the current segment
        $paddedsequence .= substr $sequence, $rs-1, $rf-$rs+1;
        for (my $i = $rs ; $i <= $rf ; $i++) {
            push @paddedquality, $quality->[$i-1];
        }
        $paddedposition = length($paddedsequence);

# adjust the boundary of the last segment and add to paddedtoread mapping

        $nrf = $paddedposition if ($segment eq $lastsegment);
        $paddedtoread->putSegment($nrs, $nrf, $rs, $rf);
    }

# get existing align to trace file records

    my $readtotrace = $this->getAlignToTraceMapping();

# compound padded-to-read with the previous alignToTrace information

    my $paddedtotrace = $paddedtoread->multiply($readtotrace);
    my $paddedtotraceSegments = $paddedtotrace->getSegments();
    if ($paddedtotraceSegments && @$paddedtotraceSegments) { 
        delete $this->{alignToTrace}; # clear existing records
        foreach my $segment (@$paddedtotraceSegments) {
	    my @segment = $segment->getSegment();
            $this->addAlignToTrace([@segment]);
        }
    }

# replace the existing DNA data by the new sequence and quality data

    $this->setSequence($paddedsequence);

    $this->setBaseQuality([@paddedquality]); 

# adjust the clipping boundaries

    my $lql = $this->getLowQualityLeft();
    my $lqr = $this->getLowQualityRight();
    my $cvs = $this->getCloningVector();
    my $svs = $this->getSequencingVector();

    $segments = $paddedtoread->getSegments();
    foreach my $segment (@$segments) {

# adjust low quality clipping

        if (my $nlq = $segment->getXforY($lql)) {
            $this->setLowQualityLeft($nlq);
        }
        if (my $nrq = $segment->getXforY($lqr)) {
            $this->setLowQualityRight($nrq);
        }

# update vector clippings

        foreach my $vectors ($cvs,$svs) {
# protect against undefined vector
            next unless ($vectors && @$vectors);
            foreach my $vector (@$vectors) {
                for my $i (1,2) {
                    if (my $vp = $segment->getXforY($vector->[$i])) {
                        $vector->[$i] = $vp;
		    }
                }
            }
        }
    }

# get new assembledFrom mapping (one record)

    my $contigtopadded = new Mapping($this->getReadName);

    $contigtopadded->putSegment($cstart,$cfinal,$rstart,$rfinal);

    $this->{padstatus} = 'Padded';

# return the mapping of the read to the contig (one assembled from entry)

    my $TEST = 0;
    if ($TEST && $this->getReadName =~ /1473|4517/) {
     $this->writeToCaf(*STDOUT);
     my $copyread = new PaddedRead($this);
     my $afm = $copyread->toUnpadded($contigtopadded); # test mode
     $copyread->writeToCaf(*STDOUT);
     print $afm->assembledFromToString();
    }

    return $contigtopadded;
}


sub dePad {
    my $this = shift;
    my $mapping = shift;

# transform the padded-read-to-contig alignment (input mapping) into
# read-to-contig alignments and read-to-trace-file alignment(s) given 
# the input mapping (one seqment), the padded sequence and the
# align-to-trace mappings

    return undef if ($this->{padstatus} eq 'Unpadded');

# locate the positions of pads in the sequence and build the padded-to-read map

    my $DEBUG = 0; # $DEBUG=1 if ($this->getReadName =~ /577/);
print "Read: ".$this->getReadName."\n" if $DEBUG;

    my $sequence = $this->getSequence();
    unless ($sequence) {
        print STDOUT "missing DNA in padded read ".$this->getReadName()."\n";
        return undef;
    }
    my $lgt = length($sequence);
    $sequence .= '-'; # add pad at the end
    my $quality = $this->getBaseQuality();
print "sequence\n$sequence\n\n" if $DEBUG;

# get the padded to read inserts from '-' pads in the sequence

    my @pad;
    my $pos = -1;
    my $start = 1;
    my $paddedtoread = new Mapping('padded-to-read');
    while (($pos = index($sequence,'-',$pos)) > -1) {
        my $pad = scalar(@pad);
print "pos $pos  pad $pad  start $start \n" if $DEBUG;
        unless ($start > $pos) {
            $paddedtoread->putSegment($start,$pos,$start-$pad,$pos-$pad);
        }
        push @pad, ++$pos;
        $start = $pos+1;
    }

# get existing align to trace file records

    my $paddedtotrace = $this->getAlignToTraceMapping();
    $paddedtotrace->setMappingName('padded-to-trace');
    $paddedtotrace->analyseSegments(); # order just in case
print $paddedtoread->toString."\n" if $DEBUG;
print $paddedtotrace->toString."\n" if $DEBUG;

# get possible deletions from AlignToTrace segments

    my $paddedtotraceSegments = $paddedtotrace->getSegments();

    my $deletetoread = new Mapping('delete-to-read');
    my ($pstart,$rstart,$i) = (1,1,1);
    my ($inserts,$deletes)  = (0,0);
    while ($i < scalar(@$paddedtotraceSegments)) {
        my $tail = $paddedtotraceSegments->[$i-1];
        my $lead = $paddedtotraceSegments->[$i++];
        my $xdif = $lead->getXstart - $tail->getXfinis;
        my $ydif = $lead->getYstart - $tail->getYfinis;
        if ($xdif < $ydif) {
# register and process a deletion
            $deletetoread->putSegment($pstart,$tail->getXfinis-$inserts,
                                      $rstart,$tail->getYfinis);
            $pstart = $lead->getXstart-$inserts;
            $rstart = $lead->getYstart;
            $deletes++;
        }
        elsif ($xdif > $ydif) {
# register an insert
            $inserts += ($xdif-$ydif);
#            $inserts++;
        }
    }

    my $tail = $paddedtotraceSegments->[$i-1];
#print "pstar $pstart  rstart $rstart inserts $inserts ".
#$tail->getXfinis." ".$tail->getYfinis."\n" if $DEBUG;
    $deletetoread->putSegment($pstart,$tail->getXfinis-$inserts,
                              $rstart,$tail->getYfinis);

# obtain read to trace padded to read and padded to trace
# if there are deletions, padded to read and padded to trace are to be modified
# consider three cases: 1) deletes & inserts 2) only deletes 3) only inserts

    my $readtotrace;

    if ($deletes && $inserts) {
#	$DEBUG = 1;
print "Read: ".$this->getReadName."\n" if $DEBUG;
print "The padded data were obtained by deletions and inserts\n" if $DEBUG;
print "deletes $deletes  inserts $inserts \n" if $DEBUG;
print $paddedtoread->toString."\n" if $DEBUG;
print $paddedtotrace->toString."\n" if $DEBUG;
print $deletetoread->toString."\n" if $DEBUG;

print "GETTING readtotrace \n" if $DEBUG;
        my $tracetopadded = $paddedtotrace->inverse();
        my $tracetoread = $tracetopadded->multiply($paddedtoread);
        $readtotrace = $tracetoread->inverse();
    }
    elsif ($deletes) {
# there is only one read-to-trace record
#	$DEBUG = 1;
print "Read: ".$this->getReadName."\n" if $DEBUG;
print "The padded data were obtained by deletions\n" if $DEBUG;
print "deletes $deletes  inserts $inserts \n" if $DEBUG;
print $deletetoread->toString if $DEBUG;
        $paddedtoread = $deletetoread;
        $paddedtoread->setMappingName('padded-to-read');
print $paddedtoread->toString if $DEBUG;
print "GETTING readtotrace \n" if $DEBUG;
        $paddedtotrace = $paddedtotrace->inverse;
        $readtotrace = $paddedtotrace->multiply($deletetoread,1);
print $readtotrace->toString if $DEBUG;
    }
    else {
# there are no deletions; derive read-to-trace by multiplying inverses
print "Read: ".$this->getReadName."\n" if $DEBUG;
print "deletes $deletes  inserts $inserts \n" if $DEBUG;
print $paddedtoread->toString."\n" if $DEBUG;
print $paddedtotrace->toString."\n" if $DEBUG;
print $deletetoread->toString."\n" if $DEBUG;
        my $tracetopadded = $paddedtotrace->inverse();
        my $tracetoread = $tracetopadded->multiply($paddedtoread);
        $readtotrace = $tracetoread->inverse();
    }

# replace existing readToSCF alignments 

unless ($readtotrace) {
    print "UNDEFINED readtotrace at read ".$this->getReadName()."\n"; exit;
}

    my $readtotraceSegments = $readtotrace->getSegments();
    if ($readtotraceSegments && @$readtotraceSegments) {
        delete $this->{alignToTrace};
        foreach my $segment (@$readtotraceSegments) {
            my @segment = $segment->getSegment();
            $this->addAlignToTrace([@segment]);
	}
    }

# assemble the depadded read sequence and quality data

    my @depaddedquality;
    my $depaddedsequence = '';
    my $paddedtoreadsegments = $paddedtoread->getSegments();
print $paddedtoread->toString."\n" if $DEBUG;
    foreach my $segment (@$paddedtoreadsegments) {
        my ($ps,$pf,$rs,$rf) = $segment->getSegment();
        my $length = length($depaddedsequence);
        while (++$length < $rs) {
            $depaddedsequence .= '-'; # compensate for deletions
            push @depaddedquality, 0;
        }
        $depaddedsequence .= substr $sequence,$ps-1,$pf-$ps+1;
        while ($ps <= $pf) {
            push @depaddedquality, $quality->[$ps++ - 1];
        }
    }

# get the contig to read mapping from padded to read and contig alignment

print "GETTING contig to unpadded read\n" if $DEBUG;

    my $contigtoread = $mapping->multiply($paddedtoread);

    $contigtoread->setMappingName($this->getReadName);

print $contigtoread->toString."\n" if $DEBUG;
print "END toUnpadded\n" if $DEBUG;

# replace the existing DNA data by the new sequence and quality data

    $this->setSequence($depaddedsequence);

    $this->setBaseQuality([@depaddedquality]);

# adjust the clipping boundaries

    my $lql = $this->getLowQualityLeft();
    my $lqr = $this->getLowQualityRight();
    my $cvs = $this->getCloningVector();
    my $svs = $this->getSequencingVector();

    my $segments = $paddedtoread->getSegments();
    foreach my $segment (@$segments) {

# adjust low quality clipping

        if (my $nlq = $segment->getYforX($lql)) {
#print "updating lql $lql\n" if $DEBUG;
            $this->setLowQualityLeft($nlq);
        }
        if (my $nrq = $segment->getYforX($lqr)) {
#print "updating lqr $lqr\n" if $DEBUG;
            $this->setLowQualityRight($nrq);
        }

# update vector clippings

        foreach my $vectors ($cvs,$svs) {
# protect against undefined vector
            next unless ($vectors && @$vectors);
            foreach my $vector (@$vectors) {
#print "updating @$vector\n" if $DEBUG;
                for my $i (1,2) {
                    if (my $vp = $segment->getYforX($vector->[$i])) {
#print "updating $vector->[$i] to $vp \n" if $DEBUG;
                        $vector->[$i] = $vp;
		    }
                }
            }
        }
    }

# get new assembledFrom mapping

    $this->{padstatus} = 'Unpadded';

    return $contigtoread;
}

sub setPadded {
    my $this = shift;
    my $padstatus = shift || "Padded";

    return unless ($padstatus eq "Padded" || $padstatus eq "Unpadded");

    $this->{padstatus} = $padstatus;
}

sub exportAsRead {
    my $this = shift;

    my $read = new Read();
        
# copy this contents into read

    &hcopy($this,$read);

    return $read;
}

#------------------------------------------------------------------------

1;
