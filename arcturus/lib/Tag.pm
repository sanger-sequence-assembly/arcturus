package Tag;

use strict;

# 



#----------------------------------------------------------------------

sub new {
# constructor
    my $class = shift;
    my $label = shift;

    my $this = {};

    bless $this, $class;

    $this->{label} = $label;

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

    if ($this->{strand} > 0) {
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

sub transpose {
# transpose a tag from another sequence to this sequence
    my $this = shift;
    my $Tag = shift;
}

#----------------------------------------------------------------------

sub writeToCaf {
    my $this = shift;
    my $FILE = shift; # obligatory output file handle

    die "Tag->writeToCaf expect a FileHandle as parameter" unless $FILE;

    my $type = $this->getType();
    my @pos  = $this->getPosition();
    my $comment = $this->getComment();

    print $FILE "Tag ($this->{label}) @pos ";
    print $FILE "\"$comment\"" if $comment;
    print $FILE "\n";
}

#----------------------------------------------------------------------

sub readTag {
    my $this = shift;
    my $data = shift;
    print "readTag detected $data\n";
}

sub editReplace {
    my $this = shift;
    my $data = shift;
    print "editReplace tag detected $data\n";

}

sub editDelete {
    my $this = shift;
    my $data = shift;
    print "editDelete tag detected $data\n";

}

sub contigTag {
    my $this = shift;
    my $data = shift;
#    print "Contig TAG detected $data\n";

}

1;


