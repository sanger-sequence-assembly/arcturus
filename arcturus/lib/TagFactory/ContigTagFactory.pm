package ContigTagFactory;

use strict;

use Tag;

use Mapping;

#----------------------------------------------------------------------
# class variables
#----------------------------------------------------------------------

my $contigtagfactory;

#----------------------------------------------------------------------
# constructor and initialisation
#----------------------------------------------------------------------

sub new {
# constructor
    my $class = shift;

# the following ensures only one instance per process

    my $this = $contigtagfactory;

    unless ($this && ref($this) eq $class) {
# create a new instance
        $this = {};

        bless $this, $class;

        $contigtagfactory = $this;
    }

    return $this;
}


#----------------------------------------------------------------------

sub makeTag {
# make a new contig Tag instance
    my $this = shift;
    my ($tagtype,$start,$final,%options) = @_;

# print STDERR "ContigTagFactory::make used\n";

    my $newtag = new Tag('Contig');

    $newtag->setType($tagtype);
    $newtag->setPosition($start,$final);

    foreach my $item (keys %options) {
        my $value = $options{$item};
        eval("\$newtag->set$item(\$value)");
    }

    return $newtag;
}

#----------------------------------------------------------------------

sub isEqual {
# compare this tag with input tag
    my $class = shift;
    my $atag = shift;
    my $otag  = shift;
    my %options = @_;

#print STDOUT "using ContigTagFactory->isEqual\n";
    
    return undef unless &verifyParameter($atag,'transpose 1-st parameter)');

    return undef unless &verifyParameter($otag,'transpose 2-nd parameter)');

    if ($options{debug}) {
        print STDOUT $atag->dump();
	print STDOUT $otag->dump();
    }

# compare tag type and host type

    return 0 unless ($atag->getType() eq $otag->getType());

    return 0 unless ($atag->getHostClass() eq $otag->getHostClass());

# compare tag position(s) by looking at the mapping representation

    my $amap = $atag->getPositionMapping();
    my $omap = $otag->getPositionMapping();
    my @equal = $amap->isEqual($omap);
print STDOUT "$amap $omap equality test @equal \n";
# insist on equality of position(s) with same alignment and no shift 
    unless ($equal[0] == 1 && $equal[1] == 1 && $equal[2] == 0) {
        return 0;
    }

#    my @spos = $atag->getPosition();
#    my @tpos = $otag->getPosition();

#    return 0 unless (scalar(@spos) && scalar(@spos) == scalar(@tpos));
#    return 0 if ($spos[0] != $tpos[0]);
#    return 0 if ($spos[1] != $tpos[1]);

# compare tag comments

    if ($atag->getTagComment() =~ /\S/ && $otag->getTagComment() =~ /\S/) {
# both comments defined
        unless ($atag->getTagComment() eq $otag->getTagComment()) {
# tags may be different, do a more detailed comparison using a cleaned version
            my $inop = $options{ignorenameofpattern}; # e.g.: oligo names
            unless (&cleanup($atag->getTagComment(),$inop) eq
                    &cleanup($otag->getTagComment(),$inop)) {
   	        return 0;
            }
	}
    }
    elsif ($atag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        $otag->setTagComment($atag->getTagComment()) if $options{copycom};
    }
    elsif  ($otag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        $atag->setTagComment($otag->getTagComment()) if $options{copycom};
    }

# compare the tag sequence & name or (if no tag sequence name) systematic ID.
# the tag sequence or name takes precedence over the systematic ID because 
# in e.g. the case of repeat tags, a systematic ID could have been generated 
# by the tag loading software

    if ($atag->getDNA() || $otag->getDNA()) {
# at least one of the tag DNA sequences is defined; then they must be equal 
        return 0 unless ($atag->getDNA() eq $otag->getDNA());
    }
    elsif ($atag->getTagSequenceName() =~ /\S/ || 
            $otag->getTagSequenceName() =~ /\S/) {
# at least one of the tag sequence names is defined; then they must be equal
	return 0 unless ($atag->getTagSequenceName() eq 
                         $otag->getTagSequenceName());
    }
# neither tag has a tag sequence name defined, then consider the systematic ID
    elsif ($atag->getSystematicID() =~ /\S/ || 
            $otag->getSystematicID() =~ /\S/) {
# at least one of the systematic IDs is defined; then they must be equal
	return 0 unless ($atag->getSystematicID() eq $otag->getSystematicID());
    }

# compare strands (optional)

    if ($options{includestrand}) {

        return 0 unless ($otag->getStrand() eq 'Unknown' ||
                         $atag->getStrand() eq 'Unknown' ||
                         $atag->getStrand() eq $otag->getStrand());
    }

# the tags are identical; inherit possible undefined data

    if ($options{copy} || $options{inherit}) {
# copy tag ID, tag sequence ID and systematic ID, if not already defined
        unless ($otag->getTagID()) {
            $otag->setTagID($atag->getTagID());
        }
        unless ($otag->getTagSequenceID()) {
            $otag->setTagSequenceID($atag->getTagSequenceID());
        }
        unless ($otag->getSystematicID()) {
           $otag->setSystematicID($atag->getSystematicID());
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

#---------------------------------------------------------------------------

sub transpose {
# apply a linear transformation to the tag position
    my $class = shift;
    my $tag   = shift;
    my $align = shift;
    my $offset = shift;
    my %options = @_;

#print STDERR "ContigTagFactory:: (new) transpose used a:$align  o:$offset  @_\n";
    
    return undef unless &verifyParameter($tag,'transpose');

    my $oldmapping = $tag->getPositionMapping();

    $tag = $tag->copy() unless $options{nonew};

# determine the multiplication mapping

    my @csegment = $tag->getPositionRange();

    foreach my $i (0,1) {
        $csegment[2+$i] = $csegment[$i];       # from current contig range (y)
        $csegment[$i]   = $csegment[$i]*$align + $offset; # to transformed (x)
    }

    my $mapping = new Mapping("linear mapping");
    $mapping->putSegment(@csegment);

    return undef unless &remapper($tag,$mapping,%options);

# ok, we have a remapped tag here; now update strand and test for truncation 

    my $newmapping = $tag->getPositionMapping();

# compare the new with the old by testing for equality 
    
    my @isequal = $newmapping->isEqual($oldmapping); # if [0] == 0 frameshift

    unless ($isequal[0] == 1) {
# the tag is truncated 
        my $newcomment = $tag->getComment() || '';
        $newcomment .= ' ' if $newcomment;
        $newcomment .= "(truncated)";
        $tag->setComment($newcomment);
    }

# transpose the strand (if needed) (transpose DNA on export only)

    my $strand = $tag->getStrand();
    my $alignment = $mapping->getAlignment();
    if ($alignment < 0) {
        if ($strand eq 'Forward') {
            $strand = 'Reverse';
        }
        elsif ($strand eq 'Reverse') {
            $strand = 'Forward';
        }
        $tag->setStrand($strand);
    }

    return $tag;
}

sub remapper {
# private, remap position of tag 
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;

    return undef unless &verifyPrivate($tag,'remapper');

    my $newmapping = $tag->getPositionMapping();

    if ($options{prewindowstart} || $options{prewindowfinal}) {
        my @range = $tag->getPositionRange();
        my $pws = $options{prewindowstart} || 1;
        my $pwf = $options{prewindowfinal} || $range[1];
        my $prefilter = new Mapping("prefilter");
        $prefilter->putSegment($pws,$pwf,$pws,$pwf);
        $newmapping = $prefilter->multiply($newmapping);
        return undef unless $newmapping; # mapped tag out of range
    }

    $newmapping = $mapping->multiply($newmapping);
    return undef unless $newmapping; # mapped tag out of range

    if ($options{postwindowfinal}) {
        my $pws = $options{postwindowstart} || 1;
        my $pwf = $options{postwindowfinal};
        my $postfilter = new Mapping("postfilter");
        $postfilter->putSegment($pws,$pwf,$pws,$pwf);
        $newmapping = $postfilter->multiply($newmapping);
        return undef unless $newmapping; # mapped tag out of range
    }
    
print STDOUT $newmapping->toString()."\n" if $options{list};

    return undef unless $newmapping->hasSegments(); # mapped tag out of range

    $tag->setPositionMapping($newmapping);

    return 1;
}

sub oldtranspose { # used in Tag, ContigHelper
# transpose a tag by applying a linear transformation
# (apply only to contig tags)
# returns new Tag instance (or undef)
    my $class = shift;
    my $tag   = shift;
    my $align = shift;
    my $offset = shift; # array length 2 with offset at begin and end
    my $window = shift || 1; # new position in range 1 .. window

    return undef unless &verifyParameter($tag,'transpose');

 print STDERR "ContigTagFactory::oldtranspose used a:$align o:@$offset w:$window\n";

# transpose the position range using the offset info. An undefined offset
# indicates a boundery outside the range 1 .. length; adjust accordingly

    return undef unless (defined($offset->[0]) && defined($offset->[1])); 

    my @tpos = $tag->getPosition();

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

    my $strand = $tag->getStrand();
    if ($strand eq 'Forward' and $align < 0) {
        $strand = 'Reverse';
    }
    elsif ($strand eq 'Reverse' and $align < 0) {
        $strand = 'Forward';
    }

# get a systematic ID if not already defined

    &composeName($tag) unless $tag->getSystematicID();

# transport the comment; add import details, if any

    my $newcomment = $tag->getComment() || '';
    $newcomment .= ' ' if $newcomment;
    $newcomment .= "imported ".$tag->getSystematicID(); # ?
    $newcomment .= " truncated" if $truncated;
    $newcomment .= " frame-shifted" if ($offset->[0] != $offset->[1]);

# create (spawn) a new tag instance

    my $newtag = $tag->new($tag->{label});

    $newtag->setTagID($tag->getTagID());
# TAG2CONTIG table items
    $newtag->setPosition(@tpos); 
    $newtag->setStrand($strand);
    $newtag->setComment($newcomment);
# CONTIGTAG table items
    $newtag->setType($tag->getType());
    $newtag->setSystematicID($tag->getSystematicID());
    $newtag->setTagSequenceID($tag->getTagSequenceID());
    $newtag->setTagComment($tag->getTagComment());
# TAGSEQUENCE table items
    $newtag->setTagSequenceName($tag->getTagSequenceName()); 
    $newtag->setDNA($tag->getDNA());

#print STDOUT "transpose in  : ".$tag->writeToCaf();  
#print STDOUT "transpose out : ".$newtag->writeToCaf();  

    return $newtag;
}

sub newremap {
# returns an array of (one or more) new tags, or undef
    my $class = shift;
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;

    return undef unless &verifyParameter($tag,'remap');

    return undef unless &verifyParameter($mapping,'remap', class=>'Mapping');

    my $oldposition = $tag->getPositionMapping();

    $tag = $tag->copy() unless $options{nonew};

print STDOUT $mapping->toString()."\n";
print STDOUT $oldposition->toString()."\n";

    return undef unless &remapper($tag,$mapping,%options);

    return $tag;
}

sub remap {
# takes a mapping and transforms the tag positions to the mapped domain
# returns an array of (one or more) new tags, or undef
    my $class = shift;
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;

# options:  break = 1 to allow splitting of a tag straddling mapping segments
#                     and return a separate tag for each segment
#                   0 (default) to not allow that; if a sequence is provided
#                     generate a tag sequence with pad(s)
#           sequence, if provided used to generate a tagsequence, possibly 
#                     with pads; in its absence a long comment is generated

    return undef unless &verifyParameter($tag,'remap');

    return undef unless &verifyParameter($mapping,'remap', class=>'Mapping');

#print STDOUT "ContigTagFactory->remap used  @_\n";

# get current tag position

    my @currentposition = $tag->getPosition();

    my $tagsequencespan = $tag->getSpan();

# generate a helper 1-1 mapping

    my $helpermapping = new Mapping('helper');
# and add the one segment
    $helpermapping->putSegment(@currentposition,@currentposition);

# multiply by input mapping; the helper mapping may be masked
# by the input mapping, which would result in a truncated tag

print STDOUT "Tag position: @currentposition \n" if $options{debug};

# the next block initializes start position for searching the mappings

    if (my $nzs = $options{nonzerostart}) {
# initialize the starting positions if that has not been done
        $nzs->{tstart} = 0 unless defined $nzs->{tstart}; # count along
print STDOUT " previous positions : $nzs->{tstart}\n" if $options{debug};
        $nzs->{tstart}-- if ($nzs->{tstart} > 0); # skip one back
        $nzs->{rstart} = 0; # always reset
print STDOUT " starting positions : $nzs->{rstart},$nzs->{tstart}\n" if $options{debug};
    }

    my $maskedmapping = $helpermapping->multiply($mapping,%options);

# trap problems with mapping by running again with debug option

    unless ($maskedmapping) {
# something wrong with mapping
        print STDOUT "Tag position: @currentposition \n";
        print STDOUT $helpermapping->toString()."\n";    
        print STDOUT $mapping->toString()."\n"; 
        $helpermapping->multiply($mapping,debug=>1);
        return undef; 
    }

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
#    my $sequence = $tag->getDNA();
#    $sequence = $options{sequence} if $options{sequence};

    if ($numberofsegments == 1) { 
# CASE 1: one shift for the whole tag
        my $newtag = $tag->copy(%options);
        my @segment = $segments->[0]->getSegment();
        my @newposition = ($segment[2],$segment[3]);
        $newtag->setPosition(sort {$a <=> $b} @newposition);
        $newtag->setDNA(substr $sequence,$segment[0],$segment[1]) if $sequence;
        my $comment = $tag->getComment() || '';
# append a warning to the comment if the tag is truncated
        if ($truncated && $comment !~ /truncated/) {
            $newtag->setComment($truncated,append=>1);
	}
        push @tags,$newtag;
    }

    elsif ($options{break}) {
# CASE 2 : more than one segment, generate multiple tags
        my $number = 0;
        my $minimumsegmentsize = $options{minimumsegmentsize} || 1;
# XXX how do we handle clipping?
        for (my $i = 0 ; $i < $numberofsegments ; $i++) {
            my $newtag = $tag->copy(%options);
            my @segment = $segments->[$i]->getSegment();
            my @newposition = sort {$a <=> $b} ($segment[2],$segment[3]);
            my $segmentlength = $newposition[1] - $newposition[0] + 1;
            next if ($segmentlength < $minimumsegmentsize);
            $newtag->setPosition(@newposition);
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
                $newtag->setComment("split! ($tagsequencespan)",append=>1);
	    }
            push @tags,$newtag;
	}
    }

    else {
# CASE 3 : more than one segment, but only one tag to be generated
# copy whatever we already have about this tag
        my $newtag = $tag->copy(%options);
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

sub merge { # used in ContigHelper
# merge two tags (fragments), if possible
    my $class = shift;
    my $atag = shift;
    my $otag = shift;
    my %options = @_;

# test input parameters

    return undef unless &verifyParameter($atag,'merge (1-st parameter)');

    return undef unless &verifyParameter($otag,'merge (2-nd parameter)');

# accept only if tag type, systematic ID and strand are identical

    return undef unless ($atag->getType()         eq $otag->getType());

    return undef unless ($atag->getSystematicID() eq $otag->getSystematicID());

    return undef unless ($atag->getHost()         eq $otag->getHost());

    if ($atag->getSize() > 1 && $otag->getSize() > 1) {
# only test strand if tag (segment) has a meaningful length
        return undef unless ($atag->getStrand()   eq $otag->getStrand());
    }

# analyse tag positions and determine the relative position of tags

    my @atagposition = $atag->getPosition();
    my @otagposition = $otag->getPosition();     

    my ($left,$right,$overlap);
    if ($atagposition[1] == $otagposition[0] - 1) {
# other tag is butting to the right of this tag
        ($left,$right) = ($atag,$otag); 
    }
    elsif ($atagposition[0] == $otagposition[1] + 1) {
# this tag is butting to the right of other tag
        ($left,$right) = ($otag,$atag); 
    }
    elsif ($options{overlap}) {
# the tag positions do not match; here test if they overlap
        if ($otagposition[0] >= $atagposition[0]) {
            if ($atagposition[1] >= $otagposition[0]) {
# other tag is overlapping at the right end of this tag
               ($left,$right) = ($atag,$otag);
	        $right = $atag if ($atagposition[1] >= $otagposition[1]);
            }
	    else {
                return undef; # no overlap
	    }
	}
        elsif ($otagposition[1] >= $atagposition[0]) {
# this tag is overlapping at the right end of other tag
           ($left,$right) = ($otag,$atag);
            $right = $otag if ($otagposition[1] >= $atagposition[1]);
        }
        else {
            return undef; # no overlap
	}
# test if the intervals extend
        $overlap = 1;
    }
    else {
# the tag positions do not match
	return undef;
    }

    my @lposition = $left->getPosition();
    my @rposition = $right->getPosition();

#$options{debug} = 1 if ($left->getSystematicID() =~ /0520.+002/);
$left->writeToCaf(*STDOUT,annotag=>1) if $options{debug};
$right->writeToCaf(*STDOUT,annotag=>1) if $options{debug};
   
    my $newdna;
    if ($left->getDNA() && $right->getDNA()) {
        $newdna = $left->getDNA(transpose => 1);
        if ($overlap) {
	    print STDERR "DNA sequence in overlapping tag to be COMPLETED\n";

#$options{debug} = 0;
if ($options{debug} && $options{debug}>1) {
 print STDOUT "tag positions DO butt: @atagposition, @otagposition \n";
 $left->writeToCaf(*STDOUT,annotag=>1);
 $right->writeToCaf(*STDOUT,annotag=>1);
}
	}
	else {
            $newdna .= $right->getDNA(transpose => 1);
	}
#print STDOUT "DNA merge: @lposition  @rposition \n" if $options{debug};
#        return undef unless (length($DNA) == $rposition[1]-$lposition[0]+1);
        # for R strand, invert DNA
    }

# try to build a new tag to replace the two parts

    my $newtag = $atag->new();
    $newtag->setType($atag->getType());
    $newtag->setPosition($lposition[0],$rposition[1]);
    $newtag->setSystematicID($atag->getSystematicID());
    $newtag->setStrand($atag->getStrand());
    $newtag->setHost($atag->getHost());
# get the new DNA
    $newtag->setDNA($newdna) if $newdna;
# merge the comments
    my $comment = $atag->getComment();
    unless ($atag->getComment() eq $otag->getComment()) {
        if ($comment !~ /$otag->getComment()/) {
            $comment .=  " " . $otag->getComment();
        }
if ($options{debug} && $options{debug}>1) {
   print STDOUT "comment a:'".$atag->getComment()."' o:'".$otag->getComment()
               ."'\n". "com: '$comment'\n" if ($comment =~ /rejoin.*split/);
}
        $comment =~ s/(.{4,})\s+\1/$1/g; # remove possible duplicated info
    }
# merge the tagcomments
    my $newcomment;
    my $lcomment = $atag->getTagComment();
    my $rcomment = $otag->getTagComment();
    if ($newcomment = &mergetagcomments ($lcomment,$rcomment)) {
# and check the new comment
        my ($total,$frags) = &unravelfragments($newcomment);

        if (@$frags == 1 && $frags->[0]->[0] == 1 && $frags->[0]->[1] == $total) {
            $comment = 'rejoined intermediate tag fragments';
            $newcomment = 'original tag';
        }
    }
    else {
# cannot handle the comments; just concatenate the two
        $newcomment = $atag->getTagComment() . " " . $otag->getTagComment();
if ($options{debug} && $options{debug}>1) {
   print STDOUT "tagcomment merging problem  l: '$lcomment'  r: '$rcomment'\nnew: '$newcomment'\n";
}
        $comment =~ s/(.{4,})\s+\1/$1/g; # remove possible duplicated info
    }

    $newtag->setComment($comment) if $comment;
    $newtag->setTagComment($newcomment) if $newcomment;

$newtag->writeToCaf(*STDOUT,annotag=>1) if $options{debug};

    return $newtag;
}

sub mergeTags {
# merge tags from a list of input tags, where possible
    my $class = shift;
    my $tags = shift; # array reference
    my %options = @_;

my $DEBUG = $options{debug};

# build an inventory of tag types & systematic ID (if defined)

    my $tagtypehash = {};

    foreach my $tag (@$tags) {
        next unless &verifyParameter($tag,'mergeTags');
        my $tagtype = $tag->getType() || next; # ignore undefined types
        my $systematicid = $tag->getSystematicID();
        $tagtype .= $systematicid if defined($systematicid);
        $tagtypehash->{$tagtype} = [] unless $tagtypehash->{$tagtype};
        push @{$tagtypehash->{$tagtype}},$tag; # add tag to list
    }

$DEBUG->warning(scalar(keys %$tagtypehash)." tag SIDs") if $DEBUG;

# now merge eligible tags from each subset

    my @mtags; # output list of (merged) tags

    my %option = (overlap => ($options{overlap} || 0));


    foreach my $tagtype (keys %$tagtypehash) {
        my $tags = $tagtypehash->{$tagtype};
# sort subset of tags according to position
        @$tags = sort {$a->getPositionLeft <=> $b->getPositionLeft()} @$tags;
# test if some tags can be merged
        my ($i,$j) = (0,1);
        while ($i < scalar(@$tags) && $j < scalar(@$tags) ) {
# test for possible merger of tags i and j
            if (my $newtag = $class->merge($tags->[$i],$tags->[$j],%option)) {
# the tags are merged: replace tags i and j by the new one
                splice @$tags, $i, 2, $newtag;
# keep the same values of i and j
	    }
            else {
# tags cannot be merged: increase both i and j
                $i++;
	        $j++;
            }
        }
# add the left-over tags to the output list
        push @mtags,@$tags;    
    }

# sort all according to position

    @mtags = sort {$a->getPositionLeft <=> $b->getPositionLeft()} @mtags;

    return [@mtags];
}

sub makeCompositeTag {
# join tags in the input list to make a composite tag
    my $class = shift;
    my $tags = shift;

    my $newtag = shift @$tags; # take the first in the list

    return $newtag unless @$tags; # there is only one tag

# for the remaining tags add the positions to the new tag and concatenate
# the tag comments if they conform to comment for fragmented annotation tags

    my $tagcommentformat = 'fragment\\s+([\\d\\,]+)\\s+of\\s+(\\d+)';

    foreach my $tag (@$tags) {
# add the position
        $newtag->setPosition($tag->getPosition(), join => 1);
# concatenate the comments 
        my $tagcomment = $tag->getTagComment();
        my $newtagcomment = $newtag->getTagComment();
        my $concatenated = 0;
        if ($newtagcomment =~ /$tagcommentformat/) {
            my $parts = $1;
            my $count = $2;
            if ($tagcomment =~ /$tagcommentformat/) {
                $parts .= ",$1";
                if ($count == $2) {
                    my @count = split /,/,$parts;
                    if (scalar(@count) == $2) {
# all original fragments are represented
                        $newtagcomment = "$2 fragments of original tag";
                    }
		    else {
                        $newtagcomment = "fragment $parts of $2";
                    }
                    $concatenated++;
	     	}
	    }
        }
        $newtagcomment .= " ".$tagcomment unless $concatenated;

# apply an ad hoc filter to remove repetition

        $newtagcomment =~ s/\s+of\s+(\d+)\s+fragment[s]?\s+([\d\,\-]+)\s+of/, $2 of/g;

        $newtag->setTagComment($newtagcomment);
    }

# test if a "split" is indicated in the comment

    my $comment = $newtag->getComment();
    if ($comment =~ /split\!\D+(\d+)\D/) {
        my $oldspan = $1;
        my $newspan = $newtag->getSpan();
        if ($oldspan == $newspan) {
            $newtag->setComment("original length preserved",append=>1);
	}
        else {
            $newtag->setComment("; frameshifts! ($newspan)",append=>1);
        }
    }

    return $newtag;
}

#----------------------------------------------------------------------------
# helper methods
#----------------------------------------------------------------------------

sub composeName {
# compose a descriptive name from tag data
    my $tag = shift;

    return undef unless $tag->getSequenceID();

    my $name = $tag->{label} || '';
    $name .= ":" if $name;
    $name .= sprintf ("%9d",$tag->getSequenceID());
    my ($ps, $pf) = $tag->getPosition();
    $name .= sprintf ("/%11d", $ps);
    $name .= sprintf ("-%11d", $pf);
    $name =~ s/\s+//g; # remove any blanks

    $tag->setSystematicID($name);
}

sub mergetagcomments {
# re-combine tag comments for fragments of a split tag
    my ($leftc,$rightc) = @_;

    my ($tl,$l) = &unravelfragments($leftc);

    my ($tr,$r) = &unravelfragments($rightc);

    my $tagcomment = '';
# check the total number of fragments
    if ($l && $r && @$l && @$r && $tl == $tr) {
# we are dealing with fragments of a split tag; compose the new tagcomment
        my $parts = [];
        push @$parts, @$l;
        push @$parts, @$r;
# sort according to increasing begin number
        @$parts = sort {$a->[0] <=> $b->[0]} @$parts;
# and reassemble the list in a new fragment comment
        $tagcomment = &composefragments($tl,$parts) if @$parts;
    }

    return $tagcomment;
}

sub unravelfragments {
# decode fragment description for a split tag
    my $string = shift;

    return undef unless ($string =~ /fragment[s]?\s+([\d\,\-]+)\s+of\s+(\d+)/);

# decodes string like: 'fragment N,M,K-L of T' (total number at end)

    my $parts = $1;
    my $total = $2;
# the parts can contain a single number, a range (n-m) or a set of ranges
    my @parts;
    my @intervals = split /\,/,$parts;
    foreach my $interval (@intervals) {
        my @part = split /\-/,$interval;
# complete single-number interval
        push @part, $interval if (scalar(@part) == 1);
        push @parts,[@part];
    }

    return $total,[@parts]; # total & array of arrays
}

sub composefragments {
# encode a fragmented tag comment
    my $total = shift;
    my $parts = shift;

# sort parts according to increasing begin number
        
    @$parts = sort {$a->[0] <=> $b->[0]} @$parts;

# compose a string like: 'fragment N,M,K-L of T' (total number at end)

    my @join;
    my $fragmentstring = '';
    for (my $i = 0 ; $i < scalar(@$parts) ; $i++) {
	my $part = $parts->[$i];
        @join = @$part unless (@join);
        if ($part->[0] <= $join[1] + 1) {
# the new interval overlaps with the previous
            $join[1] = $part->[1];
        }
        if ($part->[0] > $join[1] + 1 || $i == scalar(@$parts) - 1) {
# the previous interval is disconnected from the next
# add the interval to the fragmentstring
            $fragmentstring .= ',' if $fragmentstring;
            $fragmentstring .= "$join[0]" if (@join == 1);
            $fragmentstring .= "$join[0]-$join[1]" if (@join > 1);
            @join = @$part;
        }
    }

    my $tagcomment = "fragment " . $fragmentstring." of $total";

    return $tagcomment;
}

#-----------------------------------------------------------------------------
# access protocol
#-----------------------------------------------------------------------------

sub verifyParameter {
    my $object = shift;
    my $method = shift || 'UNDEFINED';
    my %options = @_; # class, type

    $options{class} = 'Tag' unless defined $options{class};

    &verifyPrivate($object,'verifyParameter');

    unless ($object && ref($object) eq $options{class}) {
        print STDERR "ContigTagFactory->$method expects a $options{class} "
                   . "instance as parameter\n";
	return 0;
    }

    return 1 unless (ref($object) eq 'Tag'); # for objects different from Tag

# test the tag type by interogating its host class, if any

    return 1 unless $options{type};

# test the tag type

    my $hostclass = $object->getHostClass() || "unknown";

    unless ($hostclass && $hostclass =~ /^(Contig|Read|contigtag|readtag)/
                       && $hostclass =~ /$options{type}/i) {
        print STDERR "ContigTagFactory->$method expects a tag of type "
	             . "$options{type} (instead of '$hostclass')\n";
        return 0;      
    }

    return 1;
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return 1 unless ($caller && ref($caller) eq 'ContigHelper');

    print STDERR "Invalid usage of private method '$method' in package "
               . "ContigTagFactory\n";
    return 0;
}

#----------------------------------------------------------------------

1;
