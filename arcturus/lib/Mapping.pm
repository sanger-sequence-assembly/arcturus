package Mapping;

use strict;

use Segment;

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
    my $class   = shift;
    my $mapping = shift; # mapping number or name, optional

    my $this = {};

    bless $this, $class;

    $this->{readToContig}    = [];
    $this->{assembledFrom}   = [];
    $this->{alignToTrace}    = [];

    $this->setReadName($mapping);

    return $this;
}
 
#-------------------------------------------------------------------
#
#-------------------------------------------------------------------

sub getReadID {
    my $this = shift;

    return $this->{read_id};
}

sub setReadID {
    my $this = shift;

    $this->{read_id} = shift;
}

sub getReadName {
    my $this = shift;

    return $this->{readname};
}

sub setReadName {
    my $this = shift;

    $this->{readname} = shift;
}
 
#-------------------------------------------------------------------
# store alignment segments
#-------------------------------------------------------------------

sub addAlignToTrace {
# from (possibly edited) read to trace file (raw read)
# input 4 array (readstart, readfinis, tracestart, tracefinis)
    my $this = shift;

    my $segment = new Segment(@_);

    push @{$this->{alignToTrace}},$segment;

    return scalar(@{$this->{alignToTrace}});
}

sub addAssembledFrom {
# from contig to (possibly edited) read
# input 4 array (contigstart, contigfinis, readstart, readfinis) 
    my $this = shift;

    my $segment = new Segment(@_);

    push @{$this->{assembledFrom}},$segment;

    return scalar(@{$this->{assembledFrom}});
}

sub addReadToContig {
# from raw read (trace file) to consensus contig (stored in Arcturus)
# input 4 array (contigstart, contigfinis, tracestart, tracefinis)
    my $this = shift;

    my $segment = new Segment(@_);

    push @{$this->{readToContig}},$segment;

    return scalar(@{$this->{readToContig}});
}

#-------------------------------------------------------------------
# transform the assembled_from alignment(s) & align_to_SCF records 
# to read-to-contig alignments and vice-versa. The transform from
# read-to-contig to_assembled from will result in one align_to_SCF
# record; the one to align_to_SCF in one assembled_from record
#
# If there are more than one align_to_SCF records and more than one
# assembled_from records, these transformations are not each other's
# inverse. 
#-------------------------------------------------------------------

sub toReadToContig {
# from align_to_SCF & assembled_from to read-to-contig
    my $this = shift;

# check alignment consistence for alignToTrace & assembledFrom ?

    my $alignToTrace = $this->{alignToTrace};

    if (@{$this->{alignToTrace}} <= 1) {
# the read-to-contig maps are identical to the assembled_from records
        $this->{readToContig} = $this->{assembledFrom};
# if also alignToTrace is defined, test it; if it's not, ignore
        if (shift && @{$this->{alignToTrace}}) {
            my ($cs, $cf, $rs, $rf) = $this->getOverallAlignment();
            $rf = $rs + abs($cf-$cs); # SCF range defined by Assembled_from
            my $segment = $this->{alignToTrace}->[0];
            my $ts = $segment->getYstart();
            my $tf = $segment->getYfinis();
            if ($rs > $ts || $rf < $tf) {
                print STDERR "Conflicting SCF alignment $rs $rf  ($ts $tf)\n";
            }
        }
    }
    else {
# this is the big one ..
	print "to be completed\n";
# first translate the assembled from to read to contig
        $this->{readToContig} = $this->{assembledFrom};

# then weed out alignments which are consecutive in bot X and Y 
    }
    return scalar @{$this->{readToContig}};
}

sub toAlignToTrace {
# from read-to-contig to (multi) align_to_SCF & single assembled_from
    my $this = shift;

# check alignment consistence for readToContig ?

    my ($cs, $cf, $rs, $rf) = $this->getOverallAlignment();
print "overall alignment: $cs, $cf, $rs, $rf\n";

# get ONE assembled_from mapping derived from overall alignment

    $this->{assembledFrom} =[];

    return 0 unless defined $rs;

    $this->{assembledFrom}->[0] = new Segment($cs, $cf, $rs, $rs+abs($cf-$cs));

# replace any existing alignToTrace maps by current readToContig maps ..... 

    @{$this->{alignToTrace}} = @{$this->{readToContig}}; # copy, preserve the original

# .... and transform the individual trace-to-contig into read-to-trace alignments

    foreach my $segment (@{$this->{alignToTrace}}) {
	print "toTrace transform to be completed\n";
    }

    return scalar @{$this->{alignToTrace}};
}

sub toAssembledFrom {
# from read-to-contig to SINGLE align_to_SCF & (multi) assembled_from
    my $this = shift;

# check alignment consistence for readToContig ?

    my ($cs,$cf,$rs,$rf) = $this->getOverallAlignment();
print "overall alignment: $cs, $cf, $rs, $rf\n";

# replace any existing alignToTrace maps by ONE derived from overall alignment

    $this->{alignToTrace} =[];

    return 0 unless $rs;

    $this->{alignToTrace}->[0] = new Segment($rs, $rf, $rs, $rf);

# the assembledFrom maps are given by the existing readToContig maps

    $this->{assembledFrom} = $this->{readToContig};

    return scalar @{$this->{assembledFrom}};
}

#-------------------------------------------------------------------
# export of alignments
#-------------------------------------------------------------------

sub export {
# export the contig to (raw) read mappings as array of segments
    my $this = shift;

# NOTE: the segments are internally normalised (aligned) on read data
#       you may want to normalise on contig data if the segments are
#       used in a consensus calculation (and e.g. need to be sorted)
#       re: use Segment->normaliseOnX method on all segments

    $this->toReadToContig() unless @{$this->{readToContig}};

    return $this->{readToContig}; # array reference
}

sub getOverallAlignment {
    my $this = shift;

# find the first and the last segment of the readToContig map to be used for the overal map

    my ($first, $final);
    foreach my $segment (@{$this->{readToContig}}) {
# ensure the correct alignment (on read segment, it may have been changed outside after export)
        $segment->normaliseOnY();
        $first = $segment if (!defined($first) || $first->getYstart < $segment->getYstart);
        $final = $segment if (!defined($final) || $final->getYfinis > $segment->getYfinis);
    }

print "OverallAlignment UNDEFINED \n" unless $first;
    return undef if !$first;

    return ($first->getXstart, $final->getXfinis, $first->getYstart, $final->getYfinis);
}

sub assembledFromToString {
    my $this = shift;

    my $assembledFrom = "Assembled_from ".$this->getReadName()." ";

    my $string = '';
    foreach my $segment (@{$this->{assembledFrom}}) {
        $string .= $assembledFrom.$segment->toString()."\n";
    }
    return $string;
}

sub alignToTraceToString {
    my $this = shift;
    my $string = '';

    foreach my $segment (@{$this->{alignToTrace}}) {
        $string .= "Align_to_SCF ".$segment->toString()."\n";
    }
    return $string;
}

#-------------------------------------------------------------------

1;










