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

sub setDescent {
    my $this = shift;
    my $text = shift;

    $this->{descent} .= $text if $text;
}

sub getDescent {
    my $this = shift;

    return $this->{descent} || '';
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

#sub setName {
# tag type, up to 32 char
#    my $this = shift;

#    $this->{name} = shift;
#}

#sub getName {
#    my $this = shift;

#    return $this->{name} || '';
#}

sub setSystematicID {
# tag type, up to 32 char
    my $this = shift;

    $this->{systematicid} = shift;
}

sub getSystematicID {
    my $this = shift;

    return $this->{systematicid} || '';
}

sub composeName {
# compose a descriptive name from tag data
    my $this = shift;

    my $name = $this->{label} || '';
    $name .= ":" if $name;
    $name .= sprintf ("%9d",$this->getSequenceID());
    my ($ps, $pf) = $this->getPosition();
    $name .= sprintf ("/%11d", $ps);
    $name .= sprintf ("-%11d", $pf);
    $name =~ s/\s+//g; # remove any blanks

    $this->setSystematicID($name);
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

sub setTagSequenceName {
# tag type, 4 char abbreviation
    my $this = shift;

    $this->{tsname} = shift;
}

sub getTagSequenceName {
    my $this = shift;

    return $this->{tsname} || '';
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

sub transpose {
# transpose a tag by applying a linear transformation, return new Tag (or undef)
    my $this = shift;
    my $align = shift;
    my $offset = shift; # array length 2 with offset at begin and end
    my $window = shift || 1; # position in range 1 .. window

# transpose the position range using the offset info. An undefined offset
# indicates a boundery outside the range 1 .. length; adjust accordingly
   
    return undef unless (defined($offset->[0]) && defined($offset->[1])); 

    my @tpos = $this->getPosition();

    for my $i (0,1) {
        $tpos[$i] *= $align if ($align eq -1);
        $tpos[$i] += $offset->[$i];
    }

    if ($tpos[0] > $window && $tpos[1] > $window or $tpos[0] < 0 && $tpos[1] < 0) {
# the transposed tag is completely out of range
        return undef;
    }

# adjust boundaries to ensure tag position inside allowed window
    
    my $truncated;
    for my $i (0,1) {
        if ($tpos[$i] > $window) {
            $tpos[$i] = $window;
            $truncated++;
        }
        elsif ($tpos[$i] <= 0) {
            $tpos[$i] = 1;
            $truncated++;
	}
    }

    @tpos = sort {$a <=> $b} @tpos if @tpos;

# transpose the strand (if needed); we don't transpose DNA

    my $strand = $this->getStrand();
    if ($strand eq 'Forward' and $align < 0) {
        $strand = 'Reverse';
    }
    elsif ($strand eq 'Reverse' and $align < 0) {
        $strand = 'Forward';
    }

# create (spawn) a new tag instance

    my $newtag = $this->new($this->{label});

    $newtag->setComment($this->getComment());
    $newtag->setDNA($this->getDNA());
    $this->composeName() unless $this->getSystematicID();
    $newtag->setSystematicID($this->getSystematicID());
    $newtag->setTagSequenceName($this->getTagSequenceName());
    $newtag->setPosition(@tpos);
    $newtag->setStrand($strand);
    $newtag->setType($this->getType());

# finally compose the imported tag history; to be printed to caf only? 

    $newtag->setDescent("imported ".$this->getSystematicID);
    $newtag->setDescent(" truncated") if $truncated;
    $newtag->setDescent(" frame-shifted") if ($offset->[0] != $offset->[1]);

    return $newtag;
}

#----------------------------------------------------------------------

my $etest=0;
sub isEqual {
# compare tis tag with input tag
    my $this = shift;
    my $tag  = shift;

# compare tag type

print "Tag comparison: ".$this->getType." against ".$tag->getType."\n" if $etest;
    return 0 unless ($this->getType() eq $tag->getType());

# compare tag position range

    my @spos = $this->getPosition();
    my @tpos = $tag->getPosition();
print "  position: @spos  against  @tpos \n" if $etest;

    return 0 unless (scalar(@spos) && scalar(@spos) == scalar(@tpos));
    return 0 if ($spos[0] != $tpos[0]);
    return 0 if ($spos[1] != $tpos[1]);

# compare strands

    print "   strands: ".$this->getStrand." against ".$tag->getStrand."\n" if $etest;
    return 0 unless ($this->getStrand() eq $tag->getStrand());

# finally compare comments

    print "  comment: ".$this->getComment."\n against ".$tag->getComment."\n" if $etest;
    return 0 unless ($this->getComment() eq $tag->getComment());

# the tags are identical:
print "Tags are EQUAL \n" if $etest;
$etest-- if $etest;

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
    $comment =~ s/\\n\\/\\n\\\n/g;

    my $descent = $this->getDescent();

    print $FILE "Tag $type ";
    print $FILE "@pos " unless ($type eq "NOTE");
    print $FILE "\"$comment\"" if $comment;
    print $FILE " $descent" if $descent;
    print $FILE "\n";
}

#----------------------------------------------------------------------

1;
