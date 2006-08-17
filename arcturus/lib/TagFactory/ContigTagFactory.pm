package ContigTagFactory;

use strict;

use Tag;

use Mapping;

#----------------------------------------------------------------------
#
#----------------------------------------------------------------------

my $contigtagfactory; # class variable

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

sub verify {
# private: verify the correct input type of a tag
    my $tag = shift;
    my $origin = shift;

# test the instance signature 

    unless (ref($tag) eq 'Tag') {
        print STDERR "ContigTagFactory->$origin expects a "
                   . "Tag instance as parameter\n";
	return 0;
    }

# test the tag type by interogating about its host class, if any

    unless ($tag->getHostClass() eq 'Contig') {
        print STDERR "ContigTagFactory->$origin expects a "
                   . "tag of type ContigTag (instead of : "
                   . ($tag->getHost() || "unknown type") 
                   . ")\n"; # if 0;
#        return 0;      
        print STDERR $tag->dump() . "\n";
    }

    return 1;
}

#----------------------------------------------------------------------

sub make {
# make a new contig Tag instance
    my $this = shift;
    my ($tagtype,$start,$final,%options) = @_;

print STDERR "ContigTagFactory::make used\n";

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

sub copy {
# return a copy of the input Tag instance
    my $this = shift;
    my $tag  = shift;
    my %options = @_;

    return undef unless &verify($tag,'copy');

# create (spawn) a new tag instance

    my $newtag = $tag->new($tag->getHost());

    $newtag->setTagID($tag->getTagID());
# TAG2CONTIG table items
    $newtag->setPosition($tag->getPosition());
    my $strand = $tag->getStrand();
    if ($options{changestrand}) {
	my %inverse = (Forward => 'Reverse', Reverse => 'Forward');
        $strand = $inverse{$strand} || 'Unknown';
    } # 'Unknown' is unchanged
    $newtag->setStrand($strand);
    $newtag->setComment($tag->getComment());
# CONTIGTAG table items
    $newtag->setType($tag->getType());
    $newtag->setSystematicID($tag->getSystematicID());
    $newtag->setTagSequenceID($tag->getTagSequenceID());
    $newtag->setTagComment($tag->getTagComment());
# TAGSEQUENCE table items
    $newtag->setTagSequenceName($tag->getTagSequenceName()); 
# DNA always relates to forward strand
    $newtag->setDNA($tag->getDNA()); 

    return $newtag;
}

#----------------------------------------------------------------------

sub transpose {
# transpose a tag by applying a linear transformation
# (apply only to contig tags)
# returns new Tag instance (or undef)
    my $class = shift;
    my $tag   = shift;
    my $align = shift;
    my $offset = shift; # array length 2 with offset at begin and end
    my $window = shift || 1; # new position in range 1 .. window

    return undef unless &verify($tag,'transpose');

print STDERR "ContigTagFactory::transpose used\n";

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
    $newcomment .= "imported ".$tag->getSystematicID();
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

    return $newtag;
}

sub remap {
# takes a mapping and transforms the tag positions to the mapped domain
# returns an array of (one or more) new tags, or undef
    my $this = shift;
    my $tag  = shift;
    my $mapping = shift;
    my %options = @_;

# options:  break = 1 to allow splitting of a tag straddling mapping segments
#                     and return a separate tag for each segment
#                   0 (default) to not allow that; if a sequence is provided
#                     generate a tag sequence with pad(s)
#           sequence, if provided used to generate a tagsequence, possibly 
#                     with pads; in its absence a long comment is generated

    return undef unless &verify($tag,'remap');

    unless (ref($mapping) eq 'Mapping') {
        die "ContigTagFactory->remap expects a Mapping instance as parameter";
    }

# get current tag position

    my @currentposition = $tag->getPosition();

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
#    my $sequence = $tag->getDNA();
#    $sequence = $options{sequence} if $options{sequence};

    if ($numberofsegments == 1) { 
# CASE 1: one shift for the whole tag
#        my $newtag = $tag->copy(%options);
        my $newtag = $this->copy($tag,%options);
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
# XXX how do we handle clipping?
        for (my $i = 0 ; $i < $numberofsegments ; $i++) {
#            my $newtag = $tag->copy(%options);
            my $newtag = $this->copy($tag,%options);
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
#        my $newtag = $tag->copy(%options);
        my $newtag = $this->copy($tag,%options);
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

sub merge {
# merge a tag fragment and a neighbouring tag fragment (if possible)
    my $this = shift;
    my $atag = shift;
    my $otag = shift;
    my %options = @_;

    return undef unless &verify($atag,'merge first parameter');
    return undef unless &verify($otag,'merge second parameter');

$options{debug} = 2;

# test the tag type

    return undef unless ($atag->getType() eq $otag->getType());

    my @atagposition = $atag->getPosition();
    my @otagposition = $otag->getPosition();

    my ($left,$right);
    if ($atagposition[1] == $otagposition[0] - 1) {
# other tag is butting to the right of this
        ($left,$right) = ($atag,$otag); 
    }
    elsif ($atagposition[0] == $otagposition[1] + 1) {
# this is butting to the right of other tag
        ($left,$right) = ($otag,$atag); 
    }
    else {
	return undef;
    }


if ($options{debug} && $options{debug}>1) {
 print STDOUT "tag positions DO butt: @atagposition, @otagposition \n";
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

    my $newtag = $atag->new();
    $newtag->setType($atag->getType());
    $newtag->setPosition($lposition[0],$rposition[1]);
    $newtag->setSystematicID($atag->getSystematicID());
    $newtag->setStrand($atag->getStrand());
# get the new DNA and test against length
    my $DNA = $left->getDNA() . $right->getDNA();
    $newtag->setDNA($DNA) if ($DNA =~ /\S/);
# merge the comments
    my $comment;
    if ($left->getComment() eq $right->getComment()) {
        $comment = $left->getComment();
    }
    else {
        $comment = $left->getComment() . " " . $right->getComment();
    }
# merge the tagcomments
    my $atagcomment;
    my @l = &unravelfragments( $left->getTagComment());
    my @r = &unravelfragments($right->getTagComment());
    if (@l && @r && $l[0] == $r[0]) {
        my $total = $l[0];
# we are dealing with fragments of a split tag; compose the new tagcomment
        my @parts;
        if ($r[1] == $l[$#l]+1) {
            push @parts, @l;
            $parts[$#l] = $r[$#r];
        }
        elsif ($l[1] == $r[$#r]+1) {
            push @parts, @r;
            $parts[$#r] = $l[$#l];
	}
        else {
            push @parts, @l;
            push @parts, @r;
	}
        @parts = sort {$a <=> $b} @parts;
        if (scalar(@parts) == 2 && $parts[0] == 1 && $parts[1] == $total) {
            $comment = 'rejoined after having been split!';
            undef @parts;
	}
        $atagcomment = &composefragments($total,@parts) if @parts;
    }
    else {
# cannot handle the comments; just concatenate the two
        $atagcomment = $left->getTagComment() . " " . $right->getTagComment();
    }

    $newtag->setComment($comment) if $comment;
    $newtag->setTagComment($atagcomment) if $atagcomment;

$newtag->writeToCaf(*STDOUT,annotag=>1) if $options{debug};
    return $newtag;
}

sub mirror {
# apply a mirror transform to the tag position
    my $this = shift;
    my $tag  = shift;
    my $mirror = shift || 0; # the mirror position (e.g. contig_length + 1)

    return undef unless &verify($tag,'mirror');
print STDERR "ContigTagFactory::mirror used\n";

    my @currentposition = $tag->getPosition();

    foreach my $position (@currentposition) {
        $position = $mirror - $position;
    }
    $tag->setPosition(@currentposition);
}

sub positionshift {
# apply a linear transform to the tag position (to be completed)
    my $this = shift;
    my $tag  = shift;
    my $shift = shift;
    my $start = shift; # begin of window
    my $final = shift; #  end  of window

print STDERR "ContigTagFactory::shift used\n";

    unless (ref($tag) eq 'Tag') {
        die "ContigTagFactory->shift expects a Tag instance as parameter";
    }

    return undef;
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

sub unravelfragments {
# decode fragment description for a split tag
    my $string = shift;

    return undef unless ($string =~ /fragment[s]?\s+([\d\,\-]+)\s+of\s+(\d+)/);

    my $parts = $1;
    my $total = $2;
# the parts can contain a single number, a range (n-m) or a set of ranges
    my @parts;
    my @intervals = split /\,/,$parts;
    foreach my $interval (@intervals) {
        my @part = split /\-/,$interval;
# complete single-number interval
        push @part, $interval if (scalar(@part) == 1);
        push @parts,@part;
    }

    return $total,@parts;
}

sub composefragments {
# encode a fragmented tag comment
    my $total = shift;
    my @parts = @_;

    my $tagcomment = "fragment ";




    return $tagcomment;
}

#----------------------------------------------------------------------

1;
