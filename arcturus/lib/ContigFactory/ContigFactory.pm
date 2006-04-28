package ContigFactory;

use strict;

use Contig;

# ----------------------------------------------------------------------------
# building Contig instances from a Fasta file
# ----------------------------------------------------------------------------

sub fastaFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $FASTA = shift; # file handle to the fasta file 
    my %options = @_;

    my $fastacontigs = [];

    undef my $contig;
    my $sequence = '';

    my $line = 0;
    my $report = $options{report};
    while (defined (my $record = <$FASTA>)) {

        $line++;
        if ($report && ($line%$report == 0)) {
            print STDERR "processing line $line\n";
	}

        if ($record !~ /\S/) {
            next; # empty
	}
# new contig 
        elsif ($record =~ /\>(\S+)/) {
# add existing contig to output stack
            if ($contig && $sequence) {
                $contig->setSequence($sequence);
                push @$fastacontigs, $contig;
	    }
# open a new contig object
            $contig = new Contig();
# assign name
            my $contigname = $1;
            $contig->setContigName($contigname);
# and reset sequence
            $sequence = '';
	}

        elsif ($contig) {
# append DNA string to existing sequence
            $record =~ s/\s+//g; # remove blanks
	    $sequence .= $record;
        }
        else {
            print STDERR "Ignore data: $record\n";
	}
    }
# add the last one to the stack 
    push @$fastacontigs, $contig if $contig;

    return $fastacontigs;
}

#-----------------------------------------------------------------------------
# building Contigs from CAF file 
#-----------------------------------------------------------------------------

sub cafFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $CAF   = shift; # file handle to the caf file 
    my %options = @_;

    my $cafcontigs = [];

    return $cafcontigs;
}

#-----------------------------------------------------------------------------

1;

