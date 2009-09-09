package Contig;

use strict;

use Mapping;

use ContigFactory::ContigHelper;

use TagFactory::TagFactory;

use Logging;

use Digest::MD5 qw(md5 md5_hex md5_base64);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class      = shift;
    my $contigname = shift; # optional

    my $this = {};

    bless $this, $class;

    $this->{data} = {}; # meta data hash

    $this->setContigName($contigname) if $contigname;

    $this->setPadStatus(0); # to have it defined

    return $this;
}

#------------------------------------------------------------------- 
# explicitly erase objects related to this contig (i.p. Tags)
#------------------------------------------------------------------- 

sub erase {
# erase objects with (possible) back references to this contig object
    my $this = shift;

    my $tags = $this->getTags();
    undef @$tags if $tags;

# and go through the reads to erase self-references in its tags

    if (my $reads = $this->getReads()) {
        foreach my $read (@$reads) {
            $read->erase();
        }
    }
}

sub setFrugal {
# in frugal mode, read sequence is fetched in blocks by delayed loading
# this limits the memory usage i.p. for export of very large contigs
    my $this = shift;
    $this->{frugal} = shift || 0;
}

#------------------------------------------------------------------- 
# parent database handle (or handle to other data source)
#-------------------------------------------------------------------

sub setArcturusDatabase {
# import the parent Arcturus database handle
    my $this = shift;
    my $ADB  = shift;
        
    $this->setDataSource($ADB);
}

sub getArcturusDatabase {
# return the database handle, if any
    my $this = shift;

    my $source = $this->{SOURCE};

    return (ref($source) eq 'ArcturusDatabase') ? $source : undef;
}

sub setDataSource {
# import the handle to the data source (either database or factory)
    my $this = shift;
    my $source = shift || '';

    $this->{SOURCE} = $source if (ref($source) eq 'ArcturusDatabase');

    $this->{SOURCE} = $source if (ref($source) eq 'ContigFactory');

    $this->{SOURCE} = $source if ($source eq 'ContigFactory');

    unless ($this->{SOURCE} && $this->{SOURCE} eq $source) {
        die "Invalid object passed: $source" if $this->{SOURCE};
    } 
}

sub getOrganism {
# retrieve the organism 
    my $this = shift;

    my $ADB = $this->{SOURCE}; # the source or database
    return undef unless (ref($ADB) eq 'ArcturusDatabase');

    return $ADB->getOrganism();
}

sub getInstance {
# retrieve the instance 
    my $this = shift;

    my $ADB = $this->{SOURCE}; # the source or database
    return undef unless (ref($ADB) eq 'ArcturusDatabase');

    return $ADB->getInstance();
}

#-------------------------------------------------------------------
# delayed loading of DNA and quality data from database
#-------------------------------------------------------------------

sub importSequence {
# private method for delayed loading of contig DNA and BaseQuality
    my $this = shift;

    my $SOURCE = $this->{SOURCE} || return 0; # e.g. the parent database

    return $SOURCE->getSequenceAndBaseQualityForContig($this);
}

sub importReadSequence {
# private method, delayed loading of DNA and BaseQuality for reads of this contig
    my $this = shift;

    my $SOURCE = $this->{SOURCE} || return 0; # e.g. the parent database

    return undef unless (ref($SOURCE) eq 'ArcturusDatabase');

    return $SOURCE->getSequenceForReads(@_,caller=>'Contig'); # passes array ref
}

#-------------------------------------------------------------------    
# importing & exporting data and meta data
#-------------------------------------------------------------------    

sub setAverageCover {
    my $this = shift;
    $this->{data}->{averagecover} = shift;
}

sub getAverageCover {
    my $this = shift;
    return $this->{data}->{averagecover};
}

#-------------------------------------------------------------------   

sub setCheckSum {
    my $this = shift;
    my $csum = shift;
    my %options = @_; # attribute=>0,1,2,3,4

    my $attribute = $options{attribute} || 0; # default md5 of seq IDs
    
    $this->{data}->{checksums} = {} unless defined $this->{data}->{checksums};
    $this->{data}->{checksums}->{$attribute} = $csum;
}

#-------------------------------------------------------------------   

sub getConsensusLength {
    my $this = shift;
    $this->importSequence() unless defined($this->{data}->{clength});
#    $this->getStatistics()  unless defined($this->{data}->{clength});
    return $this->{data}->{clength} || 0;
}

sub setConsensusLength {
    my $this = shift;
    $this->{data}->{clength} = shift;
}

#-------------------------------------------------------------------   

sub getContigID {
    my $this = shift;
    return $this->{data}->{contig_id} || 0;
}

sub getSequenceID {
    my $this = shift;
    return $this->getContigID();
}

sub setContigID {
    my $this = shift;
    my $cid  = shift;

    return if ($cid && $cid =~ /\D/); # if defined must be a number

    $this->{data}->{contig_id} = $cid;

# add the sequence ID to any tags

    if (my $tags = $this->getTags()) {
        foreach my $tag (@$tags) {
            $tag->setSequenceID($this->getSequenceID());
        }
    }
}

#-------------------------------------------------------------------   

sub getContigName {
    my $this = shift;

# in its absence generate a name based on the contig_id

    unless(defined($this->{contigname})) {
        my $cid = $this->getContigID() || 0;
        my $ins = $this->getInstance() || 0;
        my $org = $this->getOrganism() || 0;
        $this->setContigName($ins."_".$org."_contig_".sprintf("%08d",$cid));
    }
    return $this->{contigname};
}

sub setContigName {
    my $this = shift;
    $this->{contigname} = shift;
}

# aliases

sub setName() {
    return &setContigName(@_);
}

sub getName() {
    return &getContigName(@_);
}

#------------------------------------------------------------------- 

sub setCreated {
    my $this = shift;
    $this->{created} = shift;
}

sub getCreated {
    my $this = shift;
    my %options = @_;
    return $this->{created} unless $options{numerical};
    return &dateToNumber($this->{created});
}

#------------------------------------------------------------------- 

sub setGap4Name {
    my $this = shift;
    $this->{gap4name} = shift;
}

sub getGap4Name {
    my $this = shift;
    $this->{gap4name} = $this->getReadOnLeft() unless $this->{gap4name};
    return $this->{gap4name} || 'unknown';
}

#------------------------------------------------------------------- 
  
sub addContigNote {
    my $this = shift;
    my $note = shift || return;
    my $newnote = $this->getContigNote();
#    $newnote .= "," if $newnote; # comma separated list
    $note = "$newnote,$note" if $newnote;
    $this->setContigNote($note);
}
  
sub setContigNote {
    my $this = shift;
    $this->{data}->{note} = shift;
}

sub getContigNote {
    my $this = shift;
    return $this->{data}->{note};
}

#------------------------------------------------------------------- 
  
sub getNumberOfParentContigs {
    my $this = shift;
# if number of contigs not defined get it from the Parent Contigs array
    if (!defined($this->{data}->{numberofparentcontigs})) {
        my $npc = $this->hasParentContigs();
        $this->{data}->{numberofparentcontigs} = $npc;
    }
    return $this->{data}->{numberofparentcontigs};
}

sub setNumberOfParentContigs {
    my $this = shift;
    $this->{data}->{numberofparentcontigs} = shift;   
}

#------------------------------------------------------------------- 
  
sub getNumberOfReads {
    my $this = shift;
# if number of reads not defined get it from the Read array
    if (!defined($this->{data}->{numberofreads}) && $this->hasReads()) {
        $this->{data}->{numberofreads} = scalar(@{$this->getReads});
    }
    return $this->{data}->{numberofreads} || 0;
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;   
}

#------------------------------------------------------------------- 
  
sub getNumberOfNewReads {
    my $this = shift;
    return $this->{data}->{numberofnewreads} || 0;  
}
  
sub setNumberOfNewReads {
    my $this = shift;
    $this->{data}->{numberofnewreads} = shift;   
}

#-------------------------------------------------------------------   

sub getOrigin {
    my $this = shift;
    return $this->{data}->{origin} || '';   
}

sub setOrigin {
    my $this = shift;
    $this->{data}->{origin} = shift;
}

#-------------------------------------------------------------------   

sub setBaseQuality {
# import base quality as an array with base quality values
    my $this    = shift;
    my $quality = shift;

    if (defined($quality) and ref($quality) eq 'ARRAY') {
	$this->{BaseQuality} = $quality;
        return 1;
    }
    else {
        return undef;
    }
}

sub getBaseQuality {
# return the quality data (possibly) using delayed loading
    my $this = shift;

    $this->importSequence() unless defined($this->{BaseQuality});
    return $this->{BaseQuality}; # an array reference (or undef)
}

#------------------------------------------------------------------- 

sub getProject {
    my $this = shift;
    my %options = @_; # instance=>1 to return Project instance
 
    &verifyKeys('getProject',\%options,'instance');

    return $this->{project} unless $options{instance}; # project ID

    my $SOURCE = $this->{SOURCE}; # must be the parent database
    return undef unless (ref($SOURCE) eq 'ArcturusDatabase');
    return $SOURCE->getCachedProject(project_id => $this->{project});
}

sub setProject {
    my $this = shift;
    $this->{project} = shift;
}

#-------------------------------------------------------------------   

sub getReadOnLeft {
    my $this = shift;
    return $this->{data}->{readonleft};
}

sub setReadOnLeft {
# private method
    my $this = shift;
    $this->{data}->{readonleft} = shift;
}

#-------------------------------------------------------------------   

sub getReadOnRight {
    my $this = shift;
    return $this->{data}->{readonright};
}

sub setReadOnRight {
# private method
    my $this = shift;
    $this->{data}->{readonright} = shift;
}

#-------------------------------------------------------------------   

sub setSequence {
# import consensus sequence (string) and its length (derived)
    my $this     = shift;
    my $sequence = shift;

    if (defined($sequence)) {
	$this->{Sequence} = $sequence;
        $this->setConsensusLength(length($sequence));
    }
}

sub getSequence {
# return the DNA (possibly) using delayed loading
    my $this = shift;
    my %options = @_;

    $this->importSequence() unless defined($this->{Sequence});

    return $this->{Sequence} unless $options{minNX};

    return &replaceNbyX($this->{Sequence},$options{minNX});
}

sub hasSequence {
# return s true if both DNA and BaseQuality are defined 
    my $this = shift;
    return ($this->{Sequence} && $this->{BaseQuality});
}

sub replaceNbyX { # SHOULD GO TO ContigHelper.pm
# private helper method with getSequence for MAF export: substitute
# sequences of 'N's in the consensus sequence by 'X's and a few 'N's 
    my $sequence = shift;
    my $min      = shift; # minimum length of the string;

# first replace all Ns by X

    if ($min && $sequence =~ s/[N\?]/X/ig) {

# then change contiguous runs of X smaller than $min back to N

        my $X = 'X';
        my $N = 'N';
        my $i = 1;

        while ($i++ < $min) {
            $sequence =~ s/([ACTG\?])($X)(?=[ACTG\?])/$1$N/ig;
            $X .= 'X';
            $N .= 'N';
        }

        return $sequence;
    }

    return 0;
}

#------------------------------------------------------------------- 

sub setUpdated {
    my $this = shift;
    $this->{updated} = shift;
}

sub getUpdated {
    my $this = shift;
    my %options = @_;
    return $this->{updated} unless $options{numerical};
    return &dateToNumber($this->{updated});
}

sub dateToNumber {
    my $datestring = shift;
    $datestring =~ s/\-|\://g;
    $datestring =~ s/\s+/./;
    return $datestring + 0;
}

#-------------------------------------------------------------------    
# importing/exporting Read(s), Mapping(s) & Tag(s) etcetera
#-------------------------------------------------------------------    

sub getReads {
# return a reference to the array of Read instances (can be empty)
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation
    my %options = @_;
 
# delayed loading of reads (if required); without frugal flag, the read sequence 
# itself will be loaded in bulk, with the flag by delayed loading when required 

    if (!$this->{Read} && $load && (my $SOURCE = $this->{SOURCE})) {
#        my $frugal = $this->{frugal} || 0;
#        $SOURCE->getReadsForContig($this,nosequence=>$frugal,caller=>'Contig');
#        compare with nrofreads?

        $options{nosequence} = $this->{frugal} || 0;
        $options{caller} = 'Contig'; # for diagnostics
        $SOURCE->getReadsForContig($this,%options);
    }
    return $this->{Read};
}

sub addRead {
# add Read object or an array of Read objects to the internal buffer
    my $this = shift;
    my $Read = shift;

    $this->importer($Read,'Read');
}

sub hasReads {
# returns true if this Contig has reads
    my $this = shift;
    my $reads = $this->getReads(shift);
    return $reads ? scalar(@$reads) : 0;
}

# read-to-contig mappings

sub getMappings {
# return a reference to the array of Mapping instances (can be empty)
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{Mapping} && $load && (my $ADB = $this->{SOURCE})) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        $ADB->getReadMappingsForContig($this);
    }
    return $this->{Mapping};
} 

sub addMapping {
# add (read) Mapping object (or an array) to the internal buffer
    my $this = shift;
    $this->importer(shift,'Mapping');
}

sub hasMappings {
# returns true if this Contig has (read-to-contig) mappings
    my $this = shift;
    my $mappings = $this->getMappings(shift);
    return $mappings ? scalar(@$mappings) : 0;
}

# contig tags

sub getTags {
# return a reference to the array of Tag instances (can be empty)
    my $this = shift;
    my $load = shift; # option for loading by delayed instantiation
    my %options = @_;

    &verifyKeys('getTags',\%options,'sort','merge','all');

    if (!$this->{Tag} && $load && (my $ADB = $this->{SOURCE})) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        $ADB->getTagsForContig($this,all=>$options{all}); # re: union select ...
    }

# sort tags and remove duplicates / merge coinciding tags

    if ($options{sort} || $options{merge}) {
        ContigHelper->sortContigTags($this,%options);
    }

    return $this->{Tag};
}

sub addTag {
# add Tag object or an array of Tag objects to the internal buffer
    my $this = shift;
    my $ctag = shift;

    $this->importer($ctag,'Tag','Tag',$this->getSequenceID());
}

sub hasTags {
# returns true if this Contig has tags
    my $this = shift;
    my $tags = $this->getTags(shift);
    return $tags ? scalar(@$tags) : 0;
}

# contig-to-parent mappings

sub getContigToContigMappings {
# add (contig) Mapping object (or an array) to the internal buffer
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ContigMapping} && $load && (my $ADB = $this->{SOURCE})) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        $ADB->getContigMappingsForContig($this);
    }
    return $this->{ContigMapping};
}

sub addContigToContigMapping {
    my $this = shift;
    $this->importer(shift,'Mapping','ContigMapping');
}

sub hasContigToContigMappings {
# returns true if this Contig has contig-to-contig mappings
    my $this = shift;
    my $mappings = $this->getContigToContigMappings(shift);
    return $mappings ? scalar(@$mappings) : 0;
}

# parent contig instances

sub getParentContigs {
# returns array of parent Contig instances
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ParentContig} && $load && (my $ADB = $this->{SOURCE})) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        $ADB->getParentContigsForContig($this,@_); # pass on any options
    }
    return $this->{ParentContig};
}

sub addParentContig {
# add parent Contig instance
    my $this = shift;
    $this->importer(shift,'Contig','ParentContig');
}

sub hasParentContigs {
# returns number of previous contigs
    my $this = shift;
    my $parents = $this->getParentContigs(shift);
    return $parents ? scalar(@$parents) : 0;
}

sub getParentContigIDs {
    my $this = shift;
    
    my $parents = $this->getParentContigs(shift);

    my @parentids;
    foreach my $parent (@$parents) {
        push @parentids, $parent->getContigID();
    }
    return @parentids; # an array
}

# child contig instances (re: tag propagation)

sub getChildContigs {
# returns array of child Contig instances
    my $this = shift;
    my $load = shift; # set 1 for loading by delayed instantiation

    if (!$this->{ChildContig} && $load && (my $ADB = $this->{SOURCE})) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        $ADB->getChildContigsForContig($this,@_); # pass on any parameters
    }
    return $this->{ChildContig}; # array reference
}

sub addChildContig {
# add child Contig instance
    my $this = shift;
    $this->importer(shift,'Contig','ChildContig');
}

sub hasChildContigs {
# returns number of offspring contigs 
    my $this = shift;
    my $children = $this->getChildContigs(shift);
    return $children ? scalar(@$children) : 0;
}

#-------------------------------------------------------------------    

sub importer {
# private generic method for importing objects into a Contig instance
    my $this = shift;
    my $Component = shift;
    my $class = shift; # (obligatory) class name of object to be stored
    my $buffername = shift; # (optional) internal name of buffer

    return if ($Component && $this eq $Component); # you can't import yourself

    $buffername = $class unless defined($buffername);

    die "Contig->importer expects a component type" unless $class;

    if (ref($Component) eq 'ARRAY') {
# recursive use with scalar parameter
        while (scalar(@$Component)) {
            $this->importer(shift @$Component,$class,$buffername,@_);
        }
    }
    elsif ($Component) {
# test type of input object against specification
        my $instanceref = ref($Component);
        if ($class ne $instanceref) {
            die "Contig->importer expects a(n array of) $class instance(s) as input";
        }
        $this->{$buffername} = [] if !defined($this->{$buffername});
        push @{$this->{$buffername}}, $Component;
        return unless (defined(my $sequence_id = shift));
        $Component->setSequenceID($sequence_id);
# shouldn't this be done for ChildContigs and Mappings and Reads as well?
        $Component->setHost($this) if ($class eq 'Tag');
    }
    else {
# reset option: call method with Component undefined (or 0)
        undef $this->{$buffername};
    }
}

#-----------------------------------------------------------------------------
# copy
#-----------------------------------------------------------------------------

sub copy {
# create a copy of input contig and (some of) its components (as they are)
    my $this = shift;
    my %options = @_;

# option  nocomponents : discard any components other than sequence and quality
# option  complete     : create a copy with all standard components
# option  parent       : make the copy the parent of the current contig
# option  child        : make the current contig the parent of the copy

# if none of these is specified, copy existing components as they are

    &verifyKeys('copy',\%options,'nocomponents','complete','parent','child');

# create a new instance

    my $copy = new Contig();

# add names and sequence ID 

    $copy->setContigName($this->getContigName());
    $copy->setContigID  ($this->getContigID());
    $copy->setGap4Name  ($this->getGap4Name());
    $copy->setContigNote($this->getContigNote); # if any

    $copy->setDataSource($this->{SOURCE}); # if any

# copy the sequence (scalar)

    $copy->setSequence($this->getSequence());

# copy the array components (to make the copy independent of its original)

    my @components = ('BaseQuality','Reads','ParentContigs','ChildContigs',
                      'Mappings','ContigToContigMappings','Tags');

    foreach my $component (@components) {
	my $array;
        eval "\$array = \$this->get$component()";
        next unless ($array && @$array);
        my $arraycopy = []; 
        @$arraycopy = @$array; # duplicate the array
        if ($component eq 'BaseQuality') {
            $copy->setBaseQuality($arraycopy);
            last if $options{nocomponents};
            next;
	}
# for tags and mappings replace individual array elements with a copy
        if ($component =~ /Tag|Map/) {
            foreach my $instance (@$arraycopy) {
                $instance = $instance->copy();
            } 
        }
# add the copied array
        $component =~ s/s$//;
        eval "\$copy->add$component(\$arraycopy)";
        next unless $@;

	my $logger = &verifyLogger('copy');
        $logger->error("failed to copy $component ('$@')"); 
    }

# load components if they are not already present

    if ($options{complete}) {
        $copy->getReads(1);
        $copy->getMappings(1);
        $copy->getTags(1);
    }

    $copy->getStatistics(1) if $copy->hasMappings();

# export either as child or as parent of the original (or none)

    if ($options{parent}) {
        $this->addParentContig($copy);
        $copy->addChildContig($this);
    } elsif ($options{child}) {
        $this->addChildContig($copy);
        $copy->addParentContig($this);
    }

    return $copy;
}

#-------------------------------------------------------------------    
# test, calculate consensus length, cover, etc
#-------------------------------------------------------------------

sub isValid {
# test if contig has a valid and consistent set of components
    my $this = shift;
    my %options = @_;

    &verifyKeys('isValid',\%options,'forimport','metadata'
                         ,'noreadsequencetest','diagnose');
    return ContigHelper->testContig($this,%options); # returns 1 or 0
# possible diagnostics stored in $this->{status};
}

sub getStatus {
    my $this = shift;
    return $this->{status} || '';
}

sub isCurrent {
# returns true if contig ID is in the current generation, else 0
    my $this = shift;

    if (my $ADB = $this->{SOURCE}) {
        return undef unless (ref($ADB) eq 'ArcturusDatabase');
        return undef unless $this->getContigID();
        return $ADB->isCurrentContigID($this->getContigID());
    }
    return undef; # cannot decide
}

sub getStatistics {
# collect a number of contig statistics
    my $this = shift;
    my $pass = shift; # >= 2 allow adjustment of zeropoint, else not

    my %options;
    $options{pass} = $pass if $pass;
#    &verifyKeys('getStatistics',\%options,'pass');
    return ContigHelper->statistics($this,%options);
}

sub getCheckSum {
    my $this = shift;
    my %options = @_; # refresh=>0,1 ; attribute=> 0,1,2,3,4 ; asis=>0,1 ; load=>0,1

# attribute 0 for seq IDs ; 1,3 for DNA ->,<- ; 2,4 for base quality ->,<-

    my $attribute = $options{attribute} || 0; # default seqID checksum

    $this->{data}->{checksums} = {} unless defined $this->{data}->{checksums}; # vivify

    unless ($options{refresh}) {
        my $checksum = $this->{data}->{checksums}->{$attribute};
        return $checksum if $options{asis}; # force return
        return $checksum if $checksum; # return if available
#     else continue to calculate from scratch
    }

# case 0 : return md5 hash on sorted seq IDs 

    unless ($attribute) {
        my $reads = $this->getReads($options{load}) || return 0;
        my @seqids;
        foreach my $read (@$reads) {
            push @seqids,$read->getSequenceID(); # no check on existence here
        }
        $this->setCheckSum(md5(sort @seqids));
        return $this->getCheckSum();
    }

# cases 1 - 4 : odd for md5 hash of sequence DNA, even for md5 hash of base quality

    if ($attribute%2) { # case 1, 3 dna
        my $sequence = $this->getSequence() || return 0;;
        $this->setCheckSum(md5($sequence),@_)      unless ($attribute == 3);
        $sequence =~ tr/acgtACGT/tgcaTGCA/             if ($attribute == 3);  
        $this->setCheckSum(md5(reverse($sequence)),@_) if ($attribute == 3);
    }
    else { # case 2, 4 base quality
        my $quality = $this->getBaseQuality() || return 0;
        $this->setCheckSum(md5(@$quality),@_)      unless ($attribute == 4);
        $this->setCheckSum(md5(reverse(@$quality)),@_) if ($attribute == 4);
    }

    return $this->getCheckSum(attribute=>$attribute,asis=>1);
#    return $this->{data}->{checksums}->{$attribute};
}

#-------------------------------------------------------------------    
# compare this Contig with another one using metadata and mappings
#-------------------------------------------------------------------

sub isEqual {
    my $this = shift;
    my $compare = shift;
    my %options = @_; # bidirectional=>1 for recognition of counter-alignment

    &verifyKeys('isEqual',\%options,'sequenceonly','bidirectional');
    my $equal = ContigHelper->isEqual($this,$compare,%options);
    $equal = 0 unless ($equal == 1 || $options{bidirectional});
    return $equal;
}


sub linkToContig {
# compare two contigs using sequence IDs in their read-to-contig mappings
# adds a contig-to-contig Mapping instance with a list of mapping segments,
# if any, for mapping from $compare to $this contig
# returns the number of mapped segments (usually 1); returns undef if 
# incomplete Contig instances or missing sequence IDs in mappings
    my $this = shift;
    my $compare = shift; # Contig instance to be compared to $this
    my %options = @_;

    &verifyKeys('linkToContig',\%options,'sequenceonly','banded',
#     'readclipping','noquillotine',
#     'offsetwindow','correlation','defects','segmentsize',
                                         'forcelink','strong',);
    return ContigHelper->crossmatch($this,$compare,%options);
}

sub linkToParents {
# repeatedly invokes linkToContig (above); takes same options as linkToContig
    return ContigHelper->linkContigToParents(@_);
}

#-------------------------------------------------------------------    
# Tags
#-------------------------------------------------------------------    

sub inheritTags {
# inherit tags FROM this contig's parents
    my $this = shift;
    my %options = @_;

    my $logger = &verifyLogger('inheritTag');

# depth 1 or less: parents; depths 2 for grandparents (if no tags on parents)

    $options{depth} = 1 unless defined($options{depth}); # 

# get the parents; if none present, (try to) get them from the database

    my $parents = $this->getParentContigs(1);

    return unless ($parents && @$parents);

    $options{depth} -= 1; # here, because it applies to all parents

    foreach my $parent (@$parents) {
# check if this parent does have tags using delayed loading; if not
# inherit from its parent(s) until the depth specification runs out
        if (!$parent->hasTags(1) && $options{depth} > 0) {
	    $logger->info("inherit tags at level $options{depth}");
            $parent->inheritTags(%options);
        }
    }
# get the tags from the parents into this contig (as they now are)
    delete $options{depth};
    foreach my $parent (@$parents) {
        &propagateTagsToContig($parent,$this,%options);
    }
}

sub propagateTags {
# propagate the tags from this contig TO its child(ren)
    my $this = shift;
    my %options = @_;

# get the child(ren); if none present, (try to) get them from the database

    my $children = $this->getChildContigs(1);

    foreach my $child (@$children) {
        &propagateTagsToContig($this,$child,%options);
    }
}

sub propagateTagsToContig {
# propagate tags FROM this (parent) TO the specified target contig
    my $parent = shift; # this Contig instance
    my $target = shift; # child
    my %options = @_;

    my @validoptionkeys = ('depth',
                           'asis',         # take parent contig(s) and tags as is
                           'unique',       # specify mapping expected
                           'norerun',      # inhibit default link determination if no mapping found
                           'annotation',   # list of tags to be screened
                           'finishing',    # 1 to include, 0 to exclude 
                           'markftags',    # mark tags if different tag on parent
                           'cached',       # use caching when fetching offspring contigs
                           'banded');      # (not in use at the moment) link determination

    &verifyKeys('propagateTags',\%options,@validoptionkeys);
    return ContigHelper->propagateTagsToContig($parent,$target,%options);
}

#-------------------------------------------------------------------    
# Projects
#-------------------------------------------------------------------    

sub inheritProject {
    my $this = shift;
    my %options = @_;

    &verifyKeys('inheritProject',\%options,'delayed','measure');

# returns Project instance (while $this->{project} is also defined)

    return ContigHelper->inheritProject($this,@_); 
}

#-------------------------------------------------------------------    
# exporting to CAF (standard Arcturus)
#-------------------------------------------------------------------    

sub writeToCaf {
# write reads and contig to CAF (unpadded)
    my $this = shift;
    my $FILE = shift; # obligatory file handle
    my %options = @_;

    my @validoptionkeys = ('noreads',     # don't export reads, only contig
                           'readsonly',   # only export reads
                           'qualitymask', # if readsonly: mask low quality read sequence
 #                          'gap4name',   # 
                           'notags',      # don't export tags
		           'alltags',
                           'includetag',
                           'excludetag');

    &verifyKeys('writeToCaf',\%options,@validoptionkeys);

    return "Missing file handle for Caf output" unless $FILE;

    my $contigname = $this->getContigName();

# dump all reads, in frugal mode destroy read after it has been written

    unless ($options{noreads}) {
# if there are no reads, use delayed loading
        my $reads = $this->getReads(1); 
# in frugal mode we bunch the reads in blocks to improve speed (and reduce memory)
	if (my $blocksize = $this->{frugal}) {
            $blocksize = 100 if ($blocksize < 100); # minimum
            my $logger = &verifyLogger('writeToCaf');
            $logger->debug("blocked export of ".scalar(@$reads)." reads");
            while (my @readblock = splice @$reads,0,$blocksize) {
                $logger->debug("writing block of ".scalar(@readblock)." reads");
                $this->importReadSequence(\@readblock);
                foreach my $read (@readblock) {
                    $read->writeToCaf($FILE,%options); # transfer options, if any
                    $read->erase(); # prepare to free memory 
                }
                undef @readblock;
	    }
        }
        else {  # standard, all read components loaded
            foreach my $read (@$reads) {
                $read->writeToCaf($FILE,%options); # transfer options, if any
            }
        }
        return 0 if $options{readsonly}; # export only reads
    }

# write the overall maps for for the contig ("assembled from")

    print $FILE "\nSequence : $contigname\nIs_contig\n$this->{padstatus}\n";

    my $mappings = $this->getMappings(1); # if no maps, use delayed loading
    foreach my $mapping (@$mappings) {
        print $FILE $mapping->assembledFromToString();
    }

# write contig tags, if any are loaded (if no tags, use delayed loading)

    if (!$options{notags} && $this->hasTags(1)) {
        my $tags = $this->getTags();
# decide on which tags to export; default no annotation (assembly export)
        my ($includetag,$excludetag);
        $excludetag = "ASIT"; # default exclude
        if ($options{alltags}) {
            undef $excludetag;
        }
        elsif ($options{includetag}) { # specified takes precedence
            $includetag = $options{includetag};
            $includetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $includetag =~ s/\W+/|/g; # put separators in include list
	}
        elsif ($options{excludetag}) {
            $excludetag = $options{excludetag};
            $excludetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $excludetag =~ s/\W+/|/g; # put separators in exclude list
	}
# export the tags which pass the possible tag type filter               
        foreach my $tag (@$tags) {
            my $tagtype = $tag->getType();
            next if ($includetag && $tagtype !~ /$includetag/);
            next if ($excludetag && $tagtype =~ /$excludetag/); 
            $tag->writeToCaf($FILE,annotag=>1);
        }
    }

# to write the DNA and BaseQuality we use the two private methods

    my $errors = $this->writeDNA($FILE,marker => "\nDNA : "); # CAF marker

    $errors += $this->writeBaseQuality($FILE,marker => "\nBaseQuality : ");

    print $FILE "\n";

    return $errors;
}

sub writeToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data
    my %options = @_;

    &verifyKeys('writeToFasta',\%options,'readsonly','gap4name','minNX');

    return "Missing file handle for Fasta output" unless $DFILE;

# 'readsonly' switch dumps reads but no contig; its absence dumps contigs 

    if ($options{readsonly}) {
        my $reads = $this->getReads(1); # if no reads, use delayed loading
        foreach my $read (@$reads) {
# options:  qualitymask=>'M'
            $read->writeToFasta($DFILE,$QFILE,%options); # transfer options
        }
        return undef;

# in frugal mode we bunch the reads in blocks to improve speed 
	if (my $blocksize = $this->{frugal}) {
            $blocksize = 100 if ($blocksize < 100);
            my $logger = &verifyLogger('writeToFasta');
            $logger->debug("blocked export of ".scalar(@$reads)." reads");
            while (my @readblock = splice @$reads,0,$blocksize) {
                $logger->debug("writing block of ".scalar(@readblock)." reads");
                $this->importReadSequence(\@readblock);
                foreach my $read (@readblock) {
                    $read->writeToFasta($DFILE,$QFILE,%options); # transfer options
                    $read->erase(); # prepare to free memory 
                }
                undef @readblock;
	    }
        }
        else {  # standard, all read components loaded
            foreach my $read (@$reads) {
# options:  qualitymask=>'M'
                $read->writeToFasta($DFILE,$QFILE,%options); # transfer options
            }
        }
        return undef;
    }

#to be deleted from HERE
# apply end-region masking
#    if ($options{endregiononly}) { # to be DEPRECATED
# get a masked version of the current consensus TO BE REMOVED FROM THIS MODULE
#        $this->extractEndRegion(nonew=>1,%options);
#    }
# apply quality clipping
#    if ($options{qualityclip}) { # to be DEPRECATED
# get a clipped version of the current consensus TO BE REMOVED FROM THIS MODULE
#print STDERR "quality clipping ".$this->getContigName()."\n";
#        my ($contig,$status) = $this->deleteLowQualityBases(nonew=>1,%options);
#        unless ($contig && $status) {
#	    print STDERR "No quality clipped for ".$this->getContigName()."\n";
#        }
#    }
# TO HERE

    my $errors = $this->writeDNA($DFILE,%options);

    $errors += $this->writeBaseQuality($QFILE,%options) if $QFILE;

    return $errors;
}

# private methods

sub writeDNA {
# write consensus sequence DNA to DFILE handle
    my $this    = shift;
    my $DFILE   = shift; # obligatory
    my %options = @_;

    my $marker = $options{marker} || '>'; # default FASTA format

    my $identifier = $this->getContigName();
# optionally add gap4name (generally: extended descriptor)
    if ($options{gap4name}) {
        $identifier .= " - ".$this->getGap4Name();
        if (my $note = $this->getContigNote()) {
            $identifier .= " ".$note;
        }
    }

    if (!$DFILE) {
       print STDERR "Missing file handle for DNA sequence\n";
       return 1; # error status
    }
    elsif (my $dna = $this->getSequence(@_)) {
# output in blocks of 60 characters
	print $DFILE "$marker$identifier\n";
	my $offset = 0;
	my $length = length($dna);
	while ($offset < $length) {    
	    print $DFILE substr($dna,$offset,60)."\n";
	    $offset += 60;
	}
    }
    else {
        print STDERR "Missing DNA data for contig $identifier\n";
        return 1; # error status
    }
       
    return 0; # no errors
}

sub writeBaseQuality {
# write consensus Quality Data to QFILE handle
    my $this   = shift;
    my $QFILE  = shift; # obligatory
    my %options = @_;

    my $marker = $options{marker} || '>'; # default FASTA format

    my $identifier = $this->getContigName();
# optionally add gap4name 
    if ($options{gap4name}) {
        $identifier .= " - ".$this->getGap4Name();
    }

    if (!$QFILE) {
        priont STDERR "Missing file handle for Quality Data\n";
        return 1; # error status
    }
    elsif (my $quality = $this->getBaseQuality()) {
# output in lines of 25 numbers
	print $QFILE "$marker$identifier\n";
	my $n = scalar(@$quality) - 1;
        for (my $i = 0; $i <= $n; $i += 25) {
            my $m = $i + 24;
            $m = $n if ($m > $n);
	    print $QFILE join(' ',@$quality[$i..$m]),"\n";
	}
    }
    else {
        print STDERR "Missing BaseQuality data for contig $identifier\n";
        return 1; # error status
    }

    return 0; # no errors
}


sub writeToMaf {
# write the "reads.placed" read-contig mappings in Mullikin format
    my $this = shift;
    my $DFILE = shift; # obligatory file handle for DNA
    my $QFILE = shift; # obligatory file handle for QualityData
    my $RFILE = shift; # obligatory file handle for Placed Reads
    my %options = @_;  # minNX=>n , supercontigname=> , contigzeropoint=> 

    &verifyKeys('writeToMaf',\%options,'minNX','supercontigname');

    my $report = '';

    unless ($DFILE && $QFILE && $RFILE) {
	$report .= "Missing file handle for Maf output of ";
	$report .= "DNA Bases\n" unless $DFILE;
	$report .= "Quality Data\n" unless $QFILE;
	$report .= "Placed Reads\n" unless $RFILE;
	return 0,$report;
    }

# preset error reporting

    my $success = 1;

# first handle the fasta output of the consensus sequence DNA and Quality

    my $minNX = $options{minNX};
    $minNX = 3 unless defined($minNX);
# replace sequences of consecutive non-base by X's
    if (my $sequence = $this->getSequence()) {
        $this->writeToFasta($DFILE,$QFILE,minNX=>$minNX);
    }
    else {
        return 0,"Missing sequence for contig ".$this->getContigName();
    }

# extra outside info to be passed as parameters: supercontig name &
# approximate start of contig on supercontig

    my $contigname = $this->getContigName();
    my $supercontigname = $options{supercontigname} || $contigname;
    my $contigzeropoint = $options{contigzeropoint} || 0;

# get the reads and build a hash list for identification

    my %reads;
    my $reads = $this->getReads(1);
    foreach my $read (@$reads) {
        $reads{$read->getReadName()} = $read;
    }

# write the individual read info

    my $mappings = $this->getMappings(1);
    foreach my $mapping (@$mappings) {
        my @range = $mapping->getContigRange();
        my $readname = $mapping->getMappingName();
        unless ($readname) {
            $report .= "Missing readname in mapping "
                    .   $mapping->getMappingID()."\n";
            $success = 0;
            next;
        }
        my $read = $reads{$readname};
        unless ($read) {
	    $report .= "Missing read $readname\n";
            $success = 0;
	    next;
	}
        my $lqleft = $read->getLowQualityLeft();
        my $length = $read->getLowQualityRight() - $lqleft + 1;
        my $alignment = ($mapping->getAlignment() > 0) ? 0 : 1;
        my $supercontigstart  = $contigzeropoint + $range[0];
        print $RFILE "* $readname $lqleft $length $alignment " .
                     "$contigname $supercontigname $range[0] " .
                     "$supercontigstart\n"; 
    }

# returns 1 for success or 0 and report for errors

    return $success,$report;
}

sub writeToEMBL {
# write contig info in (minimal) EMBL format (TO BE TESTED)
    my $this = shift;
    my $DFILE = shift; # obligatory file handle for DNA output
    my $QFILE = shift; # optional file handle for quality data
    my %options = @_;

    &verifyKeys('writeToEMBL',\%options,'gap4name',
                                        'includetag', # default 'ANNO'
                                        'excludetag',
                                        'tagkey');
# compose identifier

    my $arcturusname = $this->getContigName();
    my $readonleft   = $this->getReadOnLeft()  || $this->getGap4Name();
    my $readonright  = $this->getReadOnRight() || 'undefined';

    my $identifier = $arcturusname;
    if ($options{gap4name}) {
        $identifier .= " - " . $this->getGap4Name();
    }

    if (!$DFILE) {
        print STDERR "Missing file handle for DNA sequence\n";
        return 1;
    }
    elsif (my $dna = $this->getSequence()) {

# collect length and print header record

	my $length = length($dna);
	print $DFILE "ID   $identifier  standard; Genomic DNA; CON; "
                   . "$length BP\n";
        print $DFILE "XX\n";
        print $DFILE "AC   unknown;\n"; # ?
        print $DFILE "XX\n";
        print $DFILE "FH   Key             Location/Qualifiers\n";
        print $DFILE "FH\n";
	print $DFILE "FT   contig          1..$length\n";
        if (my $note = $this->getContigNote()) {
            print $DFILE "FT                   /arcturus_note=\"$note\"\n";
	}
        print $DFILE "FT                   /arcturus_id=\"$arcturusname\"\n";
        print $DFILE "FT                   /GAP4_read_id_left=\"$readonleft\"\n";
        print $DFILE "FT                   /GAP4_read_id_right=\"$readonright\"\n";

# the tag section (if any)

        if ($this->hasTags(1)) { # force delayed loading
# determine which tags to export
            unless ($options{includetag} || $options{excludetag}) {
                $options{includetag} = 'ANNO' unless defined($options{includetag});
	    }
            my $includetag = $options{includetag};
            $includetag =~ s/^\s+|\s+$//g; # leading/trailing blanks
            $includetag =~ s/\W+/|/g; # put separators in include list
            my $excludetag = $options{excludetag};

            my $tags = $this->getTags(0,sort=>'position');
# test if there are tags with identical systematic ID; collect groups, if any
            my @newtags;
            my $joinhash = {};
            foreach my $tag (@$tags) {
                my $tagtype = $tag->getType();
                if ($includetag) {
                    next if ($tagtype !~ /$includetag/);
		}
                if ($excludetag) {
# ignore tagtype, or tags with a matching comment
                    next if ($tagtype =~ /$excludetag/);
                    my $tagcomment = $tag->getTagComment();
                    next if ($tagcomment && $tagcomment =~ /$excludetag/);
                    my $comment = $tag->getTagComment();
                    next if ($comment    && $comment    =~ /$excludetag/);
		}
                my $strand  = lc($tag->getStrand());
                my $sysID   = $tag->getSystematicID();
# if the tag is not an annotation tag, just add to local list
                unless (defined($sysID) && $sysID =~ /\S/) {
		    push @newtags,$tag;
                    next;
		}
# the tag is annotation, build the join hash
                $joinhash->{$sysID} = {} unless $joinhash->{$sysID};
                unless ($joinhash->{$sysID}->{$strand}) {
                    $joinhash->{$sysID}->{$strand} = [];
                }
		my $joinset = $joinhash->{$sysID}->{$strand};
                push @$joinset, $tag;
            }

# if there are groups of tags or tag fragments, generate joins

            foreach my $sysID (sort keys %$joinhash) {
                my $strandhash = $joinhash->{$sysID};
                foreach my $strand (keys %$strandhash) {
                    my $joinset = $strandhash->{$strand};
                    my $newtag = TagFactory->makeCompositeTag($joinset);
                    push @newtags,$newtag if $newtag;
	        }
	    }

# export the tags; sort on start position, then on end position

            @newtags = sort {$a->getPositionLeft()  <=> $b->getPositionLeft() 
			or   $a->getPositionRight() <=> $b->getPositionRight()}
	               @newtags;

            my $tagkey = $options{tagkey}; # default CDS set in Tag class
            foreach my $tag (@newtags) {
                my $tagtype = $tag->getType();
                next if ($includetag && $tagtype !~ /$includetag/);
                print $DFILE $tag->writeToEMBL(0,tagkey=>$tagkey);
            }
            print $DFILE "XX\n";
        }
  
# the DNA section, count the base composition

        my %base = (A=>0,C=>0,G=>0,T=>0); # to have them defined
        while ($dna =~ /(.)/g) {
            $base{uc($1)}++; # count on upper case
        }
# count other than ACTG
        my $other = $length;
        foreach my $key ('A','C','G','T') {
            $other -= $base{$key};
        }
        print $DFILE  "SQ   Sequence $length BP; "
                    . "$base{A} A;  $base{C} C; $base{G} G; $base{T} T; "
			. "$other  other;\n";

# output in blocks of 60 characters

	my $offset = 0;
	while ($offset < $length) {    
	    my $line = substr($dna,$offset,60);
            $line =~ tr/A-Z/a-z/; # lower case
	    $offset += 60;
            if ($offset > $length) {
# append the missing blanks to the line
                my $gap = $offset - $length;
                while ($gap--) {
                    $line .= " ";
                }
                $offset = $length;
	    }
            $line =~ s/(.{1,10})/$1 /g; # insert single space
            print $DFILE "     ". $line . sprintf('%9d',$offset) . "\n"; # 80 
	}
        print $DFILE "//\n";
    }
    else {
        print STDERR "Missing DNA data for contig $identifier\n";
        return 1;
    }

    return 0 unless $QFILE;

# Quality printout to be completed
}

#-------------------------------------------------------------------    

sub metaDataToString {
# list the contig meta data
    my $this = shift;
    my $full = shift;

    $this->getMappings(1) if $full; # load the read-to-contig maps

    if (!$this->getReadOnLeft() && $this->hasMappings()) {
        $this->getStatistics(1);
    }

    my $name     = $this->getContigName()            || "undefined";
    my $gap4name = $this->getGap4Name();
    my $created  = $this->{created}                  || "not known";
    my $updated  = $this->{updated}                  || "not known";
    my $project  = $this->{project}                  ||           0;
    my $length   = $this->getConsensusLength()       ||   "unknown";
    my $cover    = $this->getAverageCover()          ||   "unknown";
    my $rleft    = $this->getReadOnLeft()            ||   "unknown";
    my $right    = $this->getReadOnRight()           ||   "unknown";
    my $nreads   = $this->getNumberOfReads()         || "undefined";
    my $nwread   = $this->getNumberOfNewReads()      ||           0;
    my $pcntgs   = $this->getNumberOfParentContigs() ||           0;

# if the contig has parents, get their names by testing/loading the mappings

    my $parentlist = '';
    my @assembledfrom;
    if ($pcntgs && (my $mappings = $this->getContigToContigMappings(1))) {
        my @parents;
        foreach my $mapping (@$mappings) {
            push @parents, $mapping->getMappingName();
            push @assembledfrom, $mapping->assembledFromToString(1);
        }
        $parentlist = "(".join(',',sort @parents).")" if @parents;
    }

    my $string = "Contig name     = $name\n"
               . "Gap4 name       = $gap4name\n"
               . "Created         : $created\n"
               . "Last update     : $updated\n"
               . "Project ID      = $project\n"
               . "Number of reads = $nreads  (newly assembled : $nwread)\n"
               . "Parent contigs  = $pcntgs $parentlist\n"
               . "Consensuslength = $length\n"
               . "Average cover   = $cover\n"   
               . "End reads       : (L) $rleft   (R) $right\n\n";
    foreach my $assembled (sort @assembledfrom) {
        $string   .= $assembled;
    }

    return $string;
}

sub toString {
# very brief summary
    my $this = shift;

    my $name     = $this->getContigName()            || "undefined";
    my $gap4name = $this->getGap4Name();
    my $nreads   = $this->getNumberOfReads()         || -1;
    my $length   = $this->getConsensusLength()       || -1;
    my $cover    = $this->getAverageCover()          || -1;
    my $created  = $this->{created}                  || "undefined";
    my $project  = $this->{project}                  || 0;

    return sprintf 
     ("%-14s = %-20s r:%-7d l:%-8d c:%4.2f %-19s %3d",
      $name,$gap4name,$nreads,$length,$cover,$created,$project);
}

#-------------------------------------------------------------------    
# manipulation of content using the ContigHelper class; operations 
# which change the content (by number or by value) are subcontracted 
# to the helper module
#-------------------------------------------------------------------    

sub reverse {
# return the reverse complement of this contig (and its components)
    my $this = shift;
    my %options = @_;
    &verifyKeys('reverse',\%options,'nonew','complete','nocomponents','child');
    return ContigHelper->reverseComplement($this,@_);
}

sub extractEndRegion {
# return a (new, always) contig object with only the end regions
    my $this = shift;
    my %options = @_;
    &verifyKeys('extractEndRegion',\%options,
                'endregionsize','sfill','qfill','lfill');
    return ContigHelper->extractEndRegion($this,%options); # returns Contig
}

sub endRegionTrim {
# remove low quality data at either end 
    my $this = shift;
    my %options = @_; 
    &verifyKeys('endRegionTrim',\%options,'new','cliplevel','complete');
    return ContigHelper->endRegionTrim($this,%options); # returns Contig
}

sub deleteLowQualityBases {
# remove low quality dna
    my $this = shift;
    my %options = @_;
    &verifyKeys('deleteLowQualityBases',\%options, 
                'threshold','minimum','window','hqpm','symbols',
                'exportaschild','exportasparent',
                'components','nonew');
    return ContigHelper->deleteLowQualityBases($this,%options);
}

sub replaceLowQualityBases {
# replace low quality pads by a given symbol
    my $this = shift;
    my %options = @_;
    &verifyKeys('replaceLowQualityBases',\%options,'new','padsymbol',
                'threshold','minimum','window','hqpm','symbols',
                'exportaschild','components'); # ??
    return ContigHelper->replaceLowQualityBases($this,%options);
}

sub removeLowQualityReads {
# remove low quality bases and the low quality reads that cause them
    my $this = shift;
    my %options = @_;
    &verifyKeys('removeLowQualityReads',\%options,'nonew',
                'threshold','minimum','window','hqpm','symbols');
    return ContigHelper->removeLowQualityReads($this,%options);
}

sub removeShortReads {
    my $this = shift;
    my %options = @_; 
    &verifyKeys('removeShortReads',\%options,'nonew','threshold');
    return ContigHelper->removeShortReads($this,%options);
}

sub removeNamedReads {
    my $this = shift;
    my $reads = shift; # array ref with list of reads to remove
    my %options = @_; 
    &verifyKeys('removeNamedReads',\%options,'new');
    return ContigHelper->removeNamedReads($this,$reads,%options);
}

sub removeInvalidReadNames {
    my $this = shift;
    my %options = @_; 
    &verifyKeys('removeInvalidReadNames',\%options,'new','exclude_filter');
    return ContigHelper->removeInvalidReadNames($this,%options);
}

sub restoreMaskedReads {
    my $this = shift;
    my %options = @_; 
    return ContigHelper->restoreMaskedReads($this,%options);
}

sub undoReadEdits {
    my $this = shift;
    my %options = @_;
    &verifyKeys('undoReadEdits',\%options,'nonew','ADB');
    return ContigHelper->undoReadEdits($this,%options); # ? ADB? SOURCE?
}

sub break {
    my $this = shift;
    my %options = @_;
    &verifyKeys('break',\%options); # none for the moment
    return ContigHelper->break($this,%options);
}

sub disassemble {
    my $this = shift;
    my %options = @_;
    &verifyKeys('disassemble',\%options,'tagstart','tagfinal');
    return ContigHelper->disassemble($this,%options);
}

#---------------------------
# Pad status TO BE DEVELOPED
#---------------------------

sub toPadded {
    my $this = shift;
    return $this if $this->isPadded();
    return ContigHelper->pad($this,@_);
}

sub toUnpadded {
    my $this = shift;
    return $this unless $this->isPadded();
    return ContigHelper->depad($this,@_);
}

sub setPadStatus {
    my $this = shift;
    $this->{padstatus} = ((shift) ? "P" : "Unp")."added";
}

sub isPadded {
# return 0 for unpadded (default) or true for padded
    my $this = shift;
    return $this->{padstatus} eq "Padded" ? 1 : 0;
}

#-------------------------------------------------------------------    
# access protocol
#-------------------------------------------------------------------    

sub verifyKeys {
# private, test hash keys against a list of input keys
    my $method = shift; # method name
    my $hash = shift; # reference to options hash

    my %keys;
    foreach my $key (@_) {
	$keys{$key} = 1;
    }

    while (my($key,$value) = each %$hash) {
        next if $keys{$key};
        $value = 'undef' unless defined($value);
        print STDERR "Invalid key $key ($value) provided "
                   . "for method Contig->$method\n";
    }
}

#-----------------------------------------------------------------------------

my $LOGGER; # class variable

#-----------------------------------------------------------------------------

sub verifyLogger {
# private, test the logging unit; if not found, build a default logging module
    my $prefix = shift;

#    &verifyPrivate($prefix,'verifyLogger');

    if ($LOGGER && ref($LOGGER) eq 'Logging') {

        if (defined($prefix)) {

            $prefix = "Contig->".$prefix unless ($prefix =~ /\-\>/); 

            $LOGGER->setPrefix($prefix);
        }
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

#    &verifyLogger(); # creates a default if $LOGGER undefined
    ContigHelper->setLogger($logger);
}

#-------------------------------------------------------------------    

1;
