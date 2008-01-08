package TagFactory;

use strict;

use Tag;

use Mapping;

use Logging;

# ----------------------------------------------------------------------------
# purpose
# ----------------------------------------------------------------------------
#
# This is a helper module for testing the contents of tags, in particular
# oligo tags, both when loading new tags from e.g. a CAF file data source,
# or when testing tag data already stored in the Arcturus data base.
#
# The information processed by this module is presented in a Tag object,
# which may have been assembled by a loading script containing the "raw" 
# tag data read from the data source, or it can have been assembled from
# the data in the Arcturus database, in which case this module can be used 
# to test the tag information for internal consistency.
#
# When loading new tags, the usual information available consists of the
# tag type, its position and a tag comment, which, in the case of oligios,
# can contain a tagsequence name and posibly the DNA sequence fragment. That 
# information is parsed and those attributes extracted, while possible 
# redundent information or clutter can be removed from the comment.
#
# When testing an existing tag already stored, the same processes can be used
# to test and possibly restore the consistency of e.g. the tag sequence name 
# and the comment; a modified tag may subsequently replace the original one
# in Arcturus (using a specialized script)
#
# ----------------------------------------------------------------------------

my $tagfactory; # class variable

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
# constructor
    my $class = shift;

# the following ensures only one instance per process

    my $this =$tagfactory; 

    unless ($this && ref($this) eq $class) {
# create a new instance
        $this = {};

        bless $this, $class;

       $tagfactory = $this;
    }

    return $this;
}

#----------------------------------------------------------------------
# creating a new Tag instance
#----------------------------------------------------------------------

sub makeReadTag {
    my $newtag = &makeTag(@_);
    $newtag->setHost('Read');   # define kind
    return $newtag;
}

sub makeContigTag {
    my $newtag = &makeTag(@_);
    $newtag->setHost('Contig');
    return $newtag;
}

sub makeTag {
# make a new tag
    my $this = shift;
    my ($tagtype,$start,$final,%options) = @_;

    my $newtag = new Tag(); # no type

    $newtag->setType($tagtype); # gap4 tag type
    $newtag->setPosition($start,$final);
    $newtag->setStrand('Forward'); # default

    foreach my $item (keys %options) {
        my $value = $options{$item};
        eval("\$newtag->set$item(\$value)");
    }

    return $newtag;
}

#----------------------------------------------------------------------
# compare two tags
#----------------------------------------------------------------------

sub isEqual {
# compare two tags
    my $class = shift;
    my $atag = shift;
    my $otag  = shift;
    my %options = @_;
    
    return undef unless &verifyParameter($atag,'isEqual (1-st parameter)');

    return undef unless &verifyParameter($otag,'isEqual (2-nd parameter)');

#    my $logger = &verifyLogger('isEqual');

# compare tag type and host type

    return 0 unless ($atag->getType() eq $otag->getType());

    return 0 unless ($atag->getHostClass() eq $otag->getHostClass());

# compare tag position(s) by looking at the mapping representation

    my $amap = $atag->getPositionMapping();
    my $omap = $otag->getPositionMapping();
    my @equal = $amap->isEqual($omap);
# insist on equality of position(s) with same alignment and no shift 
    unless ($equal[0] == 1 && $equal[1] == 1 && $equal[2] == 0) {
        return 0 unless ($options{overlaps} || $options{contains});
# test if otag tags is embedded in atag 
        my @arange = $amap->getMappedRange();
        my @orange = $omap->getMappedRange();
# test if arange contains orange
        if ($options{contains}) {
            return 0 if ($orange[0] < $arange[0]);
            return 0 if ($orange[1] > $arange[1]);
        }
        if ($options{overlaps}) {
            return 0 if ($orange[1] < $arange[0]);
            return 0 if ($orange[0] > $arange[1]);
        }
    }

# compare tag comments

    if ($atag->getTagComment() =~ /\S/ && $otag->getTagComment() =~ /\S/) {
# both comments defined
        unless ($atag->getTagComment() eq $otag->getTagComment()) {
# tags may be different, do a more detailed comparison using a cleaned version
            my $inop = $options{ignorenameofpattern}; # e.g.: oligo names
            unless (&cleanuptagcomment($atag->getTagComment(),$inop) eq
                    &cleanuptagcomment($otag->getTagComment(),$inop)) {
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

sub cleanuptagcomment {
# private method cleanup for purpose of comparison of comments
    my $comment = shift;
    my $inop = shift; # special treatment for e.g. auto-generated oligo names

    &verifyPrivate($comment,'cleanuptagcomment');

# remove quotes, '\n\' and shrink blankspace into a single blank

    $comment =~ s/^\s*([\"\'])\s*(.*)\1\s*$/$2/; # remove quotes
    $comment =~ s/^\s+|\s+$//g; # remove leading & trailing blank
    $comment =~ s/\\n\\/ /g; # replace by blank space
    $comment =~ s/\s+/ /g; # shrink blank space

    $comment =~ s/^$inop// if $inop; # remove if present at begin
   
    return $comment;
}


#-----------------------------------------------------------------------------
# Read tags : cleanup/reformat/analyse tag info and if needed standardise
#-----------------------------------------------------------------------------

sub cleanup {
# clean the tag info by removing clutter, double info and redundent new line
    my $this = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'cleanup',kind=>'Read');

    my $info = $tag->getTagComment();

    my ($change,$inew) = &cleanupreadtaginfo($info);

    return 0 unless $change; # no change

    $tag->setTagComment($inew); # the new cleaned-up tag info

    return $change; # the number of changes
}

#-----------------------------------------------------------------------------

sub processOligoTag {
# test/complete oligo information
    my $this = shift;
    my $tag  = shift;
    my %options = @_; # used in repair mode
 
    return undef unless &verifyParameter($tag,'processOligoTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'OLIG' || $tagtype eq 'AFOL');

    my $report = '';
    my $warning = 0;

# extract the oligo DNA from the tag comment
# compare it with stored tag sequence, if any

    my $tagcomment = $tag->getTagComment();
  
    my ($DNA,$newcomment) = &get_oligo_DNA($tagcomment);

    if (!$DNA && !$tag->getDNA()) {
        $report .= "Missing DNA sequence in oligo tag info\n";
        $warning++;
    }
    else {
# has the tag comment changed?
        if ($newcomment) {
	    $report .= "Multiple DNA info removed from $tagtype tag\n";
            $tagcomment = &cleanupreadtaginfo($newcomment);
	    $tag->setTagComment($tagcomment);
            $warning++;
        }
# compare DNA with stored version (if any)
        if (!$tag->getDNA()) {
            $report .= "Oligo tag DNA sequence $DNA added\n";
            $tag->setDNA($DNA);
            $warning++;
        }
        elsif ($DNA && $tag->getDNA() ne $DNA) {
            $report .= "Oligo tag DNA sequence ($DNA) conflicts with tag\n"
	            .  "comment $tagcomment\nDNA sequence replaced\n";
            $tag->setDNA($DNA); # always repair
            $warning++;
	}
    }

# test DNA length against position specification

    $DNA = $tag->getDNA(); # may have changed
    if ($DNA && (my $length = length($DNA))) {

	my ($tposs,$tposf) = $tag->getPosition();
        
        unless ($tposf > $tposs) {
            $report .= "oligo length error ($tposs $tposf) in tag comment\n"
	            .  "$tagcomment\n";
	    $warning++;
# abort: invalid position information
            return $warning, $report;
        }

        if ($tposf-$tposs+1 != $length) {
            $report .= "oligo length mismatch ($tposs $tposf $length) "
                    .  "in tag comment\n$tagcomment\n";
# you might want to correct the positions by matching against read?
	    $warning++;
        }
    }

# get the tag sequence name from the oligo information ($tagcomment)

    if ($tagtype eq 'AFOL') {
# these tags are supposed to have a standard (Staden) format with the
# tag sequence name specified; test/assign to the $tag instance 
        if ($tagcomment =~ /oligoname\s*(\w+)/i) {
            my $newtagseqname = $1;
# check the name against the one of this $tag, if it is defined
            if (my $oldtagseqname = $tag->getTagSequenceName()) {
                if ($oldtagseqname ne $newtagseqname) {
                    $report .= "oligo tag sequence name mismatch "
                            .  "($oldtagseqname <> $newtagseqname) "
                            .  "in tag comment\n$tagcomment\n";
	            $warning++;
		}
                $tag->setTagSequenceName($newtagseqname); # if $options{forcen}
	    }
	    else {
# assign/replace name derived from tag comment
                $tag->setTagSequenceName($newtagseqname);
	    }
        }
	else {
            $report .= "Unrecognized tag information\n$tagcomment\n";
	    $warning++;
	}
    }

    elsif ($tagtype eq 'OLIG') {
# these tags have a loosly defined structure which has to be "decoded"
# we try to extract a tagsequence name from the tag information 
        my ($newname,$newcomment) = &decode_oligo_info($tagcomment,$DNA);

# test if the comment contains a place holder

        if ($newcomment && $newcomment =~ /\<\w+\>/) {
# if the tag sequence name is defined, and matches the generic place
# holder name, then substitute the place holder in the tag comment
            my $placeholder = $1;
            my $tagseqname = $tag->getTagSequenceName(); # existing name,if any
            if ($tagseqname && $tagseqname =~ /^$placeholder\w+/) {
                $newcomment =~ s/\<$placeholder\>/$tagseqname/;
                $report .= "place holder <$placeholder> replaced by "
		        .  "existing tag sequence name $tagseqname\n";
                $warning++;
            }
            elsif ($tagseqname) {
# the tag sequence name is defined, but differs from the placeholder name
# two options: replace the place holder by the tag sequence name, or
# overwrite the currrent sequence name and substitute by the place holder
                $report .= "Conflicting tag sequence name and place holder: "
		        .  "($tagseqname, <$placeholder>)\n";
                $warning++;
# choose which one by specifying the name with the force option (repair mode)
                if (my $force = $options{nameforcing}) {
                    if ($tagseqname =~ /$force/ && $placeholder =~ /$force/) {
                        $report .= "'force' option not discriminating\n";
                    }
		    elsif ($tagseqname =~ /$force/) {
                        $newcomment =~ s/\<$placeholder\>/$tagseqname/;
                    }
                    else {
                        $tag->setTagSequenceName($placeholder);
		    }
		}
            }
	    else {
# the tag name is not defined, enter the placeholder
                $tag->setTagSequenceName($newname);
	    }
            $tag->setTagComment($newcomment);
	}

        elsif ($newname && $tag->getTagSequenceName()) {
# test the name (from comment) against existing name
            my $tagseqname = $tag->getTagSequenceName();
            unless ($newname eq $tagseqname) {
                $report .= "tag sequence name change indicated: "
		        .  "($tagseqname --> $newname)\n";
# specify with the force option if the new name is selected
                my $force = $options{nameforcing};
                if ($force && ($newname =~ /$force/ || $tagseqname =~ /$force/)) {
                    $tag->setTagSequenceName($newname);
                }
	    }
            $tag->setTagComment($newcomment) if $newcomment;
	}

        elsif ($newname) {
# there is no existing name; assign the tag sequence name
            $tag->setTagSequenceName($newname);
            $tag->setTagComment($newcomment) if $newcomment;
	}

        else {
	    $report .= "Failed to decode OLIGO description:\n$tagcomment\n";
            $warning++;
	}
    }

    return $warning,$report;
}

sub processRepeatTag {
# check repeat tags for presence of tag sequence name
    my $this = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'processRepeatTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'REPT');

    my $tagcomment = $tag->getTagComment();
# test presence of a (repeat) tag sequence name upfront
    if ($tagcomment =~ /^\s*(\S+)\s/i) {
        $tag->setTagSequenceName($1);
        return 1;
    }
    return 0; # no name found
}

sub processAdditiveTag {
# check position range
    my $this = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'processAdditiveTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'ADDI');

    my ($tposs,$tposf) = $tag->getPosition();

    return 0 if ($tposs != 1); # invalid position

    return 1;
}

#-----------------------------------------------------------------------------
# private methods doing the dirty work
#-----------------------------------------------------------------------------

sub get_oligo_DNA {
# get DNA sequence from tag comment and remove possible multiple occurrences
    my $info = shift;

    if ($info =~ /([ACGT\*]{5,})/i) {
        my $DNA = $1;
# test if the DNA occurs twice in the data
        if ($info =~ /$DNA[^ACGT].*(sequence\=)?$DNA/i) {
# multiple occurrences of DNA to be removed ...
            $info =~ s/($DNA[^ACGT].*?)(sequence\=)?$DNA/$1/i;
            return $DNA,$info;
        }
	return $DNA,0; # no change
    }

    return 0,0; # no DNA
}

sub decode_oligo_info {
# ad-hoc oligo info decoder
    my $info = shift;
    my $sequence = shift;

# this is a more or less ad-hoc parser for oligo info produced in gap4

my $logger = &verifyLogger('decode_oligo_info');

$logger->debug("decode_oligo_info  $info ($sequence)");

    my $change = 0;
# clean up name (replace possible ' oligo ' string by 'o')
    $change++ if ($info =~ s/\boligo[\b\s*]/o/i);
# remove names of form oligo_m....
    $change++ if ($info =~ s/oligo\_m\w*//);

# replace blank space by \n\ if at least one \n\ already occurs
    if ($info =~ /\\n\\/) {
        $change++ if($info =~ s/\s+/\\n\\/g);
    }
# replace multiple occurring \n\ by one
    $change++ if ($info =~ s/(\\n\\){2,}/\\n\\/g); 
# remove possible place holder name
    $change++ if ($info =~ s/^\<\w+\>//i);

# clean up stretches of text between \n\

    $change++ if ($info =~ s/1300(\d)/130$1/g); # ad hoc
    $change++ if ($info =~ s/ig\\n\\pk/ig-pk/);
    $change++ if ($info =~ s/ig\spk/ig-pk/);

    if ($info =~ /(pcr.+)\\n\\seq/) {
$logger->debug("Ia change $change");
        my $clutter = $1;
        my $cleanup = $clutter;
        $cleanup =~ s/\\n\\/-/g;
        $clutter =~ s/\\/\\\\/g;
$logger->debug("Ia clutter '$clutter'\nIa cleanup '$cleanup'");
        unless ($clutter eq $cleanup) {
            $change++ if ($info =~ s/$clutter/$cleanup/);
        }
    }

$logger->debug("I change $change $info");

# split $info on blanks and \n\ separation symbols

    my @info = split /\s+|\\n\\/,$info;

# cleanup empty flags= specifications

    foreach my $part (@info) {
        if ($part =~ /flags\=(.*)/) {
            my $flag = $1;
            unless ($flag =~ /\S/) {
                $info =~ s/\\n\\flags\=\s*//;
                $change = 1;
            }
        }
    }

    my $name;
    if ($info =~ /^\s*(\d+)\b(.*?)$sequence/) {
# the info string starts with a number followed by the sequence
        $name = "o$1";
        $change++ if ($info =~ s/^\s*(\d+)\b/$name/);
    }
    elsif ($info !~ /serial/ && $info =~ /\b([dopt]\d+)\b/) {
# the info contains a name like o1234 or t1234
        $name = $1;
    }
    elsif ($info !~ /serial/ && $info =~ /\bo([a-z]\d+)\b/) {
        $name = $1;
    }
    elsif ($info !~ /serial/ && $info =~ /[^\w\.]0(\d+)\b/) {
        $name = "o$1"; # correct typo 0 for o
    }
    elsif ($info =~ /\b(o\w+)\b/ && $info !~ /\bover\b/i && $info !~ /\bof\b/i) {
# the info contains a name like oxxxxx
        $name = $1;
    }
# try its a name like 17H10.1
    elsif ($info =~ /^(\w+\.\w{1,2})\b/) {
        $name = $1;
    }
# try with the results of the split
    elsif ($info[0] !~ /\=/ && $info =~ /^([a-zA-Z]\w+)\b/i) {
# the info string starts with a name like axx..
        $name = $1;
    }
    elsif ($info[1] eq $sequence) {
        $name = $info[0];
        $name = "o$name" unless ($name =~ /\D/);
    }

$logger->debug("II name ".($name || '')." (change $change)");
 
    return ($name,0) if ($name && !$change); # no new info
    return ($name,$info) if $name; # info modified


# name could not easily be decoded: try one or two special possibilities


    foreach my $part (@info) {
        if ($part =~ /serial\#?\=?(.*)/) {
            my $number = $1;
            if (defined($number) && $number =~ /\w/) {
# generate a name based on the information following '=' (mostly a number)
                $name = "o$number"; 
# replace the serial field by the name
                $info =~ s/$part/$name/;
            }
            else {
# remove the part from the info (it contains no information)
                $info =~ s/$part//;
	    }
	    $change++;
	}
    }

$logger->debug("name ".($name || '')." (change $change)");

    return ($name,$info) if $name;

# or see if possibly the name and sequence fields have been interchanged

    if ($info[1] =~ /^\w+\.\w{1,2}\b/) {
# name and sequence possibly interchanged
$logger->debug("still undecoded info: $info  (@info)");
        $name = $info[1];
        $info[1] = $info[0];
        $info[0] = $name;
        $info = join ('\\n\\',@info);
$logger->debug("now decoded info: $info ($name)");
        return $name,$info;
    }

# still no joy, try info field that looks like a name (without = sign etc.)

    foreach my $part (@info) {
        next if ($part =~ /\=/);
# consider it a name if the field starts with a character
        if ($part =~ /\b([a-zA-Z]\w+)\b/) {
            my $save = $1;
# avoid repeating information
            $name  = $save if ($name && $save =~ /$name/);
            $name .= $save unless ($name && $name =~ /$save/);
        }
    }

    $info =~ s/\\n\\\s*$name\s*$// if $name; # chop off name at end, if any

# if the name is still blank substitute a placeholder
            
    $name = '<oligo>' unless $name; # place holder name

# put the name upfront in the info string

    $info = "$name\\n\\".$info;
    $info =~ s/\\n\\[\s*|o]\\n\\/\\n\\/g; # cleanup

    return ($name,$info);
}

sub cleanupreadtaginfo {
# remove quotes, redundant spaces and \n\ from the tag description
    my $comment = shift;

    my $changes = 0;

    $changes++ if ($comment =~ s/\s+\"([^\"]+)\".*$/$1/); # remove quotes 

    $changes++ if ($comment =~ s/^\s+|\s+$//); # remove leading/trailing blanks

    $changes++ if ($comment =~ s/\n+/\\n\\/g); # replace new line by \n\

    $changes++ if ($comment =~ s/\\n\\\s*$//); # delete trailing newline

    $changes++ if ($comment =~ s/\s+(\\n\\)/$1/g); # delete blanks before \n\

    $changes++ if ($comment =~ s/(\\n\\)\-(\\n\\)/-/g); # - between \n\

    $changes++ if ($comment =~ s/(\\n\\)o(\\n\\)/\\n\\/g); # o between \n\

    $changes++ if ($comment =~ s/(\\n\\){2,}/\\n\\/g); # remove repeats of \n\

    $changes++ if ($comment =~ s?\\/?/?g); # replace back-slashed slashes

    $changes++ if ($comment =~ /^\s*\\\s*/); # remove a single backslash

    return $changes,$comment;
}

#----------------------------------------------------------------------

sub processTagPlaceHolderName {
# substitute (possible) placeholder name of the tag sequence & comment
    my $this = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'processTagPlaceHolderName');

    my $seq_id = $tag->getSequenceID();
    return undef unless $seq_id; # seq_id must be defined

# a placeholder name is specified with a sequence name value like '<name>'

    my $name = $tag->getTagSequenceName(pskip=>1);
    return 0 unless ($name && $name =~ /^\<(\w+)\>$/); # of form '<name>'

    $name = $1; # get the name root between the bracket 

# replace the tag sequence name by one generated from 'name' & the sequence ID

    my $randomnumber = int(rand(100)); # from 0 to 99 
    my $newname = $name.sprintf("%lx%02d",$seq_id,$randomnumber);
# ok, adopt the new name as tag sequence name
    $tag->setTagSequenceName($newname);

# and similarly, if the place holder appears in the comment, substitute

    if (my $comment = $tag->getTagComment()) {
        if ($comment =~ s/\<$name\>/$newname/) {
            $tag->setTagComment($comment);
	}
    }

    return 1;
}

#----------------------------------------------------------------------
# Contig tags
#---------------------------------------------------------------------------

sub transpose {
# apply a linear transformation to the tag position
    my $class = shift;
    my $tag   = shift;
    my $align = shift;
    my $offset = shift;
    my %options = @_;

# TO BE DEPRECATED from here; catch old usage
    if (ref($offset) eq 'ARRAY') { # use the old form (to be deprecated)
        unless ($offset->[0] == $offset->[1]) {
            my $logger = &verifyLogger('transpose');
            $logger->debug("oldtranspose (offsets @$offset) TO BE DEPRECATED");
            my $wfinal = $options{postwindowfinal};
            return &oldtranspose($class,$tag,$align,$offset,$wfinal);
        }
#      my $wfinal = $options{postwindowfinal};
#      return &oldtranspose($class,$tag,$align,$offset,$wfinal);
        $offset = $offset->[0];
    }

# TO HERE
    
    return undef unless &verifyParameter($tag,'transpose');

    $tag = $tag->copy() unless $options{nonew}; # nostatus => 1 ?

# determine the multiplication mapping ( y = x * align + offset)

    my @csegment = $tag->getPositionRange();

    foreach my $i (0,1) {
        $csegment[2+$i] = $csegment[$i]; 
        $csegment[2+$i] = $csegment[2+$i] * $align if $align;
        $csegment[2+$i] = $csegment[2+$i] + $offset; 
    }

    my $mapping = new Mapping("linear mapping");
    $mapping->putSegment(@csegment);

    return undef unless &remapper($tag,$mapping,%options);

    return $tag;
}

sub remapper {
# private, remap position of tag and corresponding sequence, if any
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;

    return undef unless &verifyPrivate($tag,'remapper');

    my $newmapping = $tag->getPositionMapping(); # ; x:tag , y:sequence domain

    if ($options{prewindowstart} || $options{prewindowfinal}) {
        my @range = $tag->getPositionRange();
        my $pws = $options{prewindowstart} || 1;
        my $pwf = $options{prewindowfinal} || $range[1];
        my $prefilter = new Mapping("prefilter");
        $prefilter->putSegment($pws,$pwf,$pws,$pwf);
        $newmapping = $newmapping->multiply($prefilter);
        return undef unless $newmapping; # mapped tag out of range
    }

    my %moptions; # copy to local hash
    $moptions{nonzerostart} = $options{nonzerostart} || 0;
    $moptions{repair}       = $options{repair}       || 0;

    $newmapping = $newmapping->multiply($mapping,%moptions) if $mapping;

    return undef unless $newmapping; # mapped tag out of range

    if ($options{postwindowfinal}) {
        my $pws = $options{postwindowstart} || 1;
        my $pwf = $options{postwindowfinal};
        my $postfilter = new Mapping("postfilter");
        $postfilter->putSegment($pws,$pwf,$pws,$pwf);
        $newmapping = $newmapping->multiply($postfilter);
        return undef unless $newmapping; # mapped tag out of range
    }
    
    return undef unless $newmapping->hasSegments(); # mapped tag out of range

# truncation and frameshift test (compare object range on old with new)

    my $oldmapping = $tag->getPositionMapping(); # .. again

    my ($isequal,$align,$shift) = $oldmapping->isEqual($newmapping,domain=>'X');

    $tag->setPositionMapping($newmapping); # replace by new mapping

my $logger = &verifyLogger('remapper');
$logger->debug("e:$isequal  a:$align  o:$shift") if $isequal;
$logger->debug($oldmapping->toString()) unless $isequal;
$logger->debug($newmapping->toString()) unless $isequal;
#$logger->debug($oldmapping->toString()) if $isequal;
#$logger->debug($newmapping->toString()) if $isequal;

    $tag->setStrand('C') if ($isequal && $align == -1); # signal other strand

    return 1 if $isequal; # tagposition identical apart from linear transform

# there are trunctation(s) or frameshift(s)

    my $crossmapping = $newmapping->compare($oldmapping,domain=>'X');

$logger->debug("mapping $crossmapping");
$logger->debug($crossmapping->toString());

# count number of segments of cross comparison: is one more than frameshift(s)

    my $frameshift = $crossmapping->hasSegments() - 1;
    $tag->setFrameShiftStatus($frameshift);

# compare range covered to determine truncation of original tag

    my @orange = $oldmapping->getObjectRange();
    my @nrange = $newmapping->getObjectRange();
    my $ltruncate = $nrange[0] - $orange[0];
    $tag->setTruncationStatus(l => $ltruncate) if $ltruncate;
    my $rtruncate = $orange[1] - $nrange[1];
    $tag->setTruncationStatus(r => $rtruncate) if $rtruncate;

# if there are no truncations or frameshifts, the (possible) DNA is unchanged

    return 1 unless ($frameshift || $ltruncate || $rtruncate);

    if (my $olddna = $tag->getDNA()) {
# DNA sequence remapping (use oldmapping newmapping)

$logger->debug("remapper: there are truncations or frameshifts");
$logger->debug($oldmapping->toString());
$logger->debug($newmapping->toString());

        my @range = $newmapping->getObjectRange();
        my $newdna = substr $olddna,$range[0]-1,$range[1]-$range[0]+1;
        $tag->setDNA($newdna);
    }

    return 1;
}

sub testmapper {
# temporary 
    my $class = shift;
    my ($tag,$mapping,%options) = @_;
    return &remapper(@_);
}

sub remap {
# returns an array of (one or more) new tags, or undef
    my $class = shift;
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;

    return undef unless &verifyParameter($tag,'remap');

    return undef unless &verifyParameter($mapping,'remap', class=>'Mapping');

return $class->oldremap($tag,$mapping,@_) unless $options{usenew}; # test

my $logger = &verifyLogger('newremap');
$logger->debug("TagFactory->remap o: @_");
$logger->debug("TagFactory->remap using new version");

# experimental new remapping

    my $oldposition = $tag->getPositionMapping();

    $tag = $tag->copy() unless $options{nonew};

$logger->info($mapping->toString());
$logger->info($oldposition->toString());

    return undef unless &remapper($tag,$mapping,%options);

# case 1 segment (regular tag) out 1 tag, possibly frameshift/truncated

    my @tags;

    if (!$tag->isComposite()) {
        push @tags,$tag; # as is
    }

# case > 1 segments (composite tag) to be split into out array of tags

    elsif ($options{split} || !$options{nosplit} ) {
        my $tags = $tag->split();
        push @tags, @$tags if $tags;
    }

# case > 1 segments (composite tag) not to be split

    else {
# either out 1 tag with composite position
        if ($options{nosplit} eq 'composite') {
            push @tags,$tag; # as is
	}
# or out 1 tag with overall position and new comment
        elsif ($options{nosplit} eq 'collapse') {
            push @tags,$tag->collapse();
	}
# else, invalid option, fall back on collapse
        else {
            push @tags,$tag->collapse();
	}
    }
    
    return [@tags];
}

sub split {
# split a composite tag into 
    my $class = shift;
    my $tag   = shift;
    my %options = @_;

    return undef unless &verifyParameter($tag,'split');

    return $tag unless $tag->isComposite();

my $logger = &verifyLogger("split"); $logger->debug("ENTER split");

    my $minimumsegmentsize = $options{minimumsegmentsize} || 1;

    my $mapping = $tag->getPositionMapping();

    my $segments = $mapping->getSegments();

    my $sequence = $tag->getDNA();

    my $tagsequencespan = $tag->getSpan(); # size of original tag

    my @tags;

    my $fragment = 0;
    my $numberofsegments = scalar(@$segments);
    foreach my $segment (@$segments) {
        my $flength = $segment->getSegmentLength();
        next if ($flength < $minimumsegmentsize);
        my $newtag = $tag->copy(%options);
        $newtag->setPosition($segment->getYstart(),$segment->getYfinis());
# add sequence fragment, if any
        if ($sequence) {
            my $fxstart = $segment->getXstart();
            my $fsequence = substr $sequence, $fxstart-1, $flength;
            $newtag->setDNA($fsequence);
        }        
# add to comments
        my $tagcomment = $newtag->getTagComment() || '';
        $tagcomment .= ' ' if $tagcomment;
        $tagcomment .= "fragment " . (++$fragment) . " of $numberofsegments";
        $newtag->setTagComment($tagcomment);
        my $comment = $newtag->getComment();
        unless ($comment =~ /\bsplit\b/) {
            $newtag->setComment("split! ($tagsequencespan)",append=>1);
        }
        push @tags,$newtag;
    }
    return [@tags];
}

sub collapse {
# replace a composite tag (position) by a single position range
    my $class = shift;
    my $tag   = shift;
    my %options = @_;

    return undef unless &verifyParameter($tag,'collapse');

    return $tag unless $tag->isComposite();

my $logger = &verifyLogger("collapse"); $logger->debug("ENTER collapse");

    my $mapping = $tag->getPositionMapping();

    my @range = $mapping->getMappedRange();

    my $olddna = $tag->getDNA();

# assemble the new tag

    $tag = $tag->copy() unless $options{nonew};

    $tag->setPosition(@range);

    if ($olddna) {
# build a new sequence to store with the new single position range
        my $newdna = '';
        my ($xs,$xf,$ys,$yf,$yl);
        my $segments = $mapping->getSegments();
        foreach my $segment (@$segments) {
            $xs = $segment->getXstart();
            $xf = $segment->getXfinis();
           ($xs,$xf) = ($xf,$xs) if ($xs > $xf);
            $ys = $segment->getYstart();
            $yf = $segment->getYfinis();
           ($ys,$yf) = ($yf,$ys) if ($ys > $yf);
            if ($yl && $yl > 0) {
                while ($yl++ < $ys) {
		    $newdna .= 'X';
		}
	    }
            $newdna .= substr $olddna, $xs-1, $xf-$xs+1;
            $yl = $yf;
	}


        $tag->setDNA($newdna);
    }

    return $tag;
}

# -------------------
# old stuff, to be replaced
# -------------------

sub oldtranspose { # used in Tag, ContigHelper TO BE DEPRECATED
# transpose a tag by applying a linear transformation
# (apply only to contig tags)
# returns new Tag instance (or undef)
    my $class = shift;
    my $tag   = shift;
    my $align = shift;
    my $offset = shift; # array length 2 with offset at begin and end
    my $window = shift || 1; # new position in range 1 .. window

    return undef unless &verifyParameter($tag,'oldtranspose');

    my $logger = &verifyLogger('oldtranspose');
$logger->debug("used a:$align o:@$offset w:$window");

# transpose the position range using the offset info. An undefined offset
# indicates a boundery outside the range 1 .. length; adjust accordingly

    return undef unless (defined($offset->[0]) && defined($offset->[1])); 

    my @tpos = $tag->getPosition();
    
$logger->debug("position @tpos");

    for my $i (0,1) {
        $tpos[$i] *= $align if ($align eq -1);
        $tpos[$i] += $offset->[$i];
    }

    if ($tpos[0] > $window && $tpos[1] > $window or $tpos[0] < 1 && $tpos[1] < 1) {
# the transposed tag is completely out of range
        return undef;
    }

# adjust boundaries to ensure tag position inside allowed window
    
$logger->debug("new position @tpos");
 
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

$logger->debug("new position after truncate test");

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
    $newcomment .= "imported ".$tag->getSystematicID(); # if $options{sysID}; # ?
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

sub oldremap {
# takes a mapping and transforms the tag positions to the mapped domain
# returns an array of (one or more) new tags, or undef
    my $class = shift;
    my $tag   = shift;
    my $mapping = shift;
    my %options = @_;
my $logger = &verifyLogger('oldremap');
$logger->debug("TagFactory->oldremap 1 $tag $mapping  o: @_");

# options:  break = 1 to allow splitting of a tag straddling mapping segments
#                     and return a separate tag for each segment
#                   0 (default) to not allow that; if a sequence is provided
#                     generate a tag sequence with pad(s)
#           sequence, if provided used to generate a tagsequence, possibly 
#                     with pads; in its absence a long comment is generated

    return undef unless &verifyParameter($tag,'remap');

    return undef unless &verifyParameter($mapping,'remap', class=>'Mapping');

# get current tag position

    my @currentposition = $tag->getPosition();

    my $tagsequencespan = $tag->getSpan();

# generate a helper 1-1 mapping

    my $helpermapping = new Mapping('helper');
# and add the one segment
    $helpermapping->putSegment(@currentposition,@currentposition);

# multiply by input mapping; the helper mapping may be masked
# by the input mapping, which would result in a truncated tag

$logger->info("Tag position: @currentposition");

# the next block initializes start position for searching the mappings

    if (my $nzs = $options{nonzerostart}) {
# initialize the starting positions if that has not been done
        $nzs->{tstart} = 0 unless defined $nzs->{tstart}; # count along
$logger->info(" previous positions : $nzs->{tstart}");
        $nzs->{tstart}-- if ($nzs->{tstart} > 0); # skip one back
        $nzs->{rstart} = 0; # always reset
$logger->info(" starting positions : $nzs->{rstart},$nzs->{tstart}");
    }

$logger->info("Mapping: ".$mapping->toString());
$logger->info("Helper : ".$helpermapping->toString());

    my $maskedmapping = $helpermapping->multiply($mapping,%options);

# trap problems with mapping by running again with debug option

    unless ($maskedmapping) {
# something wrong with mapping
$logger->debug("Tag position: @currentposition");
$logger->debug($helpermapping->toString());    
$logger->debug($mapping->toString()); 
        $helpermapping->multiply($mapping,debug=>1);
        return undef; 
    }

$logger->info("Masked Mapping: ".$maskedmapping->toString());

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
$logger->info("$gapsize : sequence deletion detected"); 
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

#---------------------- TO HERE -------------

sub merge { # used in ContigHelper
# merge two tags (fragments), if possible
    my $class = shift;
    my $atag = shift;
    my $otag = shift;
    my %options = @_;

# test input parameters

    return undef unless &verifyParameter($atag,'merge (1-st parameter)');

    return undef unless &verifyParameter($otag,'merge (2-nd parameter)');

    my $logger = &verifyLogger('merge');

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

$logger->debug($left->writeToCaf(0,annotag=>1));
$logger->debug($right->writeToCaf(0,annotag=>1));
   
    my $newdna;
    if ($left->getDNA() && $right->getDNA()) {
        $newdna = $left->getDNA(transpose => 1);
        if ($overlap) {
	    $logger->info("DNA sequence in overlapping tag to be COMPLETED");
$logger->debug("tag positions DO butt: @atagposition, @otagposition");
$logger->debug($left->writeToCaf(0,annotag=>1));
$logger->debug($right->writeToCaf(0,annotag=>1));

	}
	else {
            $newdna .= $right->getDNA(transpose => 1);
	}
$logger->debug("DNA merge: @lposition  @rposition");
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
   $logger->info("comment a:'".$atag->getComment()."' o:'".$otag->getComment()
               ."'\n". "com: '$comment'") if ($comment =~ /rejoin.*split/);
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
   $logger->info("tagcomment merging problem  l: '$lcomment'  r: '$rcomment'\nnew: '$newcomment'");
}
        $comment =~ s/(.{4,})\s+\1/$1/g; # remove possible duplicated info
    }

    $newtag->setComment($comment) if $comment;
    $newtag->setTagComment($newcomment) if $newcomment;

#$newtag->writeToCaf(*STDOUT,annotag=>1) if $options{debug};

    return $newtag;
}

sub mergeTags {
# merge tags from a list of input tags, where possible
    my $class = shift;
    my $tags = shift; # array reference
    my %options = @_;

my $logger = &verifyLogger('mergeTags');

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

$logger->debug(scalar(keys %$tagtypehash)." tag SIDs");

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
    my %options = @_; # class, kind

    $options{class} = 'Tag' unless defined $options{class};

    &verifyPrivate($object,'verifyParameter');

    unless ($object && ref($object) eq $options{class}) {
        print STDERR "TagFactory->$method expects a $options{class} "
                   . "instance as parameter\n";
        print STDERR "(instead of $object)\n" if $object;
	return 0;
    }

    return 1 unless (ref($object) eq 'Tag'); # for objects different from Tag

# test the tag type by interogating its host class, if any

    return 1 unless $options{kind}; # don't test the kind of tag

# test the tag type

    my $hostclass = $object->getHostClass() || "unknown";

    unless ($hostclass && $hostclass eq $options{kind}) {
        my $logger = &verifyLogger();
        $logger->error("TagFactory->$method expects a tag of type "
	             . "$options{type} (instead of '$hostclass')");
#        return 0; # diagnostic message
        $logger->debug($object->dump());
        $hostclass =~ s/(contig|read).*/ucfirst($1)/;
        $object->setHost($hostclass); 
    }

    return 1;
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return 1 unless ($caller && ref($caller) eq 'TagFactory');

    print STDERR "Invalid usage of private method '$method' in package "
               . "TagFactory\n";
    return 0;
}

#-----------------------------------------------------------------------------
# log file
#-----------------------------------------------------------------------------

my $LOGGER;

sub verifyLogger {
# private, test the logging unit; if not found, build a default logging module
    my $prefix = shift;

    &verifyPrivate($prefix,'verifyLogger');

    if ($LOGGER && ref($LOGGER) eq 'Logging') {

        if (defined($prefix)) {

            $prefix = "TagFactory->".$prefix unless ($prefix =~ /\-\>/);

            $LOGGER->setPrefix($prefix);
        }

        $LOGGER->debug('ENTER') if shift;

        return $LOGGER;
    }

# no (valid) logging unit is defined, create a default unit

    $LOGGER = new Logging();

    return &verifyLogger($prefix);
}

sub setLogger {
# assign a Logging object
    my $this = shift;
    my $logger = shift;

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $LOGGER undefined
}

#-----------------------------------------------------------------------------

1;
