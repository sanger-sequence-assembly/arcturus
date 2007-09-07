package Tag;

use strict;

use Mapping;

use TagFactory::TagFactory; # helper class

#----------------------------------------------------------------------
# creating a new tag
#----------------------------------------------------------------------

sub new {
# constructor
    my $prototype = shift;

    my $class = ref($prototype) || $prototype;

    my $this = {};

    bless $this, $class;

    $this->setHost(@_) if @_;

    return $this;
}

sub copy {
# spawn an exact copy of this tag
    my $this = shift;

    my $tag = $this->new();

    my @items = ('Host',
                 'PositionMapping', # copy positions via mapping intermediate
                 'Strand','Comment','SequenceID', #  TAG2CONTIG table items
                 'TagID','Type','SystematicID',   #   CONTIGTAG table items
                 'TagComment','TagSequenceID',    #   CONTIGTAG table items
                 'TagSequenceName','DNA');        # TAGSEQUENCE table items

    foreach my $item (@items) {
        eval("\$tag->set$item(\$this->get$item())");
        print STDERR "failed to copy Tag $item ('$@')\n" if $@;
#        $LOGGER->error("failed to copy $item ('$@')") if ($LOGGER && $@);
    }

    return $tag;
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
# return comment and truncation / frameshift status
    my $this = shift;
    my %options = @_;

    my $comment = $this->{comment} || '';

    return $comment if $options{nostatus};

# append truncation and frame shift status, if any

    my $status = '';
    my $truncated = $this->getTruncationStatus('l'); 
    $status .= "l:$truncated " if $truncated;
    $truncated = $this->getTruncationStatus('r'); 
    $status .= "r:$truncated " if $truncated;
    $status = "truncated $status" if $status;
    my $shifts = $this->getFrameShiftStatus();
    $status .= "frameshifts: $shifts" if $shifts;

    return $comment unless $status;

    $status =~ s/^\s+|\s+$//g;
    $status = " ($status)" if $comment;
    $comment .= $status;
    return $comment;
}

sub setDNA {
# DNA sequence of (special) tags, e.g. oligos
    my $this = shift;

    $this->{DNA} = shift;
}

sub getDNA {
# the DNA string is assumed to correspond to the forward strand
# optionally, reverse-complement the dna if strand is reverse
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
    return ref($host) || ucfirst($host) || '';
}

# positions are stored as begin-end pairs (array of arrays)

sub setPosition {
# begin and end position in read or contig sequence
    my $this = shift;
    my @position = (shift,shift);
    my %options = @_;

    @position = sort {$a <=> $b} @position; # ensure ordering of segment

# clear position buffer and mapping unless otherwise specified

    $this->{position} = [] unless $options{join};

    undef $this->{mapping} unless $options{keep};

# add this position pair to the buffer

    $this->{position} = [] unless $this->{position};

    my $positionpairs = $this->{position};

    push @$positionpairs,[@position];

    return $this->isComposite(); # sorts intervals, returns number of segments - 1
}

sub getPosition {
# return the specified position segment, default the first pair
    my $this = shift;
    my $pair = shift || 0; # number of the pair

    my $positionpairs = $this->{position};

    return undef unless $positionpairs;

    return undef if ($pair < 0 || $pair >= @$positionpairs); # does not exist
    
    return @{$positionpairs->[$pair]};
}

sub setPositionMapping {
# import positions as segments of a mapping; also keep the mapping itself
    my $this = shift;
    my $mapping = shift;

    $this->{mapping} = $mapping;

    return unless $mapping;

    my $segments = $mapping->getSegments();

    my %options = (keep=>1,join=>0);
    foreach my $segment (@$segments) {
        $this->setPosition($segment->getYstart,$segment->getYfinis,%options);
        $options{join} = 1;
    }
}

sub getPositionMapping {
# export the positions as an alignment mapping
    my $this = shift;
    my %options = @_;

    if (my $mapping = $this->{mapping}) {
        return $mapping unless $options{new};
    }

    my $pairs = $this->isComposite(); # sort and test
    return undef unless defined($pairs);

# create a mapping FROM a (ficticious) tag sequence of length equal
# to the sum total of position intervals (x) TO the tagged sequence (y)

    my $mapping = new Mapping($this->getTagSequenceName() || $this->getTagID());

    my $start = 1;
    for (my $pair = 0 ; $pair <= $pairs ; $pair++) {
        my @csegment = $this->getPosition($pair); # on contig
        my $segmentlength = $csegment[1] - $csegment[0];
        my $final = $start + $segmentlength; 
        $mapping->putSegment($start,$final,@csegment); # sequence position last
        $start = $final + 1;
    }
    
    return $mapping;
}

sub isComposite {
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

    my @position = $this->getPosition(0); # the first position pair

    return $position[0];
}

sub getPositionRange {
    my $this = shift;

    my $part = $this->isComposite();
    return undef unless defined($part);


    my @pf = $this->getPosition(0);     # first segment;
    my @pl = $this->getPosition($part); # last  segment;

# alternative to be VERIFIED
my $test = 0; if ($test) {
    my $mapping = $this->getPositionMapping(new=>1);
    my @range = $mapping->getMappedRange();
    unless ($pf[0] == $range[0] && $pf[1] == $range[1]) {
        print STDOUT "range: @range  pfs: $pf[0], $pl[1]\n";
    }
#    return $mapping->getMappedRange();
}

    return $pf[0], $pl[1];
}

sub getPositionRight {
    my $this = shift;

    my @position = $this->getPosition(0); # the first position pair

    return $position[1];
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

    my $part = $this->isComposite();
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

    my @range = $this->getPositionRange();

    return abs($range[1] - $range[0]) + 1;
}

# orientation

sub setStrand {
    my $this = shift;
    my $strand = shift || '';

    if ($strand eq 'Complement' || $strand eq 'C') {
        $this->{strand} = 0  unless   defined $this->{strand};
        $this->{strand} = -$this->{strand} if $this->{strand};
    }
    elsif ($strand eq 'Forward' || $strand eq 'F') {
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
#    TagFactory->composeSystematicID($this) unless $this->{systematicid}; # ?
    return $this->{systematicid} || '';
}

sub setTagComment {
    my $this = shift;

    $this->{tagcomment} = shift;
}

sub getTagComment {
    my $this = shift;
    my %options = @_;
# before export, process possible place holder (<name>)
    if ($this->{tagcomment} && $this->{tagcomment} =~ /\</) {
        TagFactory->processTagPlaceHolderName($this) unless $options{pskip};
    }
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
    my %options = @_;
# before export, process possible place holder (<name>)
    if ($this->{tsname} && $this->{tsname} =~ /\</) {
        TagFactory->processTagPlaceHolderName($this) unless $options{pskip};
    }
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

#---------------------------------------------------------------------------------
# tag propagation info; to be included in comment / tagcomment on export
#---------------------------------------------------------------------------------

sub setFrameShiftStatus {
    my $this = shift;
    $this->{frameshift} = shift;
}

sub getFrameShiftStatus {
    my $this = shift;
    return $this->{frameshift} || 0;
}

sub setTruncationStatus {
    my $this = shift;
    my %options = @_; # define as : l => M , r => N
    foreach my $side ('l','r') {
        $this->{"${side}truncation"} = $options{$side} if defined $options{$side};
    }
}

sub getTruncationStatus {
    my $this = shift;
    my $side = shift; # either l or r
    unless (defined($side) && $side =~ /\bl|r\b/) {
        return $this->getTruncationStatus('l') + $this->getTruncationStatus('r');
    }
    return $this->{"${side}truncation"} || 0;
}

#----------------------------------------------------------------------
# methods delegating processing to the TagFactory helper class
#----------------------------------------------------------------------

sub transpose {
# transpose a tag by applying a linear transformation
# returns a new tag unless the 'nonew' option is set true
    my $this =shift;
    my $align = shift;
    my $offset = shift;
    my %options = @_;

    &verifyKeys('transpose',\%options,'prewindowstart' ,'prewindowfinal',
                                      'postwindowstart','postwindowfinal',
		                      'nonew') unless (scalar(@_)%2);

    return TagFactory->transpose($this,$align,$offset,@_);
}

sub mirror {
# invert tag, optionally with positions inside a specified interval
# returns a new tag unless the 'nonew' option is set true
    my $this =shift;
    my $mpupper = shift; # mirror position
    my %options = @_;

    &verifyKeys('mirror',\%options,'mirrorpositionlower', # default 1
                                   'prewindowstart' ,'prewindowfinal',
                                   'postwindowstart','postwindowfinal',
		                   'nonew');

    my $mplower = $options{mirrorpositionlower} || 1;
    $options{postwindowstart} = $mplower unless defined($options{postwindowstart});
    $options{postwindowfinal} = $mpupper unless defined($options{postwindowfinal});

    return TagFactory->transpose($this,-1,$mpupper+$mplower,%options);
}

sub remap { 
# transpose using input mapping; returns an array of (one or more) new tags, or undef
    my $this = shift;
    my $mapping = shift;
    my %options = @_;

    &verifyKeys('remap',\%options,'prewindowstart' ,'prewindowfinal',
                                  'postwindowstart','postwindowfinal',
                                  'break','nobreak','segmentaware',
 'usenew','list','useold', 
                                  'minimumsegmentsize',        
                                  'annooptions','sysIDoptions','changestrand');

    return TagFactory->remap($this,$mapping,%options);
}

sub split {
# split a composite tag into fragments for each position interval
    my $this = shift;
    my %options = @_; # which ?

    return $this unless $this->isComposite();

    return TagFactory->split($this,@_); # returns reference to an array of tags 
}

sub collapse {
# replace a composite tag position by one position interval
    my $this = shift;
    my %options = @_; # which ?

    return $this unless $this->isComposite();

    return TagFactory->collapse($this,@_); # returns a single tag
}

sub isEqual {
# compare this tag with another one; returns true for equality
    my $this = shift;
    my $tag  = shift;
    my %options = @_; # 'ignorenameofpattern, includestrand, inherit
  
    &verifyKeys('isEqual',\%options,'ignorenameofpattern',
                                    'ignoreblankcomment',
		                    'includestrand',
                                    'copy','copycom',
                                    'overlaps','contains',
                                    'inherit');

    return TagFactory->isEqual($this,$tag,%options);
}

#----------------------------------------------------------------------
# output
#----------------------------------------------------------------------

sub writeToCaf {
# output for all tags, except ANNO tags (see Contig->writeToEMBL)
    my $this = shift;
    my $FILE = shift; # optional output file handle
    my %options = @_; # option 'annotag' allows override of default

    &verifyKeys('writeToCaf',\%options,'pair','annotag');

    my $pair = $options{pair};

    unless (defined($pair)) {
# this recursion deals with tags having more than one position segment
        if (my $pairs = $this->isComposite()) {
            my $string = '';
            for (my $pair = 0 ; $pair <= $pairs ; $pair++) {
                $string .= $this->writeToCaf($FILE,pair=>$pair,@_);
                $string .= "\n";
	    }
            return $string;
        }        
        $pair = 0;
    }

    my $type = $this->getType();
    my @pos  = $this->getPosition($pair);
    my $tagcomment = $this->getTagComment();
    my $comment = $this->getComment();

    return '' if ($type eq 'ANNO' && !$options{annotag});

# various types of tag, NOTE and ANNO are two special cases

    my $host = $this->getHostClass();

    my $string = "Tag $type ";

    if ($type eq 'NOTE') {
# GAP4 NOTE tag, no position info
    }

    elsif ($type eq 'ANNO' && (!$host || $host eq 'Contig')) {
# if no host, assume it's a contig; contig annotation tags have special status
# generate two tags, ANNO contains the systematic ID and comment
        $string .= "@pos ";
# add the systematic ID
        my $tagtext = $this->getSystematicID() || 'unspecified'; 
        $tagtext .= ' ' . $comment if $comment;
        $string .= "\"$tagtext\"\n" ;
# if also a comment available add an info tag
        $string .= "Tag INFO @pos \"$tagcomment\"\n" if $tagcomment;
    }

    elsif ($host eq 'Read') {
# standard output of tag with position and tag comment (including ANNO)
        $string .= "@pos "; 
        $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
        $string .= "\"$tagcomment\"" if $tagcomment;
        $string .= "\n";
    }
    elsif ($host eq 'Contig') {
# standard output of tag with position and tag comment (except ANNO)
        $string .= "@pos "; 
        $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
        $string .= "\"$tagcomment\"" if $tagcomment;
        $string .= "\n";
# if comment available add an INFO tag
        if ($comment && $options{infotag}) {
            $string .= "Tag INFO @pos \"$comment\"\n";
	}
    }

    elsif ($host) {
        print STDERR "Unknown host type $host in tag\n";
    }

    else {
# standard output of tag with position and tag comment
        $string .= "@pos "; 
        $tagcomment =~ s/\\n\\/\\n\\\n/g if $tagcomment;
        $string .= "\"$tagcomment\"" if $tagcomment;
        $string .= "\n";
# if comment available add an INFO tag
        if ($comment && $options{infotag}) {
            $string .= "Tag INFO @pos \"$comment\"\n";
	}
    }

    $string  =~ s/(\"\s*\")/\"/g; # remove doubly occurring quotes

    print $FILE $string if $FILE;

    return $string;
}

sub writeToEMBL {
# write the tag in EMBL, i.p. annotation tags
    my $this = shift;
    my $FILE = shift; # optional output file handle
    my %options = @_; # tagkey (CDS/TAG)

    &verifyKeys('writeToEMBL',\%options,'tagkey');

    my $tagtype    = $this->getType();
    my $strand     = lc($this->getStrand());
    my $sysID      = $this->getSystematicID();
    my $comment    = $this->getComment();
    my $tagcomment = $this->getTagComment();
        
    my $key = $options{tagkey} || 'CDS'; # get the key to be used for export
    
    my $sp17 = "                 "; # format spacer

# composite tags have more than one position interval specified

    my $string  = "FT   ".sprintf("%3s",$key)."             ";
    if ($this->isComposite()) {
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
    my %options = @_;

    &verifyKeys('dump',\%options,'skip','pskip');

    my $skip = $options{skip}; # true to skip undefined items

    my $report = $tag->getHost() . "Tag instance $tag\n";

    my @line;
    push @line, "sequence ID       ".($tag->getSequenceID() || 0)."\n";
    push @line, "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    my $position;
    my $pairs = $tag->isComposite();
    foreach my $p (0 .. $tag->isComposite()) {
        $position .= " ; " if $position;
        my @position = $tag->getPosition($p);
        $position .= "@position";
    }
    push @line, "position          $position\n";
    push @line, "strand            ".($tag->getStrand()  || 'undef')."\n";
    push @line, "comment           ".($tag->getComment() || 'undef')."\n\n";
    push @line, "tag ID            ".($tag->getTagID()   || 'undef')."\n";
    push @line, "tag type          ".($tag->getType()    || 'undef')."\n";
    push @line, "systematic ID     ".($tag->getSystematicID()  || 'undef')."\n";
    push @line, "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    push @line, "tag comment       ".($tag->getTagComment(@_)  || 'undef')."\n\n";
    push @line, "tag sequence ID   ".($tag->getTagSequenceID() || 'undef')."\n";
    push @line, "tag sequence name ".($tag->getTagSequenceName(@_) || 'undef')."\n";
    push @line, "sequence          ".($tag->getDNA() || 'undef')."\n";
    push @line, "tag host class    ".($tag->getHostClass() || 'undef')."\n";

    foreach my $line (@line) {
	next if ($skip && $line =~ /undef/);
        $report .= $line;
    }

    print $FILE $report  if $FILE;

    return $report;
}

#-------------------------------------------------------------------    
# access protocol
#-------------------------------------------------------------------    

sub verifyKeys {
# test hash keys against a list of input keys
    my $method = shift; # method name
    my $hash = shift; # reference to hash

    my %keys;
    foreach my $key (@_) {
	$keys{$key} = 1;
    }

    while (my($key,$value) = each %$hash) {
        next if $keys{$key};
        $value = 'undef' unless defined($value);
        next if ($key eq 'debug' || $key eq 'logger');
        print STDERR "Invalid key $key => '$value' provided "
                   . "for method Tag->$method\n";
    }
}

#----------------------------------------------------------------------

1;
