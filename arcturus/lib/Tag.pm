package Tag;

use strict;

#----------------------------------------------------------------------

sub new {
# constructor
    my $prototype = shift;

    my $class = ref($prototype) || $prototype;

    my $this = {};

    bless $this, $class;

    $this->{label} = shift;

    return $this;
}

#----------------------------------------------------------------------

sub setComment {
    my $this = shift;

    $this->{comment} = shift;
}

sub getComment {
    my $this = shift;

    return $this->{comment} || '';
}

sub setDNA {
# DNA sequence of (special) tags, e.g. oligos
    my $this = shift;

    $this->{DNA} = shift;
}

sub getDNA {
    my $this = shift;

    return $this->{DNA} || '';
}

sub setName {
# tag type, 4 char abbreviation
    my $this = shift;

    $this->{name} = shift;
}

sub getName {
    my $this = shift;

    return $this->{name} || '';
}

sub setPosition {
# begin and end position in read or contig sequence
    my $this = shift;

    my @pos = (shift, shift);
    $this->{position} = [@pos];
}

sub getPosition {
    my $this = shift;

    $this->{position} = [] unless $this->{position};
    return @{$this->{position}};
}

sub setSequenceID {
# read or contig sequence ID
    my $this = shift;

    $this->{seq_id} = shift;
}

sub getSequenceID {
    my $this = shift;

    return $this->{seq_id} || '';
}

sub setStrand {
# tag type, 4 char abbreviation
    my $this = shift;
    my $strand = shift;
 
    if ($strand eq 'Forward') {
        $this->{strand} = +1;
    }
    elsif ($strand eq 'Reverse') {
        $this->{strand} = -1;
    }
}

sub getStrand {
    my $this = shift;

    if (!$this->{strand} || $this->{strand} > 0) {
        return "Forward";
    }
    elsif ($this->{strand} < 0) {
        return "Reverse";
    }    
}

sub setType {
# tag type, 4 char abbreviation
    my $this = shift;

    $this->{type} = shift;
}

sub getType {
    my $this = shift;

    return $this->{type} || '';
}

#----------------------------------------------------------------------

my %inverse; # class variable

sub transpose {
# transpose a tag by applying a linear transformation, return new Tag
    my $this = shift;
    my $align = shift;
    my $offset = shift;

# transpose the position

    my @tpos = $this->getPosition();

    for my $i (0,1) {
        $tpos[$i] *= $align if ($align eq -1);
        $tpos[$i] += $offset;
    }

# transpose the strand (if needed)

    my $strand = $this->getStrand();
    if ($strand eq 'Forward' and $align < 0) {
        $strand = 'Reverse';
    }
    elsif ($strand eq 'Reverse' and $align < 0) {
        $strand = 'Forward';
    }

# transpose the DNA, if applicable

    my $newdna;
    if (my $dna = $this->getDNA()) {
        unless (keys %inverse) {
            %inverse = (A => 'T', T => 'A', C => 'G', G => 'C',
                        a => 't', t => 'a', c => 'g', g => 'c');
        }
        my $length = length($dna);
        for my $i (1 .. $length) {
            my $base = substr $dna, $length-$i, 1;
            my $newbase = $inverse{$base} || $base;
            $newdna .= $newbase;
        }
    }

# create (spawn) a new tag instance

    my $newtag = $this->new($this->{label});

    $newtag->setComment($this->setComment());
    $newtag->setDNA($newdna) if $newdna;
    $newtag->setName($this->getName());
    $newtag->setPosition(@tpos);
    $newtag->setStrand($strand);
    $newtag->setType($this->getType());

    return $newtag;
}

#----------------------------------------------------------------------

sub isEqual {
# compare tis tag with input tag
    my $this = shift;
    my $tag  = shift;

# compare tag type

    return 0 unless ($this->getType() eq $tag->getType());

# compare tag position range

    my $spos = $this->getPosition();
    my $tpos = $tag->getPosition();

    return 0 unless (@$spos == @$tpos);
    return 0 if (@$spos && $spos->[0] != $tpos->[0]);
    return 0 if (@$spos && $spos->[1] != $tpos->[1]);

# compare strands

    return 0 unless ($this->getStrand() eq $tag->getStrand());

# finally compare comments

    return 0 unless ($this->getComment() eq $tag->getComment());

# the tags are identical:

    return 1;
}

#----------------------------------------------------------------------

sub writeToCaf {
    my $this = shift;
    my $FILE = shift; # obligatory output file handle

    die "Tag->writeToCaf expect a FileHandle as parameter" unless $FILE;

    my $type = $this->getType();
    my @pos  = $this->getPosition();
    my $comment = $this->getComment();

    print $FILE "Tag ($this->{label}) $type ";
    print $FILE "@pos " unless ($type eq "NOTE");
    print $FILE "\"$comment\"" if $comment;
    print $FILE "\n";
}

#----------------------------------------------------------------------

1;
