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
#    my $newtag = &makeTag(@_,Host=>'Read');
    $newtag->setHost('Read');   # define kind
    return $newtag;
}

sub makeContigTag {
    my $newtag = &makeTag(@_);
#    my $newtag = &makeTag(@_,Host=>'Contig');
    $newtag->setHost('Contig');
    return $newtag;
}

sub makeTag {
# make a new tag
    my $class = shift;
    my ($tagtype,$start,$final,%options) = @_;

    my $newtag = new Tag();

    $newtag->setPosition($start,$final) if (defined($start) && defined($final));

    $newtag->setType($tagtype) if defined($tagtype);

    $options{Strand} = 'Forward' unless defined($options{Strand});

    foreach my $item (keys %options) {
        my $value = $options{$item};
        eval("\$newtag->set$item(\$value)");
#        next unless $@;
#	print "failed to eval \"\$$newtag->set$item(\$value)\" : $@ \n";
    }

    return $newtag;
}

#----------------------------------------------------------------------
# processing various tags to regularise internal presentation
#----------------------------------------------------------------------

sub verifyTagContent {
# process / cleanup tagcomment / complete tag using comment 
    my $class = shift;
    my $tag   = shift;
    my %options = @_;

    return undef unless &verifyParameter($tag,'verifyTagContent');

    my $logger = &verifyLogger('verifyTagContent',1);

    my $tagtype = $tag->getType();

    my $tagcomment = $tag->getTagComment();

    my $hostclass = $tag->getHostClass() || ''; # if any

# collect diagnostic messages in a report

    my $report = '';
    my $returnstatus = 1; # exit > 0 for valid tag, else 0

# cleanup the comments

    &cleanuptagcomment($tag);

    &cleanupcontigtagcomment($tag) if ($hostclass ne 'Read');

# test for DNA info embedded in the comment

    my $msg = &get_tag_DNA($tag);

    $report .= $msg if $msg;

# ok, now analyse specific tag info

    if ($tagtype eq 'OLIG' || $tagtype eq 'AFOL') {
	my ($status,$msg) = &processOligoTag($class,$tag);
        $returnstatus = 0 unless $status;
        $report .= $msg if $msg;       
    } 
    elsif ($tagtype eq 'REPT') {
        my $status = &processRepeatTag  ($class,$tag);
        $report .= "No repeat sequence name detected" unless $status;
# reject falied tag info for read, accept for contig 
        $returnstatus = 0 unless ($status || $hostclass ne 'Read');
    }
    elsif ($tagtype eq 'ADDI') {
        my ($status,$msg) = &processAdditiveTag($class,$tag); 
        $report .= $msg if (defined($status) && $status != 1);
	$returnstatus = 0 unless $status;
    }
# testing of a description is disabled
    elsif (my $nonemptytags = $options{nonempty}) {
# for selected types, check if a tag descriptor is available
        if ($tagtype =~ /$nonemptytags/) {
            $returnstatus = 0 unless $tag->getTagComment();
	}
    }

# return status to signal a valid tag or not

$logger->info("verifyTagContent: output status $returnstatus, report: $report");

    return $returnstatus,$report;
}

#-----------------------------------------------------------------------------
# Read tags : cleanup/reformat/analyse tag info and if needed standardise
#-----------------------------------------------------------------------------

sub cleanuptagcomment {
# private, remove quotes, redundant spaces or \n\ from the tag description
    my $tag = shift;

    &verifyPrivate($tag,'cleanuptagcomment');

    my $change = 0;
    foreach my $handle ('TagComment','Comment') { 

        my ($comment,$changes);

        eval ("\$comment = \$tag->get$handle()");

        next unless ($comment =~ /\S/);

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

        next unless $changes;

        eval ("\$tag->set$handle(\$comment)");

        $change += $changes;
    }

    return $change;
}

sub cleanupcontigtagcomment {
# private, ad hoc cleanup of autogenerated contig tags
    my $tag = shift;

    &verifyPrivate($tag,'cleanupcontigtagcomment');

    my $tagcomment = $tag->getTagComment();

    my $changes = 0;

    if ($tagcomment =~ /Repeats\s+with/) {
        $changes++ if ($tagcomment =~ s/\,\s*offset\s+\d+//i);
    }

    $changes++ if ($tagcomment =~ s/expresion/expression/);

    $tag->setTagComment($tagcomment) if $changes;

    return $changes;   
}

sub get_tag_DNA {
# get DNA sequence from comment and remove possible multiple occurrences
    my $tag = shift;

    &verifyPrivate($tag,'get_tag_DNA');

    my $tagcomment = $tag->getTagComment();

    my $report = '';
    if ($tagcomment =~ /([ACGT\*]{5,})/i) {
        my $DNA = $1; my $dna = qw($DNA); # can contain "*"
# test if the DNA occurs twice in the data; remove multiple occurrences
        if ($tagcomment =~ s/($dna[^ACGT].*?)(sequence\=)?$dna/$1/i) {
            my $tagtype = $tag->getType() || "undefined type";
            $report = "Multiple DNA info removed from \'$tagtype\' tag";
            $tag->setTagComment($tagcomment);
        }
        $tag->setDNA($DNA);
    }

    return $report;
}

#-----------------------------------------------------------------------------
# Read tags : cleanup/reformat/analyse tag info and if needed standardise
#-----------------------------------------------------------------------------

sub processRepeatTag {
# check repeat tags for presence of tag sequence name
    my $class = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'processRepeatTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'REPT');

    my $tagcomment = $tag->getTagComment();

    my $status = 0;

# test presence of a (repeat) tag sequence name upfront
               
    $tagcomment =~ s/\s*\=\s*/=/g;
    if ($tagcomment =~ /^\s*(\S+)\s+from/i) {
        my $tagseqname = $1;
        $tagseqname =~ s/r\=/REPT/i;
        $tag->setTagSequenceName($tagseqname);
        $status = 1;
    }
    elsif ($tagcomment =~ /^\s*(\S+)\s/i) {
        $tag->setTagSequenceName($1);
        $status = 1;
    }
# no name found, try alternative
    elsif ($tagcomment !~ /Repeats\s+with/) {
# try to generate one based on possible read mentioned
        if ($tagcomment =~ /\bcontig\s+(\w+\.\w+)/) {
            $tag->setTagSequenceName($1);   
            $status = 2;
        }
    }

    return $status;
}

sub processAdditiveTag {
# check position range
    my $class = shift;
    my $tag  = shift;

    return undef unless &verifyParameter($tag,'processAdditiveTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'ADDI');

# test presence and content of a descriptor

    if (my $tagcomment = $tag->getTagComment()) {
# test if comment contains the "written" key; if not it's useless
        $tag->setTagComment(undef) unless ($tagcomment =~ /Written/);
    }

    return 0,"Missing tag description" unless $tag->getTagComment();

# test position

    my ($tposs,$tposf) = $tag->getPosition();

    $tag->setPosition(1,$tposf) unless ($tposs == 1); # correction

    return 1,'OK' if ($tposs == 1); 

# invalid position, additag must start at 1

    return 2,"Invalid ADDI tag start position $tposs corrected";
}

sub processOligoTag {
# test/complete oligo information
    my $class = shift;
    my $tag  = shift;
    my %options = @_; # nameforcing =>  used in repair mode

#if ($USEOLD) {
#    my ($status,$report) = &oldprocessOligoTag($class,$tag,@_);
#}
 
    return undef unless &verifyParameter($tag,'processOligoTag');

    my $tagtype = $tag->getType();

    return undef unless ($tagtype eq 'OLIG' || $tagtype eq 'AFOL');

    my $warning = 0;
    my $report = '';

    if (my $dna = $tag->getDNA()) {
# test existing dna atribute against possible description in info
        my $copytag = $tag->copy();
        my $change = &get_tag_DNA($copytag); # overrides existing DNA attribute
        $tag->setTagComment($copytag->getTagComment()) if $change;
        my $copydna = $copytag->getDNA();
# the dna and tagcomment attributes are inconsistent if copydna  differs from  dna 
        if ($copydna ne $dna) {
            my $tagcomment = $copytag->getTagComment();
            $report .= "Oligo tag DNA sequence ($dna) conflicts with tag\n"
	            .  "comment $tagcomment\nDNA sequence replaced\n";
            $tag->setDNA($copydna); # always repair
            $warning++;
	}
    }
    else {
# no DNA defined yet, extract from info, if any
        $report = &get_tag_DNA($tag); # 
        $dna = $tag->getDNA();
        $report .= "Missing DNA sequence in oligo tag info\n" unless $dna;
        $report .= "Oligo tag DNA sequence $dna added\n" if $dna;
        $warning++ if $report;
    }


# test DNA length against position specification

    my $DNA = $tag->getDNA(); # may have changed
    my $tagcomment = $tag->getTagComment();

    if ($DNA && (my $length = length($DNA))) {

	my ($tposs,$tposf) = $tag->getPosition();
        
        unless ($tposf > $tposs) {
            $report .= "position error ($tposs $tposf) in oligo tag\n"
	            .  "$tagcomment\n";
	    $warning++;
# abort: invalid position information
            return 0, $report;
        }

        my $oligospan = $tposf-$tposs+1;
        if (abs($oligospan - $length) > 2) { # only report large mismatch
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

# print STDOUT "oligotag : w:$warning r:$report\n\n";
    
    if ($tag->getTagSequenceName()) {
        return 1,"oligo tag info verified" unless $report;
        return 2,$report if $report; # still valid tag
    }
    else { # fatal, reject the tag info
        return 0,"missing oligo name";
    }
}

#-----------------------------------------------------------------------------
# private methods doing the dirty work
#-----------------------------------------------------------------------------

sub decode_oligo_info {
# ad-hoc oligo info decoder
    my $info = shift || return 0,0;
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
        $cleanup = qw($cleanup);
        $clutter = qw($clutter);
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
    my $qwsequence = qw($sequence);
    if (defined($sequence) && $info =~ /^\s*(\d+)\b(.*?)$qwsequence/) {
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
# the info contains a name like oxxxxx (check for names like of1234 -> f1234)
        $name = $1;
    }
# try its a name like 17H10.1
    elsif ($info =~ /^(\w+\.\w{1,2})\b/) {
        $name = $1;
    }
# try with the results of the split
    elsif ($info[0] && $info[0] !~ /\=/ && $info =~ /^([a-zA-Z]\w+)\b/i) {
# the info string starts with a name like axx..
        $name = $1;
    }
    elsif (defined($sequence) && defined($info[1]) && $info[1] eq $sequence) {
        $name = $info[0];
        $name = "o$name" unless ($name =~ /\D/);
    }

$logger->debug("II name ".($name || '')." (change $change)");
 
    return ($name,0) if ($name && !$change); # no new info
    return ($name,$info) if $name; # info modified


# name could not easily be decoded: try one or two special possibilities


    foreach my $part (@info) {
        if ($part =~ /serial\#?\=?(.*)/) {
            $part = qw($part);
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

    if (defined($info[1]) && $info[1] =~ /^\w+\.\w{1,2}\b/) {
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

# compare tag position(s) by using the mapping representation

    my $amap = $atag->getPositionMapping();
    my $omap = $otag->getPositionMapping();
    my @equal = $amap->isEqual($omap);
# insist on equality of position(s) with same alignment and no shift 
    unless ($equal[0] == 1 && $equal[1] == 1 && $equal[2] == 0) {
# the position ranges are not equal; test if they do overlap
        return 0 unless ($options{overlaps} || $options{contains} || $options{adjoins});
# test if otag tags is embedded in atag 
        my @arange = $amap->getMappedRange();
        my @orange = $omap->getMappedRange();
# test if arange contains orange
        if ($options{contains}) {
            return 0 if ($orange[0] < $arange[0]);
            return 0 if ($orange[1] > $arange[1]);
        }
# test if orange is to the left or to the right of arange
        if ($options{overlaps}) {
            return 0 if ($orange[1] < $arange[0]);
            return 0 if ($orange[0] > $arange[1]);
        }
# test if orange buds on the left or on the right to arange
        if (my $flush = $options{adjoins}) { #  usually 1
            return 0 unless (($orange[1] + $flush == $arange[0])   # left  join
                         ||  ($orange[0] - $flush == $arange[1])); # right join
        }
    }

# compare tag comments

    if ($atag->getTagComment() =~ /\S/ && $otag->getTagComment() =~ /\S/) {
# both comments defined
        unless ($atag->getTagComment() eq $otag->getTagComment()) {
# tags may be different, do a more detailed comparison using a cleaned version
            my $inop = $options{ignorenameofpattern}; # e.g.: oligo names
            unless (&cleancompare($atag->getTagComment(),$inop) eq
                    &cleancompare($otag->getTagComment(),$inop)) {
   	        return 0;
            }
	}
    }
    elsif ($atag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        if ($options{copycom}) {
            $otag->setTagComment($atag->getTagComment());
	}
    }
    elsif  ($otag->getTagComment() =~ /\S/) {
# one of the comments is blank and the other is not
        return 0 unless $options{ignoreblankcomment};
# fill in the blank comment where it is missing
        if ($options{copycom}) {
            $atag->setTagComment($otag->getTagComment());
	}
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
# at least one of the tag sequence names is defined; they must be equal unless '0'
	return 0 if ($atag->getTagSequenceName() && $otag->getTagSequenceName()
	          && $atag->getTagSequenceName() ne $otag->getTagSequenceName());
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

sub cleancompare {
# private method cleanup for purpose of comparison of comments
    my $comment = shift;
    my $inop = shift; # special treatment for e.g. auto-generated oligo names

    &verifyPrivate($comment,'cleancompare');

# remove quotes, '\n\' and shrink blankspace into a single blank

    $comment =~ s/^\s*([\"\'])\s*(.*)\1\s*$/$2/; # remove quotes
    $comment =~ s/^\s+|\s+$//g; # remove leading & trailing blank
    $comment =~ s/\\n\\/ /g; # replace by blank space
    $comment =~ s/\s+/ /g; # shrink blank space

    $comment =~ s/^$inop// if $inop; # remove if present at begin
   
    return $comment;
}

#----------------------------------------------------------------------
# place holder name
#----------------------------------------------------------------------

sub processTagPlaceHolderName {
# substitute (possible) placeholder name of the tag sequence & comment
    my $class = shift;
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

    if (my $comment = $tag->getTagComment(pskip=>1)) {
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
    
    return undef unless &verifyParameter($tag,'transpose');

# test $align and $offset ? (no ref type)

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
    my %options = @_; # tracksegments, repair

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

#    my %moptions; # copy to local hash
#    $moptions{tracksegments} = $options{tracksegments} || 0;
#    $moptions{repair}        = $options{repair}       || 0;

    $newmapping = $newmapping->multiply($mapping,%options) if $mapping;

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

    unless ($crossmapping && $crossmapping->hasSegments()) {
	$logger->error("cross-mapping could not be made");
        $logger->error($oldmapping->toString());
        $logger->error($newmapping->toString());
        return undef;
    }

$logger->fine("cross mapping $crossmapping");
$logger->fine($crossmapping->toString());

# count number of segments of cross comparison: is one more than frameshift(s)

    my $frameshift = $crossmapping->hasSegments() - 1;
    $tag->setFrameShiftStatus($frameshift);

# compare range covered to determine truncation of original tag

    my @orange = $oldmapping->getObjectRange();
    my @nrange = $newmapping->getObjectRange();
    my $ltruncate = $nrange[0] - $orange[0];
    $tag->setTruncationStatus('l',$ltruncate) if $ltruncate;
    my $rtruncate = $orange[1] - $nrange[1];
    $tag->setTruncationStatus('r',$rtruncate) if $rtruncate;

# if there are no truncations or frameshifts, the (possible) DNA is unchanged

    return 1 unless ($frameshift || $ltruncate || $rtruncate);
$logger->fine("remapper: there are truncations or frameshifts $frameshift | $ltruncate | $rtruncate");

    if (my $olddna = $tag->getDNA()) {
# DNA sequence remapping (use oldmapping newmapping)

$logger->debug($oldmapping->toString());
$logger->debug($newmapping->toString());

        my @range = $newmapping->getObjectRange();
        my $newdna = substr $olddna,$range[0]-1,$range[1]-$range[0]+1;
        $tag->setDNA($newdna);
    }

    return 1;
}

sub testmapper { # TO BE DEPRECATED
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
    my %options = @_; # split, nosplit=>collapse/composite, (no)tracksegments=>

    return undef unless &verifyParameter($tag,'remap');

    return undef unless &verifyParameter($mapping,'remap', class=>'Mapping');

my $logger = &verifyLogger('newremap');

# experimental new remapping

    my $oldposition = $tag->getPositionMapping();

    $tag = $tag->copy() unless $options{nonew};

$logger->fine($mapping->toString());
$logger->fine($oldposition->toString());

    return undef unless &remapper($tag,$mapping,%options);

# case 1 segment (regular tag) out 1 tag, possibly frameshift/truncated

    my @tags;

    my $split = $options{split};
    $split = 1 unless defined($split); # default
    $split = 0 if $options{nosplit}; # overrides
    my $nosplit = $options{nosplit};

    if (!$tag->isComposite()) {
        push @tags,$tag; # as is
    }

# case > 1 segments (composite tag) to be split into out array of tags

    elsif ($split) {
        my $tags = $tag->split();
        push @tags, @$tags if $tags;
    }

# case > 1 segments (composite tag) not to be split

    else {
# either out 1 tag with composite position
        if ($nosplit && $nosplit eq 'composite') {
            push @tags,$tag; # as is
	}
# or out 1 tag with overall position and new comment
        elsif ($nosplit && $nosplit eq 'collapse') {
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
#        my $newtag = $tag->copy(%options);
        my $newtag = $tag->copy();
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

#------------------------------------------------------------------------------
# sorting tags
#------------------------------------------------------------------------------

sub sortTags {
# sort an array of Tag instances in situ on position and/or comment; weedout duplicates
    my $class = shift;
    my $tags = shift; # array reference
    my %options = @_; # sort=>['position', 'full'], merge=>[0,1]

    &verifyParameter($tags,'sortTags',class=>'ARRAY');

    my $logger = &verifyLogger('sortTags');

# sort the tags with increasing tag position

    my $merge;

    if ($options{sort} && $options{sort} eq 'position') {
# do a basic sort on start position
        @$tags = sort positionsort @$tags;
    }
    elsif ($options{sort} && $options{sort} eq 'full') {
# do a sort on position and tag description in tagcomment
        $merge = $options{merge};
        @$tags = sort mergesort @$tags     if $merge;
        @$tags = sort fullsort  @$tags unless $merge;
    }
    elsif ($options{sort}) {
        $logger->error("invalid sorting option '$options{sort}' ignored");
    }

# remove duplicate tags; in merge mode also consider overlapping tags

    my $n = 1;
    while ($n < scalar(@$tags)) {
        my $leadtag = $tags->[$n-1];
        my $nexttag = $tags->[$n];
# splice the nexttag out of the array if the tags are equal
        if ($leadtag->isEqual($nexttag)) {
	    splice @$tags, $n, 1;
	}
        elsif ($merge && $leadtag->isEqual($nexttag,contains=>1)) {
	    splice @$tags, $n, 1; # lead tag contains next tag: remove next
	}
        elsif ($merge && $nexttag->isEqual($leadtag,contains=>1)) {
	    splice @$tags, $n-1, 1; # next tag contains lead tag: remove lead
	}
	elsif ($merge && $leadtag->isEqual($nexttag,overlaps=>1)) {
# overlapping tags found; add next tag range to leadtag and collapse; then remove next
            $leadtag->setPosition($nexttag->getPositionRange(),join=>1);
            $leadtag->collapse(nonew=>1);
	    splice @$tags, $n, 1; # lead tag is extended and now contains next tag
	}
	elsif ($merge && $leadtag->isEqual($nexttag,adjoins=>1)) {
# budding tags found; add next tag range to leadtag and collapse; then remove next
            $leadtag->setPosition($nexttag->getPositionRange(),join=>1);
            $leadtag->collapse(nonew=>1);
	    splice @$tags, $n, 1;
	}
        else {
	    $n++;
	}
    }
# if tags (could) have been merged, now do a full sort
    &sortTags($class,$tags,sort=>'full') if $merge;    
}

sub mergesort {
# sort for weedout/merge purposes (getting same tagcomment grouped together)
   $a->getTagComment()    cmp $b->getTagComment()     # sort on the description first
 or
   $a->getPositionLeft()  <=> $b->getPositionLeft()   # then on start position 
 or
   $a->getPositionRight() <=> $b->getPositionRight(); # finally on end position 
}

sub fullsort {
# sort for comparison purposes (inside the same tag set)
   $a->getPositionLeft()  <=> $b->getPositionLeft()   # sort on start position 
 or
   $a->getType()          cmp $b->getType()           # then on type
 or
   $a->getTagComment()    cmp $b->getTagComment()     # then on the description
 or
   $a->getPositionRight() <=> $b->getPositionRight(); # finally on end position 
}

sub positionsort {
# comparison with ordered existing tags
   $a->getPositionLeft()  <=> $b->getPositionLeft()   # sort on start position
 or
   $a->getPositionRight() <=> $b->getPositionRight(); # then on end position 
}

#------------------------------------------------------------------------------
# merging/combining tags of same type
#------------------------------------------------------------------------------

sub merge { #
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
    my %options = @_; # mergetaglist, overlap
     
    return undef unless &verifyParameter($tags,'mergeTags',class=>'ARRAY');

my $logger = &verifyLogger('mergeTags');

# build an inventory of tag types & systematic ID (if defined)

    my $tagtypehash = {};

    foreach my $tag (@$tags) {
        next unless &verifyParameter($tag,'mergeTags');
        my $tagtype = $tag->getType() || next; # ignore undefined types
        my $systematicid = $tag->getSystematicID();
        $tagtype .= "-$systematicid" if defined($systematicid);
        $tagtypehash->{$tagtype} = [] unless $tagtypehash->{$tagtype};
        push @{$tagtypehash->{$tagtype}},$tag; # add tag to list
    }

$logger->debug(scalar(keys %$tagtypehash)." tag SIDs");

# now merge eligible tags from each subset

    my @mtags; # output list of (merged) tags

    my %option = (overlap => ($options{overlap} || 0));

    my $nomergetaglist;
    if ($nomergetaglist = $options{nomergetaglist}) {
        $nomergetaglist =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $nomergetaglist =~ s/\W+/|/g; # add separator for use in regexp
    }

    foreach my $tagtype (keys %$tagtypehash) {
        my $tags = $tagtypehash->{$tagtype};
# sort subset of tags according to position
        $class->sortTags($tags,sort=>'full',merge=>1,adjoin=>0);
# if the tags are not to be merged, append directly to output list
        if ($nomergetaglist && $tagtype =~ /$nomergetaglist/) {
            push @mtags,@$tags;
	    next;
	}
# test if some tags can be merged     (NOTE can use $i & $i+1 only)

#print STDOUT "merging tag type $tagtype\n";
#foreach my $tag (@$tags) {print STDOUT "inputtag ".$tag->writeToCaf();}
#print STDOUT "merging ..\n";

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
# join tags in the input list to make a tag with a composite position range
    my $class = shift;
    my $tags = shift;

    my $newtag = shift @$tags; # take the first in the list

    return $newtag unless @$tags; # there is only one tag

# for the remaining tags add the positions to the new tag & concatenate
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

    if (ref($object) eq 'ARRAY') {
# test the first element (assuming all other are same ref type)
        return 1 unless @$object;
        delete $options{class};
        return &verifyParameter($object->[0],$method,%options);
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
    my $class = shift;
    my $logger = shift;

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $LOGGER undefined
}

#-----------------------------------------------------------------------------

1;
