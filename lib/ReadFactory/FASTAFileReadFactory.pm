package FASTAFileReadFactory;

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


use strict;

use ReadFactory;

use Read;
use Tag;

use vars qw(@ISA);

@ISA = qw(ReadFactory);

sub new {
    my $type = shift;

    my $this = $type->SUPER::new();

    my ($fastafile, $ligation, $qvalue, $qualityfile);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$fastafile = shift if ($nextword eq 'fastafile');

	$ligation = shift if ($nextword eq 'ligation');

	$qualityfile = shift if ($nextword eq 'qualityfile');

	$qvalue = shift if ($nextword eq 'defaultquality');
    }

    die "FASTA fle name not defined" unless defined($fastafile);

    die "FASTA file \"$fastafile\" does not exist" unless -f $fastafile;

    die "Quality file \"$qualityfile\" does not exist"
	if (defined($qualityfile) && ! -f $qualityfile);

    $this->{fastafile} = $fastafile;

    $this->{ligation} = defined($ligation) ? $ligation : "consensus";

    $this->{defaultquality} = defined($qvalue) ? $qvalue : 2;

    $this->{qualityfile} = $qualityfile;

    return $this;
}

sub getReadNamesToLoad {
    my $this = shift;

    my $sequences = $this->readFASTAFile();

    $this->{sequences} = $sequences;

    $this->{qualities} = $this->readQualityFile();

    return [keys(%{$sequences})];
}

sub readFASTAFile {
    my $this = shift;

    my $sequences = {};

    open(FASTA, $this->{fastafile});

    my ($readname, $readseq);

    $readseq = '';

    while (my $line = <FASTA>) {
	chop($line);

	if ($line =~ /^>(\S+)/) {
	    if (defined($readname)) {
		$sequences->{$readname} = $readseq;
		$readseq = '';
	    }

	    $readname = $1;
	} elsif ($line =~ /^[ACGTNXacgtnx]+$/) {
	    $readseq .= $line;
	}
    }

    close(FASTA);

    if (defined($readname) && length($readseq) > 0) {
	$sequences->{$readname} = $readseq;
    }

    return $sequences;
}

sub readQualityFile {
    my $this = shift;

    return undef unless defined($this->{qualityfile});

    my $qualities = {};

    open(QUALITY, $this->{qualityfile});

    my ($readname, $readqual);

    $readqual = '';

    while (my $line = <QUALITY>) {
	chop($line);

	if ($line =~ /^>(\S+)/) {
	    if (defined($readname)) {
		$qualities->{$readname} = &convertQuality($readqual);
		$readqual = '';
	    }

	    $readname = $1;
	} elsif ($line =~ /^[\s\d]+$/) {
	    $readqual .= ' ' if (length($readqual) > 0);
	    $readqual .= $line;
	}
    }

    close(QUALITY);

    if (defined($readname) && length($readqual) > 0) {
	$qualities->{$readname} = &convertQuality($readqual);
    }

    return $qualities;
}

sub convertQuality {
    my $qualstring = shift;

    my @qualarray = split(/\s+/, $qualstring);

    return [@qualarray];
}

sub getReadByName {
    my $this = shift;

    my $readname = shift;

    my $dna = $this->{sequences}->{$readname};
    my $qual = $this->{qualities}->{$readname};

    return undef unless defined($dna);

    my $read = new Read($readname);

    # Strand

    $read->setStrand("Forward");

    # Primer

    $read->setPrimer("Unknown_Primer");

    # Chemistry

    $read->setChemistry("Dye_terminator");

    # Asped date

    #$read->setAspedDate($asped);

    # Basecaller

    $read->setBaseCaller("phred");

    # Process status

    $read->setProcessStatus("PASS");

    # Template and ligation

    $read->setTemplate($readname);

    $read->setLigation($this->{ligation});

    # DNA

    $read->setSequence($dna);

    # Base quality

    my @qual = ();

    if (defined($qual)) {
	$read->setBaseQuality($qual);
    } else {
	my $dnalen = length($dna);

	my $qvalue = $this->{defaultquality};

	for (my $i = 0; $i < $dnalen; $i++) {
	    push @qual, $qvalue;
	}

	$read->setBaseQuality([@qual]);
    }

    # Clipping

    $read->setLowQualityLeft(1);
    $read->setLowQualityRight(length($dna));

    return $read;
}
