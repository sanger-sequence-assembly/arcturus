package ArcturusDatabase::ADBContig;

use strict;

use Exporter;

use ArcturusDatabase::ADBRead;

use TagFactory::TagFactory;

use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Contig;
use Mapping;

our @ISA = qw(ArcturusDatabase::ADBRead Exporter);

our @EXPORT = qw(getCurrentContigs); # DEPRECATE when view can be used

use ArcturusDatabase::ADBRoot qw(queryFailed);

#-----------------------------------------------------------------------------
# constructor and initialisation via constructor of superclass
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#------------------------------------------------------------------------------
# methods for exporting CONTIGs or CONTIG attributes
#------------------------------------------------------------------------------

sub hasContig {
# test presence of contig with given contig identifier; return 0 or contig id
    my $this = shift;
    my %options = @_;

    $options{metaDataOnly} = 1;

    my $contig = $this->getContig(%options);

    return 0 unless $contig;

    return $contig->getContigID();  
}

sub getContig {
# return a Contig object 
# options: one of: contig_id=>N, withRead=>R, withChecksum=>C, withTag=>T 
# additional : metaDataOnly=>0 or 1 (default 0), noReads=>0 or 1 (default 0)
#              noreadtag=>0, nocontigtags=>0 (or just notags?)

# DO WE NEED:andblocked: include contig from blocked projects TO BE IMPLEMENTED ?
    my $this = shift;
    my %options = @_;

# if cached option used, contig ID must be defined

    return $this->getCachedContig(%options) if $options{cached};

# decode input parameters and compose the query

    my $query  = "select CONTIG.contig_id,gap4name,length,ncntgs,nreads,"
               . "newreads,cover,created,updated,project_id,readnamehash"; 

    my @values;

    if ($options{ID} || $options{contig_id}) {
        $query .= "  from CONTIG where contig_id = ? ";
        my $value = $options{ID} || $options{contig_id};
	push @values, $value;
    }

    if ($options{withChecksum}) {
# returns the highest contig_id, i.e. most recent contig with this checksum
        $query .= "  from CONTIG where readnamehash = ? ";
	push @values, $options{withChecksum};
    }

    if ($options{withRead}) {
# returns the highest contig_id, i.e. most recent contig with this read
        $query .= "  from CONTIG, MAPPING, SEQ2READ, READINFO "
               .  " where CONTIG.contig_id = MAPPING.contig_id "
               .  "   and MAPPING.seq_id = SEQ2READ.seq_id "
               .  "   and SEQ2READ.read_id = READINFO.read_id "
	       .  "   and READINFO.readname like ? ";
	push @values, $options{withRead};

    }

    if ($options{withTagName}) {
# returns the highest contig_id, i.e. most recent contig with this tag
# NOTE: perhaps we should cater for more than one contig returned?
        $query .= "  from CONTIG,TAG2CONTIG,CONTIGTAG,TAGSEQUENCE"
               .  " where CONTIG.contig_id = TAG2CONTIG.contig_id"
               .  "   and TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
               .  "   and CONTIGTAG.tag_seq_id = TAGSEQUENCE.tag_seq_id"
               .  "   and TAGSEQUENCE.tagseqname like ? ";
	push @values, $options{withTagName};
    }

    if ($options{withAnnotationTag}) {
# returns the highest contig_id, i.e. most recent contig with this tag
        $query .= "  from CONTIG,TAG2CONTIG,CONTIGTAG"
               .  " where CONTIG.contig_id = TAG2CONTIG.contig_id"
               .  "   and TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
	       .  "   and CONTIGTAG.systematic_id like ? ";
	push @values, $options{withAnnotationTag};
    }

# use '=' if no wildcards specified in data (speed!)

    $query =~ s/like/=/ unless (@values && $values[0] =~ /\%/);

# add possible project specification

    if ($options{project_id}) {
        $query .= "   and project_id = ? ";
	push @values,$options{project_id};
    }
    elsif ($options{projectname}) {
        my $subquery = "select project_id from PROJECT"
	             . " where name like ? ";
        $subquery =~ s/like/=/ unless ($options{projectname} =~ /\%/);
        $query .= "   and project_id in ($subquery)";
        push @values, $options{projectname};
    }

# add limit clause to guarantee latest contig returned

    $query .= "order by contig_id desc limit 1";

    $this->logQuery('getContig',$query,@values) if $options{report};

# ok, execute

    my $dbh = $this->getConnection();
        
    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@values) || &queryFailed($query,@values);

# get the metadata

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;
        $contig->setContigID($contig_id);

        my $gap4name = shift @attributes;
        $contig->setGap4Name($gap4name);

        my $length = shift @attributes;
        $contig->setConsensusLength($length);

        my $ncntgs= shift @attributes;
        $contig->setNumberOfParentContigs($ncntgs);

        my $nreads = shift @attributes;
        $contig->setNumberOfReads($nreads);

        my $newreads = shift @attributes;
        $contig->setNumberOfNewReads($newreads);

        my $cover = shift @attributes;
        $contig->setAverageCover($cover);

        my $created = shift @attributes;
        $contig->setCreated($created);

        my $updated = shift @attributes;
        $contig->setUpdated($updated);

        my $project = shift @attributes;
        $contig->setProject($project);

        my $checksum = shift @attributes;
        $contig->setCheckSum($checksum);

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return undef unless defined($contig);

# in frugal mode, read sequence will be delayed loaded when required
# otherwise, read sequence  (base quality) will be loaded here in bulk
# NOTE: read tags are not delayed-loaded, so if you set the noreadtags
# flag, you will not get the tags by default but will have to explicitly
# load read tags afterwards (allows tag selection); conversely, contig 
# tags are delayed-loaded

    my $frugal = $options{frugal}; # if defined > 0 used as threshold

    $frugal = 500 unless defined($frugal); # default

    $contig->setFrugal($frugal) if ($frugal && $contig->getNumberOfReads()>=$frugal);

    return $contig if ($options{metaDataOnly} || $options{metadataonly});

# get the reads for this contig with their DNA sequences and tags

    my $noreadtags = $options{notags} || $options{noreadtags} || 0;

    $this->getReadsForContig($contig,notags=>$noreadtags,
                                     nosequence=>$frugal,
                                     caller=>'ADBContig');
#    $contig->getReads(1 ,notags=>$noreadtags,
#                         nosequence=>$frugal,
#                         caller=>'ADBContig');

# get read-to-contig mappings (and implicit segments)

    $this->getReadMappingsForContig($contig);

# get contig-to-contig mappings (and implicit segments)

    $this->getContigMappingsForContig($contig);

# get contig tags

    my $nocontigtags = $options{notags} || $options{nocontigtags} || 0;

    $this->getTagsForContig($contig) unless $nocontigtags;

# for consensus sequence we use lazy instantiation in the Contig class

    return $contig if $contig->isValid(noreadsequencetest=>$frugal); # for export

# store the query and the contig status

    $this->logQuery('getContig',$query,@values) unless $options{report};

    my $logger = $this->verifyLogger("getContig :");
    $logger->debug("invalid contig returned",emphasis=>1);
    $logger->debug($contig->{status});

    return undef;
}

sub getCachedContig {
    my $this = shift;
    my %options = @_;

    $this->{ContigCache} = {} unless defined $this->{ContigCache};
    my $cache = $this->{ContigCache};

    delete $options{cached}; # to prevent looping

    my $contig_id = $options{contig_id} || 0; # if undefined, returns undef

print STDOUT "getting cached contig $contig_id\n";
    return ( $cache->{$contig_id} ||= $this->getContig(%options) );
}

sub getSequenceAndBaseQualityForContig {
# load DNA data given the contig ID
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig = shift;

    &verifyParameter($contig,"getSequenceAndBaseQualityForContig");

    my $log = $this->verifyLogger("getSequenceAndBaseQualityForContig (ID)");

    my $cid = $contig->getContigID() || return 0;

    my $dbh = $this->getConnection() || return 0;

    my ($sequence,$quality) = &getSequenceAndBaseQualityForContigID($dbh,$cid,$log);

    $contig->setSequence($sequence);    # a string

    $contig->setBaseQuality($quality);  # reference to an array of integers

    return 1;
}

sub getSequenceAndBaseQualityForContigID {
# returns DNA sequence (string) and quality (array) for the specified contig
    my $dbh = shift;
    my $cid = shift;
    my $log = shift;

    &verifyPrivate($dbh,"getSequenceAndBaseQualityForContigID");

    my $query = "select sequence,quality from CONSENSUS where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($cid) || &queryFailed($query,$cid);

    my ($sequence, $quality);

    if (my @ary = $sth->fetchrow_array()) {
	($sequence, $quality) = @ary;
    }

    $sth->finish();

    if (defined($sequence)) {
        $sequence = uncompress($sequence);
        unless ($sequence) {
            $log->error("uncompress FAILED for contig ID = $cid : "
                       ."undefined sequence");
        }
    }

    if (defined($quality)) {
	$quality = uncompress($quality);
        if ($quality) {
	    my @qualarray = unpack("c*", $quality);
	    $quality = [@qualarray];
	}
        else {
# the decompression failed, probably due to a bug in the Perl Z-lib module
            my $length = 0;
            $length = length($sequence) if $sequence;
            $log->error("uncompress FAILED for contig ID = $cid : "
                       ."undefined quality (sequence length $length)");
# try to recover by faking an array of low quality data
            my @qualarray;
            while ($length--) {
                push @qualarray,4; 
            }
	    $quality = [@qualarray];
        }
    }

#    $sequence =~ s/\*/N/g if $sequence; # temporary fix 

    return ($sequence, $quality);
}

sub getParentContigsForContig {
# adds the parent contig instances, if any, to the input Contig 
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig = shift;
    my %options = @_; # usereads=>  nocache=>  

    &verifyParameter($contig,"getParentContigsForContig");

    return 1 if $contig->hasParentContigs(); # already done

# options : default the search for parents uses, in this order, possibly
#           existing contig to contig mappings, a possibly existing 
#           contig_id, or read IDs or readnames of reads or mappings
#           The 'usereads' options forces use of read items, ignoring 
#           posible other info; default the parents are searched in the
#           current generation of contigs (which is cached on first use); 
#           the 'nocache' option uses a different method based on the age/
#           inheritance tree and allows finding parents from scratch any
#           where in the tree (for test purposes, using contig_id info).

    my $usereads = $options{usereads};
    my $nocache  = $options{nocache};
    $usereads = 1 if $nocache;

    my @parentids;
# first try contig-to-contig mapping, if any 
    if (!$usereads && $contig->hasContigToContigMappings()) {
        my $contigmappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$contigmappings) {
            push @parentids, $mapping->getSequenceID();
        }
    }
# alternatively, get the IDs from the C2CMAPPING data given contig_id, if any
    elsif (!$usereads && (my $contigid = $contig->getContigID())) {
        my $dbh = $this->getConnection();
        my $parentids = &getParentIDsForContigID($dbh,$contigid);
        @parentids = @$parentids if $parentids;
    }
# else use the reads in the contig to find the parents from read comparison
    elsif ($nocache) {
#  find the parents from read comparison using age tree anywhere in tree
        my $parentids = $this->getParentIDsForContig($contig);
        @parentids = @$parentids if $parentids;
    }
#    elsif ($usereads) { # has to be defined explicitly ?
    else { # default 
#  find the parents in generation 0 from read comparison using cache
        my $parentids = $this->getParentIDsForReadsInContig($contig);
	unless (defined($parentids)) {
            my $logger = $this->verifyLogger('getParentContigsForContig');
            $logger->error("unexpected : missing sequence data for "
			   . $contig->getContigName());
            next;
	}
        @parentids = @$parentids if @$parentids;        
    }

# build the Contig instances (metadata only) and add to the input Contig object

    foreach my $parentid (@parentids) {
        my $parent = $this->getContig(ID=>$parentid, metaDataOnly=>1);
        $contig->addParentContig($parent) if $parent;
    }

    return $contig->hasParentContigs();
}

sub getChildContigsForContig {
# adds the Child Contig instances, if any, to the input Contig 
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig = shift;

    &verifyParameter($contig,"getChildContigsForContig");

    return if $contig->hasChildContigs(); # already done

# get the IDs from the database given contig_id

    my $contig_id = $contig->getContigID();

    return unless defined($contig_id);

    my $dbh = $this->getConnection();

    my $childids = &getChildIDsForContigID($dbh,$contig_id,notnull=>1);

# build the Contig instances (metadata only) and add to the input Contig object

    foreach my $child_id (@$childids) {
        my $child = $this->getContig(ID=>$child_id, metaDataOnly=>1,@_); # pass on possible options
        $contig->addChildContig($child) if $child;
    }

    return $contig->hasChildContigs();
}

#------------------------------------------------------------------------------
# methods for importing CONTIGs or CONTIG attributes into the database
#------------------------------------------------------------------------------

sub importContig {
    my $this = shift;
    my $contig = shift;  # Contig instance
    my $project = shift; # Project instance or '0' or undef
    my %options = @_;
}

sub putContig {
# enter a contig into the database
    my $this = shift;
    my $contig = shift;  # Contig instance
    my $project = shift; # Project instance or '0' or undef
    my %options = @_;

    &verifyParameter($contig,"putContig");

    &verifyParameter($project,"putContig",'Project',null=>1);

    my $log = $this->verifyLogger('putContig');

# optional input parameters: 
# setprojectby        for choice of method used for project inheritance
# lockcheck 0/1       for choice of project used for project inheritance
# inheritTags=>0/1/2  for generation depth of tag inheritance from parents
# noload=>0/1         for testmode (everything except write to database)
# acceptversionzero   when identifying read sequence id without sequence dat
# findparentcontigs   if no parent contigs specified, find them

    my $setprojectby = $options{setprojectby} || 'contiglength'; # 'none'
    if ($setprojectby eq 'project' && !$project) {
        return (0,"Missing Project instance as parameter when expected");
    }
    elsif ($setprojectby eq 'none' && $project) {
        return (0,"Incompatible parameters: Project instance specified "
                 ."when none expected");
    }

    my $inheritTags  = $options{inheritTags};
    $inheritTags = 2 unless defined($inheritTags);
    my $doload  = $options{noload} ? 0 : 1; # default 1

# do the statistics on this contig, allow zeropoint correction
# the getStatistics method also checks and orders the mappings 

    $contig->getStatistics(2);

    my $contigname = $contig->getGap4Name();

# test the Contig reads and mappings for completeness (using readname)

    unless ($contig->isValid(forimport => 1)) {
	my $diagnosis = $contig->{status} || '';
        return 0,"Contig $contigname failed completeness test : $diagnosis";
    }

# get readIDs/seqIDs for reads & mappings, load new sequence for edited reads

    my $avz = $options{acceptversionzero}; 
    my ($status,$errmsg) = $this->getSequenceIDsForContig($contig, 
				       acceptversionzero=>$avz);
    return 0, $errmsg unless ($status || !$doload); # exit on error

    my $message = $status ? '' : $errmsg; # report in 'noload' mode

# test if the contig has been loaded before using the sequence checksum

    my $checksum = $contig->getCheckSum(refresh=>1);

# try the sequence ID hash (returns the last entered matching contig, if any)

    if (my $previous = $this->getContig( withChecksum => $checksum,
                                         metaDataOnly => 1 ) ) {

# test if the previous contig is valid; if not, send a warning to the administrator
        
        unless ($previous->isValid(metadata => 1)) {
            my $status = $previous->getStatus(); # get details
            $this->logMessage('ejz','putContig',$status);
            $log->error($status,prefix=>0);
# optionally abort here ?
        }

        $message = "Contig $contigname matches checksum for contig "
                 .  $previous->getContigName()." ";

# test the generation

        unless ($previous->isCurrent()) {
            $message .= "in an older generation; ";
            $previous = 0; # reject the match
	}

        if ($previous && $contig->isEqual($previous)) {
# add the contig ID to the contig

            $message = "Contig $contigname is identical to contig "
                     .  $previous->getContigName() . " (project:"
		     .  $previous->getProject() . ")";
 
# (re-)assign the contig to project, if a project is explicitly defined

            if ($doload && $project && $setprojectby eq 'project') {
                my ($status,$msg) = $this->assignContigToProject($previous,$project,%options);
                if ($status && $msg !~ /no\s+change/i) {
                    $message .= "; re-assigned to project ".$project->getProjectName();
		}
                $message .= "; failed to assign contig to project: ".$msg unless $status;
            }

# import tags for this contig 

            $contig->setContigID($previous->getContigID());

            if ($doload && $contig->hasTags()) {
                my $newtags = $this->putTagsForContig($contig,synchronise=>0); # synchronise option not yet active
                $message .= "; $newtags new contig tags loaded" if $newtags;
            }

# input ordering info to be processed outside; for this we register previous as parent

            $contig->addParentContig($previous);

            return $previous->getContigID(),$message;
        }
        elsif ($previous) {
            $message .= "but is not identical; ";
	}
    }

# okay, the contig is new; find out if it is connected to existing contigs
# search based on the read_ids (not seq_id) in (initial) current contigs  

    $message .= "$contigname is new ";
    if ($this->getParentContigsForContig($contig,usereads=>1)) {
        my @parentids = $contig->getParentContigIDs();
        $message .= "and has parent(s) : @parentids ";
        if ($options{prohibitparent}) {
            return 0,"$message  ('prohibitparent' option active)";
        }
# set-up the contig-to-contig mappings between the new contig and its parents
        my $msg = $contig->linkToParents();
        $message .= "; ".$msg if $msg;
    }
    else {
        $message .= "and has no parents";
    }

# determine the project to which the contig is to be assigned project is 
# either the assigned project, or the backup; if backup, determine inherited project

    unless ($setprojectby eq 'project' || $setprojectby eq 'none') {

        $message .= "; contig is assigned to ";

        my $inheritedProject = $contig->inheritProject(measure=>$setprojectby);

        if ($inheritedProject && ref($inheritedProject) eq 'Project') {
            $project = $inheritedProject; # override default
            $message .= "inherited project " . $project->getProjectName();
        }
        elsif ($project) {
            $message .= "default project " . $project->getProjectName();            
        }
        else {
            $message .= "'bin' project (ID=0)"; # should not occur ...
        }
    }

    $log->info("contighasparents : ".$contig->hasParentContigs() );

    if ($contig->hasParentContigs()) {

        if (!$contig->hasContigToContigMappings()) {
# normally there should be at least one contig-contig mapping
	    $message .= "; contig ". $contig->getContigName. " has parents"
	              . " but no valid contig-to-contig mappings";
	}
	else {
# inherit (selected) tags (either specified or use defaults)
            my %tagscreenoptions;
            foreach my $key ('annotation','finishing','markftags') {
                $tagscreenoptions{$key} = $options{$key} if defined $options{$key};
	    }
            $contig->inheritTags(%tagscreenoptions);
	}
    }
    else {
# the contig has no precursor, is completely new
        $message .= "; assigned to project 0 " unless $project;
    }

    return 0, $message unless $doload; # (NO-LOAD option active)

# now load the contig into the database

    my $dbh = $this->getConnection();

    my $user_id = $this->getArcturusUser();

    my $problems_project_id = $this->getProblemsProjectID($dbh);

    $dbh->{RaiseError} = 1;

    my $contigid = 0;

    eval {
	$dbh->begin_work;

	$contigid = &putMetaDataForContig($dbh,$contig,$checksum,$user_id,$problems_project_id);

	$this->{lastinsertedcontigid} = $contigid;

	return 0, "Failed to insert metadata for $contigname" unless $contigid;

	$contig->setContigID($contigid);

# then load the overall mappings (and put the mapping ID's in the instances)

	die "Failed to insert read-to-contig mappings for $contigname"
	    unless &putMappingsForContig($dbh,$contig,$log,type=>'read');

# the CONTIG2CONTIG mappings

	die "Failed to insert contig-to-contig mappings for $contigname"
	    unless &putMappingsForContig($dbh,$contig,$log,type=>'contig');

# and contig tags?

	my %ctoptions = (notestexisting => 1); # it's a new contig
# TODO ? add tagtype selection ? register number opf tags added in Project object
	die "Failed to insert tags for $contigname"
	    unless $this->putTagsForContig($contig,%ctoptions);

# update the age counter in C2CMAPPING table (at very end of this insert)

	$this->buildHistoryTreeForContig($contigid);

# and assign the contig to the specified project (if possible)

	$message .= "; ".$this->allocateContigToProject($contig,$project) if $project;

	$dbh->commit;
    };

    if ($@) {
	$message = "Failed to store contig in database: " . $@;

	eval {
	    $dbh->rollback;
	};
	if ($@) {
	    $message .= "; ***** ROLLBACK FAILED: " . $@ . " *****";
	}
    }

    $dbh->{RaiseError} = 0;

    return $contigid, $message;
}

sub getProblemsProjectID {
    my $this = shift;

    return $this->{'PROBLEMS_PROJECT_ID'} if defined($this->{'PROBLEMS_PROJECT_ID'});

    my $dbh = shift;

    my $query = "select project_id from PROJECT where name = ?";

    my $sth = $dbh->prepare($query);

    $sth->execute('PROBLEMS');

    my ($project_id) = $sth->fetchrow_array();

    $sth->finish();

    die "Cannot determine project ID for PROBLEMS" unless defined($project_id);

    $this->{'PROBLEMS_PROJECT_ID'} = $project_id;

    return $project_id;
}

# ---------- (private) helper methods with putContig -----------

sub getSequenceIDsForContig {
# get seqIDs fo Reads and Mappings; load new sequence for edited reads
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'getSequenceIDsForContig');
 
    my $reads = $contig->getReads();
    unless ($reads && @$reads) {
        return 0, "missing reads for contig ".$contig->getContigName();
    }

# if no sequence hashes are available in Read the avz flag forces version 0

    my $avz = $options{acceptversionzero}; 
    unless ($this->getSequenceIDsForReads($reads,acceptversionzero=>$avz)) {
        return 0, "Missing sequence IDs for reads of contig "
                .  $contig->getContigName();
    }

# get the sequenceIDs (from Read instances); also build the readnames array 

    my %seqids;
#    my $missing = 0;
    foreach my $read (@$reads) {
        my $seqid = $read->getSequenceID();
        my $readname = $read->getReadName();
# extra check on read sequence presence, should not occur, just to be sure
        return 0, "undefined sequence ID for read $readname" unless $seqid;
#print STDOUT "seqids : $readname, $seqid \n";
        $seqids{$readname} = $seqid;
    }

# and put the sequence IDs into the Mapping instances

    my $mappings = $contig->getMappings();
    foreach my $mapping (@$mappings) {
        my $readname = $mapping->getMappingName();
#print STDOUT "seqids recall $readname : $seqids{$readname} \n";
        $mapping->setSequenceID($seqids{$readname});
    }

    return 1,scalar(@$reads)." processed";
}

sub allocateContigToProject {
# should be used privately
    my $this = shift;
    my $contig  = shift || return undef;
    my $project = shift;

# verify parameters

    &verifyParameter($contig ,'allocateContigToProject');
    &verifyParameter($project,'allocateContigToProject','Project') if $project;

# if no project defined, instantiate the BIN project as a fallback position

    my $default;
    unless ($project) {
        my ($projects,$dummy) = $this->getProject(projectname=>'BIN');
# test uniqueness?
        $project = $projects->[0];
        $default = $project;
    }

    my $cid = $contig->getContigID() || 0;

    my $report = "contig $cid ";

    return "$report could not be allocated to any project "
         . "(undefined destination project)" unless $project;

# get an inventory of the projects of the contigs parents (if any)

    my @projectsoforigin;
    my $parentcontigs = $contig->getParentContigs();
    my %parentcontigcount;
    foreach my $parent (@$parentcontigs) {
        my $parentproject = $parent->getProject(instance=>1);
        unless ($parentcontigcount{$parentproject}) {
            push @projectsoforigin, $parentproject; # only accept once
            $parentcontigcount{$parentproject} = [];
	}
        my $parentcontiglist = $parentcontigcount{$parentproject};
        push @$parentcontiglist, $parent->getContigID();
    }

#    action depends on nr of projects of origin (p-o-o)
# 1) none or one p-o-o and same as input project: just (try to) assign
# 2) one p-o-o  but different from input project: (try to) assign to original
#    & submit a request for transfer to project, with message to project owners
#    (! in case of failure: fall back on case 3)
#    note: this situation should not occur in standard finishing or asssembly mode
# 3) several p-o-o:(try to) assign to input project & message to project owners
#    & (optionally ?) sub mit request to return to inherited project
#    note: this situation should not occur in finishing mode, but may occur in 
#          assembly mode

    my $projectname = $project->getProjectName();

    my $inheritedproject = $contig->getProject(instance=>1);

    $inheritedproject = $contig->inheritProject() unless $inheritedproject;

# if still no inherited project, look at projects of origin

    unless ($inheritedproject || scalar(@projectsoforigin) != 1) {
        $inheritedproject = $projectsoforigin[0];
    }

    my $logger = $this->verifyLogger('allocateContigToProject');
    $logger->fine("Allocating (trying to) contig $cid to project $projectname; ");
    if ($inheritedproject) {
        $logger->fine("inherited project : " . $inheritedproject->getProjectName());
    }

# if there's only one p-o-o, compare with the inherited project

    if (scalar(@projectsoforigin) == 1 && $inheritedproject
        && $project->getOwner()        && $inheritedproject->getOwner() 
        && !$inheritedproject->isEqual($project)) {
# case 2
        my $inheritedname = $inheritedproject->getProjectName();
        my ($success,$msg) = $this->assignContigToProject($contig,$inheritedproject,force=>1);
        if ($success) {
            $report .= "has been put in project $inheritedname";
            my $message = "contig $cid in project $inheritedname has been identified "
                        . "as belonging in project $projectname\na transfer request "
	                . "has been submitted and is awaiting approval"; 
            $this->logMessage($inheritedproject->getOwner(),$inheritedname,$message);
# submit a contig transfer request (on behalf of project owner)
            my $rid = $this->putContigTransferRequest($cid, $project->getProjectID(),
                                                            $project->getOwner() );
            $report .= "; a request to transfer $cid to project $projectname ";
            $report .= "has been submitted" if $rid;
            $report .= "failed" unless $rid;
            return $report;
	}
        $report .= "could not be assigned to project $inheritedname ($msg) ";
        undef $inheritedproject;
    }

# case 1 & case 3 : assign the contig to $project

    my ($success,$msg) = $this->assignContigToProject($contig,$project,force=>1);

    if ($success) {
        $report .= "has been put in project $projectname";
        foreach my $projectoforigin (@projectsoforigin) {
            next unless $projectoforigin->getOwner();
            next if $projectoforigin->isEqual($project);
            my $parentcontigs = $parentcontigcount{$projectoforigin};
            my $text = join ", " , @$parentcontigs;
	    my $originname = $projectoforigin->getProjectName();
            my $message = "contigs $text from project $originname were (possibly partly) "
 		        . "merged into contig $cid in $projectname";
            $this->logMessage($projectoforigin->getOwner(),$originname,$message);
	}
    }
    else {
        $report .= " could not be assigned to project " . $project->getProjectName() ." ($msg)";                
# try the backup position (i.e. the BIN or the inherited project; undef defaults to BIN)
        if ($inheritedproject && $project->isEqual($inheritedproject)) {
            undef $inheritedproject;
        }
# try with the deault unless already done
        $report .= "; ".$this->allocateContigToProject($contig,$inheritedproject) unless $default;
# here a test on the existence of the user, just in case
        unless ($inheritedproject || defined($this->userCanMoveAnyContig())) {
            $report .= "; user has no privilege";
	}
    }
    return $report;
}

sub putMetaDataForContig {
# private method only
    my $dbh = shift; # database handle
    my $contig = shift; # Contig instance
    my $readhash = shift;
    my $userid = shift;
    my $default_project_id = shift;

    &verifyPrivate($dbh,"informUsersOfChange");

    my $query = "insert into CONTIG "
              . "(gap4name,length,ncntgs,nreads,newreads,cover,userid"
              . ",origin,created,readnamehash,project_id) "
              . "VALUES (?,?,?,?,?,?,?,?,now(),?,?)";

    my $sth = $dbh->prepare_cached($query);

    my @data = ($contig->getGap4Name(),
                $contig->getConsensusLength() || 0,
                $contig->getNumberOfParentContigs(),
                $contig->getNumberOfReads(),
                $contig->getNumberOfNewReads(),
                $contig->getAverageCover(),
                $userid,
                $contig->getOrigin(),
                $readhash,
		$default_project_id);

    my $rc = $sth->execute(@data) || &queryFailed($query,@data); 

    $sth->finish();

    return 0 unless ($rc == 1);
    
    return $dbh->{'mysql_insertid'}; # the contig_id
}

#----------------------------------------

sub deleteContig {
# remove data for a given contig_id from all tables
# this function requires DBA privilege
    my $this = shift;
    my $identifier = shift;
    my %options = @_; # treatassinglereadparent=>, forcedelete=>
#                       confirm=>, cleanup=>

    $identifier = $this->{lastinsertedcontigid} unless $identifier;

    return 0,"Missing contig ID" unless defined($identifier);

# test privilege of user
  
    my $user = $this->getArcturusUser();
    unless ($this->userCanGrantPrivilege($user)) {
	return 0,"user $user has no privilege for this operation";
    }

# collect some data for the contig to be deleted

    my $query = "select contig_id,gap4name,nreads,ncntgs,created from CONTIG";
    $query   .= " where gap4name  = ?" if ($identifier =~ /\D/);
    $query   .= " where contig_id = ?" if ($identifier !~ /\D/);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $row = $sth->execute($identifier) || &queryFailed($query,$identifier);

    unless ($row && $row > 0) { 

        $sth->finish();

        return 0,"Unknown contig identifier $identifier";
    }

# if more than one row was found, the contig may be a parent; test below

    my ($cid,$gap4name,$nreads,$ncntgs,$created) = $sth->fetchrow_array();

    $sth->finish();

    my $description = "$cid $gap4name  r:$nreads c:$ncntgs  $created ";

# safeguard: contig may not be among the parents (careful with override!)

    my $deletetarget = "contig_id";
    unless ($nreads == 1 && $options{treatassinglereadparent}) {
# test if this contig IS NOT a parent of another contig; if so, never delete 
# only single-read parent contigs can be exempted from this protection
        my $pquery = "select parent_id from C2CMAPPING where parent_id = $cid";

        my $isparent = $dbh->do($pquery) || &queryFailed($pquery);

        if (!$isparent || $isparent > 0) {
# this also exits on failed query as safeguard
            return 0, "Contig $identifier is, or may be, a parent "
                    . "and can't be deleted";
	}
    }
    else {
# test if this single-read contig itself HAS NO parent
        my $pquery = "select parent_id from C2CMAPPING where contig_id = $cid";
        my $hasparent = $dbh->do($pquery) || &queryFailed($pquery);
        if (!$hasparent || $hasparent > 0) { # exit, unless forcedelete
            return 0, "Single-read contig $identifier has, or may have, a parent "
                    . "and can't be deleted" unless $options{forcedelete};
	}
        $deletetarget = "parent_id";
    }

# here we finally test for ambiguity not found by parent test

    return 0,"Ambiguous contig $description ($row)" if ($row > 1);

# safeguard: contig may not belong to a project and have checked 'out' status

# the next line deletes the contig from a project (or not)

    my $confirm = $options{confirm};

# assign the contig to the PROBLEMS project before actual removal (to test privileges)

    my $problem = $this->getCachedProject(projectname=>'PROBLEMS');
    $problem = $this->getCachedProject(projectname=>'BIN') unless $problem; # fall back
    return (0,"Contig $identifier cannot be deleted: no PROBLEM or BIN project") unless $problem;  
    my $pid = $problem->getProjectID();

# for some reason I have to call this private function on the fully specified
# class; importing unlinkContigID using Exporter in ADBProject doesn't work as
# expected ...

    my ($status,$message) = ArcturusDatabase::ADBProject::unlinkContigID($dbh,$cid,$pid,$confirm);

    return (0,"Contig $identifier cannot be deleted: $message") unless $status;

    return (1,"Contig $description can be deleted") unless $confirm; # preview
    
# proceed only if contig has been unlinked; now delete from the primary tables

    my $report = '';
    my $success = 1;
    foreach my $table ('C2CMAPPING','CONTIG') {
        my $query = "delete from $table where $deletetarget = $cid";         
        $deletetarget = "contig_id"; # replace possible initial target parent_id
        my $deleted = $dbh->do($query) || &queryFailed($query);
        if (!$deleted && $table eq 'CONTIG') { # query failed
            $success = 0; last;
	}
        if ($deleted && ($deleted+0)) { # deleted can be 0E0
            $report .= ($deleted+0). " delete(s) done from $table\n";
	}
        else {
            $report .= " No deletes done from $table for $deletetarget = $cid\n";
	}
    }

# remove the redundent entries in SEGMENT and C2CSEGMENT (MyISAM tables)

    return ($success,$report) unless $options{cleanup};

# cleanup the segment table; can be slow for large tables !

    $report .= &cleanupSegmentTables($dbh,0);

    return ($success,$report);
}

#---------------------------------------------------------------------------------
# methods dealing with Mappings
#---------------------------------------------------------------------------------

sub getReadMappingsForContig {
# adds an array of read-to-contig MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;

    &verifyParameter($contig,"getReadMappingsForContig");

    return if $contig->hasMappings(); # already has its mappings

    my $mquery = "select readname,SEQ2READ.seq_id,mapping_id,".
                 "       cstart,cfinish,direction" .
                 "  from MAPPING, SEQ2READ, READINFO" .
                 " where contig_id = ?" .
                 "   and MAPPING.seq_id = SEQ2READ.seq_id" .
                 "   and SEQ2READ.read_id = READINFO.read_id" .
                 " order by cstart";

    my $squery = "select SEGMENT.mapping_id,SEGMENT.cstart,"
               . "       rstart,length"
               . "  from MAPPING join SEGMENT using (mapping_id)"
               . " where MAPPING.contig_id = ?"
               . " order by mapping_id,rstart";

    my $dbh = $this->getConnection();

# first pull out the mapping IDs

    my $sth = $dbh->prepare_cached($mquery);

    my $cid = $contig->getContigID();

    $sth->execute($cid) || &queryFailed($mquery,$cid);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    while(my ($nm, $sid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# intialise and add readname and sequence ID
        my $mapping = new Mapping($nm);
        $mapping->setSequenceID($sid);
        $mapping->setAlignmentDirection($dir);
        $mapping->setHostSequenceID($cid);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# ? add remainder of data (cstart, cfinish) ?
    }

    $sth->finish();

# second, pull out the segments

    $sth = $dbh->prepare($squery);

    $sth->execute($cid) || &queryFailed($squery,$cid);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rpstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rpstart, $length);
        }
        else {
# what if not? (should not occur at all)
            my $log = $this->verifyLogger("getReadMappingsForContig");
            $log->severe("Missing Mapping instance for ID $mappingid");
        }
    }

    $sth->finish();

    $contig->addMapping([@mappings]);
}

sub getContigMappingsForContig {
# adds an array of contig-to-contig MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,"getContigMappingsForContig");
                
    return if $contig->hasContigToContigMappings(); # already done

    return unless $contig->getContigID(); # must have contig ID defined and > 0

    my $log = $this->verifyLogger("getContigMappingsForContig");

    my $mquery = "select age,parent_id,mapping_id," .
                 "       cstart,cfinish,direction" .
                 "  from C2CMAPPING" .
                 " where contig_id = ?" .
                 " order by ".($options{orderbyparent} ? "parent_id" : "cstart");
 
    my $squery = "select C2CSEGMENT.mapping_id,C2CSEGMENT.cstart," .
                 "       C2CSEGMENT.pstart,length" .
                 "  from C2CMAPPING join C2CSEGMENT using (mapping_id)".
                 " where C2CMAPPING.contig_id = ?";

    my $dbh = $this->getConnection();

# 1) pull out the mapping_ids

    my $sth = $dbh->prepare_cached($mquery);

    my $cid = $contig->getContigID();

    $sth->execute($cid) || &queryFailed($mquery,$cid);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    my $generation;
    while(my ($age,$pid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# protect against empty contig-to-contig links 
        $dir = 'Forward' unless defined($dir);
# intialise and add parent name and parent ID as sequence ID
        my $mapping = new Mapping();
#        $mapping->setMappingName(sprintf("contig%08d",$pid)); # to the parent
        $mapping->setMappingName("contig_".sprintf("%08d",$pid)); # the parent
        $mapping->setSequenceID($pid);
        $mapping->setAlignmentDirection($dir);
        $mapping->setMappingID($mid);
        $mapping->setHostSequenceID($cid);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# add remainder of data (cstart, cfinish) ?
# do an age consistence check for this mapping
        $generation = $age unless defined ($generation);
        next if ($generation == $age);
        $log->severe("Inconsistent generation in links for contig $cid");
    }
    $sth->finish();

# 2) pull out the segments

    $sth = $dbh->prepare($squery);

    $sth->execute($cid) || &queryFailed($squery,$cid);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rpstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rpstart, $length);
        }
        else {
# what if not? (should not occur at all)
            $log->severe("Missing Mapping instance for ID $mappingid");
        }
    }

    $sth->finish();

    $contig->addContigToContigMapping([@mappings]);

    return $generation;
}

sub putMappingsForContig {
# private method, write mapping contents to (C2C)MAPPING & (C2C)SEGMENT tables
    my $dbh = shift; # database handle
    my $contig = shift;
    my $log = shift;
    my %option = @_;

    &verifyPrivate($dbh,"putMappingsForContig");

# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# this method inserts mapping segments in blocks of 100
           
    $log->setPrefix("putMappingsForContig $option{type}");

# define the queries and the mapping source

    my $mquery; # for insert on the (C2C)MAPPING table 
    my $squery; # for insert on the (C2C)SEGMENT table
    my $mappings; # for the array of Mapping instances

    if ($option{type} eq "read") {
# for read-to-contig mappings
        $mappings = $contig->getMappings();
        return 0 unless $mappings; # MUST have read-to-contig mappings
        $mquery = "insert into MAPPING " .
                  "(contig_id,seq_id,cstart,cfinish,direction) ";
        $squery = "insert into SEGMENT " .
                  "(mapping_id,cstart,rstart,length) values ";
    }
    elsif ($option{type} eq "contig") {
# for contig-to-contig mappings
        $mappings = $contig->getContigToContigMappings();
        return 1 unless $mappings; # MAY have contig-to-contig mappings
        $mquery = "insert into C2CMAPPING " .
	          "(contig_id,parent_id,cstart,cfinish,direction) ";
        $squery = "insert into C2CSEGMENT " .
                  " (mapping_id,cstart,pstart,length) values ";
    }
    else {
        $option{type} = 'missing' unless $option{type};
        $log->severe("Missing or invalid 'type' parameter $option{type}");
        return 0; # or die ?
    }

    $mquery .= "values (?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($mquery);

    my $contigid = $contig->getContigID();

# 1) the overall mapping

    my $mapping;
    foreach $mapping (@$mappings) {

# protect against empty mappings (unless invoked via method 'markAsVirtualParent')

        next unless ($mapping->hasSegments() || $option{allowemptymapping});

        my ($cstart, $cfinish) = $mapping->getContigRange();

        my @data = ($contigid,
                    $mapping->getSequenceID(),
                    $cstart,
                    $cfinish,
                    $mapping->getAlignmentDirection());

        my $rc = $sth->execute(@data) || &queryFailed($mquery,@data);

        $mapping->setMappingID($dbh->{'mysql_insertid'}) if ($rc == 1);
    }
    $sth->finish();

# 2) the individual segments (in block mode)

    my $block = 100;
    my $success = 1;
    my $accumulated = 0;
    my $accumulatedQuery = $squery;
    foreach my $mapping (@$mappings) {
# test existence of segments
        next unless $mapping->hasSegments();
# test existence of mappingID
        my $mappingid = $mapping->getMappingID();
        if ($mappingid) {
            my $segments = $mapping->normaliseOnX(); # order contig range
#          my $segments = $mapping->getSegments();
            foreach my $segment (@$segments) {
#              my $length = $segment->normaliseOnX(); # order contig range
                my $length = $segment->getSegmentLength();
                my $cstart = $segment->getXstart();
                my $rstart = $segment->getYstart();
                $accumulatedQuery .= "," if $accumulated++;
                $accumulatedQuery .= "($mappingid,$cstart,$rstart,$length)";
# dump the accumulated query if a number of inserts has been reached
# $log->debug("Insert mapping block (mapping loop) $accumulated\n($block)");
                if ($accumulated >= $block) {
                    $sth = $dbh->prepare($accumulatedQuery); 
                    my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
                    $sth->finish();
                    $success = 0 unless $rc;
                    $accumulatedQuery = $squery;
                    $accumulated = 0;
		}
            }
        }
        else {
            $log->severe("Mapping ".$mapping->getMappingName().
		        " unexpectedly has no mapping_id");
            $success = 0;
        }
    }
# dump any remaining accumulated query after the last mapping has been processed
    if ($accumulated) {
# $log->debug("Insert mapping block (mapping loop) $accumulated\n($block)");
        $sth = $dbh->prepare($accumulatedQuery); 
        my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
        $sth->finish();
        $success = 0 unless $rc;
    }

# we now update the contig-to-contig mappings by adding the parent range
# this is kept separate from the basic inserts because this is derived data
# which may or may not be transparently defined, hence may be missing (undef)

    &updateMappingsForContig ($dbh,$mappings) if ($option{type} eq "contig");

    return $success;
}

sub addMappingsForContig {
# public interface for update of contig mappings
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,"addMappingsForContig");

    my $mappings = $contig->getContigToContigMappings();

    my $dbh = $this->getConnection();
    return &updateMappingsForContig($dbh,$mappings,$options{replace});
}

sub updateMappingsForContig {
# private, update the mapped contig range
    my $dbh = shift;
    my $mappings = shift || return;
    my $replace = shift;

    &verifyPrivate($dbh,"updateMappingsForContig");

# default query inserts when pstart or pfinish field undefined

    my $rquery = "update C2CMAPPING"
               . "   set pstart = ?, pfinish = ?"
	       . " where mapping_id = ?";
    $rquery   .= "   and (pstart is null or pfinish is null)" unless $replace;

    my $sth = $dbh->prepare_cached($rquery);

    my $report = '';
    foreach my $mapping (@$mappings) {
# test existence of segments
        next unless $mapping->hasSegments();
# test existence of mappingID
        if (my $mappingid = $mapping->getMappingID()) {
            my @data = $mapping->getMappedRange();
            next unless defined($data[0]);
            next unless defined($data[1]);
            push @data,$mappingid;
            my $rc = $sth->execute(@data) || &queryFailed($rquery,@data);
            $report .= "range inserted : @data\n" if ($rc && $rc == 1);
	}
    }

    $sth->finish();

    return $report;
}

sub getEndReadsForContigID {
# returns left-most and right-most read names
    my $this = shift;
    my $contig_id = shift;

    my $query = "select Rl.readname, Rr.readname"
              . "  from READINFO as Rl, READINFO as Rr,"
              . "       SEQ2READ as SRl, SEQ2READ as SRr,"
              . "       MAPPING as Ml, MAPPING as Mr,"
              . "       CONTIG"
              . " where Rl.read_id=SRl.read_id"
              . "   and Rr.read_id=SRr.read_id"
              . "   and Ml.seq_id=SRl.seq_id"
              . "   and Mr.seq_id=SRr.seq_id"
              . "   and Ml.contig_id=CONTIG.contig_id"
              . "   and Mr.contig_id=CONTIG.contig_id"
              . "   and Ml.cstart=1"
              . "   and Mr.cfinish=CONTIG.length"
              . "   and CONTIG.contig_id=?"
	      . " order by Ml.cfinish,Mr.cstart";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);
           
    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

# the most  left-hand read is the first name of the first row returned
# the most right-hand read is the  last name of the  last row returned

    my ($left,$right);
    while (my ($l,$r) = $sth->fetchrow_array()) {
        $left = $l unless defined($left);
        $right = $r;
    }

    $sth->finish();

    return $left,$right;  
}

sub getReadsInContigWindow {
# return a list of seq_ids of read straddling a contig position (interval) 
    my $this = shift;
    my ($contig,$cstart,$cfinal) = @_;

    my $query = "select seq_id from MAPPING"
              . " where contig_id = ?"
	      . "   and cfinish >= ?"  # cstart
	      . "   and  cstart <= ?"; # cfinish

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig,$cstart,$cfinal) || &queryFailed($query,@_);

    my @seqids;
    while (my ($seqid) = $sth->fetchrow_array()) {
	push @seqids,$seqid;
    }
    $sth->finish();

    return [@seqids];
}

#--------------------------------------------------------------------------

sub retireContig {
# remove a contig from the list of current contigs by linking it to contig 0
    my $this = shift;
    my $c_id = shift; # contig ID
    my %options = @_;

# is the contig a current contig?

    unless ($this->isCurrentContigID($c_id)) {
        return 0,"Contig $c_id is not in the current generation";
    }   

    my $log = $this->verifyLogger("retireContig");

# get the project ID and test if the user has access to the project

    my @lockinfo = $this->getLockedStatusForContigID($c_id);

# re organise: if locked level 2, always fail; if locked level 1, 
# only proceed if user == lockowner; if no lock, test user access to project

    my $user = $this->getArcturusUser();

    my $message = "Contig $c_id is in project $lockinfo[5]";

    if ($lockinfo[0] > 1) {
        return 0, $message." which can not be modified ($lockinfo[3])";
    }
    elsif ($lockinfo[0] && $user ne $lockinfo[1]) {
        return 0, $message." and locked by user $lockinfo[1]";
    }
    elsif (!$lockinfo[0]) {
        my $p_id = $lockinfo[6];
# test if the user has access to the project (either as owner or by privilege) 
        my $accessibleproject = $this->getAccessibleProjects(project=>$p_id);
# abort if the user has no access
        unless (@$accessibleproject == 1 && $accessibleproject->[0] == $p_id) {
            return 0, $message." to which $user has no access";
        }
    }

    return 0, $message." and can be retired" unless $options{confirm};

# add a link for this contig ID marking it as parent of contig 0
# this (virtual) link removes the contig from the current contig list
 
    unless (&markAsVirtualParent($this->getConnection(),$c_id,$log)) {
        return 0, "Failed to update database";
    }

    return 1, "OK";
}

sub markAsVirtualParent {
# enter a record in C2CMAPPING for parent_id pointing to contig_id = 0
# this virtual link removes the contig from the current contig list
    my $adb = shift;
    my $parent_id = shift || return 0;
    my $log = shift;

    return 0 unless $parent_id;

# create a dummy contig with contig ID 0

    my $contig = new Contig();

    $contig->setContigID(0);

# create a dummy C2CMAPPING for this contig

    my $c2cmap = new Mapping();

    $c2cmap->setSequenceID($parent_id);

    $contig->addContigToContigMapping($c2cmap);

# present for loading

    my %options = (type=>'contig',allowemptymapping=>1);

    return &putMappingsForContig($adb,$contig,$log,%options);
}

#-----------------------------------------------------------------------------
# housekeeping
#-----------------------------------------------------------------------------

sub cleanupMappings {
# public method (to be extended with other tests?)
    my $this = shift;
    my %options = @_; # preview; fullscan; confirm

    my $preview = $options{confirm} ? 0 : 1; # specify confirm explicitly

    my $fullscan = $options{fullscan} || 0;

    my $dba = $this->getConnection();

    my $report = &cleanupMappingTables($dba,$preview,$fullscan);

    $report .= &cleanupSegmentTables($dba,$preview) if $fullscan;

    return $report;
}

sub cleanupMappingTables {
# private method: remove redundent mapping references from MAPPING
# (re: housekeeping required after e.g. deleting contigs)
    my $dbh = shift;
    my $preview = shift;
    my $full = shift; # include testing parent IDs

    &verifyPrivate($dbh,"cleanupMappingTables");

    my $query;
    my $report = '';
    foreach my $table ('MAPPING','C2CMAPPING','CONSENSUS') {
        $query  = "select $table.contig_id" if $preview; 
        $query  = "delete $table" unless $preview;
        $query .= "  from $table left join CONTIG using (contig_id)"
	       .  " where $table.contig_id > 0"
	       .  "   and CONTIG.contig_id IS NULL";
        my $sth = $dbh->prepare_cached($query);
        my $rc = $sth->execute() || &queryFailed($query) && next;
        $sth->finish();
        $report .= sprintf ("%6d",($rc+0)) . " contig IDs ";
        $report .= "to be " if $preview;
        $report .= "have been " unless $preview;
        $report .= "removed from $table\n";
    }

    return $report unless $full;       

# also remove entries of C2CMAPPING with un matched parent IDs

    $query  = "select C2CMAPPING.parent_id" if $preview; 
    $query  = "delete C2CMAPPING" unless $preview;
    $query .= "  from C2CMAPPING left join CONTIG"
           .  "    on (C2CMAPPING.parent_id = CONTIG.contig_id)"
	   .  " where CONTIG.contig_id IS NULL";
    my $sth = $dbh->prepare_cached($query);
    my $rc = $sth->execute() || &queryFailed($query);
    $sth->finish();
    $report .= sprintf ("%6d",($rc+0)) . " parent IDs ";
    $report .= "to be " if $preview;
    $report .= "have been " unless $preview;
    $report .= "removed from C2CMAPPING\n";

    return $report;
}

sub cleanupSegmentTables {
# private method: remove redundent mapping references from (C2C)SEGMENT
# (re: housekeeping required after e.g. deleting contigs)
    my $dbh = shift;
    my $preview = shift;

    &verifyPrivate($dbh,"cleanupSegmentTables");

    my $query;
    my $report = '';
    foreach my $table ('','C2C') {
        next if (shift); # one extra parameter skips to C2C mappings
        $query  = "select ${table}SEGMENT.mapping_id" if $preview;
        $query  = "delete ${table}SEGMENT" unless $preview;
        $query .= "  from ${table}SEGMENT left join ${table}MAPPING"
                . " using (mapping_id)"
	       .  " where ${table}MAPPING.mapping_id IS NULL";
        my $sth = $dbh->prepare_cached($query);
        my $rc = $sth->execute() || &queryFailed($query) && next;
        $sth->finish();
        $report .= sprintf ("%6d",($rc+0)) . " mapping IDs ";
        $report .= "to be " if $preview;
        $report .= "have been " unless $preview;
        $report .= "removed from ${table}SEGMENT\n";
# long list option
    }

    return $report;
}

sub deleteContigToContigMapping {
# remove a specified C2C mapping
    my $dbh = shift;
# input: mapping ID, contig ID & parent ID, in that order

    &verifyPrivate($dbh,"deleteContigToContigMapping");

    my $delete = "delete from C2CMAPPING"
	       . " where mapping_id = ?"
               . "   and contig_id = ?"
	       . "   and parent_id = ?";

    my $sth = $dbh->prepare_cached($delete);

    my $row = $sth->execute(@_) || &queryFailed($delete,@_);

    $sth->finish();

    return ($row+0);
}

sub repairContigToContigMappings {
# replace contig to contig mappings which are different from those in database
    my $this = shift;
    my $contig = shift;
    my %options = @_; # nokeep update confirm

    &verifyParameter($contig,"repairContigToContigMappings");

# contig ID must be defined

    my $contig_id = $contig->getContigID();

    return 0,"Missing contig ID" unless $contig_id;

    my $log = $this->verifyLogger('repairContigToContigMappings');

# 1) retrieve the existing C2C mappings for the given contig_id:
#  - first copy the (new) mappings into a temporary buffer;
#  - reset the mapping array, then pull out the existing mappings

    my $newmappings = $contig->getContigToContigMappings() || [];

    $contig->addContigToContigMapping(0); # reset the $contig C2C buffer

# return 0,"Missing new contig-to-contig mappings" unless @$newmappings;

    my $age = $this->getContigMappingsForContig($contig,orderbyparent=>1);
   
# 2) compare the existing mappings (now in $contig) with the new ones
#    add the ones that have changed to the contig
#    remove the mappings that do not figure in the list of new mappings
#    remove the mappings that have not changed

    my $oldmappings = $contig->getContigToContigMappings() || [];

    $contig->addContigToContigMapping(0); # reset the $contig C2C buffer again

# build a hash keyed on parent ID to identify the mapping

    my $message = "There are ".scalar(@$oldmappings).
                  " mapping(s) in the database for contig $contig_id ";
    $message .= "to parents: " if scalar(@$oldmappings);

    my $inventory = {};
    foreach my $mapping (@$oldmappings) {
        my $parent_id = $mapping->getSequenceID();
        $inventory->{$parent_id} = $mapping;
        $message .= "$parent_id ";
    }
    $message .= "\n";

# compare each input new mapping with its existing counterpart; if a mapping
# is different, remove the existing one and add the new version to $contig

    $message .= "There are ".scalar(@$newmappings).
                " mapping(s) defined for contig $contig_id ";
    $message .= "to parents:  " if scalar(@$newmappings);

    my @deletemappings;
    my @deleteparentids;
    foreach my $mapping (@$newmappings) {
        my $parent_id = $mapping->getSequenceID();
        my $existingmapping = $inventory->{$parent_id};
        $message .= "$parent_id ";
        unless ($existingmapping) {
            $message .= "(new) ";
	    $contig->addContigToContigMapping($mapping);
            next;
        }
        push @deleteparentids,$parent_id; # collect mappings with a counterpart
#       delete $inventory->{$parent_id}; # not here, to trap duplicate mappings
        my ($isEqual,@dummy) = $mapping->isEqual($existingmapping);
        if ($isEqual) {
            $message .= "(unchanged) ";
            next;
        }
# the mapping has changed: add old one to delete list, the new one to contig
	$contig->addContigToContigMapping($mapping);
        push @deletemappings, $existingmapping;
        $message .= "(changed) ";
    }

# remove all mappings having a counterpart

    foreach my $parent_id (@deleteparentids) {
        delete $inventory->{$parent_id};
    }

# the keys left of %$inventory are existing mappings without
# new counterpart; they have to be deleted too

    foreach my $parent_id (keys %$inventory) {
        push @deletemappings, $inventory->{$parent_id};
    }

    my $dbh = $this->getConnection();

    $message .= "\n";
#   $log->debug("deletemappings  @deletemappings  $message");
    foreach my $existingmapping (@deletemappings) {
        next if $options{nodelete};
        my $parent_id = $existingmapping->getSequenceID();
        my $mapping_id = $existingmapping->getMappingID();
        $message .= "Existing mapping ";
        $message .= "to be deleted" if $options{nokeep};
        $message .= ": $contig_id - $parent_id ($mapping_id) ..";
        unless ($options{nokeep}) {
            $message .= ".. \n";
            next;
	}
        if (!$options{confirm}) {
            $message .= ".. (to be confirmed)\n";
        }
# and remove the existing mapping
        elsif (&deleteContigToContigMapping($dbh,$mapping_id,$contig_id,$parent_id)) {
            $message .= ".. DONE\n";
        }
        else {
            $message .= ".. FAILED\n";
	}
    }

    if ($options{cleanup}) {
# remove redundent segments form the C2CSEGMENT table
        $message .= &cleanupSegmentTables($dbh, ($options{confirm} ? 0 : 1) ,1);
    }
  
    my $nm = 0;
    if ($contig->hasContigToContigMappings()) {
        $nm = scalar(@{$contig->getContigToContigMappings()});
    }
    $message .= ($nm || "No")." new mappings to be loaded for contig $contig_id\n";

    if ($nm && $options{confirm}) {
        $message .= "Insert contig-to-contig mappings for $contig_id ..";
        my %insertoptions = (type=>'contig');
        $insertoptions{allowemptymapping} = 1 if $options{allowemptymapping};
        if (&putMappingsForContig($dbh,$contig,$log,%insertoptions)) {
            $message .= ".. DONE\n";
# update the age of the mapping, if > 0
            if ($age) {
                $message .= "Update generation age counter (to $age) ..";
                if (&updateMappingAge($dbh,$contig_id,$age)) {
                    $message .= ".. DONE\n";
		}
		else {
                    $message .= ".. FAILED\n";
		}
	    }
        }
        else {
            $message .= ".. FAILED\n";
            return 0,$message;
        }
    }

    return 1,$message;
}

#-----------------------------------------------------------------------------
# methods dealing with generations and age tree
#-----------------------------------------------------------------------------

sub getParentIDsForContig {
# returns a list contig IDs of parents for input Contig based on 
# its reads sequence IDs and the sequence-to-contig MAPPING data
# search from scratch for new contigs (no ID!) and existing contigs
# this method uses the age parameter in the C2CMAPPING table
    my $this = shift;
    my $contig = shift; # Contig Instance
    my %options = @_;   # for exclude list

    &verifyParameter($contig,"getParentIDsForContig");

#my $log = $this->verifyLogger('getParentIDsForContig');
#$log->debug("searching parents from scratch using age tree");

    return undef unless $contig->hasReads();

    my $reads = $contig->getReads();

# get the readIDs (or, alternatively sequenceIDs)

    my $useseqid = $options{useseqid};

    my @ids;
    foreach my $read (@$reads) {
        push @ids, $read->getSequenceID() if $useseqid;
        push @ids, $read->getReadID() unless $useseqid;
    }

# we find the parent contigs in two steps: first we collect all contigs
# in which the sequenceIDs are referenced; subsequently we eliminate
# from that list those contigs which do have a child IN THE LIST, i.e.
# select from the list those which are NOT parent of a child in the list.
# This strategy will deal with split parent contigs as well as "normal" 
# parents and does only rely on the fact that all contigIDs also occur
# as parentIDs except for those in the previous generation for $contig

# step 1: get all (potential) parents: find ancestors sharing same reads

    my $contigID = $contig->getContigID(); # may be defined or not

# do a blocked search (to deal with very large contigs)

    my $blocksize = 1000;

    my $dbh = $this->getConnection();

    my %contigids;
    while (my $block = scalar(@ids)) {

        $block = $blocksize if ($block > $blocksize);

        my @block = splice @ids, 0, $block;

        my $range = join ',',sort {$a <=> $b} @block;

        my $query;
	if (!$useseqid) {
# use read IDs (default)
            $query = "select distinct contig_id"
                   . "  from MAPPING join SEQ2READ using (seq_id)"
                   . " where read_id in ($range)";
	}
	else {
# this query takes into account that the seq_id for the same read can change  
            $query = "select distinct contig_id"
                   . "  from MAPPING,SEQ2READ as S1,SEQ2READ as S2"
                   . " where MAPPING.seq_id = S1.seq_id"
                   . "   and S1.read_id = S2.read_id"
                   . "   and S2.seq_id in ($range)";
	}

# add an exclusion of the contig itself (and younger) if its ID is defined

        $query .= "   and contig_id < $contigID" if $contigID;

# add an exclusion clause for any contigs listed with options

        if (my $excludelist = $options{exclude}) {
# the list should consist of comma-separated contig IDs
            $excludelist =~ s/^\s*|\s*$//g; # remove leading/trailing blanks
            if ($excludelist =~ /[^\,\d]/) { # other than comma and numbers
                my @exclude = split /\D+/,$excludelist;
                $excludelist = join ',',@exclude;
	    }
            $query .= " and contig_id not in ($excludelist)";
        
        }

        $query .= " order by contig_id";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($contig_id) = $sth->fetchrow_array()) {
            $contigids{$contig_id}++;
        }

        $sth->finish();
    }

    my @contigids = sort {$a <=> $b} keys %contigids;

# step 2 : remove from this list all parents which link to a (child) contig 
#          also in this list, and also contigs in older generations 

    my $ageoffset = 0; # reference age

    if (@contigids) {
       
        if ($contigID) {
            my $query = "select max(age) from C2CMAPPING where contig_id=?";
            my $sth = $dbh->prepare($query);
            my $rc = $sth->execute($contigID) || &queryFailed($query,$contigID);
            if (my $age = $sth->fetchrow_array()) {
                $ageoffset = $age;
            }
            $sth->finish();
	}

        my $join = join(',',@contigids);

        my $query = "select age,contig_id,parent_id from C2CMAPPING"
        	  . " where contig_id in ($join)";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($age,$contig_id,$parent_id) = $sth->fetchrow_array()) {
# the parent_id is removed because it is not the last in the chain
            delete $contigids{$parent_id};
            if ($age > 1 + $ageoffset  || $age < $ageoffset) {
                delete $contigids{$contig_id};
            }
        }

        $sth->finish();

        @contigids = sort {$a <=> $b} keys %contigids;
   }

# step 3 : check the remaining initial contigs by restoring 

# However, this list still may contain spurious parents due to 
# misassembled reads in early contigs which are picked up in the
# first step of the search; these are weeded out by selecting on
# the age: true parents have age 0 ("regular" parent) or 1 (split contigs)
# for new contigs; when testing on older generation contigs apply age offset 

    if (@contigids) {

        my $join = join(',',@contigids);

        my $query  = "select max(age)+1,parent_id as age from C2CMAPPING"
                   . " where parent_id in ($join)";
        $query    .= "   and contig_id != $contigID" if $contigID;
        $query    .= " group by parent_id";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($age,$parent_id) = $sth->fetchrow_array()) {
# the parent_id is removed because it is not the last in the chain
            if ($age > 1 + $ageoffset  || $age < $ageoffset) {
                delete $contigids{$parent_id};
            }
        }

        $sth->finish();

        @contigids = sort {$a <=> $b} keys %contigids;
    }

    return [@contigids];
}

sub getParentIDsForReadsInContig {
# returns a list of contig IDs in generation 0 identified by shared reads  
# the search can be done using read IDs, if the contig has Reads, or readnames,
# if the contig has either Reads or Mappings; generation 0 IS CACHED on first
# entry, so that new contigs presented one after another are linked to the
# same set of parent contigs
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,"getParentIDsForReadNames");

#my $log = $this->verifyLogger('getParentIDsForReadNames');
#$log->debug("searching parents from scratch in generation zero");

    my $dbh = $this->getConnection();

    my $usereadname = $options{readname}; # default use read id

    my $rids = []; # for either bread ID or readname

    my $reads = $contig->getReads() || [];

    foreach my $read (@$reads) {
        if ($usereadname) {
            next unless $read->getReadName();
            push @$rids,$read->getReadName();
        }
        else {
            next unless $read->getReadID();
            push @$rids,$read->getReadID();
        }
    }

    unless (@$rids) { # if no read identifiers available try the mappings
        $usereadname = 1;
        my $mappings = $contig->getMappings() || [];
        foreach my $mapping (@$mappings) {
            next unless $mapping->getMappingName();
            push @$rids,$mapping->getMappingName(); 
	}
    }

# test if info available is complete; else abort with error 

    return undef unless @$rids; # no info at all 
    unless (scalar(@$rids) == scalar(@$reads)) {
#        return undef unless $options{partialcover}; # accept partial info
        return undef if $options{complete}; # insist on complete info 
    } 

    my $parentids = $this->getCachedParentIDs();

    my $outputlist = []; # array of arrays

    return $outputlist unless ($parentids && @$parentids);

# the query is in blocks to accommodate large contigs

    my $contiglist = {}; # for intermediate results in short mode

    my $rblocksize = $options{blocksize} || 1000;

    while (my $rblock = scalar(@$rids)) {

        $rblock = $rblocksize if ($rblock > $rblocksize);

        my @rblock = splice @$rids, 0, $rblock;

        my $readjoin;
        $readjoin = join (',',@rblock) unless $usereadname;
        $readjoin = join ("','",@rblock)   if $usereadname;

        my @parentids = @$parentids;

        my $pblocksize = $options{blocksize} || 1000;

        while (my $pblock = scalar(@parentids)) {

            $pblock = $pblocksize if ($pblock > $pblocksize);

            my @pblock = splice @parentids, 0, $pblock;

            my $parentjoin = join (',',@pblock);
   

            my $query   = "select distinct MAPPING.contig_id";

            if ($usereadname) {
                my $readnamejoin = join ("','",@rblock);
                $query .= "  from READINFO,SEQ2READ,MAPPING"
                        . " where READINFO.read_id = SEQ2READ.read_id"
                        . "   and SEQ2READ.seq_id = MAPPING.seq_id"
                        . "   and READINFO.readname in ('${readjoin}')";
            }
            else {
                $query .= "  from SEQ2READ,MAPPING"
                       . " where SEQ2READ.seq_id = MAPPING.seq_id"
                       . "   and SEQ2READ.read_id  in (${readjoin})";
            }

            $query     .= "   and MAPPING.contig_id in (${parentjoin})"
                        . " order by contig_id";

            my $sth = $dbh->prepare($query);

            $sth->execute() || &queryFailed($query);
    
            while (my $aryref = $sth->fetchrow_arrayref()) {
                $contiglist->{$aryref->[0]}++;
            }

            $sth->finish();
        }
    }

    @$outputlist = sort {$a <=> $b} keys %$contiglist;

    return $outputlist;
}

sub getCachedParentIDs {
# caches the currentcontig IDs on first call; subsequently returns cached ids
    my $this = shift;

# return the cached contigids, if any defined (but may be empty)

    my $currentparentids = $this->{currentparents}; # an array ref

# on first call, cache the current generation of contigs as parents

    unless (defined($this->{currentparents})) {

        $this->{currentparents} = $this->getCurrentContigIDs(singleton=>1);

        $this->{currentparents} = 0 unless defined($this->{currentparents});

        $currentparentids = $this->{currentparents};
    }

    return 0 unless $currentparentids;

    my @currentparentids = @$currentparentids; # copy array

    return \@currentparentids;
}

sub getParentIDsForContigID {
# private,  returns a list of contig IDs of connected earlier contig(s)
# using the C2CMAPPING table; i.e for contigs already loaded
    my $dbh = shift;
    my $contig_id = shift;

    &verifyPrivate($dbh,"getParentIDsForContigID");

    my $query = "select distinct(parent_id) from C2CMAPPING"
	      . " where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

    return [@contigids];
}

sub getChildIDsForContigID {
# private,  returns a list of contig IDs of connected later contig(s)
# using the C2CMAPPING table; i.e for contigs already loaded
    my $dbh = shift;
    my $contig_id = shift;
    my %options = @_;

    &verifyPrivate($dbh,"getChildIDsForContigID");

    my $query = "select distinct(contig_id) from C2CMAPPING"
	      . " where parent_id = ?";
    $query   .= "   and contig_id > 0" if $options{notnull};
    
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

    return [@contigids];
}

sub getSingleReadParentIDs {
# get contigs which are parents and have one read only, i.e. a read which
# is assembled in a larger contig of the next generation
    my $this = shift;
    my %options = @_;

    my $linktype = $options{linktype} || 0;

# linktype = 0 for all parents (default)
#          = 1 for parents with links listed in C2CMAPPING
#          = 2 for parents without such links
# options : parent=>ID contig=>ID mincid=>ID maxcid=>ID
#           contigname=>gap4N   parentname=>gap4N 
#          (contig)project=>ID  parentproject=>ID

    my @data;
    my @constraint;
    my $constraints;

# contig : contig ID of (child) for which parent contigs are tested
# parent : contig ID of parent (very specific, select one parent only)

    if ($options{parent}) {
# retrieve a given parent contig
        push @constraint, "C2CMAPPING.parent_id = ?";
        push @data, $options{parent};
    }

    if ($options{contig}) {
# retrieve parents of a given child contig
        push @constraint, "C2CMAPPING.contig_id = ?";
        push @data, $options{contig};
    }
# mincid & maxcid : selects (child) contigs for which parent contigs are tested
    else {
# specify a range of contig IDs to explore
        if ($options{mincid}) {
            push @constraint, "C2CMAPPING.contig_id >= ?";
            push @data, $options{mincid};
        }
        if ($options{maxcid}) {
            push @constraint, "C2CMAPPING.contig_id <= ?";
            push @data, $options{maxcid};
        }
    }

# contigname, parentname (may include wild card)
# including contig names requires the long version of a query

    if ($options{contigname}) {
# retrieve parents of a given child contig
        push @constraint, "CHILD.gap4name like ?";
        push @data, $options{contigname};
    }

    if ($options{parentname}) {
# retrieve parents of a given child contig
        push @constraint, "PARENT.gap4name like ?";
        push @data, $options{parentname};
    }

# including project info requires the long version of a query

    if ($options{project}) {
        push @constraint,"CHILD.project_id = ?";
        push @data, $options{project};
    }

    if ($options{parentproject}) {
        push @constraint,"PARENT.project_id = ?";
        push @data, $options{parentproject};
    }

    $constraints = join(' and ',@constraint) if @constraint;

    my $dbh = $this->getConnection();

    my @pids;

    if ($linktype <= 1) {
# select contigs that occur as single-read parents in C2CMAPPING table
        my $query = "select distinct PARENT.contig_id";
        if ($constraints && $constraints =~ /CHILD/) {
# long version includes constraints on PARENT or CHILD contigs
            $query .= "  from CONTIG as PARENT, CONTIG as CHILD, C2CMAPPING"
                   .  " where PARENT.contig_id = C2CMAPPING.parent_id"
                   .  "   and  CHILD.contig_id = C2CMAPPING.contig_id"
                   .  "   and PARENT.nreads = 1"
                   .  "   and  CHILD.nreads > 1"
                   .  "   and $constraints";
        }
	else {
# the short version contains no testing of (child) contig items
            $query .= "  from CONTIG as PARENT join C2CMAPPING"
                   .  "   on (PARENT.contig_id = C2CMAPPING.parent_id)"
                   .  " where PARENT.nreads = 1";
            $query .= " and $constraints" if $constraints;
	}

        $query .= " order by contig_id";

        my $sth = $dbh->prepare_cached($query);

        $sth->execute(@data) || &queryFailed($query);

        while (my $pid = $sth->fetchrow_array()) {
            push @pids, $pid;
        }

        $sth->finish();
    }   

# then add the unlinked parents (occur in MAPPING but not in C2CMAPPING)

    if ($linktype != 1) {
# select contigs that do not occur as single-read parents in C2CMAPPING table
# but do occur in the MAPPING table; this part uses temporary tables
# the result list has all single read contigs without contig links
        my $temporaryitems = "contig_id integer not null,"
	                   . "project_id integer not null";
        my $create = "create temporary table absentparent "
                   . "($temporaryitems, key(contig_id)) as "
                   . "select CONTIG.contig_id from CONTIG left join C2CMAPPING"
                   . "   on (CONTIG.contig_id = C2CMAPPING.parent_id)"
                   . " where CONTIG.nreads = 1 "
		   . "   and C2CMAPPING.parent_id is null";

        my $rw = $dbh->do($create) || &queryFailed($create);

# now find those parent IDs which are linked to contigs via the MAPPING table
        my $query = "select distinct absentparent.contig_id "
                  . "  from absentparent,MAPPING as PMAP, SEQ2READ as PS2R,"
                  . "       SEQ2READ as CS2R,  MAPPING as CMAP, CONTIG"
                  . " where absentparent.contig_id = PMAP.contig_id"
                  . "   and PMAP.seq_id  = PS2R.seq_id"
                  . "   and PS2R.read_id = CS2R.read_id"
		  . "   and CS2R.seq_id  = CMAP.seq_id"
                  . "   and CMAP.contig_id = CONTIG.contig_id"
                  . "   and CONTIG.contig_id > absentparent.contig_id"
#                  . "   and CONTIG.contig_id in (".join(',',@current).")"
                  . "   and CONTIG.nreads > 1";
        if ($constraints) {
            $constraints =~ s/C2CMAPPING|CHILD/CONTIG/g;
            $constraints =~ s/PARENT/absentparent/g;
            $query .= "  and $constraints";
        }

        $query .= " order by contig_id";

        my $sth = $dbh->prepare_cached($query);

        $sth->execute(@data) || &queryFailed($query);

        while (my $pid = $sth->fetchrow_array()) {
            push @pids, $pid;
        }

        $sth->finish();
    }

    return [@pids];
}

sub buildHistoryTreeForContig {
# update contig age (generation) from zero age upwards
    my $this = shift;
    my @contigids = @_; # initialise with one contig_id or array

# scan the C2CMAPPING table starting at the input contig IDs and
# collect the contig IDs in previous generation which have to be
# updated, i.e. increased by 1. We keep track of the target age
# in each generation and collect only those contig IDs which have
# an age less than that target. After each generation, the collected
# contig IDs (of that generation) are the starting point for locating 
# the next (previous) generation until no more IDs are found.

# this method updates the age by 1, which is all that's needed for
# an incremental update for a newly loaded contig. For building the
# tree from scratch, use rebuildHistoryTree repeatedly until no more
# updates occur.

    my $dbh = $this->getConnection();

# accumulate IDs of contigs to be updated by recursively querying

    my @updateids;
    my $targetAge = 0;
# the loop starts with contig_ids assumed to be at age 0, top of the tree
    while (@contigids) {

        $targetAge++;
        my $query = "select CHILD.parent_id, PARENT.age"
#  my $query = "select distinct(CHILD.parent_id)" .
                  . "  from C2CMAPPING as CHILD join C2CMAPPING as PARENT"
                  . "    on CHILD.parent_id = PARENT.contig_id"
	          . " where CHILD.contig_id in (".join(',',@contigids).")"
#  "   and PARENT.age < $targetAge".
                  . " order by parent_id";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        undef @contigids;
        while (my ($parent_id,$age) = $sth->fetchrow_array()) {
            push @updateids, $parent_id if ($age < $targetAge);
            push @contigids, $parent_id;
	}

        $sth->finish();
    }

    return 0 unless @updateids;

# here we have accumulated all IDs of contigs linked to input contig_id
# increase the age for these entries by 1

    my $query = "update C2CMAPPING set age=age+1".
	        " where contig_id in (".join(',',@updateids).")";
    
    my $sth = $dbh->prepare($query);

    my $update = $sth->execute() || &queryFailed($query);
    
    $sth->finish();

    return $update + 0;
}

sub rebuildHistoryTree {
# build contig age tree from scratch
    my $this = shift;

# this method rebuilds the 'age' column of C2CMAPPING from scratch

    my $dbh = $this->getConnection();

# step 1: reset the complete table to age 0

    my $query = "update C2CMAPPING set age=0";

    $dbh->do($query) || &queryFailed($query);

# step 2: get all contig_ids of age 0

    my $contigids = &getCurrentContigs($dbh,singleton=>1);

# step 3: each contig id is the starting point for tree build from the top

    my $logger = $this->verifyLogger('rebuildHistoryTree',1);

    while (my $update = $this->buildHistoryTreeForContig(@$contigids)) {
	$logger->fine("update cycle completed : $update");
	next;
    }
}

sub updateMappingAge {
# private, redefine the age for a contig-to-contig mapping
    my $dbh = shift;
    my $cid = shift;
    my $age = shift;

    &verifyPrivate($dbh,"updateMappingAge");

    my $query = "update C2CMAPPING set age=$age where contig_id=$cid";

    return $dbh->do($query) || &queryFailed($query);
}

#-------------------------------------------------------------------------
# contig generations
#-------------------------------------------------------------------------

sub getCurrentContigIDs {
# public method
    my $this = shift;
    my %options = @_;

# for options see getCurrentContigs

    return &getCurrentContigs($this->getConnection(),%options);
}

sub getCurrentContigs {
# private: returns list of contig_ids of some age (default 0, top of the tree)
    my $dbh = shift;
    my %option = @_;

    &verifyPrivate($dbh,"getCurrentContigs");

# parse options (default long look-up excluding singleton contigs)

# option singleton : set true for including single-read contigs (default F)
# option short     : set true for doing the search using age column of 
#                    C2CMAPPING; false for a left join for contigs which are
#                    not a parent (results in 'current' generation age=0)
# option age       : if specified > 0 search will default to short method
#                    selecting on age (or short) assumes a complete age tree 

    my $age   = $option{age}   || 0;
    my $short = $option{short} || 0;

    my $singleton = $option{singleton};

# there are two ways of searching: the short way assumes that all
# contigs in CONTIG occur in C2CMAPPING and that the age structure
# is consistent; the long way checks from scratch using a left join.

# if the age is specified > 0 we default to the short method.

    my $query;
    if ($short && !$singleton) {
# use age column information and exclude singleton contigs
        $query = "select distinct(CONTIG.contig_id)".
                 "  from CONTIG join C2CMAPPING".
                 "    on CONTIG.contig_id = C2CMAPPING.contig_id".
                 " where C2CMAPPING.age = $age".
		 "   and CONTIG.nreads > 1";
    }
    elsif ($short || $age) {
# use age column information and include possible singletons
	$query = "select distinct(contig_id) from C2CMAPPING where age = $age"
               . "   and contig_id > 0";
    }
    else {
# generation 0 consists of all those contigs which ARE NOT a parent
        $query = "select CONTIG.contig_id".
                 "  from CONTIG left join C2CMAPPING".
                 "    on CONTIG.contig_id = C2CMAPPING.parent_id".
	         " where C2CMAPPING.parent_id is null";
        $query .= "  and CONTIG.nreads > 1" unless $singleton;
    }

    $query .= " and project_id in ($option{project_id})" if $option{project_id};

    $query .= " order by contig_id";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    $sth->finish();

    return [@contigids]; # always return array, may be empty
}

sub getCurrentParentIDs {
# returns contig IDs of the parents of the current generation, i.e. age = 1
    my $this = shift;
    my %options = @_;

    my $dbh = $this->getConnection();

    $options{short} = 0; # force 'long' method
    my $current = &getCurrentContigs($dbh,%options);

    push @$current,0 unless @$current; # protect against empty array

    my $query = "select distinct(parent_id) from C2CMAPPING" . 
	        " where contig_id in (".join(",",@$current).")" .
		" order by parent_id";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    $sth->finish();

    return [@contigids];
} 

sub getInitialContigIDs {
# returns contig IDs at the bottom of the age tree (variable age)
    my $this = shift;

# consists of all those contigs which HAVE NOT a parent

    my $query = "select distinct(contig_id)" .
                "  from C2CMAPPING" .
	        " where parent_id = 0 or parent_id is null" .
                " union " .
                "select distinct(CONTIG.contig_id)" .
                "  from CONTIG left join C2CMAPPING" .
                " using (contig_id)" .
		" where C2CMAPPING.contig_id is null" .
                " order by contig_id";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    $sth->finish();

    return [@contigids];
}

sub getCurrentContigIDsForAncestorIDs {
# returns a list of current contig ID - ancestor ID pairs; using MAPPING table
    my $this = shift;
    my $acid = shift; # array ref, ancestor IDs 

    my $dbh = $this->getConnection();

    my $ccid = &getCurrentContigs($dbh);

#    my $subquery = "select contig_id from CURRENTCONTIGS order by contig_id";

    my $query = "select distinct M1.contig_id as cc, M2.contig_id as ac"
              . "  from MAPPING as M1,  SEQ2READ as S1,"
              . "       MAPPING as M2,  SEQ2READ as S2 "
              . " where M1.seq_id  = S1.seq_id"
              . "   and M2.seq_id  = S2.seq_id"
              . "   and S1.read_id = S2.read_id"
#              . "   and M1.contig_id in ($subquery)" # test for speed
              . "   and M1.contig_id in (" . join(',',@$ccid) . ")"
              . "   and M2.contig_id in (" . join(',',@$acid) . ")"
	      . "   order by cc,ac";
 
    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    undef my @results;
    while (my @cids = $sth->fetchrow_array()) {
        push @results, [@cids];
    }

    $sth->finish();

    return [@results];
}

sub getAncestorIDsForContigID {
    return &getFamilyIDsForContigID(@_,ancestors=>1)
}
sub getFamilyIDsForContigID {
# returns list of IDs of all contigs sharing reads with input contig_id
# using a join of the MAPPING table onto itself
    my $this = shift;
    my $cid = shift || 0; # input contig ID
    my %options = @_;

    my $dbh = $this->getConnection();

    my $cmp = "!="; # default all contig sharing reads
    $cmp = "<" if $options{ancestors};   # all earlier contigs sharing reads
    $cmp = ">" if $options{descendants}; # all  later  contigs sharing reads

    my $query = "select distinct M2.contig_id as ac"
              . "  from MAPPING as M1,  SEQ2READ as S1,"
              . "       MAPPING as M2,  SEQ2READ as S2 "
              . " where M1.seq_id  = S1.seq_id"
              . "   and M2.seq_id  = S2.seq_id"
              . "   and S1.read_id = S2.read_id"
	      . "   and M2.contig_id $cmp M1.contig_id"
	      . "   and M1.contig_id = ?"
              . " order by ac";
 
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($cid) || &queryFailed($query,$cid);

    undef my @results;
    while (my $cid = $sth->fetchrow_array()) {
        push @results, $cid;
    }

    $sth->finish();

    return [@results];
}

sub getContigIDsForReadNames {
# returns a list of (current) contig identifiers for input readname(s)
    my $this = shift;
    my $readnames = shift; # array
    my %options = @_; # short=>1, blocksize=>1000

    &verifyParameter($readnames,"getContigIDsForReadNames","ARRAY");

    my $dbh = $this->getConnection();

    my @reads = sort @$readnames; # copy to local

    my $blocksize = $options{blocksize} || 1000;

    my $short = $options{short}; # to return only contig_id

    my $searchitems;
    $searchitems = "distinct CURRENTCONTIGS.contig_id" if $short;
    $searchitems = "CURRENTCONTIGS.contig_id,gap4name,readname" unless $short;

    my $outputlist = []; # array of arrays
    my $contiglist = {}; # for intermediate results in short mode

    while (my $block = scalar(@reads)) {

        $block = $blocksize if ($block > $blocksize);

        my @block = splice @reads, 0, $block;

        my $range = join '","', @block;

        my $query = "select $searchitems"
                  . "  from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS"
                  . " where READINFO.read_id = SEQ2READ.read_id"
                  . "   and SEQ2READ.seq_id = MAPPING.seq_id"
                  . "   and MAPPING.contig_id = CURRENTCONTIGS.contig_id"
                  . "   and readname in (\"$range\")";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my @ary = $sth->fetchrow_array()) {
            push @$outputlist,[@ary] unless $short;
            $contiglist->{$ary[0]}++ if $short;
        }

        $sth->finish();
    }

    @$outputlist = sort {$a <=> $b} keys %$contiglist if $short;

    return $outputlist; # array reference
}


sub getContigIDsForContigProperty {
# return a list of contig IDs for (a combination of) contig properties
    my $this = shift;
    my %options = @_;

# select option on: length, nr of reads, nr of parents, cover, creation date

    my $dbh = $this->getConnection();

    my $subselect = "select CONTIG.contig_id "
                  . "  from CONTIG left join C2CMAPPING using (contig_id)"
		  . " where C2CMAPPING.parent_id is null";

    my $query = "select CONTIG.contig_id"
              . "  from CONTIG"
	      . " where CONTIG.contig_id in ($subselect)";

    my @data;
    foreach my $key (keys %options) {
# get the relationship
        my $relation = "=";
        $relation = ">="   if ($key =~ /^(minimum|after)/);
        $relation = "<="   if ($key =~ /^(maximum|before)/);
        $relation = "like" if ($key =~ /^(gap4|read)name/);
# get the contig property
        my $property;
        $property = "length"   if ($key =~ /^(min|max)imumlength$/);
        $property = "nreads"   if ($key =~ /^(min|max)imumnumberofreads$/);
        $property = "ncntgs"   if ($key =~ /^(min|max)imumnumberofparents$/);
        $property = "cover"    if ($key =~ /^(min|max)imumcover$/);
        $property = "created"  if ($key =~ /^created(before|after)$/);
	$property = "gap4name" if ($key =~ /(gap4|read)name/);
	$property = "project_id" if ($key =~ /project/);
        $property = $key unless $property; # e.g. origin
# add the clause to the query
        $query .= " and $property $relation ?";
        push @data,$options{$key}; 
    }
#    print "query  @data\n$query\n";

    $this->logQuery('getContigIDsForContigProperty',$query,@data); # for debugging

    my $sth = $dbh->prepare($query);

    $sth->execute(@data) || &queryFailed($query,@data);

    my @cids;
    while (my ($cid) = $sth->fetchrow_array()) {
        push @cids,$cid;
    }

    $sth->finish();

    return [@cids];
}

sub isCurrentContigID {
# returns true if the contig ID is of a contig in the current generation
    my $this = shift;

    my $dbh = $this->getConnection();

    my $children = &getChildIDsForContigID($dbh,@_);

    return (scalar(@$children) ? 0 : 1);
}

sub getRelationsForContigID {
# returns a list of contig_id,generation of all contigs related to 
# input contig ID, using the C2CMAPPING table info
    my $this = shift;
    my $contig_id = shift;
    my $hash = shift;
    my %options = @_;

    $hash = {} unless (ref($hash) eq 'HASH');

    my $generation = $options{generation} || 0;

    $hash->{$contig_id} = $generation;

    my $dbh = $this->getConnection();

    unless ($options{children}) {
        my $parentids = &getParentIDsForContigID($dbh,$contig_id);
        my $parentgeneration = $generation + 1;
        my %poptions = (generation=>$parentgeneration,parents=>1);
        foreach my $parent_id (@$parentids) {
            $this->getRelationsForContigID($parent_id,$hash,%poptions);
	}
    }

    unless ($options{parents}) {
        my $childids = &getChildIDsForContigID($dbh,$contig_id);
        my $childgeneration = $generation - 1;
        my %coptions = (generation=>$childgeneration,children=>1);
        foreach my $child_id (@$childids) {
            $this->getRelationsForContigID($child_id,$hash,%coptions);
	}
    }

    return $hash; # generation keyed on contig ID
}

#------------------------------------------------------------------------------
# methods dealing with contig TAGs
#------------------------------------------------------------------------------

sub getContigIDsWithTags {
    my $this = shift;
    my %options = @_;

# tag_id,comment,tagtype,tagcomment,systematic_id,tag_seq_id

    my $query = "select distinct contig_id from TAG2CONTIG";

    if (($options{current} && !$options{notcurrent}) ||
        ($options{notcurrent} && !$options{current})) {
        $query .= " where contig_id";
        $query .= "   not" if $options{notcurrent}; # overrides
        $query .= "    in (select contig_id from CURRENTCONTIGS)";
    }
    delete $options{notcurrent};
    delete $options{current};

    my @bindvalue;
    if ($options{comment}) {
        $query .= "   and comment like ?"     if ($query =~ /where/);
        $query .= " where comment like ?" unless ($query =~ /where/);
        push @bindvalue,$options{comment};
        delete $options{comment};
    }

    if (keys %options) {
        my $subselect = "select tag_id from CONTIGTAG";
        foreach my $key (keys %options) {
            $subselect .= "   and"     if ($subselect =~ /where/);
            $subselect .= " where" unless ($subselect =~ /where/);
            $subselect .= " $key = ? "        if ($key =~ /\_id/);
            $subselect .= " $key like ? " unless ($key =~ /\_id/);
            push @bindvalue, $options{$key};
	}
        $query .= "   and tag_id in ($subselect)"     if ($query =~ /where/);
        $query .= " where tag_id in ($subselect)" unless ($query =~ /where/);
    }

    $query .= " order by contig_id";  

    $this->logQuery('getContigIDsWithTags',$query,@bindvalue);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare($query);

    $sth->execute(@bindvalue) || &queryFailed($query,@bindvalue);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    $sth->finish();

    return [@contigids]; # always return array, may be empty    
}

sub getTagsForContig {
# add Tags to Contig instance; returns number of tags added; undef on error
    my $this = shift;
    my $contig = shift; # Contig instance

    &verifyParameter($contig,"getTagsForContig");

    return 0 if $contig->hasTags(); # only 'empty' instance allowed

    my $cid = $contig->getContigID() || return undef;

    my $dbh = $this->getConnection();

    my $tags = &fetchTagsForContigIDs($dbh,[($cid)],@_); # options ported

#my $log = $this->verifyLogger('getTagsForContig');
#$log->debug("Tags found: ".scalar(@$tags));

    foreach my $tag (@$tags) {
        $contig->addTag($tag);
    }

    return scalar(@$tags); # number of tags added to contig
}

sub getTagsForContigIDs {
# public method, returns array of Tag objects
    my $this = shift;
    my @cids = @_;

    my $dbh = $this->getConnection();

    return &fetchTagsForContigIDs ($dbh,[@cids]);
}

sub fetchTagsForContigIDs {
# private method
    my $dbh = shift;
    my $ids = shift; # reference to array of contig IDs
    my %options = @_;

    &verifyPrivate($dbh,"fetchTagsForContigIDs");

    &verifyParameter($ids,"fetchTagsForContigIDs","ARRAY");

    my $contig_or_tag_id = $options{tag} ? $options{tag} : 'contig_id';

# compose query (note, this query uses the UNION construct to cater
# for the case tag_id > 0 & tag_seq_id = 0)

    my $tagitems = "id,parent_id,contig_id,TAG2CONTIG.tag_id,cstart,cfinal,strand,"
	         . "comment,tagtype,systematic_id,tagcomment,CONTIGTAG.tag_seq_id";
    my $seqitems = "tagseqname,sequence";

    my $query = "select $tagitems,$seqitems"
              . "  from TAG2CONTIG, CONTIGTAG, TAGSEQUENCE"
              . " where TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
              . "   and CONTIGTAG.tag_seq_id = TAGSEQUENCE.tag_seq_id"
	      . "   and $contig_or_tag_id in (".join (',',@$ids) .")"
#              . "   and deprecated != 'Y'" # no table column now
              . " union "       # union weeds out duplicates
              . "select $tagitems,'',''"
              . "  from TAG2CONTIG, CONTIGTAG"
              . " where TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
              . "   and CONTIGTAG.tag_seq_id = 0" # explicitly undefined sequence
	      . "   and $contig_or_tag_id in (".join (',',@$ids) .")"
#              . "   and deprecated != 'Y'" # no table column now
              . " order by contig_id,cstart,tagtype,tagcomment,cfinal";

    $query =~ s/union/union all/ if $options{all}; # include duplicates

    my @tag;

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query) && exit;

    while (my @ary = $sth->fetchrow_array()) {
# create a new Tag instance
        my $tag = new Tag('Contig');

        $tag->setID              (shift @ary); # auto-incremented id
        $tag->setParentTagID     (shift @ary); # parent tag id (0 for new tags)
        $tag->setSequenceID      (shift @ary); # contig_id
        $tag->setTagID           (shift @ary); # tag ID ?
        $tag->setPosition        (shift @ary, shift @ary); # pstart, pfinal
        $tag->setStrand          (shift @ary); # strand
        $tag->setComment         (shift @ary); # comment
        $tag->setType            (shift @ary);
        $tag->setSystematicID    (shift @ary);
        $tag->setTagComment      (shift @ary);
        $tag->setTagSequenceID   (shift @ary);
        $tag->setTagSequenceName (shift @ary);
        $tag->setDNA             (shift @ary); # sequence
# add to output array
        push @tag, $tag;
    }

    $sth->finish();

    return [@tag];
}

# --------------- individual contigtags ---------------

sub getContigTagForID {
    my $this = shift;
    my $ids  = shift; # id or parent_id
    my $parent = shift; # parent flag

    my $dbh = $this->getConnection();

    my $id = $parent ? 'parent_id' : 'id';
    
    return &fetchTagsForContigIDs ($dbh,[($ids)],tag=>$id);
}

sub getPrecursorsOfContigTag {
    my $this = shift;
    my $tag  = shift;

    &verifyParameter($tag,"fetchTagsForContigIDs","Tag");

    my $logger = $this->verifyLogger('getPrecursorsOfContigTag');

    my @taglist;
    my $id = $tag->getParentTagID();
    while (my $tags = $this->getContigTagForID($id)) {
$logger->info("tags for id $id : ".scalar(@$tags));
        my $tag = $tags->[0] || last;
        push @taglist,$tag;
        my $pid = $tag->getParentTagID();
$logger->info("tag id $id   parenttagid $pid");
        last unless $pid;
        last if ($id <= $pid); # protection against ordering errors in db
        $id = $pid;
    }

    return [@taglist];
}

sub getDescendantsOfContigTag {
    my $this = shift;
    my $tag  = shift;

    &verifyParameter($tag,"fetchTagsForContigIDs","Tag");

    my $logger = $this->verifyLogger('getDescendantsOfContigTag');

    my @taglist;
    my $parent_id = $tag->getID();
    while (my $tags = $this->getContigTagForID($parent_id,tag=>'parent_id')) {
	$logger->info("tags for parent_id $parent_id : ".scalar(@$tags));
        last unless @$tags;
        push @taglist,@$tags;
        if(scalar(@$tags) == 1) {
            my $id = $tag->getID();
            last if ($parent_id >= $id); # protection against ordering errors in db
            $parent_id = $id;
	}
        else {
$logger->info("branching",ss=>1);
            foreach my $tag (@$tags) {
                my $dtags = $this->getDescendantsOfContigTag($tag);
$logger->info("output branch : ".scalar(@$dtags));
                push @taglist,@$dtags;
	    }
$logger->info("end branching",ss=>1);
            last;
        }
    }

    return [@taglist];
}

# ---------------

sub enterTagsForContig { # TEST purposes, to be DEPRECTATED
# public method for test purposes; returns number of new tags
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    $options{noload}   = 1 unless defined $options{noload};

    return 0 unless $contig->hasTags();

    return &putTagsForContig($this,$contig,%options);
}

sub putTagsForContig {
# public method
    my $this = shift;
    my $contig = shift;
    my %options = @_; # noload; noexistencetest; nokeep; nomerge; synchronise

    &verifyParameter($contig,"putTagsForContig");

    return 1 unless $contig->hasTags(); # no tags

    my $cid = $contig->getContigID();
    
    my $contigname = $contig->getContigName() || $contig->getGap4Name();

    unless (defined $cid) {
        my $logger = $this->verifyLogger("putTagsForContig");
        $logger->error("undefined contig ID in contig $contigname");
        return undef;
    }

    return undef unless defined $cid; # missing contig ID

# get the tags and test for valid tag info (at least a tag type defined)

    my $otags = $contig->getTags();

    my $original = scalar(@$otags); # the number of input tags

    my $merge = $options{nomerge} ? 0 : 1;

    my $ctags = $contig->getTags(0,sort=>'full',merge=>$merge); # as is

    my $logger = $this->verifyLogger("putTagsForContig");

    if (my $removed = $original - scalar(@$ctags)) {
# warning to output device
        $logger->warning("$removed duplicate tags removed from contig $contigname");
    }

# copy the ordered $ctag array to keep all tags in $contig; nokeep option erases existing tags

    unless ($options{nokeep}) {
        my @otags = @$ctags; # copy
        $ctags   =  \@otags; # point to copy array
    }

# test tag type and remove any tag without

    my $i = 0;
    while ($i < scalar(@$ctags)) {
 # each tag must have a tag type
        if ($ctags->[$i]->getType()) { 
	    $i++;
        }
        else {
            my $tagcomment = $ctags->[$i]->getTagComment() || "no description";
            $logger->debug("Invalid tag removed from contig $cid: "
                          ."missing tagtype for ($tagcomment)");
            splice @$ctags,$i,1; # remove from list
        }
    }

# test contig instance tags against possible tags (already) in database

    my $dbh = $this->getConnection();

    my $testexistence = $options{noexistencetest} ? 0 : 1;

    if ($testexistence && @$ctags) {

        $logger->debug("testing against existing Tags");

        my $etags = &fetchTagsForContigIDs($dbh,[($cid)]); # existing tags

        TagFactory->sortTags($etags,sort=>'full'); # MySQL sort is case insensitive
    
# delete the (possibly) existing tags from the ctags list; keep track of matches with e tags

        my $etaghash = {};

        my ($i,$j) = (0,0);
        while ($i < scalar(@$ctags) && $j < scalar(@$etags)) {
# test positions, which must coincide
            if ($ctags->[$i]->getPositionLeft() < $etags->[$j]->getPositionLeft()) {
                $i++;
            }
            elsif ($ctags->[$i]->getPositionLeft() > $etags->[$j]->getPositionLeft()) {
                $j++;
            }
# test for equality or overlap 
            elsif ($etags->[$j]->isEqual($ctags->[$i],leftjoin=>1)) {
                $etaghash->{$etags->[$j]}++;
                splice @$ctags,$i,1;
            }
            elsif ($etags->[$j]->isEqual($ctags->[$i],leftjoin=>1,contains=>1)) {
                $etaghash->{$etags->[$j]}++;
                splice @$ctags,$i,1;
            }
# tags are not equal
            else {
                $j++; # next existing tag only
            }
        }

        if ($options{synchronise}) {
# remove existing tags which are not among input tags
            foreach my $etag (@$etags) {
                next if $etaghash->{$etag};
# the tag is not accounted for
                &retireContigTag($dbh,$etag); # to be developed
            }
	}
    }

    $logger->info("new tags $contigname ".scalar(@$ctags),ss=>1);

    return 0 unless @$ctags; # no new tags 

    return scalar(@$ctags) if $options{noload}; # number of new tags
    
    $this->getTagSequenceIDsForTags($ctags,autoload => 1); # ->ADBRead

    $this->getTagIDsForContigTags($ctags,insert_enable=>1);

    return &putContigTags($dbh,$ctags);
}

sub getTagIDsForContigTags {
# for tags with undefined tag_id: 1) find tag_id from tag comment or systematic ID
#                                 2) if that fails, create a new tag_id
# for tags with tag_id defined  : update systematic IDs if that's appropriate
# inconsistencies are 
    my $this = shift;
    my $tags = shift; # ref to array with Tags
    my %options = @_;

    &verifyParameter($tags,"getTagIDsForTags",'ARRAY');

    return 0 unless ($tags && @$tags);

    &verifyParameter($tags->[0],"getTagIDsForTags",'Tag');


    my $logger = $this->verifyLogger('getTagIDsForContigTags');

    my ($dbh, $qsth,$isth,$usth, $query,$insert,$update);

    $dbh = $this->getConnection();

# prepare query to identify the tag_id from either tagcomment or systematic ID

# first we test if the combination tagtype and tagcomment/systematic ID exists
# we use the UNION construct to test cases where either tagcomment or the
# systematic ID is null; we also cater for undefined data values (-> 'is not null') 

    $query = "select tag_id,systematic_id,tag_seq_id"
           . "  from CONTIGTAG"
           . " where tagtype = ?"
           . "   and tagcomment is not null" # these three conditions ensure
           . "   and tagcomment != ''"       # that no line is returned should
           . "   and tagcomment = ?"         # the bind value be NULL or '' 
           . " union "
           . "select tag_id,systematic_id,tag_seq_id"
           . "  from CONTIGTAG"
           . " where tagtype = ?"
           . "   and systematic_id is not null"
           . "   and systematic_id != ''" 
           . "   and systematic_id = ?"
#           . "   and (tagcomment is null or tagcomment = '')"
           . " limit 1";

    $qsth = $dbh->prepare($query);

# prepare insert of new contigtag info 

    if ($options{insert_enable}) {

        $insert = "insert into CONTIGTAG "
                . "(tagtype,systematic_id,tag_seq_id,tagcomment) "
	        . "values (?,?,?,?)";

        $isth = $dbh->prepare_cached($insert);

# prepare update of systematic ID

        $update = "update CONTIGTAG set systematic_id = ? where tag_id = ?";

        $usth = $dbh->prepare_cached($update);
    }

# ok, run through each tag in turn

    my $failed = 0;

    my $systematicIDhash = {};

    foreach my $tag (@$tags) {

        my $inconsistent = 0;

# (1) identify the tag_id from either tagcomment or systematic ID

        my $tagtype = $tag->getType();
        unless ($tagtype) {
	    next;
	}
        my $tagcomment = $tag->getTagComment();
        my $systematic_id = $tag->getSystematicID();
        my @binddata = ($tagtype,$tagcomment,$tagtype,$systematic_id);

# pull out existing data

        my $rc = $qsth->execute(@binddata) || &queryFailed($query,@binddata);

        if ($rc > 0) {
            my ($tag_id,$systematic_id,$tag_seq_id) = $qsth->fetchrow_array();
# test consistency of tag ID and tag seq ID
            my $existingtagid = $tag->getTagID();
            if ($existingtagid && $existingtagid != $tag_id) {
                $logger->special("Inconsistent contig tag ID ($existingtagid "
                                ."vs $tag_id for '$tagcomment')",ss=>1);
                $inconsistent++;
            }
            $tag->setTagID($tag_id) if $tag_id;
# test consistency of tag sequence ID and tag seq ID
            my $existingseqid = $tag->getTagSequenceID();
            if ($existingseqid && $existingseqid != $tag_seq_id) {
                if ($tag_seq_id) { # always flag this inconsistence
                    $logger->special("Inconsistent tag sequence ID "
                                    ."($existingseqid vs $tag_seq_id for "
                                    ."'$tagcomment')",ss=>1);
                }
                else { # tag_seq_id in the database is 0
                    $logger->info("Inconsistent tag sequence ID "
                                  ."($existingseqid vs $tag_seq_id for "
                                  ."'$tagcomment')",ss=>1);
# update database value ??
		}
                $inconsistent++;
            }
            $tag->setTagSequenceID($tag_seq_id) if $tag_seq_id; # dbase value
# and flag a possible update to sys ID
            $systematicIDhash->{$tag}++ unless $systematic_id;
	}
# if no match of data found, set tag ID to undefined
        else {
            $tag->setTagID(0);
	}

        $qsth->finish();

# for those tags that do not have an ID, we generate a new entry in CONTIGTAG

        next if $tag->getTagID();
 
        @binddata = ($tag->getType(),
                     $tag->getSystematicID(),
                     $tag->getTagSequenceID() || 0,
                     $tag->getTagComment());

        next unless $options{insert_enable};

        $rc = $isth->execute(@binddata) || &queryFailed($insert,@binddata);

        if ($rc > 0) {
            my $tag_id = $dbh->{'mysql_insertid'};
            $tag->setTagID($tag_id);
        }
        else {
            $failed++;
	}
        $isth->finish();
    }

# finally update systematic IDs, if any

    if ($options{insert_enable} && keys %$systematicIDhash) {

        foreach my $tag (@$tags) {
            next unless $systematicIDhash->{$tag};
            next unless $tag->getSystematicID();
            my @binddata = ($tag->getTagID(),$tag->getSystematicID());
            $usth->execute(@binddata) || &queryFailed($update,@binddata);
            $usth->finish();
	}
    }

    return $failed;
}


sub putContigTags {
# use as private method only
    my $dbh = shift;
    my $tags = shift; # ref to array with Tags

    &verifyPrivate($dbh,"putContigTags");

    return undef unless ($tags && @$tags);

    my $query = "insert into TAG2CONTIG " # insert ignore ?
              . "(parent_id,contig_id,tag_id,cstart,cfinal,strand,comment) "
              . "values (?,?,?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($query);        

    my $missed  = 0;
    my $success = 0;

    foreach my $tag (@$tags) {

        my $parent_id        = $tag->getParentTagID() || 0;
        my $contig_id        = $tag->getSequenceID();
        my $tag_id           = $tag->getTagID();
        unless ($contig_id && $tag_id) {
            $missed++;
            next; # protect against undef seq ID
        }
        my ($cstart,$cfinal) = $tag->getPosition();
        my $strand           = $tag->getStrand();
        $strand =~ s/(\w)\w*/$1/;
        my $comment          = $tag->getComment();

        my @data = ($parent_id,$contig_id,$tag_id,$cstart,$cfinal,$strand,$comment || undef);

        my $rc = $sth->execute(@data) || &queryFailed($query,@data);

        $missed++ unless $rc;
        $success++ if $rc;
    }

    $sth->finish();

    return $success; 
}

sub retireContigTag {
    my $dbh = shift;
    my $tag = shift;

    print STDOUT "TO BE COMPLETED tag to be retired :\n".$tag->writeToCaf();
}

#------------------------------------------------------------------------------
# verification of method parameter and access mode
#------------------------------------------------------------------------------

sub verifyParameter {
    my $object = shift;
    my $method = shift || 'UNDEFINED';
    my $class  = shift || 'Contig';
    my %options = @_;

    return if (!$object && $options{null});
    return if ($object && ref($object) eq $class);
    print STDERR "method 'ADBContig->$method' expects a $class instance as parameter\n";
    print STDERR "instead of $object\n";
    exit 1; 
}

sub verifyPrivate {
    my $caller = shift;
    my $method = shift;

    if (ref($caller) eq 'ArcturusDatabase' || $caller =~ /^ADB\w+/) {
        print STDERR "Invalid use of private method ADBContig->$method\n";
	exit 1;
    }
}

#------------------------------------------------------------------------------

1;
