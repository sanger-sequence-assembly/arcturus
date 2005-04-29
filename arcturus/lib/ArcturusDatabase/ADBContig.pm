package ArcturusDatabase::ADBContig;

use strict;

use ArcturusDatabase::ADBRead;

use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Contig;
use Mapping;

our @ISA = qw(ArcturusDatabase::ADBRead);

use ArcturusDatabase::ADBRoot qw(queryFailed);

my $DEBUG = 0;

# ----------------------------------------------------------------------------
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

sub getContig {
# return a Contig object  (under development)
# options: one of: contig_id=>N, withRead=>R, withChecksum=>C, withTag=>T 
# additional : metaDataOnly=>0 or 1 (default 0), noReads=>0 or 1 (default 0)
# DO WE NEED:andblocked: include contig from blocked projects TO BE IMPLEMENTED ?
    my $this = shift;

# decode input parameters and compose the query

    my $query  = "select CONTIG.contig_id,length,ncntgs,nreads,".
                 "newreads,cover,readnamehash "; 

    my $nextword;
    my $metadataonly = 0; # default export the lot

    my $value;
    while ($nextword = shift) {
	if ($nextword eq 'ID' || $nextword eq 'contig_id') {
            $query .= "from CONTIG where contig_id = ?";
            $value = shift;
        }
        elsif ($nextword eq 'withChecksum') {
# returns the highest contig_id, i.e. most recent contig with this checksum
            $query .= " from CONTIG where readnamehash = ? "
		    . "order by contig_id desc limit 1";
            $value = shift;
        }
        elsif ($nextword eq 'withRead') {
# returns the highest contig_id, i.e. most recent contig with this read
            $query .= " from CONTIG, MAPPING, SEQ2READ, READS "
                    . "where CONTIG.contig_id = MAPPING.contig_id"
                    . "  and MAPPING.seq_id = SEQ2READ.seq_id"
                    . "  and SEQ2READ.read_id = READS.read_id"
                    . "  and READS.readname = ? "
		    . "order by contig_id desc limit 1";
#print STDERR "getContig: $query\n";
             $value = shift;
        }
        elsif ($nextword eq 'withTagName') {
# returns the highest contig_id, i.e. most recent contig with this tag
# NOTE: perhaps we should cater for more than one contig returned?
            $query .= " from CONTIG join CONTIGTAG using (contig_id) "
                    . "where tag_seq_id in " 
                    .       "(select tag_seq_id from TAGSEQUENCE"
                    .       " where tagseqname = ?) "
		    . "order by contig_id desc limit 1";
print STDERR "getContig: $query\n";
            $value = shift;
        }
        elsif ($nextword eq 'withAnnotationTag') {
# returns the highest contig_id, i.e. most recent contig with this tag
            $query .= " from CONTIG join CONTIGTAG using (contig_id)".
                      "where systematic_id like '?' ". 
		      "order by contig_id desc limit 1";
print STDERR "getContig: $query\n";
            $value = shift;
        }
        elsif ($nextword eq 'metaDataOnly') {
            $metadataonly = shift;
        }
        else {
            print STDERR "Invalid parameter in getContig : $nextword\n";
            $this->disconnect();
            exit 0;
        }
    }

    my $dbh = $this->getConnection();
        
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

# get the metadata

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;
        $contig->setContigID($contig_id);

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

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return undef unless defined($contig);

    return $contig if $metadataonly;

# get the reads for this contig with their DNA sequences and tags

    $this->getReadsForContig($contig);

# get read-to-contig mappings (and implicit segments)

    $this->getReadMappingsForContig($contig);

# get contig-to-contig mappings (and implicit segments)

    $this->getContigMappingsForContig($contig);

# get contig tags

    $this->getTagsForContig($contig);

# for consensus sequence we use lazy instantiation in the Contig class

    return $contig if ($this->testContigForExport($contig));

    return undef; # invalid Contig instance
}

sub getSequenceAndBaseQualityForContigID {
# returns DNA sequence (string) and quality (array) for the specified contig
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig_id = shift;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from CONSENSUS where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    my ($sequence, $quality);

    if (my @ary = $sth->fetchrow_array()) {
	($sequence, $quality) = @ary;
    }

    $sth->finish();

    $sequence = uncompress($sequence) if defined($sequence);

    if (defined($quality)) {
	$quality = uncompress($quality);
print STDERR "undefined quality in contig_id = $contig_id\n" unless $quality;
	my @qualarray = unpack("c*", $quality);
	$quality = [@qualarray];
    }

    $sequence =~ s/\*/N/g if $sequence; # temporary fix 

    return ($sequence, $quality);
}

sub hasContig {
# test presence of contig with given contig_id; (REDUNDENT?)
# if so, return Contig instance with metadata only
    my $this = shift;
    my $contig_id = shift;

    return $this->getContig(ID=>$contig_id,metaDataOnly=>1);
}

sub getParentContigsForContig {
# adds the parent Contig instances, if any, to the input Contig 
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig = shift;

    return if $contig->hasParentContigs(); # already done

# get the parent IDs; try ContigToContig mappings first

    my @parentids;
    if ($contig->hasContigToContigMappings()) {
        my $contigmappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$contigmappings) {
            push @parentids, $mapping->getSequenceID();
        }
    }
# alternatively, get the IDs from the database given contig_id
    elsif (my $contigid = $contig->getContigID()) {
        my $dbh = $this->getConnection();
        my $parents = &getParentIDsForContigID($dbh,$contigid);
        @parentids = @$parents if $parents;
    }
# or, if no contig_id available, get the parents from read comparison
    else {
print "searching parents from scratch\n" if $DEBUG; 
        my $parents = $this->getParentIDsForContig($contig);
        @parentids = @$parents if $parents;        
    }

# build the Contig instances (metadata only) and add to the input Contig object

    foreach my $parentid (@parentids) {
        my $parent = $this->getContig(ID=>$parentid, metaDataOnly=>1);
        $contig->addParentContig($parent) if $parent;
    }
}

sub getChildContigsForContig {
# adds the Child Contig instances, if any, to the input Contig 
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig = shift;

    return if $contig->hasChildContigs(); # already done

# get the IDs from the database given contig_id

    my $contig_id = $contig->getContigID();

    return unless defined($contig_id);

    my $dbh = $this->getConnection();

    my $childids = &getChildIDsForContigID($dbh,$contig_id);

# build the Contig instances (metadata only) and add to the input Contig object

    foreach my $child_id (@$childids) {
        my $child = $this->getContig(ID=>$child_id, metaDataOnly=>1);
print "contig $child for id=$child_id\n";
        $contig->addChildContig($child) if $child;
    }
}

#------------------------------------------------------------------------------
# methods for importing CONTIGs or CONTIG attributes into the database
#------------------------------------------------------------------------------

sub putContig {
# enter a contig into the database
    my $this = shift;
    my $contig = shift;  # Contig instance
    my $project = shift; # Project instance or '0' or undef
    my %options = @_;

    die "ArcturusDatabase->putContig expects a Contig instance ".
        "as parameter" unless (ref($contig) eq 'Contig');
    die "ArcturusDatabase->putContig expects a Project instance ".
        "as parameter" if ($project && ref($project) ne 'Project');

# optional input parameters: 
# setprojectby        for choice of method used for project inheritance
# lockcheck 0/1       for choice of project used for project inheritance
# inheritTags=>0/1/2  for generation depth of tag inheritance from parents
# noload=>0/1         for testmode (everything except write to database)

    my $setprojectby = $options{setprojectby} || 'none';
    if ($setprojectby eq 'project' && !$project) {
        return (0,"Missing Project instance as parameter when expected");
    }
    elsif ($setprojectby eq 'none' && $project) {
        return (0,"Incompatible parameters: Project instance specified "
                 ."when none expected");
    }

    my $inheritTags  = $options{inheritTags};
    $inheritTags = 2 unless defined($inheritTags);
    my $noload  = $options{noload} || 0;

# do the statistics on this contig, allow zeropoint correction
# the getStatistics method also checks and orders the mappings 

    $contig->getStatistics(2);

    my $contigname = $contig->getContigName();

# test the Contig reads and mappings for completeness (using readname)

    if (!$this->testContigForImport($contig)) {
        return 0,"Contig $contigname failed completeness test";
    }

# get readIDs/seqIDs for its reads, load new sequence for edited reads
 
    my $reads = $contig->getReads();
    return 0, "Missing sequence IDs for contig $contigname" 
        unless $this->getSequenceIDsForReads($reads); # to be tested
# unless $this->getSequenceIDForAssembledReads($reads);

# get the sequenceIDs (from Read); also build the readnames array 

    my @seqids;
    my %seqids;
    foreach my $read (@$reads) {
        my $seqid = $read->getSequenceID();
# extra check on read sequence presence, just to be sure
        unless ($seqid) {
            print STDERR "undefined sequence ID for read ".
		$read->getReadName."\n";
            unless ($noload) {
                return (0,"Missing sequence IDs for contig $contigname");
            }
	}
        my $readname = $read->getReadName();
        $seqids{$readname} = $seqid;
        push @seqids,$seqid;
    }
# and put the sequence IDs into the Mapping instances
    my $mappings = $contig->getMappings();
    foreach my $mapping (@$mappings) {
#?	next if ($mapping->getSequenceID());
        my $readname = $mapping->getMappingName();
        $mapping->setSequenceID($seqids{$readname});
    }

# test if the contig has been loaded before using the readname/sequence hash

    my $readhash = md5(sort @seqids);
# first try the sequence ID hash (returns the last entered contig, if any)
    my $previous = $this->getContig(withChecksum=>$readhash,
                                    metaDataOnly=>1);
# if not found try the readname hash
    $previous = $this->getContig(withChecksum=>md5(sort keys %seqids),
                                 metaDataOnly=>1) unless $previous;

    if ($previous) {
# the read name hash or the sequence IDs hash does match
# pull out previous contig mappings and compare them one by one with contig's
        $this->getReadMappingsForContig($previous);
        if ($contig->isSameAs($previous)) {
# add the contig ID to the contig
            my $contigid = $previous->getContigID();
            $contig->setContigID($contigid);
            my $message = "Contig $contigname is identical to contig ".
                           $previous->getContigName();

# the next block allows updates to contigs already in the database

            unless ($noload) {
 
# (re-)assign project, if a project is explicitly defined

                if ($project && $setprojectby eq 'project') {
# shouldn't this have an extra switch? 
# determine old project for contig, generate message system?
print STDERR "putContig: line 381 assignContigToProject I\n";
# what about message? get project allocated for contig, test if pid cahnged
                    $this->assignContigToProject($previous,$project,1);
                    $project->addContigID($contigid);
                }

# check / import tags for this contig

                if ($contig->hasTags() && $inheritTags) {
                    my $dbh = $this->getConnection();
                    $message .= "\nWarning: no tags inserted for $contigname"
                    unless &putTagsForContig($dbh,$contig,1);
                }
	    }

            return $contigid,$message;
        }
    }

# okay, the contig is new; find out if it is connected to existing contigs

    my $parentids = $this->getParentIDsForContig($contig);

# pull out mappings for those previous contigs, if any

    my @originalprojects;
    my $message = "$contigname ";
    if ($parentids && @$parentids) {
# compare with each previous contig and return/store mapings/segments
        $message .= "has parent(s) : @$parentids ";
        foreach my $parentid (@$parentids) {
            my $parent = $this->getContig(ID=>$parentid,metaDataOnly=>1);
            unless ($parent) {
# protection against missing parent contig from CONTIG table
                print STDERR "Parent $parentid for $contigname not found ".
		             "(possibly corrupted MAPPING table?)\n";
                next;
            }
            $this->getReadMappingsForContig($parent);
            my ($linked,$deallocated) = $contig->linkToContig($parent);
# add parent to contig, later import tags from parent(s)
            $contig->addParentContig($parent) if $linked; 
            $previous = $parent->getContigName();
            $message .= "; empty link detected to $previous" unless $linked;
            $message .= "; $deallocated reads deallocated from $previous".
  		        "  (possibly split contig?) " if $deallocated;
        }

# inherit the tags

        $contig->inheritTags() if $inheritTags;

# determine the project_id unless it's already specified (with options)

        unless ($setprojectby eq 'project' || $setprojectby eq 'none') {
            my %poptions;
            $poptions{lockcheck} = 1; # always in loading mode
            my ($projects,$msg) = $this->inheritProject($contig,$setprojectby,
                                                        %poptions);
            if ($projects) {
# a project has been determined
                $project = shift @$projects;
                @originalprojects = @$projects;
                $message .= "; project ".$project->getProjectName()." selected ";
                $message .= "($msg) " if $msg;
	    }
	    elsif ($project) {
# a project could not be determined; use input $project as default project
                $message .= "; assigned to default project "
                          .  $project->getProjectName();
	    }
	    else {
# a project could not be determined; assign to bin project
                $message .= "; assigned to 'bin' project (ID=0) ";
            }
        }

	if ($noload) {
	    $message .= "Contig ".$contig->getContigName."\n";
	    foreach my $mapping (@{$contig->getContigToContigMappings}) {
	        $message .= ($mapping->assembledFromToString || "empty link\n");
	    }
	}
    }
    else {
# the contig has no precursor, is completely new
        $message .= "has no parents";
        $message .= "; assigned to project 0 " unless $project;
    }

    return 0, "(NO-LOAD option active) ".$message if $noload; # test option

# now load the contig into the database

    my $dbh = $this->getConnection();

    my $contigid = &putMetaDataForContig($dbh,$contig,$readhash);

    $this->{lastinsertedcontigid} = $contigid;

    return 0, "Failed to insert metadata for $contigname" unless $contigid;

    $contig->setContigID($contigid);

# then load the overall mappings (and put the mapping ID's in the instances)

    return 0, "Failed to insert read-to-contig mappings for $contigname"
    unless &putMappingsForContig($dbh,$contig,type=>'read');

# the CONTIG2CONTIG mappings

    return 0, "Failed to insert contig-to-contig mappings for $contigname"
    unless &putMappingsForContig($dbh,$contig,type=>'contig');

# and contig tags?

    return 0, "Failed to insert tags for $contigname"
    unless &putTagsForContig($dbh,$contig);

# update the age counter in C2CMAPPING table (at very end of this insert)

    $this->buildHistoryTreeForContig($contigid);

# and assign the contig to the specified project

    if ($project) {
        my ($success,$msg) = $this->assignContigToProject($contig,$project,1);
        $message .= "; assigned to project ";
        $message .=  $project->getProjectName() if $success;
        $message .= "ID = 0" unless $success;
        $project = 0 unless $success;
# compose messages for owners of contigs which have changed project
        my $messages = &informUsersOfChange($contig,$project,\@originalprojects);
        foreach my $message (@$messages) {
            $this->logMessage(@$message); # owner, projects, text
        }

    }

    return $contigid, $message;
   
# 2) ?? lock MAPPING and SEGMENT tables
# 3) enter record in MAPPING for each read and contig=0 (bulk loading)
# 4) enter segments for each mapping (bulk loading)
# 5) enter record in CONTIG with meta data, gets contig_id
# 6) replace contig_id=0 by new contig_id in MAPPING
# 7) release lock on MAPPING 
}

sub inheritProject {
# decide which project is inherited by a contig; returns a LIST of projects, 
# the selected one up front followed by all projects considered 
    my $this = shift;
    my $contig = shift;
    my $imodel = shift; # select project by (inheritance model)
    my %options = @_;

# test input parameters and contents

    die "method 'inheritProject' expects a Contig instance as parameter" 
    unless ($contig && ref($contig) eq 'Contig');

    unless ($contig->hasParentContigs()) {
        return 0,"has no parents; project ID = 0 assigned";
    }

# test inheritance model specification and other options

    my %inherit = ('readcount',1,'contigcount',2,'contiglength',3);
    unless ($inherit{$imodel}) {
        return (0,"invalid inheritance model: $imodel");
    }
    my $inheritmodel = $inherit{$imodel}; # replace by 1,2 or 3

    my $lockcheck = $options{lockcheck} || 0;
    my $preload   = $options{preload}   || 0; 

# collect the parent IDs and hashed measures

    my $parents = $contig->getParentContigs();

    my @parentids;
    my %readsinparent;
    my %consensussize;
    foreach my $parent (@$parents) {
        my $pid = $parent->getContigID();
        push @parentids, $pid;
        $readsinparent{$pid} = $parent->getNumberOfReads();
	$consensussize{$pid} = $parent->getConsensusLength();
    }

# find the projects for these parent IDs
    
    my @projects;
    if ($options{preload}) {
# check on presence of contig, project allocation hash
        my $cphash = $this->{cphash};
# assemble the hash for preloaded projects if it's missing
        unless ($cphash && scalar(keys (%$cphash))) {
            $this->{cphash} = {};
            my $projects = $this->getProjects();
            foreach my $project (@$projects) {
                my $nolockcheck = ($lockcheck ? 0 : 1);
                my ($cids,$msg) = $project->fetchContigIDs($nolockcheck);
                $project->addContig(0); # reset contig ID list
                next unless ($cids);
                foreach my $contigid (@$cids) {
                    $this->{cphash}->{$contigid} = $project;
                }
            }
        }
# build a hash for the projects for the parent IDs
        my $subcphash = {};
        foreach my $parentid (@parentids) {
            my $project = $cphash->{$parentid} || next;
            $subcphash->{$project} = $project; # should be copied!
	}
# assemble the list of projects
        foreach my $key (keys (%$subcphash)) {
            push @projects,$subcphash->{$key};
        }
    }
    else {
#print "putContig 451: getProject parentids= @parentids\n" if $DEBUG;
        my ($projects,$msg) = $this->getProject(contig_id=>[@parentids]);
#                                               lockcheck=>$options{lockcheck});
#print "Projects found @$projects $msg\n" if @$projects;
#print "No Projects found $msg\n" unless @$projects;
        @projects = @$projects if ($projects && @$projects);
    }

# decide on which project to use; weed out (possible) BIN if more than one

    my @original = @projects;
    if (scalar(@projects) > 1) {
# there is more than one project to chose from: first ignore any BIN
        while (scalar(@projects)) {
            my $isbin;
            for (my $i=0 ; $i < @projects ; $i++) {
                my $project = $projects[$i];
                $isbin = $i unless ($project->getProjectID()); # PID = 0, the bin
                $isbin = $i if ($project->getProjectName() =~ /BIN/);
                last if defined($isbin);
            }
            last unless defined($isbin);
# if the BIN project is in the list, remove it
            splice @projects,$isbin,1;
        }
# if no project left (i.e. all were a BIN of some kind) restore original
        @projects = @original unless @projects;
    }

# ok, now decide which project to use

    my $project;
    if (scalar(@projects) > 1) {
# here we have to chose between several projects; in this case at least one of
# the parent contigs is propagated into another project: flag project change
        my $largestscore = 0;
	foreach my $testproject (@projects) {
	    my $contigids = $testproject->getContigIDs();
print "Project ".$testproject->getProjectID().
      " ".$testproject->getProjectName().
      " contigs: @$contigids\n" if $DEBUG;
            my $measure = $options{measure} || 0;
            my $score = 0;
            foreach my $contigid (@$contigids) {
                if ($inheritmodel == 1) {
                    $score += $readsinparent{$contigid};
                }
		elsif ($inheritmodel == 2) {
                    $score += 1;
		}
		else {
                    $score += $consensussize{$contigid};
                }
            }
print "Score $score ($largestscore)\n" if $DEBUG;
            if (!$largestscore || $score > $largestscore) {
                $largestscore = $score;
                $project = $testproject;
            }          
        }
        unshift @original,$project;
        return ([@original],"$imodel score $largestscore");
    }
    elsif (scalar(@projects) == 1) {
        $project = $projects[0];
        unshift @original,$project;
        return ([@original],"default choice");
    }
    else {
# should not occur when BIN autoload is active
	return (0,"no project inherited from contig(s) @parentids");
    }

    return (0,"Illegal termination of inheritProject"); # should never occur
}

sub informUsersOfChange {
# private method only
    my $contig = shift; # the contig instance
    my $newproject = shift; # Project instance or 0 for 'bin'
    my $oldprojects = shift; # array of Project instances

    my $newpid = 0;
    $newpid = $newproject->getProjectID() if $newproject;
    my $newprojectname = 0;

    my @messages;
    foreach my $oldproject (@$oldprojects) {
# test if a project has changed using the project ID
        next if ($oldproject->getProjectID() == $newpid);
        next if ($oldproject->getProjectName() eq "BIN");
 
        my $oldprojectname = $oldproject->getProjectName();
	my $contigids = $oldproject->getContigIDs();
        my $owner = $oldproject->getOwner();
        my $message = "Contig(s) @$contigids from project $oldprojectname"
	            . " have been merged into contig ".$contig->getContigID();
        if ($newpid) {
            $newprojectname = $newproject->getProjectName();
            $message .= " under project $newprojectname";
            $message .= " (assembly ".$newproject->getAssemblyID().")";
            if ($newproject->getOwner() ne $oldproject->getOwner()) {
                $message .= " owned by user ".$newproject->getOwner();
            } 
        }
        else {
            $message .= "and assigned to the bin";
        }
# build output messages as array of arrays
        push @messages,[($owner,$newprojectname,$message)];
    }
    return [@messages];
}

sub putMetaDataForContig {
# private method only
    my $dbh = shift; # database handle
    my $contig = shift; # Contig instance
    my $readhash = shift; 

    my $query = "insert into CONTIG " .
                "(length,ncntgs,nreads,newreads,cover".
                ",origin,readnamehash) ".
                "VALUES (?,?,?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($contig->getConsensusLength() || 0,
                           $contig->hasParentContigs(),
                           $contig->getNumberOfReads(),
                           $contig->getNumberOfNewReads(),
                           $contig->getAverageCover(),
                           $contig->getOrigin(),
                           $readhash) || &queryFailed($query);

    return 0 unless ($rc == 1);
    
    return $dbh->{'mysql_insertid'}; # the contig_id
}

sub getSequenceIDForAssembledReads {
# put sequenceID, version and read_id into Read instances given their 
# readname (for unedited reads) or their sequence (edited reads)
# NOTE: this method may insert new read sequence
    my $this = shift;
    my $reads = shift;

# collect the readnames of unedited and of edited reads
# for edited reads, get sequenceID by testing the sequence against
# version(s) already in the database with method addNewSequenceForRead
# for unedited reads pull the data out in bulk with a left join

    my $success = 1;

    my $unedited = {};
    foreach my $read (@$reads) {
        if ($read->isEdited) {
            my ($added,$errmsg) = $this->putNewSequenceForRead($read);
	    print STDERR "Edited $added $errmsg\n";
	    print STDERR "$errmsg\n" unless $added;
            $success = 0 unless $added;
        }
        else {
            my $readname = $read->getReadName();
            $unedited->{$readname} = $read;
        }
    }

# get the sequence IDs for the unedited reads (version = 0)

    my $range = join "','",sort keys(%$unedited);

    return unless $range;

    my $query = "select READS.read_id,readname,seq_id" .
                "  from READS left join SEQ2READ using(read_id) " .
                " where readname in ('$range')" .
	        "   and version = 0";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        my ($read_id,$readname,$seq_id) = @ary;
        my $read = $unedited->{$readname};
        delete $unedited->{$readname};
        $read->setReadID($read_id);
        $read->setSequenceID($seq_id);
        $read->setVersion(0);
    }

    $sth->finish();

# have we collected all of them? then %unedited should be empty

    if (keys %$unedited) {
        print STDERR "Sequence ID not found for reads: " .
	              join(',',sort keys %$unedited) . "\n";
        $success = 0;
    }
    return $success;
}

sub testContigForExport {
    &testContig(shift,shift,0);
}

sub testContigForImport {
    &testContig(shift,shift,1);
}

sub testContig {
# use via ForExport and ForImport aliases
    my $this = shift;
    my $contig = shift || return undef; # Contig instance
    my $level = shift;

# level 0 for export, test number of reads against mappings and metadata    
# for export: test reads against mappings using the sequence ID
# for import: test reads against mappings using the readname
# for both, the reads and mappings must correspond 1 to 1

    my %identifier; # hash for IDs

# test contents of the contig's Read instances

    my $ID;
    if ($contig->hasReads()) {
        my $success = 1;
        my $reads = $contig->getReads();
        foreach my $read (@$reads) {
# test identifier: for export sequence ID; for import readname (or both? for both)
            $ID = $read->getReadName()   if  $level; # import
	    $ID = $read->getSequenceID() if !$level;
            if (!defined($ID)) {
                print STDERR "Missing identifier in Read ".$read->getReadName."\n";
                $success = 0;
            }
            $identifier{$ID} = $read;
# test presence of sequence and quality data
            if ((!$level || $read->isEdited()) && !$read->hasSequence()) {
                print STDERR "Missing DNA or BaseQuality in Read ".
                              $read->getReadName."\n";
                $success = 0;
            }
        }
        return 0 unless $success;       
    }
    else {
        print STDERR "Contig ".$contig->getContigName." has no Reads\n";
        return 0;
    }

# test contents of the contig's Mapping instances and against the Reads

    if ($contig->hasMappings()) {
        my $success = 1;
	my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
# get the identifier: for export sequence ID; for import readname
            if ($mapping->hasSegments) {
                $ID = $mapping->getMappingName()    if $level;
	        $ID = $mapping->getSequenceID() if !$level;
# is ID among the identifiers? if so delete the key from the has
                if (!$identifier{$ID}) {
                    print STDERR "Missing Read for Mapping ".
                            $mapping->getMappingName." ($ID)\n";
                    $success = 0;
                }
                delete $identifier{$ID}; # delete the key
            }
	    else {
                print STDERR "Mapping ".$mapping->getMappingName().
                         " for Contig ".$contig->getContigName().
                         " has no Segments\n";
                $success = 0;
            }
        }
        return 0 unless $success;       
    } 
    else {
        print STDERR "Contig ".$contig->getContigName." has no Mappings\n";
        return 0;
    }
# now there should be no keys left (when Reads and Mappings correspond 1-1)
    if (scalar(keys %identifier)) {
        foreach my $ID (keys %identifier) {
            my $read = $identifier{$ID};
            print STDERR "Missing Mapping for Read ".$read->getReadName." ($ID)\n";
        }
        return 0;
    }

# test the number of Reads against the contig meta data (info only; non-fatal)

    if (my $numberOfReads = $contig->getNumberOfReads()) {
        my $reads = $contig->getReads();
        my $nreads =  scalar(@$reads);
        if ($nreads != $numberOfReads) {
	    print STDERR "Read count error for contig ".$contig->getContigName.
                         " (actual $nreads, metadata $numberOfReads)\n";
        }
    }
    elsif (!$level) {
        print STDERR "Missing metadata for ".contig->getContigName."\n";
    }
    return 1;
}

sub deleteContig {
# remove data for a given contig_id from all tables
    my $this = shift;
    my $contigid = shift;

    $contigid = $this->{lastinsertedcontigid} unless defined($contigid);

    return 0,"Missing contig ID" unless defined($contigid);

    my $dbh = $this->getConnection();

# safeguard: contig may not be among the parents

    my $query = "select parent_id from C2CMAPPING" .
	        " where parent_id = $contigid";

    my $isparent = $dbh->do($query) || &queryFailed($query);

    return 0,"Contig $contigid is, or may be, a parent and can't be deleted" 
        if (!$isparent || $isparent > 0); # also exits on failed query

# safeguard: contig may not belong to a project and have checked 'out' status

# the next line deletes from CONTIG2PROJECT (or not)

    my ($status,$message) = $this->unlinkContigID($contigid); 
    return (0,"Contig $contigid cannot be deleted: $message") unless $status;
    
# proceed only if contig has been unlinked; now delete from the primary tables

    my $success = 1;
    foreach my $table ('CONTIG','MAPPING','C2CMAPPING','CONSENSUS') {
        my $query = "delete from $table where contig_id = $contigid"; 
        my $deleted = $dbh->do($query) || &queryFailed($query);
        $success = 0 unless $deleted;
    }

# remove the redundent entries in SEGMENT and C2CSEGMENT

#    $success = $this->cleanupSegmentTables(0) if $success;
    $success = &cleanupSegmentTables($dbh,0) if $success;

    return $success;
}

# internal consistency test

sub readback {
# checks mappings against
    my $this = shift;
    my $contig = shift; 
}

#---------------------------------------------------------------------------------
# methods dealing with Mappings
#---------------------------------------------------------------------------------

sub getReadMappingsForContig {
# adds an array of read-to-read MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;

    unless (ref($contig) eq 'Contig') {
        die "getReadMappingsForContig expects a Contig instance as parameter";
    } 

    return if $contig->hasMappings(); # already has its mappings

    my $mquery = "select readname,SEQ2READ.seq_id,mapping_id,".
                 "       cstart,cfinish,direction" .
                 "  from MAPPING, SEQ2READ, READS" .
                 " where contig_id = ?" .
                 "   and MAPPING.seq_id = SEQ2READ.seq_id" .
                 "   and SEQ2READ.read_id = READS.read_id" .
                 " order by cstart";

    my $squery = "select SEGMENT.mapping_id,SEGMENT.cstart," .
                 "       rstart,length" .
                 "  from MAPPING join SEGMENT using (mapping_id)" .
                 " where MAPPING.contig_id = ?";

    my $dbh = $this->getConnection();

# first pull out the mapping IDs

    my $sth = $dbh->prepare_cached($mquery);

    $sth->execute($contig->getContigID) || &queryFailed($mquery);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    while(my ($nm, $sid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# intialise and add readname and sequence ID
        my $mapping = new Mapping($nm);
        $mapping->setSequenceID($sid);
        $mapping->setAlignmentDirection($dir);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# ? add remainder of data (cstart, cfinish) ?
    }
    $sth->finish();

# second, pull out the segments

    $sth = $dbh->prepare($squery);

    $sth->execute($contig->getContigID()) || &queryFailed($squery);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rpstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rpstart, $length);
        }
        else {
# what if not? (should not occur at all)
            print STDERR "Missing Mapping instance for ID $mappingid\n";
        }
    }

    $sth->finish();

    $contig->addMapping([@mappings]);
}

sub getContigMappingsForContig {
# adds an array of read-to-read MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;

    unless (ref($contig) eq 'Contig') {
        die "getContigMappingsForContig expects a Contig instance";
    }
                
    return if $contig->hasContigToContigMappings(); # already done

    my $mquery = "select parent_id,mapping_id," .
                 "       cstart,cfinish,direction" .
                 "  from C2CMAPPING" .
                 " where contig_id = ?" .
                 " order by cstart";
print "DEBUG getContigMappingsForContig: \n$mquery\n" if $DEBUG;
 
    my $squery = "select C2CSEGMENT.mapping_id,C2CSEGMENT.cstart," .
                 "       pstart,length" .
                 "  from C2CMAPPING join C2CSEGMENT using (mapping_id)".
                 " where C2CMAPPING.contig_id = ?";

    my $dbh = $this->getConnection();

# 1) pull out the mapping_ids

    my $sth = $dbh->prepare_cached($mquery);

    $sth->execute($contig->getContigID) || &queryFailed($mquery);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    while(my ($pid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# protect against empty contig-to-contig links 
        $dir = 'Forward' unless defined($dir);
# intialise and add parent name and parent ID as sequence ID
        my $mapping = new Mapping();
        $mapping->setMappingName(sprintf("contig%08d",$pid));
        $mapping->setSequenceID($pid);
        $mapping->setAlignmentDirection($dir);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# add remainder of data (cstart, cfinish) ?
    }
    $sth->finish();

# 2) pull out the segments

    $sth = $dbh->prepare($squery);

    $sth->execute($contig->getContigID()) || &queryFailed($squery);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rpstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rpstart, $length);
        }
        else {
# what if not? (should not occur at all)
            print STDERR "Missing Mapping instance for ID $mappingid\n";
        }
    }

    $sth->finish();

    $contig->addContigToContigMapping([@mappings]);
}

sub putMappingsForContig {
# private method, write mapping contents to (C2C)MAPPING & (C2C)SEGMENT tables
    my $dbh = shift; # database handle
    my $contig = shift;

# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# this method inserts mappinmg segments in blocks of 100

# define the queries and the mapping source

    my $mquery; # for insert on the (C2C)MAPPING table 
    my $squery; # for insert on the (C2C)SEGMENT table
    my $mappings; # for the array of Mapping instances

    while (my $nextword = shift) {
        my $value = shift;
        if ($nextword eq "type") {
# for read-to-contig mappings
            if ($value eq "read") {
                $mappings = $contig->getMappings();
                return 0 unless $mappings; # MUST have read-to-contig mappings
                $mquery = "insert into MAPPING " .
	                  "(contig_id,seq_id,cstart,cfinish,direction) ";
                $squery = "insert into SEGMENT " .
                          "(mapping_id,cstart,rstart,length) values ";
            }
# for contig-to-contig mappings
            elsif ($value eq "contig") {
                $mappings = $contig->getContigToContigMappings();
                return 1 unless $mappings; # MAY have contig-to-contig mappings
                $mquery = "insert into C2CMAPPING " .
	                  "(contig_id,parent_id,cstart,cfinish,direction) ";
                $squery = "insert into C2CSEGMENT " .
                          " (mapping_id,cstart,pstart,length) values ";
            }
            else {
                die "Invalid parameter value for ->putMappingsForContig";
            }
        }

        else {
            die "Invalid parameter $nextword for ->putMappingsForContig";
        }
    }

    die "Missing parameter for ->putMappingsForContig" unless $mappings;

    $mquery .= "values (?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($mquery);

    my $contigid = $contig->getContigID();

    #print STDERR "--> putMappingsForContig($contigid)\n";

# 1) the overall mapping

    my $mapping;
    foreach $mapping (@$mappings) {
	#print STDERR $mapping->toString(),"\n";

        my ($cstart, $cfinish) = $mapping->getContigRange();

        my $rc = $sth->execute($contigid,
                               $mapping->getSequenceID(),
                               $cstart,
                               $cfinish,
                               $mapping->getAlignmentDirection()) 
              || &queryFailed($mquery);
        $mapping->setMappingID($dbh->{'mysql_insertid'}) if ($rc == 1);
    }

    #print STDERR "<--\n\n";

# 2) the individual segments (in block mode)

    my $block = 100;
    my $success = 1;
    my $accumulated = 0;
    my $accumulatedQuery = $squery;
    my $lastMapping = $mappings->[@$mappings-1];
    foreach my $mapping (@$mappings) {
# test existence of mappingID
        my $mappingid = $mapping->getMappingID();
        if ($mappingid) {
            my $segments = $mapping->getSegments();
            foreach my $segment (@$segments) {
                my $length = $segment->normaliseOnX(); # order contig range
                my $cstart = $segment->getXstart();
                my $rstart = $segment->getYstart();
                $accumulatedQuery .= "," if $accumulated++;
                $accumulatedQuery .= "($mappingid,$cstart,$rstart,$length)";
            }
        }
        else {
            print STDERR "Mapping ".$mapping->getMappingName().
		" has no mapping_id\n";
            $success = 0;
        }
# dump the accumulated query if a number of inserts has been reached
        if ($accumulated >= $block || ($accumulated && $mapping eq $lastMapping)) {
            $sth = $dbh->prepare($accumulatedQuery); 
            my $rc = $sth->execute() || &queryFailed($squery);
            $success = 0 unless $rc;
            $accumulatedQuery = $squery;
            $accumulated = 0;
        }
    }
    return $success;
}

sub cleanup {
# public method (to be extended with other tests?)
    my $this = shift;
    return &cleanupSegmentTables($this->getConnection(),1);
}

sub cleanupSegmentTables {
# private method: remove redundent mapping references from (C2C)SEGMENT
# (re: housekeeping required after e.g. deleting contigs) 
    my $dbh = shift;
    my $list = shift;

# first we deal with SEGMENT in blocks of 10000, then with C2CSEGMENT 

    my $pf = '';
    my $success = 1;
    while ($success) {
# find mapping IDs in (C2C)SEGMENT which do not occur in (C2C)MAPPING
        my $query = "select distinct(${pf}SEGMENT.mapping_id)" .
                    "  from ${pf}SEGMENT left join ${pf}MAPPING using (mapping_id)".
                    " where ${pf}MAPPING.mapping_id is null limit 10000";

        my $sth = $dbh->prepare_cached($query);

        $sth->execute() || &queryFailed($query);

        my @mappingids;
        while (my ($mappingid) = $sth->fetchrow_array()) {
            push @mappingids, $mappingid;
        }

        print STDERR "To be deleted from ${pf}SEGMENT : ".
	              scalar(@mappingids)." mapping IDs\n" if $list;

        if (@mappingids) {
            $query = "delete from ${pf}SEGMENT where mapping_id in (".
		      join(',',@mappingids).")";
            my $deleted = $dbh->do($query) || &queryFailed($query);
            $success = 0 unless $deleted;
        } 
        elsif (!$pf) {
# MAPPING finished, now do C2CMAPPING
            $pf = "C2C";
        }
        else {
            last;
        }
    }

    return $success;
}

#-----------------------------------------------------------------------------
# methods dealing with generations and age tree
#-----------------------------------------------------------------------------

sub getParentIDsForContig {
# returns a list contig IDs of parents for input Contig based on 
# its reads sequence IDs and the sequence-to-contig MAPPING data
    my $this = shift;
    my $contig = shift; # Contig Instance

    return undef unless $contig->hasReads();

    my $reads = $contig->getReads();

# get the sequenceIDs (from Read instances)

    my @seqids;
    foreach my $read (@$reads) {
        push @seqids,$read->getSequenceID();
    }

# we find the parent contigs in two steps: first we collect all contigs
# in which the sequenceIDs are referenced; subsequently we eliminate
# from that list those contigs which do have a child IN THE LIST, i.e.
# select from the list those which are NOT parent of a child in the list.
# This strategy will deal with split parent contigs as well as "normal" 
# parents and does only rely on the fact that all contigIDs also occur
# as parentIDs except for those in the previous generation for $contig

# step 1: get all (potential) parents

    my $query = "select distinct contig_id from MAPPING"
	      . " where seq_id in (".join(',',@seqids).")";
# add an exclusion of the contig itself if its ID is defined
    if (my $contig_id = $contig->getContigID()) {
        $query .= " and contig_id != $contig_id";
    }

    print STDOUT "query 1 getParentIDsForContig : \n$query\n" if $DEBUG;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my %contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        $contigids{$contig_id}++;
    }

    $sth->finish();

    my @contigids = keys %contigids;

    if (scalar(@contigids)) {

        print STDOUT "Linked contigs found : @contigids\n" if $DEBUG;

# step 2 : remove the parents of the contigs found in step 1 from the list

        $query = "select age,contig_id, parent_id from C2CMAPPING"
	       . " where contig_id in (".join(',',@contigids).")";


        $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        my %ageprofile;
        while (my ($age,$contig_id,$parent_id) = $sth->fetchrow_array()) {
# the parent_id is removed because it is not the last in the chain
            delete $contigids{$parent_id};
            $ageprofile{$contig_id} = $age; 
        }

        $sth->finish();

# ok, the keys of %contigids are the IDs of the possible parents

        @contigids = keys %contigids;

        print STDOUT "Possible parents found : @contigids\n" if $DEBUG;

# However, this list still may contain spurious parents due to 
# misassembled reads in early contigs which are picked up in the
# first step of the search; these are weeded out by selecting on
# the age: true parents have age 0 ("regular" parent) or 1 (split contigs)

        foreach my $contig_id (keys %contigids) {
            next unless defined($ageprofile{$contig_id});
            delete $contigids{$contig_id} if ($ageprofile{$contig_id} > 1);
        }
    }

# those keys left are the true parent(s)

    @contigids = keys %contigids;

    print STDOUT "Confirmed parents found : @contigids\n" if $DEBUG;

    return [@contigids];
}

sub getParentIDsForContigID {
# private,  returns a list of contig IDs of connected contig(s)
# using the C2CMAPPING table
    my $dbh = shift;
    my $contig_id = shift;

    my $query = "select distinct(parent_id) from C2CMAPPING".
	        " where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

    return [@contigids];
}

sub getChildIDsForContigID {
# private, returns a list of contig IDs of child contig(s)
# using the C2CMAPPING table
    my $dbh = shift;
    my $contig_id = shift;

    my $query = "select distinct(contig_id) from C2CMAPPING".
	" where parent_id = ?"; print "$query $contig_id\n";
    
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

print "children @contigids\n";
    return [@contigids];
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
# tree from scractch, use rebuildHistoryTree repeatedly until no more
# updates occur.

    my $dbh = $this->getConnection();

# accumulate IDs of contigs to be updated by recursively querying

    my @updateids;
    my $targetAge = 0;
# the loop starts with contig_ids assumed to be at age 0, top of the tree
    while (@contigids) {

        $targetAge++;
        my $query = "select distinct(CHILD.parent_id)" .
                    "  from C2CMAPPING as CHILD join C2CMAPPING as PARENT" .
                    "    on CHILD.parent_id = PARENT.contig_id" .
	            " where CHILD.contig_id in (".join(',',@contigids).")".
                    "   and PARENT.age < $targetAge".
                    " order by parent_id";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        undef @contigids;
        while (my ($parent_id) = $sth->fetchrow_array()) {
            push @contigids, $parent_id;
	}
# add the contigs of the current generation to the update list
        push @updateids,@contigids;
    }

    return 0 unless @updateids;

# here we have accumulated all IDs of contigs linked to input contig_id
# increase the age for these entries by 1

    my $query = "update C2CMAPPING set age=age+1".
	        " where contig_id in (".join(',',@updateids).")";
    
    my $sth = $dbh->prepare($query);

    my $update = $sth->execute() || &queryFailed($query);

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

    my $contigids = $this->getCurrentContigIDs(singleton=>1);

# step 3: each contig id is the starting point for tree build from the top

    while ($this->buildHistoryTreeForContig(@$contigids)) {
	next;
    }
}

#-------------------------------------------------------------------------

sub getCurrentContigIDs {
# returns a list of contig_ids of some age (default 0, at the top of the tree)
    my $this = shift;

# parse options (default long look-up excluding singleton contigs)

# option singleton : set true for including single-read contigs (default F)
# option short     : set true for doing the search using age column of 
#                    C2CMAPPING; false for a left join for contigs which are
#                    not a parent (results in 'current' generation age=0)
# option age       : if specified > 0 search will default to short method
#                    selecting on age (or short) assumes a complete age tree 

    my $age = 0;
    my $short = 0;
    my $singleton = 0;
    while (my $nextword = shift) {
        if ($nextword eq 'short') {
            $short = shift;
        }
        elsif ($nextword eq 'singleton') {
            $singleton = shift;
        }
        elsif ($nextword eq 'age') {
            $age = shift;
        }
        else {
            die "Invalid parameter $nextword for ->getCurrentContigIDs";
        }
    }

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
	$query = "select distinct(contig_id) from C2CMAPPING where age = $age";
    }
    else {
# generation 0 consists of all those contigs which ARE NOT a parent
# search from scratch for those contigs which are not a parent
        $query = "select CONTIG.contig_id".
                 "  from CONTIG left join C2CMAPPING".
                 "    on CONTIG.contig_id = C2CMAPPING.parent_id".
	         " where C2CMAPPING.parent_id is null";
        $query .= "  and CONTIG.nreads > 1" unless $singleton;
    }

    $query .= " order by contig_id";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    return [@contigids]; # always return array, may be empty
}

sub getCurrentParentIDs {
# returns contig IDs of the parents of the current generation, i.e. age = 1
    my $this = shift;

    my $current = $this->getCurrentContigIDs(@_,short=>0); # force 'long' method

    push @$current,0 unless @$current; # protect against empty array

    my $query = "select distinct(parent_id) from C2CMAPPING" . 
	        " where contig_id in (".join(",",@$current).")" .
		" order by parent_id";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

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

    return [@contigids];
}

#------------------------------------------------------------------------------
# methods dealing with contig TAGs
#------------------------------------------------------------------------------

sub getTagsForContig {
# add Tags to Contig instance; returns number of tags added; undef on error
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getTagsForContig expects a Contig instance" unless (ref($contig) eq 'Contig');

    return 0 if $contig->hasTags(); # only 'empty' instance allowed

    my $cid = $contig->getContigID() || return undef;

    my $dbh = $this->getConnection();

    my $tags = &fetchTagsForContigIDs($dbh,[($cid)]);

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

sub fetchTagsForContigIDs { # TO BE DEVELOPED AND TESTED
# private method
    my $dbh = shift;
    my $cids = shift; # array of seq IDs

# compose query

    my $items = "contig_id,tagtype,systematic_id,pstart,pfinal,strand,comment,"
              . "tagseqname,sequence";

    my $query = "select $items from CONTIGTAG left join TAGSEQUENCE"
              . " using (tag_seq_id)"
	      . " where contig_id in (".join (',',@$cids) .")"
              . "   and deprecated != 'Y'"
              . " order by contig_id";
#print "fetchTagsForContigIDs: $query \n" if $DEBUG;

    my @tag;

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query) && exit;

    while (my @ary = $sth->fetchrow_array()) {
# create a new Tag instance
        my $tag = new Tag('contigtag');

        $tag->setSequenceID      (shift @ary); # contig_id
        $tag->setType            (shift @ary); # tagtype
        $tag->setSystematicID    (shift @ary); # tagname
        $tag->setPosition        (shift @ary, shift @ary); # pstart, pfinal
        $tag->setStrand          (shift @ary); # strand
        $tag->setComment         (shift @ary); # comment
        $tag->setTagSequenceName (shift @ary); # tagseqname
        $tag->setDNA             (shift @ary); # sequence
# add to output array
        push @tag, $tag;
    }

    return [@tag];
}


sub enterTagsForContig {
# public method for test purposes
    my $this = shift;
    my $contig = shift;

    die "getTagsForContigPublic expects a Contig instance" 
     unless (ref($contig) eq 'Contig');

    my $dbh = $this->getConnection();

    return &putTagsForContig($dbh,$contig,1);
}

sub putTagsForContig {
# private method
    my $dbh = shift;
    my $contig = shift;
    my $testexistence = shift;

    return 1 unless $contig->hasTags();
$DEBUG=0;

    my $cid = $contig->getContigID();
print STDOUT "putTagsForContig: contig ID = $cid\n" if $DEBUG;

    return undef unless defined $cid;

# to be completed

    my $ctags = $contig->getTags();
print STDOUT "putTagsForContig: ctags $ctags ".scalar(@$ctags)."\n" if $DEBUG;

    if ($testexistence) {
# test contig instance tags against possible tags in database
print STDOUT "putTagsForContig: testing for existing Tags\n" if $DEBUG;
# construct a hash table for tag instance names

        my $tags = {};
        foreach my $ctag (@$ctags) {
            $tags->{$ctag} = $ctag;
        }

# delete the existing tags from the hash

        my $existingtags = &fetchTagsForContigIDs($dbh,[($cid)]);

        foreach my $etag (@$existingtags) {
            foreach my $ctag (@$ctags) {
                if ($ctag->isEqual($etag)) {
                    delete $tags->{$ctag};
                    last;
		}
            }
        }

# collect the tags left

        my @tags;
        foreach my $key (keys %$tags) {
            push @tags, $tags->{$key};
	}
     

        $ctags = [@tags];
print STDOUT "putTagsForContig: new tags ".scalar(@$ctags)."\n" if $DEBUG;

        foreach my $tag (@$ctags) {
            $tag->writeToCaf(*STDOUT) if $DEBUG;
        }
print STDOUT "putTagsForContig:  end testing for existing Tags\n" if $DEBUG;
#exit; # temporary
    }

#$DEBUG=0;

    return &putTags ($dbh,$ctags,'CONTIGTAG','contig_id',1); # old system

# new system TO BE TESTED

print "enter getTagSequenceIDsForTags $ctags @$ctags\n";     
    my $tagIDhash = &getTagSequenceIDsForTags($dbh,$ctags,1); # autoload = 1
print "tagIDhash: $tagIDhash \n";

#    return;
    return &putContigTags($dbh,$ctags,$tagIDhash);
}


sub putContigTags {
# use as private (generic) method only
    my $dbh = shift;
    my $tags = shift; # ref to array with Tags
    my $tagIDhash = shift; # of missing tag names and sequences

print "ENTER putContigTags ".scalar(@$tags)."\n" if $DEBUG;;

    return undef unless ($tags && @$tags);

# TO BE DEVELOPED USING SEPARATE STORAGE OF systematic_id

    my $query = "insert into CONTIGTAG " # insert ignore ?
              . "(contig_id,tagtype,systematic_id,tag_seq_id,pstart,pfinal,strand,comment) "
              . "values ";

    my $success = 1;
    my $block = 100; # insert block size

    my $accumulated = 0;
    my $accumulatedQuery = $query;
    my $lastTag = $tags->[@$tags-1];

    foreach my $tag (@$tags) {

        my $contig_id        = $tag->getSequenceID();
        next unless $contig_id; # protect against undef seq ID
        my $tagtype          = $tag->getType();
        my $systematic_id    = $tag->getSystematicID() || '';
        my $tagseqname       = $tag->getTagSequenceName() || '';
        my ($pstart,$pfinal) = $tag->getPosition();
        my $tag_seq_id       = $tagIDhash->{$tagseqname} || 0;
        my $strand           = $tag->getStrand();
        $strand =~ s/(\w)\w*/$1/;
        my $comment          = $tag->getComment() || '';
# we quote the comment string because it may contain odd characters
        $comment = $dbh->quote($comment); 

        $accumulatedQuery .= ',' if $accumulated++;
        $accumulatedQuery .= "($contig_id,'$tagtype',";
        $accumulatedQuery .=  "'$systematic_id',";
        $accumulatedQuery .=  "$tag_seq_id,$pstart,$pfinal,'$strand',$comment)";

        if ($accumulated >= $block || $accumulated && $tag eq $lastTag) {

            my $sth = $dbh->prepare($accumulatedQuery);        
            my $rc = $sth->execute() || &queryFailed($accumulatedQuery);

            $success = 0 unless $rc;
            $accumulatedQuery = $query;
            $accumulated = 0;
        }
    }
print "EXIT putTags success $success\n" if $DEBUG;
    return $success; 
}

#------------------------------------------------------------------------------


sub putTags { # TO BE REMOVED
# use as private (generic) method only
    my $dbh = shift;
    my $tags = shift;
    my $table = shift;
    my $seqkeyid = shift;
    my $autoload = shift; # of missing tag names and sequences

print "ENTER putTags $table ".scalar(@$tags)."\n" if $DEBUG;;

    return 0 unless ($tags && @$tags);

# get tag_seq_id using tagseqname for (possible) link with TAGSEQUENCE (reference list)

    my %tagdata;
    foreach my $tag (@$tags) {
        my $tagseqname = $tag->getTagSequenceName();
        $tagdata{$tagseqname}++ if $tagseqname;
    }

# build the tag ID hash keyed on tag name

    my $tagID = {};

    if (my @tagseqnames = keys %tagdata) {
# get tag_seq_id, tagsequence for tagseqnames
        my $query = "select tag_seq_id,tagseqname,sequence from TAGSEQUENCE"
	          . " where tagseqname in ('".join("','",@tagseqnames)."')";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        my $tagSQ = {};

        while (my ($tag_seq_id,$tagseqname,$sequence) = $sth->fetchrow_array()) {
            $tagID->{$tagseqname} = $tag_seq_id;
            $tagSQ->{$tagseqname} = $sequence;
print "TAG SEQUENCE $tagseqname, $tag_seq_id, ".($sequence || '')."\n" if $DEBUG;
        }

        $sth->finish();

# test the sequence against the one specified in the tags

        foreach my $tag (@$tags) {
            my $tagseqname = $tag->getTagSequenceName();
            next unless $tagseqname;
	    my $sequence = $tag->getDNA();
            if (!$tagID->{$tagseqname}) {
                print STDERR "Missing tag name $tagseqname (".
                ($sequence || 'no sequence available').
                ") in TAGSEQUENCE list\n";
                next unless $autoload; # allow sequence to be undefined
#                next unless ($autoload && $sequence);
# add tag name and sequence, if any, to TAGSEQUENCE list
	        my $tag_seq_id = &insertTagSequence($dbh,$tagseqname,$sequence);
         	if ($tag_seq_id) {
                    $tagID->{$tagseqname} = $tag_seq_id;                
                    $tagSQ->{$tagseqname} = $sequence if $sequence;
                }
            }
            elsif ($sequence) {
                unless ($sequence eq $tagSQ->{$tagseqname}) {
                    print STDERR "Tag sequence mismatch for tag $tagseqname : ".
                             "(tag) $sequence  (taglist) $tagSQ->{$tagseqname}\n";
                    next;
		}
	    }
        }
    }
   
# insert in bulkmode

    my $query = "insert into $table ". # insert ignore ?
                "($seqkeyid,tagtype,tag_seq_id,pstart,pfinal,strand,comment) values ";
    $query =~ s/tagtype/tagtype,systematic_id/ if ($table eq 'CONTIGTAG');

    my $success = 1;
    my $block = 100; # insert block size

    my $accumulated = 0;
    my $accumulatedQuery = $query;
    my $lastTag = $tags->[@$tags-1];

    foreach my $tag (@$tags) {

        my $seq_id           = $tag->getSequenceID();
        next unless $seq_id; # protect against undef seq ID
        my $tagtype          = $tag->getType();
        my $systematic_id    = $tag->getSystematicID() || '';
        my $tagseqname       = $tag->getTagSequenceName() || '';
        my ($pstart,$pfinal) = $tag->getPosition();
        my $tag_seq_id       = $tagID->{$tagseqname} || 0;
        my $strand           = $tag->getStrand();
        $strand =~ s/(\w)\w*/$1/;
        my $comment          = $tag->getComment() || '';
# we quote the comment string because it may contain odd characters
        $comment = $dbh->quote($comment) if $comment; 

        $accumulatedQuery .= ',' if $accumulated++;
        $accumulatedQuery .= "($seq_id,'$tagtype',";
        $accumulatedQuery .=  "'$systematic_id'," if ($table eq 'CONTIGTAG');
        $accumulatedQuery .=  "$tag_seq_id,$pstart,$pfinal,'$strand',$comment)";

        if ($accumulated >= $block || $accumulated && $tag eq $lastTag) {

            my $sth = $dbh->prepare($accumulatedQuery);        
            my $rc = $sth->execute() || &queryFailed($accumulatedQuery);

            $success = 0 unless $rc;
            $accumulatedQuery = $query;
            $accumulated = 0;
        }
    }
print "EXIT putTags success $success\n" if $DEBUG;
    return $success; 
}

#------------------------------------------------------------------------------

1;
