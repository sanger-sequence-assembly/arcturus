package Tag;

use strict;

use Mapping;

#----------------------------------------------------------------------

sub new {
# constructor
    my $prototype = shift;

    my $class = ref($prototype) || $prototype;

    my $this = {};

    bless $this, $class;

    $this->setHost(@_);

    return $this;
}

#----------------------------------------------------------------------

sub setComment {
    my $this = shift;
    my $text = shift;
    my %options = @_;

    if ($options{append}) {
        $this->{comment} .= ' ' if $this->{comment};
        $this->{comment} .= $text;
    }
    else {
        $this->{comment} = $text;
    }
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
# the DNA string is assumed to correspond to the forward strand
# reverse-complement the dna if strand is reverse AND if so specified
    my $this = shift;
    my %options = @_; # transpose

    unless ($options{transpose} && $this->getStrand() eq 'Reverse') {
        return $this->{DNA} || '';
    }

    my $dna = inverse($this->{DNA} || '');
    $dna =~ tr/ACGTacgt/TGCAtgca/ if $dna;
    return $dna;
}

sub setHost {
# instance of host object
    my $this = shift;
    $this->{host} = shift;
}

sub getHost {
# return instance of host
    my $this = shift;
    return $this->{host};
}

sub getHostClass {
# return type of host
    my $this = shift;
    my $host = $this->getHost();
    return ref($host) || $host || '';
}

# positions are stored as begin-end pairs (array of arrays)

sub setPosition {
# begin and end position in read or contig sequence
    my $this = shift;
    my @position = (shift,shift);
    my %options = @_;

    @position = sort {$a <=> $b} @position; # ensure ordering of segment
# add this position pair to the buffer
    undef $this->{position} unless $options{join};
    unless (defined($this->{position})) {
        $this->{position} = [];
    }
    my $positionpairs = $this->{position};

    push @$positionpairs,[@position];
}

sub getPosition {
# return the specified position, default the first pair
    my $this = shift;
    my $pair = shift || 0; # number of the pair

    my $positionpairs = $this->{position};
    return undef if ($pair < 0 || $pair >= @$positionpairs); # does not exist
    
    return @{$positionpairs->[$pair]};
}

sub isJoined {
# returns number of position pairs
    my $this = shift;

    my $positionpairs = $this->{position};
    return undef unless defined $positionpairs;
# numericall sort the positions in the join (ensure ordering)
    @$positionpairs = sort {$a->[0] <=> $b->[0]} @$positionpairs;
    return scalar(@$positionpairs) - 1;    
}

sub getPositionLeft {
    my $this = shift;

    my @position = $this->getPosition();
    return $position[0];
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

# measures of tag size

sub getSize {
# returns total sequence length occupied by tag 
    my $this = shift;

    my $part = $this->isJoined();
    return undef unless defined($part);

    $part++;
    my $size = 0.0;
    while ($part--) {
        my @segment = $this->getPosition($part);
        $size += ($segment[1] - $segment[0] + 1);
    }

    return $size;
} 

sub getSpan {
# returns the total distance on the sequence occupied by the tag  
    my $this = shift;

    my $part = $this->isJoined();
    return undef unless defined($part);

    my @pf = $this->getPosition(0);     # first segment;
    my @pl = $this->getPosition($part); # last  segment;
    return $pl[1] - $pf[0] + 1;
}

# orientation

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

sub setSystematicID {
# tag type, up to 32 char
    my $this = shift;

    $this->{systematicid} = shift;
}

sub getSystematicID {
    my $this = shift;

    return $this->{systematicid} || '';
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

sub processTagPlaceHolderName {
# substitute (possible) placeholder name of the tag sequence & comment
    my $this = shift;

    my $seq_id = $this->getSequenceID();
    return undef unless $seq_id; # seq_id must be defined

# a placeholder name is specified with a sequence name value like '<name>'

    my $name = $this->getTagSequenceName();
    return 0 unless ($name && $name =~ /^\<(\w+)\>$/); # of form '<name>'
print STDOUT "processTagPlaceHolderName: $name \n";

    $name = $1; # get the name root between the bracket 

# replace the tag sequence name by one generated from 'name' & the sequence ID

    my $randomnumber = int(rand(100)); # from 0 to 99 
    my $newname = $name.sprintf("%lx%02d",$seq_id,$randomnumber);
# ok, adopt the new name as tag sequence name
    $this->setTagSequenceName($newname);

# and similarly, if the place holder appears in the comment, substitute
 
    if (my $comment = $this->getTagComment()) {
        if ($comment =~ s/\<$name\>/$newname/) {
            $this->setTagComment($comment);
	}
    }

    return 1;
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

# print STDERR "Tag::transpose used\n";

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

    &composeName($this) unless $this->getSystematicID();

# transport the comment; add import details, if any

    my $newcomment = $this->getComment() || '';
    $newcomment .= ' ' if $newcomment;
    $newcomment .= "imported ".$this->getSystematicID();
    $newcomment .= " truncated" if $truncated;
    $newcomment .= " frame-shifted" if ($offset->[0] != $offset->[1]);

# create (spawn) a new tag instance

    my $newtag = $this->new($this->getHost());

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

    my $name = $this->getHostClass() || '';
    $name .= "Tag:" if $name;
    $name .= sprintf ("%9d",$this->getSequenceID());
    my ($ps, $pf) = $this->getPosition();
    $name .= sprintf ("/%11d", $ps);
    $name .= sprintf ("-%11d", $pf);
    $name =~ s/\s+//g; # remove any blanks

    $this->setSystematicID($name);
}

#----------------------------------------------------------------------
# comparing tags
#----------------------------------------------------------------------

sub isEqual {
# compare this tag with input tag
    my $this = shift;
    my $tag  = shift;
    my %options = @_;

    if ($options{debug}) {
        print STDOUT $this->dump();
	print STDOUT $tag->dump();
    }

# compare tag type and host type

    return 0 unless ($this->getType() eq $tag->getType());

    return 0 unless ($this->getHostClass() eq $tag->getHostClass());

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
# tags may be different, do a more detailed comparison using a cleaned version
            my $inop = $options{ignorenameofpattern}; # e.g.: oligo names
            unless (&cleanup($this->getTagComment(),$inop) eq
                    &cleanup( $tag->getTagComment(),$inop)) {
   	        return 0;
            }
	}
    }
    elsif ($this->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        $tag->setTagComment($this->getTagComment()) if $options{copycom};
    }
    elsif  ($tag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        $this->setTagComment($tag->getTagComment()) if $options{copycom};
    }

# compare the tag sequence & name or (if no tag sequence name) systematic ID.
# the tag sequence or name takes precedence over the systematic ID because 
# in e.g. the case of repeat tags, a systematic ID could have been generated 
# by the tag loading software

    if ($this->getDNA() || $tag->getDNA()) {
# at least one of the tag DNA sequences is defined; then they must be equal 
        return 0 unless ($this->getDNA() eq $tag->getDNA());
    }
    elsif ($this->getTagSequenceName() =~ /\S/ || 
            $tag->getTagSequenceName() =~ /\S/) {
# at least one of the tag sequence names is defined; then they must be equal
	return 0 unless ($this->getTagSequenceName() eq 
                          $tag->getTagSequenceName());
    }
# neither tag has a tag sequence name defined, then consider the systematic ID
    elsif ($this->getSystematicID() =~ /\S/ || 
            $tag->getSystematicID() =~ /\S/) {
# at least one of the systematic IDs is defined; then they must be equal
	return 0 unless ($this->getSystematicID() eq $tag->getSystematicID());
    }

# compare strands (optional)

    if ($options{includestrand}) {

        return 0 unless ( $tag->getStrand() eq 'Unknown' ||
                         $this->getStrand() eq 'Unknown' ||
                         $this->getStrand() eq $tag->getStrand());
    }

# the tags are identical; inherit possible undefined data

    if ($options{copy} || $options{inherit}) {
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
# private method cleanup for purpose of comparison of comments
    my $comment = shift;
    my $inop = shift; # special treatment for e.g. auto-generated oligo names

# remove quotes, '\n\' and shrink blankspace into a single blank

    $comment =~ s/^\s*([\"\'])\s*(.*)\1\s*$/$2/; # remove quotes
    $comment =~ s/^\s+|\s+$//g; # remove leading & trailing blank
    $comment =~ s/\\n\\/ /g; # replace by blank space
    $comment =~ s/\s+/ /g; # shrink blank space

    $comment =~ s/^$inop// if $inop; # remove if present at begin
   
    return $comment;
}

#----------------------------------------------------------------------
# output
#----------------------------------------------------------------------

sub writeToCaf {
# output for all tags, except ANNO tags (see Contig->writeToEMBL)
    my $this = shift;
    my $FILE = shift; # optional output file handle
    my %options = @_; # option 'annotag' allows override of default

    my $type = $this->getType();
    my @pos  = $this->getPosition();
    my $tagcomment = $this->getTagComment();
    my $comment = $this->getComment();

    return '' if ($type eq 'ANNO' && !$options{annotag});

# various types of tag, NOTE and ANNO are two special cases

    my $host = $this->getHostClass();
$host = 0;

    my $string = "Tag $type ";

    if ($type eq 'NOTE') {
# GAP4 NOTE tag, no position info
    }
    elsif ($host eq 'Read') {
# standard output of tag with position and tag comment
        $string .= "@pos "; 
        $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
        $string .= "\"$tagcomment\"" if $tagcomment;
        $string .= "\n";
    }
    elsif ($host eq 'Contig') {
# annotation tags have special status
        if ($type eq 'ANNO') {
# generate two tags, ANNO contains the systematic ID and comment
            $string .= "@pos ";
# add the systematic ID
            my $tagtext = $this->getSystematicID() || 'unspecified'; 
            $tagtext .= ' ' . $comment if $comment;
            $string .= "\"$tagtext\"\n" ;
# if also a comment available add an info tag
            $string .= "Tag INFO @pos \"$tagcomment\"\n" if $tagcomment;
#            $string .= "Tag INFO @pos \"$comment\"\n" if $comment;
        }
        else {
# standard output of tag with position and tag comment
            $string .= "@pos "; 
            $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
            $string .= "\"$tagcomment\"" if $tagcomment;
            $string .= "\n";
# if comment available add an INFO tag
            $string .= "Tag INFO @pos $comment\n" if $comment;
	}
    }
#    else {
#        print STDERR "Unknown host type in tag\n";
#    }

    elsif ($type eq 'ANNO') {
# generate two tags, ANNO contains the systematic ID and comment
        $string .= "@pos ";
# add the systematic ID
        my $tagtext = $this->getSystematicID() || 'unspecified'; 
        $tagtext .= ' ' . $comment if $comment;               # ? tagcomment
        $string .= "\"$tagtext\"\n" ;
# if comment available add an info tag
        $string .= "Tag INFO @pos \"$tagcomment\"\n" if $tagcomment;
#        $string .= "Tag INFO @pos \"$comment\"\n" if $comment;
    }
    else {
# standard output of tag with position and tag comment
        $string .= "@pos "; 
        $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
        $string .= "\"$tagcomment\"" if $tagcomment;
        $string .= "\n";
# if comment available add an INFO tag
        $string .= "Tag INFO @pos $comment\n" if $comment;
    }

    print $FILE $string if $FILE;

    return $string;
}

sub writeToEMBL {
# write the tag in EMBL, i.p. annotation tags
    my $this = shift;
    my $FILE = shift; # optional output file handle
    my %options = @_; # tagkey (CDS/TAG)

    my $tagtype    = $this->getType();
    my $strand     = lc($this->getStrand());
    my $sysID      = $this->getSystematicID();
    my $comment    = $this->getComment();
    my $tagcomment = $this->getTagComment();
        
    my $key = $options{tagkey} || 'CDS'; # get the key to be used for export
    
    my $sp17 = "                 "; # format spacer

# composite tags have more than one position interval specified

    my $string  = "FT   ".sprintf("%3s",$key)."             ";
    if ($this->isJoined()) {
# generate the join construct for composite tags
        my @joinlist;
        $string .= "complement(" if ($strand eq "reverse");
        $string .= "join("; # always
	my $pair = 0;
        my $offsetposition = length($string);
        while ($this->getPosition($pair)) {
            my ($ps,$pf) = $this->getPosition($pair++);
            last unless (defined($ps) && defined($pf));
            my $substring = "$ps..$pf,";
            if ($offsetposition+length($substring) > 80) {
	        $string .= "\nFT $sp17 "; # start a new line
                $offsetposition = 21;
            }
	    $string .= "$substring";
            $offsetposition += length($substring);
        }
        chop $string; # remove the last comma
        $string .= ")" if ($strand eq "reverse");
        $string .= ")\n";
    }
    else {
# just generate the (single) position pair
        my ($ps,$pf) = $this->getPosition(0);
        $string .= "complement(" if ($strand eq "reverse");
        $string .= "$ps..$pf";
        $string .= ")" if ($strand eq "reverse");
        $string .= "\n";
    }

    $tagtype =~ s/ANNO/annotation/ if $tagtype;
    $string .= "FT $sp17 /type=\"$tagtype\"\n" if $tagtype;
    $string .= "FT $sp17 /arcturus_feature_id=\"$sysID\"\n" if $sysID;
    if ($strand eq 'U') {
        $string .= "FT $sp17 /strand=\"no strand information\"\n";
    }
    else {
        $string .= "FT $sp17 /strand=\"$strand\"\n";
    }
    $string .= "FT $sp17 /arcturus_comment=\"$comment\"\n" if $comment;
# process tag comment; insert new line if it is too long
    if ($tagcomment) {
        my @tcparts = split /,/,$tagcomment;
        my $cstring = "FT $sp17 /arcturus_description=\"";
        my $positionoffset = length($cstring);
        foreach my $part (@tcparts) {
            my $substring = "$part,";
            if ($positionoffset + length($substring) >= 80) {
	        $cstring .= "\nFT $sp17 "; # start a new line
                $positionoffset = 21;
            }
	    $cstring .= $substring;
            $positionoffset += length($substring);
        }
        chop $cstring; # remove trailing comma
        $string .= $cstring . "\"\n";
    }

    print $FILE $string if $FILE;

    return $string;
}

sub dump {
# listing poption for debugging purposes
    my $tag = shift;
    my $FILE = shift; # optional file handle
    my $skip = shift; # true to skip undefined items

    my $report = $tag->getHost() . "Tag instance $tag\n";

    my @line;
    push @line, "sequence ID       ".($tag->getSequenceID() || 0)."\n";
    push @line, "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    my @position = $tag->getPosition();
    push @line, "position          '@position'\n";
    push @line, "strand            ".($tag->getStrand()  || 'undef')."\n";
    push @line, "comment           ".($tag->getComment() || 'undef')."\n\n";
    push @line, "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    push @line, "tag type          ".($tag->getType()    || 'undef')."\n";
    push @line, "systematic ID     ".($tag->getSystematicID()  || 'undef')."\n";
    push @line, "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    push @line, "tag comment       ".($tag->getTagComment()    || 'undef')."\n\n";
    push @line, "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    push @line, "tag sequence name ".($tag->getTagSequenceName() || 'undef')."\n";
    push @line, "sequence          ".($tag->getDNA() || 'undef')."\n";
    push @line, "tag host class    ".($tag->getHostClass() || 'undef')."\n";

    foreach my $line (@line) {
	next if ($skip && $line =~ /undef/);
        $report .= $line;
    }

    print $FILE $report  if $FILE;

    return $report;
}

#----------------------------------------------------------------------

1;
