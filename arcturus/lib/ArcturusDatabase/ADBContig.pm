package ArcturusDatabase::ADBContig;

use strict;

use Exporter;

use ArcturusDatabase::ADBRead;

use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Contig;
use Mapping;

our @ISA = qw(ArcturusDatabase::ADBRead Exporter);

our @EXPORT = qw(getCurrentContigs);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation via constructor of superclass
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

my $DEBUG;
sub cDebug   { $DEBUG = shift || 1; }
sub cNoDebug { $DEBUG = 0; }

#------------------------------------------------------------------------------
# methods for exporting CONTIGs or CONTIG attributes
#------------------------------------------------------------------------------

sub getContig {
# return a Contig object 
# options: one of: contig_id=>N, withRead=>R, withChecksum=>C, withTag=>T 
# additional : metaDataOnly=>0 or 1 (default 0), noReads=>0 or 1 (default 0)
#              noreadtag=>0, nocontigtags=>0 (or just notags?)

# DO WE NEED:andblocked: include contig from blocked projects TO BE IMPLEMENTED ?
    my $this = shift;
    my %options = @_;

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
        $query .= "  from CONTIG, MAPPING, SEQ2READ, READS "
               . " where CONTIG.contig_id = MAPPING.contig_id "
               . "   and MAPPING.seq_id = SEQ2READ.seq_id "
               . "   and SEQ2READ.read_id = READS.read_id "
	       . "   and READS.readname like ? ";
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

    $this->logQuery('getContig',$query,@values) if $options{debug};

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

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return undef unless defined($contig);

    return $contig if ($options{metaDataOnly} || $options{metadataonly});

# get the reads for this contig with their DNA sequences and tags

    my $notags = $options{notags} || 0;

    $this->getReadsForContig($contig,notags=>$notags);

# get read-to-contig mappings (and implicit segments)

    $this->getReadMappingsForContig($contig);

# get contig-to-contig mappings (and implicit segments)

    $this->getContigMappingsForContig($contig);

# get contig tags

    $this->getTagsForContig($contig) unless $notags;

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

    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    my ($sequence, $quality);

    if (my @ary = $sth->fetchrow_array()) {
	($sequence, $quality) = @ary;
    }

    $sth->finish();

    if (defined($sequence)) {
        $sequence = uncompress($sequence);
        unless ($sequence) {
	    print STDERR "uncompress FAILED in contig_id=$contig_id : ";
            print STDERR "undefined sequence\n";
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
	    print STDERR "uncompress FAILED in contig_id=$contig_id : ";
            print STDERR "undefined quality (sequence length $length)\n";
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

sub hasContig {
# test presence of contig with given contig identifier; return 0 or contig id
    my $this = shift;
    my %options = @_;

    $options{metaDataOnly} = 1;

    my $contig = $this->getContig(%options);

    return 0 unless $contig;

    return $contig->getContigID();
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
print ">getParentContigsForContig: searching parents from scratch\n" if $DEBUG; 
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

    my $childids = &getChildIDsForContigID($dbh,$contig_id,notnull=>1);

# build the Contig instances (metadata only) and add to the input Contig object

    foreach my $child_id (@$childids) {
        my $child = $this->getContig(ID=>$child_id, metaDataOnly=>1);
print ">getChildContigsForContig: contig $child for id=$child_id\n" if $DEBUG;
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
    my $noload  = $options{noload} || 0;

# do the statistics on this contig, allow zeropoint correction
# the getStatistics method also checks and orders the mappings 

    $contig->getStatistics(2);

    my $contigname = $contig->getGap4Name();

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
                                    metaDataOnly=>1); # current generation?
# if not found try the readname hash
    $previous = $this->getContig(withChecksum=>md5(sort keys %seqids),
                                 metaDataOnly=>1) unless $previous;

# if a matching contig is found, test that it is in the current generation

    my $message;
    if ($previous) {
        $message = "Contig $contigname matches contig "
                 .  $previous->getContigName();
# the read name hash or the sequence IDs hash does match: test generation
        unless ($this->isCurrentContigID($previous->getContigID())) {
            $message .= " in an older generation; ";
            $previous = 0; # reject the match
	}
    }

    if ($previous) {
# pull out previous contig mappings and compare them one by one with contig's
        $this->getReadMappingsForContig($previous);
        if ($contig->isSameAs($previous)) {
# add the contig ID to the contig
            my $contigid = $previous->getContigID();
            $contig->setContigID($contigid);
            $message = "Contig $contigname is identical to contig "
                     .  $previous->getContigName();
# 'prohibitparent' is an option used by assignReadAsContigToProject
            return 0,$message if $options{prohibitparent};
 
# the next block allows updates to contigs already in the database

            unless ($noload) {
 
# (re-)assign project, if a project is explicitly defined

                if ($project && $setprojectby eq 'project') {
# shouldn't this have an extra switch?
                    my $newproject = $project->getProjectID();
                    my $oldproject = $previous->getProject();
# determine old project for contig, generate message system?
print STDERR "putContig: line 449 assignContigToProject "
           .  $project->getProjectName()."\n";
# what about message? get project allocated for contig, test if pid changed
                    $this->assignContigToProject($previous,$project);
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
        $message .= "but is not identical; ";
    }

# okay, the contig is new; find out if it is connected to existing contigs

    $contig->setContigID(); # clears ID to ensure correct exec of next

    my $parentids = $this->getParentIDsForContig($contig);

# pull out mappings for those previous contigs, if any

    my @originalprojects;
    $message = "$contigname " unless $message;
    if ($parentids && @$parentids) {
# compare with each previous contig and return/store mapings/segments
        $message .= "has parent(s) : @$parentids ";
# 'prohibitparent' is an option used by assignReadAsContigToProject
# to avoid loading single-read contigs when the read is an assembled read
        if ($options{prohibitparent}) {
            return 0,"$message  ('prohibitparent' option active)";
        }
        my @rejectids; # for spurious links
        foreach my $parentid (@$parentids) {
            my $parent = $this->getContig(ID=>$parentid,metaDataOnly=>1);
            unless ($parent) {
# protection against missing parent contig from CONTIG table
                print STDERR "Parent $parentid for $contigname not found ".
		             "(possibly corrupted MAPPING table?)\n";
                next;
            }
            $this->getReadMappingsForContig($parent);
#$contig->setDEBUG();
            $contig->setArcturusDatabase($this); # re: link recovery
            my ($linked,$deallocated) = $contig->linkToContig($parent);
# add parent to contig, later import tags from parent(s)
            my $previous = $parent->getContigName();
            if ($linked) {
                $contig->addParentContig($parent); # re: Tag transport
	    }
            else {
                $message .= "; empty link detected to $previous";
# TO BE TESTED: what if the link is spurious? Go back to 
# getParentIDsForContig and find new parents by masking with this parent
# then add new parents at the end of the current list
                push @rejectids, $parentid;
                my $exclude = join ',',@rejectids;
                my $newids = $this->getParentIDsForContig($contig,exclude=>$exclude);
# determine if any new contig ids are added to the list
                my $parentidhash = {};
                foreach my $pid (@$parentids) {
                    $parentidhash->{$pid}++;
		}
# find the newly added parent IDs, if any, which do not occur in the parent ID hash 
                foreach my $pid (@$newids) {
                    next if $parentidhash->{$pid};
                    $message .= "; parent $pid added";
                    push @$parentids,$pid;
                }

	    }
            $message .= "; $deallocated reads deallocated from $previous".
  		        "  (possibly split contig?)\n" if $deallocated;
        }

# inherit the tags

#        $contig->inheritTags(excludeTagType=>'REPT') if $inheritTags;
        $contig->inheritTags() if $inheritTags;

# determine the project_id unless it's already specified (with options)

        unless ($setprojectby eq 'project' || $setprojectby eq 'none') {
            my %poptions;
            $poptions{lockcheck} = 1; # always in loading mode
            my ($projects,$msg) = $this->inheritProject($contig,$setprojectby,
                                                        %poptions);
            if ($projects) {
# a project has been determined; the first in the list is the chosen project
                $project = shift @$projects;
                @originalprojects = @$projects; # original parent projects
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

	if ($noload && $contig->hasContigToContigMappings()) {
	    $message .= "Contig ".$contig->getContigName.":\n";
	    foreach my $mapping (@{$contig->getContigToContigMappings}) {
	        $message .= ($mapping->assembledFromToString || "empty link\n");
	    }
	}
        elsif ($noload) {
	    $message .= "Contig ". $contig->getContigName
	              . " has no valid contig-to-contig mappings\n";
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

    my $user_id = $this->getArcturusUser();

    my $contigid = &putMetaDataForContig($dbh,$contig,$readhash,$user_id);

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
        my ($success,$msg) = $this->assignContigToProject($contig,$project,
                                                            unassigned=>1);
        $message .= "; assigned to project ";
        $message .=  $project->getProjectName() if $success;
        $message .= "ID = 0 (failed assignment: $msg)" unless $success;
        $project = 0 unless $success;
# compose messages for owners of contigs which have changed project
        my $messages = &informUsersOfChange($contig,$project,\@originalprojects);
        foreach my $message (@$messages) {
            $this->logMessage(@$message); # owner, projects, text
        }

    }

    return $contigid, $message;
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
#                                               lockcheck=>$lockcheck);
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
print ">inheritProjectProject: ".$testproject->getProjectID()." ".
$testproject->getProjectName()." contigs: @$contigids\n" if $DEBUG;
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
print ">inheritProject: Score $score ($largestscore)\n" if $DEBUG;
            if (!$largestscore || $score > $largestscore) {
                $largestscore = $score;
                $project = $testproject;
            }          
        }
# add chosen project upfront in the return list
        unshift @original,$project;
        return ([@original],"$imodel score $largestscore");
    }
    elsif (scalar(@projects) == 1) {
# add chosen project upfront in the return list
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
print STDOUT "Diagnostic message: enter ADBContig->informUsersOfChange "
           . "($newpid, ".$oldproject->getProjectID()
           . ", ".$oldproject->getProjectName().")\n";
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
    my $userid = shift;

    my $query = "insert into CONTIG "
              . "(gap4name,length,ncntgs,nreads,newreads,cover,userid"
              . ",origin,created,readnamehash) "
              . "VALUES (?,?,?,?,?,?,?,?,now(),?)";

    my $sth = $dbh->prepare_cached($query);

    my @data = ($contig->getGap4Name(),
                $contig->getConsensusLength() || 0,
                $contig->hasParentContigs(),
                $contig->getNumberOfReads(),
                $contig->getNumberOfNewReads(),
                $contig->getAverageCover(),
                $userid,
                $contig->getOrigin(),
                $readhash);

    my $rc = $sth->execute(@data) || &queryFailed($query,@data); 

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
# this function requires DBA privilege
    my $this = shift;
    my $identifier = shift;
    my %options = @_;

    $identifier = $this->{lastinsertedcontigid} unless $identifier;

    return 0,"Missing contig ID" unless defined($identifier);

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

    unless ($nreads == 1 && $options{noparentcheck}) {
# only single-read contigs can be exempted from this protection
        my $pquery = "select parent_id from C2CMAPPING where parent_id = $cid";

        my $isparent = $dbh->do($pquery) || &queryFailed($pquery);

        if (!$isparent || $isparent > 0) {
# this also exits on failed query as safeguard
            return 0, "Contig $identifier is, or may be, a parent "
                    . "and can't be deleted";
	}
    }

# here we finally test for ambiguity not found by parent test

    return 0,"Ambiguous contig $description ($row)" if ($row > 1);

# safeguard: contig may not belong to a project and have checked 'out' status

# the next line deletes the contig from a project (or not)

    my $confirm = $options{confirm};

# for some reason I have to call this private function on the fully specified
# class; importing unlinkContigID using Exporter in ADBProject doesn't work as
# expected ...
  
    my $user = $this->getArcturusUser();

    my ($status,$message) = ArcturusDatabase::ADBProject::unlinkContigID($dbh,$cid,$user,$confirm); 

    return (0,"Contig $identifier cannot be deleted: $message") unless $status;

    return (1,"Contig $description can be deleted") unless $confirm; # preview
    
# proceed only if contig has been unlinked; now delete from the primary tables

    my $report = '';
    my $success = 1;
    foreach my $table ('CONTIG','MAPPING','C2CMAPPING','CONSENSUS') {
        my $query = "delete from $table where contig_id = $cid"; 
        my $deleted = $dbh->do($query) || &queryFailed($query);
        $success = 0 if (!$deleted && $table eq 'CONTIG');
        $report .= "No delete done from $table for contig_id = $cid\n"
        unless (($deleted+0) || $table eq 'C2CMAPPING');
    }

# if noparentcheck active, the deleted contig can be a (single-read) parent

    if ($nreads == 1 && $options{noparentcheck}) {
        my $query = "delete from C2CMAPPING where parent_id = $cid"; 
        my $deleted = $dbh->do($query) || &queryFailed($query);
        $success = 0 unless $deleted;
        $report .= "No delete done from C2CMAPPING for parent_id = $cid\n"
        unless ($deleted+0);
    }

# remove the redundent entries in SEGMENT and C2CSEGMENT

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
            print STDERR "Missing Mapping instance for ID $mappingid\n";
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

    unless (ref($contig) eq 'Contig') {
        die "getContigMappingsForContig expects a Contig instance";
    }
                
    return if $contig->hasContigToContigMappings(); # already done

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
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# add remainder of data (cstart, cfinish) ?
# do an age consistence check for this mapping
        $generation = $age unless defined ($generation);
        next if ($generation == $age);
        print STDOUT "Inconsistent generation in links for contig $cid\n";
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
            print STDERR "Missing Mapping instance for ID $mappingid\n";
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
    my %option = @_;

# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# this method inserts mappinmg segments in blocks of 100

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

    die "Missing 'type' parameter for ->putMappingsForContig" unless $mappings;

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

# 2) the individual segments (in block mode)

    my $block = 100;
    my $success = 1;
    my $accumulated = 0;
    my $accumulatedQuery = $squery;
    my $lastMapping = $mappings->[@$mappings-1];
    foreach my $mapping (@$mappings) {
# test existence of segments
        next unless $mapping->hasSegments();
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

    my $mappings = $contig->getContigToContigMappings();

    my $dbh = $this->getConnection();
    return &updateMappingsForContig($dbh,$mappings,$options{replace});
}

sub updateMappingsForContig {
# private, update the mapped contig range
    my $dbh = shift;
    my $mappings = shift || return;
    my $replace = shift;

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
 
    unless (&markAsVirtualParent($this->getConnection(),$c_id)) {
        return 0, "Failed to update database";
    }

    return 1, "OK";
}

sub markAsVirtualParent {
# enter a record in C2CMAPPING for parent_id pointing to contig_id = 0
# this virtual link removes the contig from the current contig list
    my $adb = shift;
    my $parent_id = shift || return 0;

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

    return &putMappingsForContig($adb,$contig,%options);
}

#-----------------------------------------------------------------------------
# housekeeping
#-----------------------------------------------------------------------------

sub cleanupMappings {
# public method (to be extended with other tests?)
    my $this = shift;
    my %options = @_;

    my $preview = $options{confirm} ? 0 : 1; # specify confirm explicitly

    my $fullscan = $options{fullscan} || 0;

    my $dba = $this->getConnection();

    my $report = &cleanupMappingTables($dba,$preview,$fullscan);

    if ($options{includesegments} || $options{fullscan}) {
        $report .= &cleanupSegmentTables($dba,$preview);
    }

    return $report;
}

sub cleanupMappingTables {
# private method: remove redundent mapping references from MAPPING
# (re: housekeeping required after e.g. deleting contigs)
    my $dbh = shift;
    my $preview = shift;
    my $full = shift; # include testing parent IDs

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
        $report .= sprintf ("%6d",($rc+0)) . " mapping IDs ";
        $report .= "to be " if $preview;
        $report .= "have been " unless $preview;
        $report .= "removed from ${table}SEGMENT\n";
# long list option? preview = 2
        if ($preview > 1) {
# long list option: return a list of all mapping IDs affected (TO BE DONE)
        }
    }

    return $report;
}

sub deleteContigToContigMapping {
# remove a specified C2C mapping
    my $dbh = shift;
# input: mapping ID, contig ID & parent ID, in that order

    my $delete = "delete from C2CMAPPING"
	       . " where mapping_id = ?"
               . "   and contig_id = ?"
	       . "   and parent_id = ?";

    my $sth = $dbh->prepare_cached($delete);

    my $row = $sth->execute(@_) || &queryFailed($delete,@_);

    return ($row+0);
}

sub repairContigToContigMappings {
# replace contig to contig mappings which are different from those in database
    my $this = shift;
    my $contig = shift;
    my %options = @_;

# contig ID must be defined

    my $contig_id = $contig->getContigID();

    return 0,"Missing contig ID" unless $contig_id;

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
#print "deletemappings  @deletemappings  $message\n" if $DEBUG;
    foreach my $existingmapping (@deletemappings) {
        next if $options{nodelete};
        my $parent_id = $existingmapping->getSequenceID();
        my $mapping_id = $existingmapping->getMappingID();
        $message .= "To be deleted: $contig_id - $parent_id ($mapping_id) ..";
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
        if (&putMappingsForContig($dbh,$contig,type=>'contig')) {
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

sub oldgetParentIDsForContig {
# returns a list contig IDs of parents for input Contig based on 
# its reads sequence IDs and the sequence-to-contig MAPPING data
# search from scratch for new contigs (no ID!) and existing contigs
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

    my $contig_id = $contig->getContigID();

    my $query = "select distinct contig_id from MAPPING"
	      . " where seq_id in (".join(',',@seqids).")";
# add an exclusion of the contig itself if its ID is defined
    $query .= " and contig_id < $contig_id" if $contig_id;

$DEBUG = 0;
print STDOUT ">oldgetParentIDsForContig query 1: \n$query\n" if $DEBUG;

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

print STDOUT ">oldgetParentIDsForContig: Linked contigs found : @contigids\n" if $DEBUG;

# step 2 : remove the parents of the contigs found in step 1 from the list
# THERE MAY BE A PROBLEM HERE: INVESTIGATE!

        $query = "select age,contig_id, parent_id from C2CMAPPING"
	       . " where contig_id in (".join(',',@contigids).")";
print STDOUT ">oldgetParentIDsForContig: $query \n" if $DEBUG;

        $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        my %ageprofile;
        while (my ($age,$contig_id,$parent_id) = $sth->fetchrow_array()) {
# the parent_id is removed because it is not the last in the chain
print STDOUT ">oldgetParentIDsForContig: $age,$contig_id,$parent_id\n" if $DEBUG; 
            delete $contigids{$parent_id};
            $ageprofile{$contig_id} = $age; 
        }

        $sth->finish();

# ok, the keys of %contigids are the IDs of the possible parents

        @contigids = keys %contigids;

print STDOUT ">oldgetParentIDsForContig: Possible parents found : @contigids\n" if $DEBUG;

# However, this list still may contain spurious parents due to 
# misassembled reads in early contigs which are picked up in the
# first step of the search; these are weeded out by selecting on
# the age: true parents have age 0 ("regular" parent) or 1 (split contigs)
# NOTE: this applies only to newly added contigs, i.e. without contig_id

        unless ($contig_id) {
            foreach my $contig_id (keys %contigids) {
                next unless defined($ageprofile{$contig_id});
                delete $contigids{$contig_id} if ($ageprofile{$contig_id} > 1);
	    }
        }
    }

# those keys left are the true parent(s)

    @contigids = keys %contigids;

print STDOUT ">oldgetParentIDsForContig: Confirmed parents found : @contigids\n" if $DEBUG;
exit if $DEBUG;

    return [@contigids];
}

sub getParentIDsForContig {
# returns a list contig IDs of parents for input Contig based on 
# its reads sequence IDs and the sequence-to-contig MAPPING data
# search from scratch for new contigs (no ID!) and existing contigs
    my $this = shift;
    my $contig = shift; # Contig Instance
    my %options = @_;   # for exclude list

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

    my $contigID = $contig->getContigID(); # may be defined or not

# do a blocked search (to deal with very large contigs)

    my $blocksize = 10000;

    my $dbh = $this->getConnection();

    my %contigids;
    while (my $block = scalar(@seqids)) {

        $block = $blocksize if ($block > $blocksize);

        my @block = splice @seqids, 0, $block;

        my $range = join ',',sort {$a <=> $b} @block;

        my $query = "select distinct contig_id from MAPPING"
	          . " where seq_id in ($range)";
# add an exclusion of the contig itself (and younger) if its ID is defined
        $query .= " and contig_id < $contigID" if $contigID;
# add an exclusion clause for any contigs listed with options
        if (my $excludelist = $options{exclude}) {
# NOTE: the list should consist of comma-separated contig IDs
            $excludelist =~ s/^\s*|\s*$//g; # remove leading/trailing blanks
            if ($excludelist =~ /[^\,\d]/) { # other than comma and numbers
                my @exclude = split /\D+/,$excludelist;
                $excludelist = join ',',@exclude;
	    }
            $query .= " and contig_id not in ($excludelist)";
print "Diagnostic message: exclude list active:\nQ: $query\n" if $options{debug};
        }

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($contig_id) = $sth->fetchrow_array()) {
            $contigids{$contig_id}++;
        }

        $sth->finish();
    }

    my @contigids = keys %contigids;

    if (scalar(@contigids)) {

$DEBUG=0;
print STDOUT ">getParentIDsForContig: Linked contigs found : @contigids\n" if $DEBUG;
        my $ageoffset = 0;
        push @contigids,$contigID if $contigID;

# step 2 : remove the parents of the contigs found in step 1 from the list

        my $query = "select age,contig_id, parent_id from C2CMAPPING"
        	  . " where contig_id in (".join(',',@contigids).")";
print STDOUT ">getParentIDsForContig: $query \n" if $DEBUG;

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        my %ageprofile;
        while (my ($age,$contig_id,$parent_id) = $sth->fetchrow_array()) {
# the parent_id is removed because it is not the last in the chain
print STDOUT ">getParentIDsForContig: $age,$contig_id,$parent_id\n" if $DEBUG;
            if ($contigID && $contig_id == $contigID) {
                $ageoffset = $age;
                next;
            } 
            delete $contigids{$parent_id};
            $ageprofile{$contig_id} = $age;
        }
print STDOUT "ageoffset $ageoffset \n" if $DEBUG;

        $sth->finish();

# ok, the keys of %contigids are the IDs of the possible parents

        @contigids = keys %contigids;

print STDOUT ">getParentIDsForContig: Possible parents found : @contigids\n" if $DEBUG;

# However, this list still may contain spurious parents due to 
# misassembled reads in early contigs which are picked up in the
# first step of the search; these are weeded out by selecting on
# the age: true parents have age 0 ("regular" parent) or 1 (split contigs)
# NOTE: this applies only to newly added contigs, i.e. without contig_id
#       when testing on older generation contigs apply age offset 

        foreach my $contig_id (keys %contigids) {
            next unless defined($ageprofile{$contig_id});
            if ($ageprofile{$contig_id} > 1 + $ageoffset) {
                delete $contigids{$contig_id};
            }
	}
    }

# those keys left are the true parent(s)

    @contigids = keys %contigids;

print STDOUT ">getParentIDsForContig: Confirmed parents found : @contigids\n" if $DEBUG;
#exit if $DEBUG;

    return [@contigids];
}

sub getParentIDsForContigID {
# private,  returns a list of contig IDs of connected contig(s)
# using the C2CMAPPING table; i.e for contigs already loaded
    my $dbh = shift;
    my $contig_id = shift;

    my $query = "select distinct(parent_id) from C2CMAPPING".
	        " where contig_id = ?";

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
# private, returns a list of contig IDs of child contig(s) using C2CMAPPING table
    my $dbh = shift;
    my $contig_id = shift;
    my %options = @_;

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
    my %options = @_;  print "options @_\n";

    my $linktype = $options{linktype} || 0;

# linktype = 0 for all parents (default)
#          = 1 for parents with links listed in C2CMAPPING
#          = 2 for parents without such links

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
# the result list has all single read contigs contigs without links
        my $temporaryitems = "contig_id integer not null,"
	                   . "project_id integer not null";
        my $create = "create temporary table absentparent "
                   . "($temporaryitems, key(contig_id)) as "
                   . "select CONTIG.contig_id from CONTIG left join C2CMAPPING"
                   . "   on (CONTIG.contig_id = C2CMAPPING.parent_id)"
                   . " where CONTIG.nreads = 1 "
		   . "   and C2CMAPPING.parent_id is null";

        my $rw = $dbh->do($create) || &queryFailed($create);

my $TEST=0; if ($TEST) {
print "rw=$rw\n";
my $testquery = "select contig_id from absentparent";
my $tsth = $dbh->prepare_cached($testquery);
$tsth->execute() || &queryFailed($testquery);
while (my $pid = $tsth->fetchrow_array()) {push @pids, $pid;}
print "IDs found: @pids\n";
undef @pids;
}

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

#   my $contigids = $this->getCurrentContigIDs(singleton=>1);
    my $contigids = &getCurrentContigs($dbh,singleton=>1);

# step 3: each contig id is the starting point for tree build from the top

    while ($this->buildHistoryTreeForContig(@$contigids)) {
	next;
    }
}

sub updateMappingAge {
# private, redefine the age for a contig-to-contig mapping
    my $dbh = shift;
    my $cid = shift;
    my $age = shift;

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

    $query .= " order by contig_id";

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
    my %options = @_;

    my $dbh = $this->getConnection();

    $options{short} = 0; # force 'long' method
    my $current = &getCurrentContigs($dbh,%options);

    push @$current,0 unless @$current; # protect against empty array

    my $query = "select distinct(parent_id) from C2CMAPPING" . 
	        " where contig_id in (".join(",",@$current).")" .
		" order by parent_id";

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

sub getContigIDsForReadNames {
# returns a list of contigids (in generation 0) for input readname(s)
    my $this = shift;
    my $reads = shift; # array ref

    my $dbh = $this->getConnection();

    my $subselect = "select CONTIG.contig_id "
                  . "  from CONTIG left join C2CMAPPING "
                  . "    on (CONTIG.contig_id = C2CMAPPING.parent_id)"
		  . " where C2CMAPPING.parent_id is null";

    my $query = "select distinct CONTIG.contig_id,gap4name,readname"
              . "  from READS,CONTIG,SEQ2READ,MAPPING"
              . " where READS.read_id = SEQ2READ.read_id"
              . "   and SEQ2READ.seq_id = MAPPING.seq_id"
              . "   and READS.readname in ('".join("','",@$reads)."')"
              . "   and CONTIG.contig_id = MAPPING.contig_id"
	      . "   and CONTIG.contig_id in ($subselect)";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my $outputlist = []; # array of arrays
    while (my @ary = $sth->fetchrow_array()) {
        push @$outputlist,[@ary];
    }
    $sth->finish();

    return $outputlist;
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
        $relation = "=>" if ($key =~ /^(minimum|after)/);
        $relation = "=<" if ($key =~ /^(maximum|before)/);
# get the contig property
        my $property;
        $property = "length"  if ($key =~ /^(min|max)imumlength$/);
        $property = "nreads"  if ($key =~ /^(min|max)imumnumberofreads$/);
        $property = "ncntgs"  if ($key =~ /^(min|max)imumnumberofparents$/);
        $property = "cover"   if ($key =~ /^(min|max)imumcover$/);
        $property = "created" if ($key =~ /^created(before|after)$/);
        $property = $key unless $property; # e.g. origin
# add the clause to the query
        $query .= " and $property $relation ?";
        push @data,$options{$key}; 
    }

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
# returns a list of contig_id,generation of all contigs related to input contig ID
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

sub getTagsForContig {
# add Tags to Contig instance; returns number of tags added; undef on error
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getTagsForContig expects a Contig instance" 
        unless (ref($contig) eq 'Contig');

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

sub fetchTagsForContigIDs {
# private method
    my $dbh = shift;
    my $cids = shift; # reference to array of contig IDs

    die "fetchTagsForContigIDs expects an array as parameter"
    unless (ref($cids) eq 'ARRAY');

# compose query (note, this query uses the UNION construct to cater
# for the case tag_id > 0 tag_seq_id = 0)

    my $tagitems = "contig_id,TAG2CONTIG.tag_id,cstart,cfinal,strand,comment,"
	         . "tagtype,systematic_id,tagcomment,CONTIGTAG.tag_seq_id";
    my $seqitems = "tagseqname,sequence";

    my $query = "select $tagitems,$seqitems"
              . "  from TAG2CONTIG, CONTIGTAG, TAGSEQUENCE"
              . " where TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
              . "   and CONTIGTAG.tag_seq_id = TAGSEQUENCE.tag_seq_id"
	      . "   and contig_id in (".join (',',@$cids) .")"
#              . "   and deprecated != 'Y'" # no table column now
              . " union "
              . "select $tagitems,'',''"
              . "  from TAG2CONTIG, CONTIGTAG"
              . " where TAG2CONTIG.tag_id = CONTIGTAG.tag_id"
              . "   and CONTIGTAG.tag_seq_id = 0" # explicitly undefined sequence
	      . "   and contig_id in (".join (',',@$cids) .")"
#              . "   and deprecated != 'Y'" # no table column now
              . " order by contig_id";

print ">fetchTagsForContigIDs: retrieve tags for @$cids \n" if $DEBUG;

    my @tag;

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query) && exit;

    while (my @ary = $sth->fetchrow_array()) {
# create a new Tag instance
        my $tag = new Tag('contigtag');

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

print ">fetchTagsForContigIDs tags found: ".scalar(@tag)."\n" if $DEBUG;

    return [@tag];
}

# ---------------

sub enterTagsForContig {
# public method for test purposes
    my $this = shift;
    my $contig = shift;
    my %options = @_;

$DEBUG=$options{debug};

    die "enterTagsForContigPublic expects a Contig instance"
     unless (ref($contig) eq 'Contig');

    my $dbh = $this->getConnection();

    return &putTagsForContig($dbh,$contig,1);
}

sub putTagsForContig {
# private method
    my $dbh = shift;
    my $contig = shift;
    my $testexistence = shift;

    return 1 unless $contig->hasTags(); # no tags

    my $cid = $contig->getContigID();

print STDOUT ">putTagsForContig: contig ID = $cid\n" if $DEBUG;

    return undef unless defined $cid; # missing contig ID

# get the tags and test for valid tag info (at least a tag type defined)

    my $ctags = $contig->getTags();

print STDOUT ">putTagsForContig: ctags $ctags ".scalar(@$ctags)."\n" if $DEBUG;

# construct a hash table for tag instance names

    my $tags = {};
    foreach my $ctag (@$ctags) {
        my $tagtype = $ctag->getType(); # must have a tag type
        unless ($tagtype) {
            my $tagcomment = $ctag->getTagComment() || "no description";
            print STDERR "Invalid tag in contig $cid: missing tagtype "
                       . "($tagcomment)\n";
            next;
        }
        $tags->{$ctag} = $ctag;
    }

# test contig instance tags against possible tags (already) in database

    if ($testexistence && keys %$tags) {

print STDOUT ">putTagsForContig: testing for existing Tags\n" if $DEBUG;

        my $existingtags = &fetchTagsForContigIDs($dbh,[($cid)]);

# delete the existing tags from the hash

        foreach my $etag (@$existingtags) {
print STDOUT "\nTesting existing tag\n" if $DEBUG;
$etag->dump(*STDOUT,1) if $DEBUG;
            foreach my $key (keys %$tags) {
                my $ctag = $tags->{$key};
                if ($ctag->isEqual($etag)) {
                    delete $tags->{$ctag};
                    last;
		}
            }
        }

print STDOUT ">putTagsForContig:  end testing for existing Tags\n" if $DEBUG;

    }

# collect the tags left

    my @tags;
    foreach my $key (keys %$tags) {
        my $ctag = $tags->{$key};
        push @tags, $ctag;
    }
    $ctags = [@tags];

print STDOUT ">putTagsForContig: new tags ".scalar(@tags)."\n" if $DEBUG;

    return 0 unless @tags; # no tags because of tag errors
    
    &getTagSequenceIDsForTags($dbh,$ctags,1); # autoload active (-> ADBRead)

    &getTagIDsForTags($dbh,$ctags);

#return 0,"DEBUG abort" if $DEBUG;

    return &putContigTags($dbh,$ctags);
}


sub getTagIDsForTags {
# use as private method only: get tag IDs for tags with undefined tag_id
    my $dbh = shift;
    my $tags = shift; # ref to array with Tags

print STDOUT ">getTagIDsForTags for ".scalar(@$tags)." tags\n" if $DEBUG;;

    return undef unless ($tags && @$tags);

# first we test if the combination tagtype and tagcomment/systematic ID exists
# we use the UNION construct to test cases where either tagcommenmt or the
# systematic ID is null; we also cater for undefined data values (-> 'is not null') 

    my $query = "select tag_id,systematic_id,tag_seq_id"
              . "  from CONTIGTAG"
              . " where tagtype = ?"
              . "   and tagcomment is not null" # these three conditions ensure
              . "   and tagcomment != ''"       # that no line is returned should
              . "   and tagcomment = ?"         # the bind value be NULL or '' 
              . " union "
              . "select tag_id,systematic_id,tag_seq_id"
              . "  from CONTIGTAG"
              . " where tagtype = ?"
              . "   and systematic_id is not null and systematic_id = ?"
              . "   and (tagcomment is null or tagcomment = '')"
	      . " limit 1";

    my $sth = $dbh->prepare($query);

    my %sIDupdate;
    foreach my $tag (@$tags) {

# retrieve contig tag information for combination tagtype & tagcomment/systematic_id

        my $tagtype = $tag->getType(); # already tested in putTagsForContig
        my $tagcomment = $tag->getTagComment();
        my $systematic_id = $tag->getSystematicID();
        my @data = ($tagtype,$tagcomment,$tagtype,$systematic_id);

# pull out existing data

        my $rc = $sth->execute(@data) || &queryFailed($query,@data);

        if ($rc > 0) {
            my ($tag_id,$systematic_id,$tag_seq_id) = $sth->fetchrow_array();
print STDOUT ">getTagIDsForTags: tag ID $tag_id  tag_seq ID $tag_seq_id ($systematic_id)\n" if $DEBUG;
# now a) test consistency of tag ID and tag seq ID
            my $existingtagid = $tag->getTagID();
            if ($existingtagid && $existingtagid != $tag_id) {
                print STDERR "Inconsistent tag ID ($existingtagid ".
                             "vs $tag_id for '$tagcomment')\n";
            }
            $tag->setTagID($tag_id);
            my $existingseqid = $tag->getTagSequenceID();
            if ($existingseqid && $existingseqid != $tag_seq_id) {
                print STDERR "Inconsistent tag sequence ID ($existingseqid ".
                             "vs $tag_seq_id for '$tagcomment')\n";
            }
            $tag->setTagSequenceID($tag_seq_id);
# and flag an update to sys ID
            $sIDupdate{$tag}++ unless $systematic_id;
$tag->dump(*STDOUT,1) if $DEBUG;
	}
        $sth->finish();
    }

    $sth->finish();

# second, for those tags that do not now have an ID, we generate a new entry
# in the CONTIGTAG table

    my $insert = "insert into CONTIGTAG "
               . "(tagtype,systematic_id,tag_seq_id,tagcomment) "
	       . "values (?,?,?,?)";

    $sth = $dbh->prepare_cached($insert);        

    my $failed = 0;

    foreach my $tag (@$tags) {
# skip a tag if the ID is already defined
        next if $tag->getTagID();
print STDOUT ">getTagIDsForTags: inserting into CONTIGTAG \n" if $DEBUG;
        my $tagtype        = $tag->getType();
        next unless $tagtype; # invalid tag
        my @data = ($tagtype,
                    $tag->getSystematicID(),
                    $tag->getTagSequenceID() || 0,
                    $tag->getTagComment());
        my $rc =  $sth->execute(@data) || &queryFailed($insert,@data);

        if ($rc > 0) {
            my $tag_id = $dbh->{'mysql_insertid'};
            $tag->setTagID($tag_id);
print STDOUT ">getTagIDsForTags: ID $tag_id added\n" if $DEBUG;
        }
        else {
            $failed++;
	}
    }

    $sth->finish();

# finally update systematic IDs, if any

    if (keys %sIDupdate) {

        my $update = "update CONTIGTAG set systematic_id = ? where tag_id = ?";

        my $sth = $dbh->prepare_cached($update);

        foreach my $tag (@$tags) {
            next unless $sIDupdate{$tag};
#            my $tag_id = $tag->getTagID();
#            my $systematic_id = $tag->getSystematicID();
            my @binddata = ($tag->getTagID(),$tag->getSystematicID());
print STDOUT ">getTagIDsForTags: systematic ID added (@binddata)\n" if $DEBUG; 
            $sth->execute(@binddata) || &queryFailed($update,@binddata);
	}
    }

print STDOUT ">getTagIDsForTags: EXIT getTagIDsForTags $failed\n" if $DEBUG;;
    return $failed;
}


sub putContigTags {
# use as private method only
    my $dbh = shift;
    my $tags = shift; # ref to array with Tags

print STDOUT ">putContigTags for ".scalar(@$tags)." tags\n" if $DEBUG;

    return undef unless ($tags && @$tags);

    my $query = "insert into TAG2CONTIG " # insert ignore ?
              . "(contig_id,tag_id,cstart,cfinal,strand,comment) "
              . "values (?,?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($query);        

    my $missed  = 0;
    my $success = 0;

    foreach my $tag (@$tags) {

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

        my @data = ($contig_id,$tag_id,$cstart,$cfinal,$strand,$comment || undef);

        my $rc = $sth->execute(@data) || &queryFailed($query,@data);

        $missed++ unless $rc;
        $success++ if $rc;
    }

print STDOUT ">putContigTags: EXIT putContigTags success $success missed $missed\n" if $DEBUG;

    return $success; 
}

#------------------------------------------------------------------------------

1;
