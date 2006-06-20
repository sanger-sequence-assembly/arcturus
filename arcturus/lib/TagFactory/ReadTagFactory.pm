package ReadTagFactory;

use strict;

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

my $readtagfactory; # class variable

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
# constructor
    my $class = shift;

# we want only one instance per process

    my $this = $readtagfactory; 

    unless ($this && ref($this) eq $class) {
# create a new instance
        $this = {};

        bless $this, $class;

        $readtagfactory = $this;
    }

    $this->importTag(@_) if @_; # import a Tag instance, if specified 

    return $this;
}

#-----------------------------------------------------------------------------
# public method to cleanup/reformat/analyse tag info and if needed standardize
#-----------------------------------------------------------------------------

sub importTag {
# import a read Tag Instance
    my $this = shift;
    my $rtag = shift; # a read tag instance

    die "importTag expects a Tag instance" unless (ref($rtag) eq 'Tag');

    die "importTag expects a read tag" unless ($rtag->{label} eq 'readtag');

    $this->{Tag} = $rtag;

    return;
}

#-----------------------------------------------------------------------------

sub cleanup {
# clean the tag info by removing clutter, double info and redundent new line
    my $this = shift;
    
    my $tag = $this->{Tag} || return undef; # Missing Tag

    my $info = $tag->getTagComment();

    my ($change,$inew) = &cleanup_comment($info);

    return 0 unless $change; # no change

    $tag->setTagComment($inew); # the new cleaned-up tag info

    return $change; # the number of changes
}

#-----------------------------------------------------------------------------

sub processOligoTag {
# test/complete oligo information
    my $this = shift;
    my %options = @_; # used in repair mode
 
    my $tag = $this->{Tag} || return undef; # Missing Tag

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
            $tagcomment = &cleanup_comment($newcomment);
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

    my $tag = $this->{Tag} || return undef; # Missing Tag

    my $tagtype = $tag->getTagType();

    return undef unless ($tagtype eq 'REPT');

    my $tagcomment = $tag->getTagComment();
# test presence of a (repeat) tag sequence name upfront
    if ($tagcomment =~ /^\s*(\S+)\s/i) {
        $tag->setTagSequenceName($1);
        return 1;
    }
    return 0; # no name found
}

sub processAddiTag {
# check position range
    my $this = shift;

    my $tag = $this->{Tag} || return undef;

    my $tagtype = $tag->getTagType();

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


my $DEBUG = 0;
print "decode_oligo_info  $info ($sequence) \n" if $DEBUG;

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
print "Ia change $change\n" if $DEBUG;
        my $clutter = $1;
        my $cleanup = $clutter;
        $cleanup =~ s/\\n\\/-/g;
        $clutter =~ s/\\/\\\\/g;
print "Ia clutter '$clutter'\nIa cleanup '$cleanup'\n" if $DEBUG;
        unless ($clutter eq $cleanup) {
            $change++ if ($info =~ s/$clutter/$cleanup/);
        }
    }

print "I change $change $info \n" if $DEBUG;

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

print "II name ".($name || '')." (change $change) \n" if $DEBUG;
 
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

print "name ".($name || '')." (change $change) \n" if $DEBUG;

    return ($name,$info) if $name;

# or see if possibly the name and sequence fields have been interchanged

    if ($info[1] =~ /^\w+\.\w{1,2}\b/) {
# name and sequence possibly interchanged
print STDOUT "still undecoded info: $info  (@info)\n";
        $name = $info[1];
        $info[1] = $info[0];
        $info[0] = $name;
        $info = join ('\\n\\',@info);
print STDOUT "now decoded info: $info ($name)\n";
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

sub cleanup_comment {
# remove quotes, redundant spaces and \n\ from the tag description
    my $comment = shift;

    my $changes = 0;

    $changes++ if ($comment =~ s/\s+\"([^\"]+)\".*$/$1/); # remove quotes 

    $changes++ if ($comment =~ s/^\s+|\s+$//); # remove leading/trailing blanks

    $changes++ if ($comment =~ s/\\n\\\s*$//); # delete trailing newline

    $changes++ if ($comment =~ s/\s+(\\n\\)/$1/g); # delete blanks before \n\

    $changes++ if ($comment =~ s/(\\n\\)\-(\\n\\)/-/g); # - between \n\

    $changes++ if ($comment =~ s/(\\n\\)o(\\n\\)/\\n\\/g); # o between \n\

    $changes++ if ($comment =~ s/(\\n\\){2,}/\\n\\/g); # remove repeats of \n\

    $changes++ if ($comment =~ s?\\/?/?g); # replace back-slashed slashes

    $changes++ if ($comment =~ /^\s*\\\s*/); # remove a single backslash

    return $changes,$comment;
}

#----------------------------------------------------------------------------

1;
