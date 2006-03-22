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
# transpose the dna if strand is reverse
    my $this = shift;
    my $dotranspose = shift;

    unless ($dotranspose && $this->getStrand() ne 'Reverse') {
        return $this->{DNA} || '';
    }

    return &transposeDNA($this->{DNA});
}

sub setSystematicID {
# tag type, up to 32 char
    my $this = shift;

    $this->{systematicid} = shift;
}

sub getSystematicID {
    my $this = shift;

    return $this->{systematicid} || '';
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
    my $this = shift;
    my $strand = shift;
 
    if ($strand eq 'Forward' || $strand eq 'F') {
        $this->{strand} = +1;
    }
    elsif ($strand eq 'Reverse' || $strand eq 'R') {
        $this->{strand} = -1;
    }
    else {
        $this->{strand} = 0;
    }
}

sub getStrand {
    my $this = shift;

    if (!$this->{strand}) {
        return "Unknown";
    }
    elsif ($this->{strand} > 0) {
        return "Forward";
    }
    elsif ($this->{strand} < 0) {
        return "Reverse";
    }
    else {
        return "Unknown";
    }
}

sub setTagComment {
    my $this = shift;

    $this->{tagcomment} = shift;
}

sub getTagComment {
    my $this = shift;

    return $this->{tagcomment} || '';
}

sub setTagID {
    my $this = shift;

    $this->{tag_id} = shift;
}

sub getTagID {
    my $this = shift;

    return $this->{tag_id};
}

sub setTagSequenceID {
    my $this = shift;

    $this->{tsid} = shift;
}

sub getTagSequenceID {
    my $this = shift;

    return $this->{tsid} || 0;
}

sub setTagSequenceName {
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
# transpose a tag by applying a linear transformation
# (apply only to contig tags)
# returns new Tag instance (or undef)
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

    if ($tpos[0] > $window && $tpos[1] > $window or $tpos[0] < 1 && $tpos[1] < 1) {
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

# transpose the strand (if needed) (transpose DNA on export only)

    my $strand = $this->getStrand();
    if ($strand eq 'Forward' and $align < 0) {
        $strand = 'Reverse';
    }
    elsif ($strand eq 'Reverse' and $align < 0) {
        $strand = 'Forward';
    }

# get a systematic ID if not already defined

    $this->composeName() unless $this->getSystematicID();

# transport the comment; add import details, if any

    my $newcomment = $this->getComment() || '';
    $newcomment .= ' ' if $newcomment;
    $newcomment .= "imported ".$this->getSystematicID();
    $newcomment .= " truncated" if $truncated;
    $newcomment .= " frame-shifted" if ($offset->[0] != $offset->[1]);

# create (spawn) a new tag instance

    my $newtag = $this->new($this->{label});

    $newtag->setTagID($this->getTagID());
# TAG2CONTIG table items
    $newtag->setPosition(@tpos); 
    $newtag->setStrand($strand);
    $newtag->setComment($newcomment);
# CONTIGTAG table items
    $newtag->setType($this->getType());
    $newtag->setSystematicID($this->getSystematicID());
    $newtag->setTagSequenceID($this->getTagSequenceID());
    $newtag->setTagComment($this->getTagComment());
# TAGSEQUENCE table items
    $newtag->setTagSequenceName($this->getTagSequenceName()); 
    $newtag->setDNA($this->getDNA());

    return $newtag;
}

sub composeName {
# compose a descriptive name from tag data
    my $this = shift;

    return undef unless $this->getSequenceID();

    my $name = $this->{label} || '';
    $name .= ":" if $name;
    $name .= sprintf ("%9d",$this->getSequenceID());
    my ($ps, $pf) = $this->getPosition();
    $name .= sprintf ("/%11d", $ps);
    $name .= sprintf ("-%11d", $pf);
    $name =~ s/\s+//g; # remove any blanks

    $this->setSystematicID($name);
}

sub transposeDNA {
# reverse complement an input DNA sequence TO BE TESTED
    my $string = shift;

    return undef unless $string;

    my $output = '';
    my $length = length($string);
    while ($length--) {
        my $base = substr $string,$length,1;
        $base =~ tr/ACGTacgt/TGCATGCA/;
        $output .= $base;
    }

    return $output;
}

#----------------------------------------------------------------------

sub isEqual {
# compare this tag with input tag
    my $this = shift;
    my $tag  = shift;
    my %options = @_;

# compare tag type

    return 0 unless ($this->getType() eq $tag->getType());

# compare tag position range

    my @spos = $this->getPosition();
    my @tpos = $tag->getPosition();

    return 0 unless (scalar(@spos) && scalar(@spos) == scalar(@tpos));
    return 0 if ($spos[0] != $tpos[0]);
    return 0 if ($spos[1] != $tpos[1]);

# compare tag comments

    if ($this->getTagComment() =~ /\S/ && $tag->getTagComment() =~ /\S/) {
# both comments defined
        unless ($this->getTagComment() eq $tag->getTagComment()) {
# the tags may be different, do a more detailed comparison using a cleaned version
            my $itnop = $options{ignorenameofpattern}; # e.g.: oligo's
            unless (&cleanup($this->getTagComment(),$itnop) 
                 eq &cleanup( $tag->getTagComment(),$itnop)) {
   	        return 0;
            }
	}
    }
    elsif ($this->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment
        $tag->setTagComment($this->getTagComment()) if $options{copycom};
    }
    elsif  ($tag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment
        $this->setTagComment($tag->getTagComment()) if $options{copycom};
    }

# compare strands (optional)

    if ($options{includestrand}) {

        return 0 unless ( $tag->getStrand() eq 'Unknown' ||
                         $this->getStrand() eq 'Unknown' ||
                         $this->getStrand() eq $tag->getStrand());
    }

# the tags are identical

    if ($options{copy}) {
# copy tag ID, tag sequence ID and systematic ID, if not already defined
        unless ($tag->getTagID()) {
            $tag->setTagID($this->getTagID());
        }
        unless ($tag->getTagSequenceID()) {
            $tag->setTagSequenceID($this->getTagSequenceID());
        }
        unless ($tag->getSystematicID()) {
           $tag->setSystematicID($this->getSystematicID());
        }
    }

    return 1
}

sub cleanup {
# private method cleanup comments 
    my $comment = shift;
    my $itnop = shift; # special treatment for e.g. auto-generated oligo names

# remove quotes, '\n\' and shrink blankspace into a single blank

    $comment =~ s/^\s*([\"\'])\s*(.*)\1\s*$/$2/;
    $comment =~ s/^\s+|\s+$//g; # remove leading & trailing blank
    $comment =~ s/\\n\\/ /g; # replace by blank space
    $comment =~ s/\s+/ /g; # shrink blank space

    $comment =~ s/^$itnop// if $itnop; # remove if present at begin
   
    return $comment;
}

#----------------------------------------------------------------------

sub writeToCaf {
    my $this = shift;
    my $FILE = shift; # optional output file handle

    my $type = $this->getType();
    my @pos  = $this->getPosition();
    my $tagcomment = $this->getTagComment();
    $tagcomment =~ s/\\n\\/\\n\\\n/g;

    my $descent = $this->getComment();

    my $string = "Tag $type ";
    $string .= "@pos " unless ($type eq "NOTE");
    $string .= "\"$tagcomment\"" if $tagcomment;
    $string .= "\n";
    $string .= "Tag INFO $descent\n" if $descent; # INFO tag only

    print $FILE $string if $FILE;

    return $string;
}

sub dump {
    my $tag = shift;
    my $FILE = shift; # optional file handle

    my $report = "Tag instance $tag\n";
    $report .= "sequence ID       ".($tag->getSequenceID() || 0)."\n";
    $report .= "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    my @position = $tag->getPosition();
    $report .= "position          '@position'\n";
    $report .= "strand            ".($tag->getStrand()  || 'undef')."\n";
    $report .= "comment           ".($tag->getComment() || 'undef')."\n\n";
    $report .= "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    $report .= "tag type          ".($tag->getType()    || 'undef')."\n";
    $report .= "systematic ID     ".($tag->getSystematicID()  || 'undef')."\n";
    $report .= "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    $report .= "tag comment       ".($tag->getTagComment()    || 'undef')."\n\n";
    $report .= "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    $report .= "tag sequence name ".($tag->getTagSequenceName() || 'undef')."\n";
    $report .= "sequence          ".($tag->getDNA() || 'undef')."\n";

    print $FILE $report  if $FILE;

    return $report;
}

#----------------------------------------------------------------------

1;
