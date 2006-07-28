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

    $this->{label} = shift;

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
# transpose the dna if strand is reverse
    my $this = shift;
    my $dotranspose = shift;

    unless ($dotranspose && $this->getStrand() ne 'Reverse') {
        return $this->{DNA} || '';
    }

    return &transposeDNA($this->{DNA});
}

# positions are stored as begin-end pairs (array or arrays)

sub setPosition {
# begin and end position in read or contig sequence
    my $this = shift;
    my @position = (shift,shift);
    my %options = @_;

    @position = sort {$a <=> $b} @position; # ensure ordering
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

sub remap {
# takes a mapping and transforms the tag positions to the mapped domain
# returns an array of (one or more) new tags, or undef
    my $this = shift;
    my $mapping = shift;
    my %options = @_;

# options:  break = 1 to allow splitting of a tag straddling mapping segments
#                     and return a separate tag for each segment
#                   0 (default) to not allow that; if a sequence is provided
#                     generate a tag sequence with pad(s)
#           sequence, if provided used to generate a tagsequence, possibly 
#                     with pads; in its absence a long comment is generated

    unless (ref($mapping) eq 'Mapping') {
        die "Tag->transpose expects a Mapping instance as parameter";
    }

# get current tag position

    my @currentposition = $this->getPosition();

# generate a helper 1-1 mapping

    my $helpermapping = new Mapping('helper');
# and add the one segment
    $helpermapping->putSegment(@currentposition,@currentposition);

# multiply by input mapping; the helper mapping may be masked
# by the input mapping, which would result in a truncated tag

print STDOUT "Tag position: @currentposition \n" if $options{debug};

    my $maskedmapping = $helpermapping->multiply($mapping);

# trap problems with mapping by running again with debug option

    print STDOUT "Tag position: @currentposition \n" unless $maskedmapping;
    print $helpermapping->toString()."\n" unless $maskedmapping;    
    print $mapping->toString()."\n" unless $maskedmapping; 
    $helpermapping->multiply($mapping,debug=>1) unless $maskedmapping;
    return undef unless $maskedmapping; # something wrong with mapping
   

print STDOUT "Masked Mapping: ".$maskedmapping->toString()."\n" if $options{debug};

    return undef unless $maskedmapping->hasSegments(); # just in case
          
    my $segments = $maskedmapping->getSegments();
    my $numberofsegments = scalar(@$segments);
    my $invert  = ($maskedmapping->getAlignment() < 0) ? 1 : 0;
# input parameter definition takes precedence
    $options{changestrand} = $invert unless defined $options{changestrand};

# OK, here we have the mapping of the tag sorted

# test if the tag is clipped

    my @range = $maskedmapping->getContigRange();
    my $lclip = $range[0] - $currentposition[0];
    my $rclip = $currentposition[1] - $range[1];
    my $truncated = ($lclip > 0 || $rclip < 0) ? 1 : 0; 
    $truncated = "truncated (L:$lclip R:$rclip)" if $truncated; # used later

# now output of transformed tags; consider three cases

    my @tags;
    
    my $sequence = $options{sequence};
#    my $sequence = $this->getDNA();
#    $sequence = $options{sequence} if $options{sequence};

    if ($numberofsegments == 1) { 
# CASE 1: one shift for the whole tag
        my $newtag = $this->copy(%options);
        my @segment = $segments->[0]->getSegment();
        my @newposition = ($segment[2],$segment[3]);
        $newtag->setPosition(sort {$a <=> $b} @newposition);
        $newtag->setDNA(substr $sequence,$segment[0],$segment[1]) if $sequence;
        my $comment = $this->getComment() || '';
# append a warning to the comment if the tag is truncated
        if ($truncated && $comment !~ /truncated/) {
            $newtag->setComment($truncated,append=>1);
	}
        push @tags,$newtag;
    }

    elsif ($options{break}) {
# CASE 2 : more than one segment, generate multiple tags
        my $number = 0;
# XXX how do we handle clipping?
        for (my $i = 0 ; $i < $numberofsegments ; $i++) {
            my $newtag = $this->copy(%options);
            my @segment = $segments->[$i]->getSegment();
            my @newposition = ($segment[2],$segment[3]);
            $newtag->setPosition(sort {$a <=> $b} @newposition);
            my $tagcomment = $newtag->getTagComment() || '';
# compose the sequence for this tag fragment
            if ($sequence) {
                my $fragment = substr $sequence,$segment[0],$segment[1];
                $newtag->setDNA($fragment);
	    }
# add comment to possibly existing one
	    $number++;
            $tagcomment .= ' ' if $tagcomment;
            $tagcomment .= "fragment $number of $numberofsegments";
            $newtag->setTagComment($tagcomment);
            my $comment = $newtag->getComment();
            unless ($comment =~ /\bsplit\b/) {
                $newtag->setComment("split!",append=>1);
	    }
            push @tags,$newtag;
	}
    }

    else {
# CASE 3 : more than one segment, but only one tag to be generated
# copy whatever we already have about this tag
        my $newtag = $this->copy(%options);
# amend the comment to signal frame shifts and possible truncation
        my $comment = $newtag->getComment() || '';
        unless ($comment =~ /frame\s+shift/) {
            $newtag->setComment("frame shifts!",append=>1);
	}
        if ($truncated && $comment !~ /truncated/) {
            $newtag->setComment($truncated,append=>1);
	}
# generate a tag sequence with pads for this new tag
        my $tagcomment = '';
        my $tagsequence = '';
        my ($spos,$fpos) = (0,0);
        foreach my $segment (@$segments) {
# either generate a sequence with pads, or a comment about pad positions
            my @segment = $segment->getSegment();
            if ($fpos > 0) {
                my $length = $segment[1] - $segment[0] + 1;
                my $gapsize = $segment[2] - 1 - $fpos;

                if (my $sequence = $options{sequence}) {
# add pads if gapsize > 0 (insertions)
                    foreach my $i (1..$gapsize) {
                        $tagsequence .= '-'; # add pads
		    }
# if gapsize < 0 there has been a deletion 
                    if ($gapsize < 0) {
print STDOUT "$gapsize : sequence deletion detected \n"; 
# check for pads removed from the sequence, if so, no message
########## TO BE COMPLETED ##########
		    }
# add sequence fragment
                    $tagsequence .= substr $sequence,$segment[0]-1,$length;
	        }
                my $offset = $segment[2] - $spos;
                $tagcomment .= ' ' if $tagcomment;
                $tagcomment .= "pad by $gapsize at pos $offset";
#?              $newtag->setTagComment("pad by $gapsize at pos $offset",append=>1);
	    }
# update the position
            $spos = $segment[2] unless $spos;
            $fpos = $segment[3];
        }
        $newtag->setPosition(sort {$a <=> $b} ($spos,$fpos));
        $newtag->setDNA($tagsequence) if $tagsequence;
        $newtag->setTagComment($tagcomment);
# generate an new comment signaling frame shifts
        push @tags,$newtag;
    }

    return [@tags];
}

sub copy {
# return a copy of the current Tag instance
    my $this = shift;
    my %options = @_;

# create (spawn) a new tag instance

    my $newtag = $this->new($this->{label});

    $newtag->setTagID($this->getTagID());
# TAG2CONTIG table items
    $newtag->setPosition($this->getPosition());
    my $strand = $this->getStrand();
    if ($options{changestrand}) {
	my %inverse = (Forward => 'Reverse', Reverse => 'Forward');
        $strand = $inverse{$strand} || 'Unknown';
#        $strand = 'Reverse' if ($this->getStrand() eq 'Forward');         
#        $strand = 'Forward' if ($this->getStrand() eq 'Reverse');
    } # 'Unknown' is unchanged
    $newtag->setStrand($strand);
    $newtag->setComment($this->getComment());
# CONTIGTAG table items
    $newtag->setType($this->getType());
    $newtag->setSystematicID($this->getSystematicID());
    $newtag->setTagSequenceID($this->getTagSequenceID());
    $newtag->setTagComment($this->getTagComment());
# TAGSEQUENCE table items
    $newtag->setTagSequenceName($this->getTagSequenceName()); 
    my $DNA = $this->getDNA();
    if ($options{changestrand} && $options{transposedna}) {
        $DNA = &transpose($DNA);
    }
    $newtag->setDNA($DNA);

    return $newtag;
}

sub mirror {
# apply a mirror transform to the tag position
    my $this = shift;
    my $mirror = shift || 0; # the mirror position (e.g. contig_length + 1)

    my @currentposition = $this->getPosition();

    foreach my $position (@currentposition) {
        $position = $mirror - $position;
    }
    $this->setPosition(@currentposition);
}

sub shiftTag {
# apply a linear transform to the tag position
    my $this = shift;
    my $shift = shift;
    my $start = shift; # begin of window
    my $final = shift; #  end  of window


    return undef;
}

sub merge {
# merge this tag and another (if possible)
    my $this = shift;
    my $otag = shift;
    my %options = @_;

    unless (ref($otag) eq 'Tag') {
        die "Tag->merge expects another Tag instance as parameter";
    }

# test thhe tag type

    return undef unless ($this->getType() eq $otag->getType());

    my @thisposition = $this->getPosition();
    my @otagposition = $otag->getPosition();

    my ($left,$right);
    if ($thisposition[1] == $otagposition[0] - 1) {
# other tag is butting to the right of this
        ($left,$right) = ($this,$otag); 
    }
    elsif ($thisposition[0] == $otagposition[1] + 1) {
# this is butting to the right of other tag
        ($left,$right) = ($otag,$this); 
    }
    else {
#print STDOUT "tag positions do not butt: @thisposition, @otagposition \n";
	return undef;
    }

if ($options{debug}) {
 print STDOUT "tag positions DO butt: @thisposition, @otagposition \n";
 $left->writeToCaf(*STDOUT,annotag=>1);
 $right->writeToCaf(*STDOUT,annotag=>1);
}

# accept if systematic IDs and strand are identical

    return undef unless ($left->getSystematicID() eq $right->getSystematicID());

    return undef unless ($left->getStrand() eq $right->getStrand());

    my @lposition = $left->getPosition();
    my @rposition = $right->getPosition();
    if ($left->getDNA() && $right->getDNA()) {
        my $DNA = $left->getDNA() . $right->getDNA(); # combined
print STDOUT "DNA merge: @lposition  @rposition \n" if $options{debug};
        return undef unless (length($DNA) == $rposition[1]-$lposition[0]+1);
    }

# try to build a new tag to replace the two parts

    my $newtag = $this->new();
    $newtag->setPosition($lposition[0],$rposition[1]);
    $newtag->setSystematicID($this->getSystematicID());
    $newtag->setStrand($this->getStrand());
# get the new DNA and test against length
    my $DNA = $left->getDNA() . $right->getDNA();
    $newtag->setDNA($DNA) if ($DNA =~ /\S/);
# merge the comment and tagcomment
print STDOUT "TO BE COMPLETED\n" if $options{debug};

$newtag->writeToCaf(*STDOUT,annotag=>1) if $options{debug};
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

    my $output = inverse($string);
    $output =~ tr/ACGTacgt/TGCAtgca/;
    return $output;

#    my $output = '';
#    my $length = length($string);
#    while ($length--) {
#        my $base = substr $string,$length,1;
#        $base =~ tr/ACGTacgt/TGCAtgca/;
#        $output .= $base;
#    }

#    return $output;
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

    my $string = "Tag $type ";

    if ($type eq 'NOTE') {
# GAP4 NOTE tag, no position info
    }
    elsif ($type eq 'ANNO') {
print STDOUT "ANNO tag\n";
# generate two tags, ANNO contains the systematic ID and comment
        $string .= "@pos ";
# add the systematic ID
        my $tagtext = $this->getSystematicID() || 'unspecified'; 
        $tagtext .= ' ' . $comment if $comment;               # ? tagcomment
        $string .= "\"$tagtext\"\n" ;
# if comment available add an info tag
        $string .= "Tag INFO @pos $tagcomment\n" if $tagcomment; # ? comment
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

    my $string = '';

    my $tagtype    = $this->getType();
    my $strand     = lc($this->getStrand());
    my $sysID      = $this->getSystematicID();
    my $comment    = $this->getComment();
    my $tagcomment = $this->getTagComment();
        
    my $key = $options{tagkey} || 'CDS'; # get the key to be used for export
    
    my $sp17 = "                 "; # format spacer
    if ($this->isJoined()) {
# generate the join construct for composite tags
        my @joinlist;
        $string = "FT   ".sprintf("%3s",$key)."             ";
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
        $string = "FT   ".sprintf("%3s",$key)."             $ps..$pf\n";
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
        my $cstring = "FT $sp17 /description=\"";
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
    my $tag = shift;
    my $FILE = shift; # optional file handle
    my $skip = shift; # true to skip undefined items

    my $report = "Tag instance $tag\n";

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

    foreach my $line (@line) {
	next if ($skip && $line =~ /undef/);
        $report .= $line;
    }

    print $FILE $report  if $FILE;

    return $report;
}

#----------------------------------------------------------------------

1;
