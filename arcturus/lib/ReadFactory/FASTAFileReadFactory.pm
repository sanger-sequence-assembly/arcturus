package FASTAFileReadFactory;

use strict;

use ReadFactory;

use Read;
use Tag;

use vars qw(@ISA);

@ISA = qw(ReadFactory);

sub new {
    my $type = shift;

    my $this = $type->SUPER::new();

    my ($fastafile, $ligation, $qvalue);

    while (my $nextword = shift) {
	$nextword =~ s/^\-//;

	$fastafile = shift if ($nextword eq 'fastafile');

	$ligation = shift if ($nextword eq 'ligation');

	$qvalue = shift if ($nextword eq 'defaultquality');
    }

    die "FASTA fle name not defined" unless defined($fastafile);

    die "FASTA file \"$fastafile\" does not exist" unless -f $fastafile;

    $this->{fastafile} = $fastafile;

    $this->{ligation} = defined($ligation) ? $ligation : "consensus";

    $this->{defaultquality} = defined($qvalue) ? $qvalue : 2;

    return $this;
}

sub getReadNamesToLoad {
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

    $this->{sequences} = $sequences;

    return [keys(%{$sequences})];
}

sub getReadByName {
    my $this = shift;

    my $readname = shift;

    my $dna = $this->{sequences}->{$readname};

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

    my $dnalen = length($dna);

    my $qvalue = $this->{defaultquality};

    for (my $i = 0; $i < $dnalen; $i++) {
	push @qual, $qvalue;
    }

    $read->setBaseQuality([@qual]);

    # Clipping

    $read->setLowQualityLeft(1);
    $read->setLowQualityRight(length($dna));

    return $read;
}
