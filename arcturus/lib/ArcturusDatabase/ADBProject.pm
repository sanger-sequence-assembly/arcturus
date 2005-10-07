package ArcturusDatabase::ADBProject;

use strict;

use ArcturusDatabase::ADBContig;

use Project;

use Contig;

use Mapping;

our @ISA = qw(ArcturusDatabase::ADBContig);

use ArcturusDatabase::ADBRoot;

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#------------------------------------------------------------------------------
# methods dealing with Projects
#------------------------------------------------------------------------------

sub getProject {
    my $this = shift;
    my %options = @_;

    my $itemlist = "PROJECT.project_id,PROJECT.name,PROJECT.assembly_id,"
                 . "PROJECT.updated,PROJECT.owner," #?locked not included here
		 . "PROJECT.created,PROJECT.creator,PROJECT.comment";

    my $query = "select $itemlist from PROJECT ";

    my @data;
    my $assembly = 0;
    my $binautoload = 1;
    my $usecontigid = 0;
    my $lookingforbin = 0;
    while (my $nextword = shift) {
        my $datum = shift;
        return (0,"Missing parameter value") unless defined ($datum);
# this should usually be the only item given
        if ($nextword eq "project_id") {
            $lookingforbin = 1 unless $datum; # ID = 0
            $query .= (@data ? "and " : "where ");
            $query .= "project_id = ? ";
            push @data, $datum;
        }
        elsif ($nextword eq "assembly_id") {
            $query .= (@data ? "and " : "where ");
            $query .= "assembly_id = ? ";
            push @data, $datum;
            $assembly = $datum;
        }
        elsif ($nextword eq "assemblyname") {
# if a where clasue already exists, create space for the join clause
            my $join = "join ASSEMBLY using (assembly_id) where "
                     . "ASSEMBLY.name like ? ";
            if ($query =~ s/where/$join and/) {
                unshift @data, $datum;
            }
            else {
                $query .= $join;
                push @data, $datum;
            }
            $assembly = $datum;            
	}
        elsif ($nextword eq "projectname") {
            $lookingforbin = 1 if ($datum =~ /^bin$/i);
            $query .= (@data ? "and " : "where ");
            $query .= "PROJECT.name like ? "; # re_ allowing assembly name
            push @data, $datum;
	}
        elsif ($nextword eq "comment") {
            $query .= (@data ? "and " : "where ");
            $query .= "comment like ? ";
            push @data, $datum;
	}
# if contig_id or contigname is used, it should be the only specification 
        elsif ($nextword eq "contigname") { 
            return (0,"only contig name can be specified") if ($query =~ /where/);
            $query =~ s/comment/comment,CONTIG.contig_id/;
            $query .= ",CONTIG,MAPPING,SEQ2READ,READS"
                    . " where CONTIG.project_id = PROJECT.project_id"
                    . "   and MAPPING.contig_id = CONTIG.contig_id"
                    . "   and SEQ2READ.seq_id = MAPPING.seq_id"
                    . "   and READS.read_id = SEQ2READ.read_id"
		    . "   and READS.readname = ? ";
            push @data, $datum;
            $usecontigid = 1;
print "getProject:$query '@data' \n";
        }
# if an array of contig_ids is used, it should be the only specification
        elsif ($nextword eq "contig_id") {
            return (0,"only contig_id can be specified") if ($query =~ /where/);
            $query =~ s/comment/comment,CONTIG.contig_id/;
            $query .= "join CONTIG using (project_id)"
                    . " where CONTIG.contig_id ";
            if (ref($datum) eq 'ARRAY') {
                if (scalar(@$datum) > 1) {
                    $query .= "in (".join(',',@$datum).") ";
                }
                elsif (scalar(@$datum) == 1) {
                    $query .= "= ? ";
                    push @data, $datum->[0];
	        }
                else {
                    return (0,"Empty array for contig IDs");
		}
            }
            else {
                $query .= "= ? ";
                push @data, $datum;
	    }
            $usecontigid = 1;
        }
# determine the project based on a number of project_ids? 
        elsif ($nextword eq "binautoload") {
	    $binautoload = $datum;
	}
        else{
            return (0,"Invalid keyword '$nextword'");     
	}
    }

    $query .= "order by assembly_id,project_id";

#    $this->logQuery('getProject',$query,@data);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@data) || &queryFailed($query,@data) || return undef;

# cater for the case of more than one project !

    my @projects;
    undef my %projects;
    while (my @ary = $sth->fetchrow_array()) {
# prevent multiple copies of the same project in case contig_id is added
        my $project = $projects{$ary[0]};
        unless ($project) {
            $project = new Project();
	    $projects{$ary[0]} = $project;
            push @projects,$project;
            $project->setProjectID(shift @ary);
            $project->setProjectName(shift @ary);
            $project->setAssemblyID(shift @ary);
            $project->setUpdated(shift @ary);
            $project->setOwner(shift @ary);
            $project->setCreated(shift @ary);
            $project->setCreator(shift @ary);
            $project->setComment(shift @ary);
# assign ADB reference
            $project->setArcturusDatabase($this);
        }
        $project->addContigID($ary[$#ary]) if $usecontigid;
    }

    $sth->finish();

    return ([@projects],"OK") if @projects;

# if no project found, test if it's the bin project we're after
# e.g. if we search on contig ID, unallocated contigs (pid=0) require the bin
# to exist in order to return a project

    if ($binautoload && ($usecontigid || $lookingforbin)) {
# test if there is a project BIN or bin in assembly 0
        my ($project,$msg) = $this->getProject(assembly_id=>0,
                                               projectname=>'BIN',
                                               binautoload=>0);
        return ($project,$msg) if $project;
# no, it does not exist; test for existence of 'bin' project
        ($project,$msg) = $this->getProject(assembly_id=>0,
                                            projectname=>'bin',
                                            binautoload=>0);
        return ($project,$msg) if $project;
# also this one doesn't exist, create it      
        &createBinProject($dbh,$this->getArcturusUser(),'bin');
        return $this->getProject(assembly_id=>0,
                                 projectname=>'bin',
                                 binautoload=>0);
    }
    else {
        return 0,"unknown project or assembly";
    }
}

sub createBinProject {
# private method to create the project BIN in assembly 0
    my $dbh = shift;
    my $user = shift || 'arcturus';
    my $name = shift || 'BIN';

# create the special BIN project in assembly 0 and project ID 0
#  (if it already exists, no changes are made but an error is generated)

# first create a new project row for assembly-id = 0

    my $pid = &insertProject($dbh,0,$name,$user,'arcturus','autogenerated');

    return unless ($pid);

# then update the table and set the row to project ID = 0

    my $query = "update PROJECT set project_id=0 where project_id=$pid";

    $dbh->do($query) || &queryFailed($query);
}

sub insertProject {
# private method: add a new project row to the database
    my $dbh = shift;

# compose query and input parameters

    my $pitems = "assembly_id,name,owner,created,creator,comment";
    my $values = "?,?,?,now(),?,?";

# if no project ID specified (position 4) use autoincrement mode, else add ID 
# to query (one cannot enter project 0 in this way; see createBinProject)

    if (defined($_[5])) {
        $pitems .= ",project_id";
        $values .= ",?";
    }

    my $query = "insert into PROJECT ($pitems) VALUES ($values)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@_) || &queryFailed($query,@_);

    $sth->finish();

    return 0 unless ($rc && $rc == 1);
    
    my $projectid = $dbh->{'mysql_insertid'};

    return $projectid;
}

sub putProject {
# public method: add a new project to the database
    my $this = shift;
    my $project = shift;

    die "putProject expects a Project instance as parameter"
	unless (ref($project) eq 'Project');

    my @data   = ($project->getAssemblyID() || 0,
                  $project->getProjectName() || 'undefined',
                  $this->getArcturusUser() || 'unknown',
                  $this->getArcturusUser() || 'arcturus',
                  $project->getComment() || undef,
                  $project->getProjectID() );

    my $projectid = &insertProject($this->getConnection(),@data);

    $project->setProjectID($projectid) if $projectid;

    return $projectid;
}

sub deleteProject {
# remove project for project ID / name, but only if no associated contigs
    my $this = shift;
    my %options = @_;

# upgrade to include assembly_id/assembly name

    my $tquery;
    my $dquery;
    my $report;
# project_id must be specified
    if (defined (my $value = $options{project_id})) {
        $tquery = "select contig_id from CONTIG join PROJECT"
                . " using (project_id)"
	        . " where PROJECT.project_id = $value";
        $dquery = "delete from PROJECT where project_id = $value ";
        $report = "Project $value";
    }
    else {
        return 0,"Invalid parameters: missing project_id"; 
    }
# if assembly is specified it acts as an extra check constraint
    if (defined (my $value = $options{assembly_id})) {
         $tquery .= " and assembly_id = $value";
         $dquery .= " and assembly_id = $value";
         $report .= " in assembly $value";
    }
# add user/lockstatus restriction (to be completely sure)
    my $user = $this->getArcturusUser();
    $dquery .= " and (locked is null or owner='$user')";

    my $dbh = $this->getConnection();

# safeguard: project_id may not have contigs assigned to it

    my $hascontig = $dbh->do($tquery) || &queryFailed($tquery);

    if (!$hascontig || $hascontig > 0) {
# also exits on failed query
        return 0,"$report has $hascontig contigs and cannot be deleted";
    }
    
# test if the project is locked by acquiring a lock myself

    my ($status,$msg) = $this->acquireLockForProjectID($options{project_id});

    return 0,$msg unless $status; # belongs to someone else

# ok, delete from the primary tables

    my $nrow = $dbh->do($dquery) || &queryFailed($dquery);

    return 0,"$report was NOT deleted" unless $nrow; # failed query

    return 0,"$report cannot be deleted or does not exists" unless ($nrow+0);
    
    return 1,"$report deleted";
}

#------------------------------------------------------------------------------
# assigning contigs to a project and reads (as singleton contig) to a project
#------------------------------------------------------------------------------

sub assignContigToProject {
# public method for allocating one contig to a project
    my $this = shift;
    my $contig = shift;
    my $project = shift;

    unless (ref($contig) eq 'Contig') {
        die "assignContigToProject expects a Contig instance as parameter";
    }

    unless (ref($project) eq 'Project') {
        die "assignContigToProject expects a Project instance as parameter";
    }

    my $contig_id  = $contig->getContigID()   || return (0,"Missing data");
    my $project_id = $project->getProjectID() || return (0,"Missing data");

    return &linkContigIDsToProjectID($this->getConnection(),
                                     $this->getArcturusUser(),
                                     [($contig_id)],
                                     $project_id,
                                     @_); # transfer of possible switches
}

sub assignContigsToProject {
# public method for allocating several contigs to a project
    my $this  = shift;
    my $contigs = shift; # array ref for Contig instances
    my $project = shift; # Project instance

    unless (ref($contigs) eq 'ARRAY' && ref($contigs->[0]) eq 'Contig') {
        die "assignContigsToProject expects an Array of Contig instances "
          . "as parameter";
    }

    unless (ref($project) eq 'Project') {
        die "assignContigToProject expects a Project instance as parameter";
    }

    my @contigids;
    foreach my $contig (@$contigs) {
        my $contig_id = $contig->getContigID();
        return (0,"Missing or invalid contig ID(s)") unless $contig_id;
	push @contigids, $contig->getContigID();
    }

    my $project_id = $project->getProjectID() || return (0,"Missing data");

    return &linkContigIDsToProjectID($this->getConnection(),
                                     $this->getArcturusUser(),
                                     [@contigids],
                                     $project_id,
                                     @_); # transfer of possible switches
}

sub linkContigIDsToProjectID {
# private method : allocate contig IDs to project ID
    my $dbh = shift;
    my $user = shift;
    my $contig_ids = shift || return undef;
    my $project_id = shift || return undef;
    my $forced = shift;

# protect against an empty list

    return (0,"The contig list is empty") unless @$contig_ids;

# check if project specified can be modified by the user

    my $donotreleaselock;

    my ($islocked,$lockedby) = &getLockedStatus($dbh,$project_id);
# lock also overrides the owner of the project (if different from lockedby)
# (to acquire a lock requires ownership or overriding privilege): test lockedby
    if ($islocked && $lockedby ne $user) {
        return (0,"Project $project_id is locked by user $lockedby");
    }
    elsif ($islocked && $lockedby eq $user) {
        $donotreleaselock = 1;
    }
# acquire a lock on the project
    elsif (!&setLockedStatus($dbh,$project_id,$user,1)) {
        return (0,"Failed to acquire lock on project $project_id");
    }

# now assign the contigs to this project, except for those contigs
# which have been assigned to (other) projects; the 'forced' flag
# overrides this restriction, BUT even then contigs are re-assigned
# from their current project to the new one only if their current project
# is not locked by someone else (this cannot be overridden; you have to
# have those contigs unlocked first by their owners).
# However, we are using a join of CONTIG and PROJECT for consistence testing
# and nothing will happen if the project_id in CONTIG doesn't exist in PROJECT
# Therefore, we also use a left join 

# THIS QUERY SUCKS! investigate!

    my $message = '';

    my $query = "update CONTIG,PROJECT"
              . "   set CONTIG.project_id = $project_id"
              . " where CONTIG.project_id = PROJECT.project_id"
              . "   and CONTIG.contig_id in (".join(',',@$contig_ids).")"
              . "   and CONTIG.project_id != $project_id"
#	      . "   and (PROJECT.locked is null or PROJECT.lockedby = '$user')";
	      . "   and (PROJECT.locked is null or PROJECT.owner = '$user')";
    $query   .= "   and CONTIG.project_id = 0" unless $forced;

    my $nrow = $dbh->do($query) || &queryFailed($query) || return undef;

# compare the number of lines changed with input contigIDs

    $message .= ($nrow+0)." Contigs were (re-)assigned to project $project_id\n" if ($nrow+0);

#print STDOUT "linkContigIDsToProjectID :\n$query\nrows: $nrow lockedby $lockedby\n";
#return 0,$message;

# return if all expected entries have been updated

    if ($nrow == scalar(@$contig_ids)) {
        &setLockedStatus($dbh,$project_id,$user,0) unless $donotreleaselock;
        return (1,$message);
    }

# not all selected contigs have been re-allocated; try for missing projects

    $query = "update CONTIG set CONTIG.project_id = $project_id"
           . " where CONTIG.contig_id in (".join(',',@$contig_ids).")"
           . "   and CONTIG.project_id != $project_id"
	   . "   and CONTIG.project_id not in"
           .      " (select PROJECT.project_id from PROJECT)";

    my $mrow = $dbh->do($query) || &queryFailed($query) || return undef;

    $message .= ($mrow+0). " Contigs were assigned to project $project_id"
              . " which had invalid original project IDs\n" if ($mrow+0);

# return if all expected entries have been updated

    if ($nrow+$mrow == scalar(@$contig_ids)) {
        &setLockedStatus($dbh,$project_id,$user,0) unless $donotreleaselock;
        return (1,$message);
    }

# not all expected rows have changed; do a test on the remaining ones

    $query = "select CONTIG.contig_id,CONTIG.project_id,"
           .        "PROJECT.locked,PROJECT.owner"
           . "  from CONTIG join PROJECT using (project_id)"
           . " where CONTIG.contig_id in (".join(',',@$contig_ids).")"
	   . "   and CONTIG.project_id != $project_id"
           . " UNION "
           . "select CONTIG.contig_id,CONTIG.project_id,"
           .        "'missing','project'"
           . "  from CONTIG left join PROJECT using (project_id)"
           . " where CONTIG.contig_id in (".join(',',@$contig_ids).")"
	   . "   and CONTIG.project_id != $project_id"
	   . "   and PROJECT.project_id is null";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query) && return undef;

    my $na = 0; # not assigned
    while (my ($cid,$pid,$locked,$owner) = $sth->fetchrow_array()) {
        $message .= "- contig $cid is in project $pid ";
        $message .= "(owned by user $owner)\n" unless $locked;
        $message .= "(owned by user $owner; locked by [$owner])\n" if $locked;
        $na++;
    }

    $sth->finish();

    &setLockedStatus($dbh,$project_id,$user,0) unless $donotreleaselock;

    $message .= "$na contigs were NOT assigned to project $project_id\n" if $na;

    $message .= ($na ? (scalar(@$contig_ids)-$na) : "All")
	      . " contigs specified are assigned to project $project_id\n";
    
    return (2,$message);
}

sub assignReadAsContigToProject {
# public method for allocating reads to a project as single read contig
    my $this = shift;
    my $project = shift; # obligatory
    my %roption = (shift,shift); # read specification (read_id OR readname)
    my %poption = @_; # project options

    die "assignReadAsContigToProject expects a Project instance as parameter"
        unless (ref($project) eq 'Project');

# get the read for this readname

    $roption{version} = 0;

    my $read = $this->getRead(%roption);

    my $identifier = ($roption{read_id} || $roption{readname} || 0);

    return 0,"unknown read : $identifier" unless (ref($read) eq 'Read');

    $identifier = $read->getReadName();

# apply our own clipping if so specified

    my $minimumlength = $poption{minimumlength};
    $minimumlength = 50 unless $minimumlength;

    if (my $qc = $poption{qualityclip}) {
        my $qr = $read->qualityClip(threshold=>$qc);
        return 0,"read $identifier is of insufficient length: $qr "
                ."($minimumlength) for quality clip level $qc" 
        unless ($qr >= $minimumlength);
    }

# check if it is a valid read by getting the read_id and quality ranges

    my $lqleft  = $read->getLowQualityLeft();
    my $lqright = $read->getLowQualityRight();

    return 0,"incomplete read $identifier : missing quality range"
        unless (defined($lqleft) && defined($lqright));

# check read does not belong to any contig

    return 0,"read $identifier is an assembled read"
        unless $this->isUnassembledRead(read_id=>$read->getReadID());

# check if it meets the minimum quality range

    my $contiglength = $lqright - $lqleft + 1;
    return 0,"read $identifier is of insufficient length: $contiglength "
            ."($minimumlength)" unless ($contiglength >= $minimumlength);

# create a new contig with a single read

    my $contig = new Contig();

    $contig->addRead($read);

# add the mapping in as quality range

    my $mapping = new Mapping($read->getReadName());

    $mapping->putSegment($lqleft,$lqright,$lqleft,$lqright);

    $contig->addMapping($mapping);

# Load into database for project

    $poption{setprojectby} = 'project';
# the new contig may not have any parent contigs (else it is an assembled read)
    $poption{prohibitparents} = 1;

    return $this->putContig($contig,$project,%poption); # transfer of noload
}

#------------------------------------------------------------------------------

sub unlinkContigID {
# private remove link between contig_id and project_id (set project_id to 0)
    my $dbh = shift;
    my $contig_id = shift || return undef;
    my $user = shift;
    my $confirm = shift;

# a contig can only be unlinked (assigned to project_id = 0) by the owner
# of the project or a user with overriding privilege on unlocked project

# THIS QUERY SUCKS! redo, allowing changes by lockedby 

    my ($islocked,$lockedby) = &getLockedStatus($dbh,$contig_id,1);
    return (0,"Contig $contig_id is locked by user $lockedby") if $islocked;

    return (1,"OK") unless $confirm; # preview option   

    my $query = "update CONTIG join PROJECT using (project_id)"
              . "   set CONTIG.project_id = 0"
              . " where CONTIG.contig_id = ?"
	      . "   and PROJECT.locked is null";

    my $sth = $dbh->prepare_cached($query);

    my $success = $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    $sth->finish();

    return ($success,"OK") if $success;

# report an unexpected lock status for the contig_id 

    return (0,"Contig $contig_id was (unexpectedly) found to be locked");
}

#------------------------------------------------------------------------------
# assigning reads to projects using the queuing system
#------------------------------------------------------------------------------

sub createReadTransferRequest {
# enter a request for project allocation of read as single-read contig to the queue 
    my $this = shift;
    my $r_id = shift; # read ID
    my $p_id = shift; # project ID
    my $user = shift;

# each request is tested against other (active) requests in the queue
# for consistency; each request is then tested for validity, i.e. can be executed

    return 0,"invalid parameters ($r_id,$p_id)" unless ($r_id && $p_id);

    $user = $this->getArcturusUser() unless $user;

    my ($dbh,$sth,$query);

# open database

    $dbh = $this->getConnection();

# test if the request is not already present (include refused requests)

    if (my $r = &existsReadTransferRequest($dbh,$r_id,$p_id,1)) {
        my $status = ($r->[3] eq 'approved' ? 1 : 0);
        return $status,"request $r->[0] was created on $r->[2] by $r->[1] ($r->[3])";
    }

# enter the new request with status 'pending'; get its request ID

    my $ritems = "read_id,new_project_id,creator,created";

    $query = "insert into READTRANSFERREQUEST ($ritems) values(?,?,?,now())";

    $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($r_id,$p_id,$user) || &queryFailed($query,$r_id,$p_id,$user);

    $sth->finish();

    return 0,"failed to add request to queue" unless ($rc && $rc == 1);
    
    my $rqid = $dbh->{'mysql_insertid'}; # request ID

# now check if the request is valid: is the read not requested by someone else
# and is it an unassembled read; if not set status to 'refused', else to 'approved'

    my $message = '';
    my $returnstatus = $rqid;
    my $status = 'approved';

    $query = "select new_project_id,creator"
           . "  from READTRANSFERREQUEST"
           . " where read_id = ? and status = 'approved'";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($r_id) || &queryFailed($query,$rqid) || return 0,"failed to verify";

    if (my($project_id,$creator) = $sth->fetchrow_array()) {
        $message = "read $r_id is requested by $creator for project $project_id";
        $status = "refused";
        $returnstatus = 0;
    }
    $sth->finish();

    unless ($this->isUnassembledRead(read_id=>$r_id)) {
        $message = "read $r_id is an assembled read";
        $status = "refused";
        $returnstatus = 0;
    }

# update the status of the new request: we do a multi-table update to catch the
# possibility that we use a non-existent project ID; in that case no row is returned

    $rc = &updateReadTransferRequest($dbh,$rqid,$status,$p_id);

    if ($rc+0) {
# the update was successful; message depends on status
        $message = "request $rqid was created for user $user" if $returnstatus;
    }
    else {
# the update failed: status value could not be changed and remains 'pending'
        $message .= " & " if $message;
        $message .= "possibly invalid project ID?";
        $message = "failed to complete request ($message)";
        $returnstatus = 0;
    }

# finally, add a comment if return status = 0 (no checks here)

    &addReadTransferRequestComment($dbh,$rqid,$message) unless $returnstatus;
#    &addTransferRequestComment($dbh,'READ',$rqid,$message) unless $returnstatus;

# the 'status' field in the record can have 3 values: 'approved','rejected' or 'pending'
# the latter occurs when the last update fails, either because of a SQL error (unlikely)
# or because of an invalid project ID used. Thus, 'pending' could be treated as rejected

    return $returnstatus,$message;
}

sub cancelReadTransferRequest {
# cancel an existing read transfer request identified by read_id and project_id
    my $this = shift;
    my $r_id = shift || 0; # read ID
    my $p_id = shift || 0; # project ID

# put user verification in this section; user ID (or user 'role') should match

    my $user = $this->getArcturusUser();

    my $dbh = $this->getConnection();

# does the request exist?

    my $req = &existsReadTransferRequest($dbh,$r_id,$p_id);

    return 0, "no active request exists" unless $req;

    my $description = "$req->[0] (read $r_id -> project $p_id)";

# do the users match?

    unless ($user eq $req->[1] || &userRoles($user,$req->[1])) {
        return 0, "request $description belongs to user '$req->[1]'";
    }

# preview option (no other entry in parameter list)

    return 1, "request $description is to be cancelled" unless shift;
    
# ok, do the update

    my $rc = &updateReadTransferRequest($dbh,$req->[0],'cancelled');

    return 1, "request $description was cancelled" if ($rc+0);

    return 0, "failed to cancel request $description";
}

sub processReadTransferRequests {
# execute all pending transfers, optionally for a specified user
    my $this = shift;
    my %options = @_;

# first, create a list of pending requests

    my $dbh = $this->getConnection();

    my $query = "select request_id,read_id,new_project_id"
              . "  from READTRANSFERREQUEST"
              . " where status = 'approved'";
    $query   .= "   and creator = '$options{user}'" if $options{user};

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my %readrequest;
    my %readtransfer;
    my %project;
    while (my ($req,$rid,$pid) = $sth->fetchrow_array()) {
        $readtransfer{$rid} = $pid;
        $readrequest{$rid} = $req;
        $project{$pid}++;
    }

    $sth->finish();

# get the projects

    foreach my $pid (keys %project) {
        my ($plist,$msg) = $this->getProject(project_id=>$pid);
        $project{$pid} = $plist->[0] if ($msg eq 'OK');
        print STDERR "WARNING: unkown project $pid\n" unless ($msg eq 'OK');
    }

# ok, go and do it

    my $report = "There are ".scalar(keys %readtransfer)." transfer requests\n";

    my $success = 0;
    foreach my $rid (keys %readtransfer) {
        my $pid = $readtransfer{$rid}; 
        $report .= "read $rid is to be moved to project $pid ..";
        if ($options{confirm}) {
            my ($cid,$msg) = $this->assignReadAsContigToProject($project{$pid},read_id=>$rid);
            if ($cid) {
                $success++;
                $report .= ".. done (contig $cid)";
  	        print STDERR "failed to update queue entry $readrequest{$rid} for read $rid\n"
                    unless &updateReadTransferRequest($dbh,$readrequest{$rid},'done');
	    }
	    else {
                $report .= ".. FAILED ($msg)";
  	        print STDERR "failed to update queue entry $readrequest{$rid} for read $rid\n"
                    unless &updateReadTransferRequest($dbh,$readrequest{$rid},'pending');
            }
	}
	else {
            my ($cid,$msg) = $this->assignReadAsContigToProject($project{$pid},read_id=>$rid,
                                                                               noload=>1);
            $report .= ".. rejected $msg" unless $cid;
            $report .= ".. to be confirmed" if $cid;
        }
        $report .= "\n";
    }

    return $success,$report;
}

sub findReadTransferRequest {
# public: return the status and possibly comment for the input request
    my $this = shift;
    my $rid = shift; # read ID
    my $pid = shift; # project ID

# requests with status 'done' or 'cancelled' are ignored because they could be present
# more than once: returns data of active request only ('pending','approved','refused')

    my $output = &existsReadTransferRequest($this->getConnection(),$rid,$pid,1);

    return 1,$output if @$output;

    return 0; 
}

#---------------------------------------------------------------------------------

sub existsReadTransferRequest {
# private: test existence of an active request
    my $dbh = shift;
    my $rid = shift; # read ID
    my $pid = shift; # project ID

    my @svalues = ('pending','approved');
    push @svalues,'refused' if shift; # add refused option with extar parameter

    my $query = "select request_id, creator, created, status, comment"
              . "  from READTRANSFERREQUEST"
              . " where read_id = ? and new_project_id = ?"
              . "   and status in ('". join("','",@svalues) ."')"
              . " order by status limit 1";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($rid,$pid) || &queryFailed($query,$rid,$pid);  

    my @output = $sth->fetchrow_array();

    $sth->finish();

    return (@output ? [@output] : 0);
}

sub updateReadTransferRequest {
# private: change request status
    my $dbh = shift;
    my $rid = shift; # request ID
    my $status = shift; # new status
    my $pid = shift; # project ID, optional

    my $query = "update READTRANSFERREQUEST,PROJECT"
              . "   set READTRANSFERREQUEST.status = '$status'"
	      . " where READTRANSFERREQUEST.request_id = $rid";

# invoke multi-table update if project ID is specified

    if (defined($pid)) {
        $query .= " and READTRANSFERREQUEST.new_project_id = PROJECT.project_id"
	       .  " and PROJECT.project_id = $pid";
    }
    else {
	$query =~ s/\,PROJECT//; # perhaps could be left out?
    }

    my $rc = $dbh->do($query) || &queryFailed($query);
}

sub addReadTransferRequestComment {
# OBSOLETE, to be replaced by addTransferRequestComment
# private: update comment field for transfer request
    my $dbh = shift;
    my $rid = shift;
    my $text = shift;

    return unless $text;

    my $query = "update READTRANSFERREQUEST set comment = ? where request_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($text,$rid) || &queryFailed($query,$text,$rid);
}

#------------------------------------------------------------------------------
# assigning contigs to projects using the queuing system
#------------------------------------------------------------------------------

sub createContigTransferRequest {
# public; create a contig transfer request if it does not already exist
    my $this = shift;
    my $c_id = shift; # contig ID
    my $p_id = shift; # project ID
    my %options = @_;

# each request is tested against other (active) requests in the queue for
# consistency; each request is then tested for validity, i.e. whether it
# can be executed

    return 0,"invalid parameters ($c_id,$p_id)" unless ($c_id && $p_id);

    my $user = $options{user};

    $user = $this->getArcturusUser() unless $user;
print STDOUT "ENTER createContigTransferRequest $c_id, $p_id, $user\n";

    my ($dbh,$sth,$query);

# open database

    $dbh = $this->getConnection();

# test if a request to move the contig is not already present

    my %foptions = (contig_id=>$c_id,rstatus=>'pending');

    my $rids = &findContigTransferRequestIDs($dbh,%foptions);

    if (my $r_id = $rids->[0]) {
# get the details
        my $data = &fetchContigTransferRequest($dbh,$r_id);

        unless ($data->[3] == $p_id) {
# contig is involved in another request
            return 0, "contig $c_id is not available: is requested for "
                    . "project $data->[3] by user $data->[4]";
        }
# this request is already queued
        return 2, "existing request $r_id was created on $data->[5] "
                . "by $data->[4] (current status: $data->[10], $data->[8])";
    }

# test if the contig is in the latest generation

print STDOUT "testing contig $c_id\n";
    unless ($this->isCurrentContigID($c_id)) {
        return 0,"contig $c_id is not in the current generation";
    }

# test current project against target project 
print STDOUT "testing project against $p_id\n";

    my ($cpid,$lock) = $this->getProjectIDforContigID($c_id); # current project ID

    if ($cpid == $p_id) {
        return 0,"contig $c_id is already allocated to project $p_id";
    }  

# has the user privilege on its current project or its target project or both?


    my @opns = split /\W/,$options{open}; # optional: open project names
print STDOUT "open projects: @opns\n";

    my $open = '';
    foreach my $openprojectname (@opns) {
        my $projectlist = $this->getProjectIDsForProjectName($openprojectname);
	return 0,"invalid project name $openprojectname" unless @$projectlist;
        foreach my $project (@$projectlist) {
            $open .= " " if $open;
            $open .= $project->[0];
        }
    }
print STDOUT "open project test string '$open'\n";

#$user = "ajax";
#$user = "ibg";
    my ($cpp,$cown) = &hasPrivilegeOnProject($dbh,$cpid,$user); # current project
print STDOUT "privilege $user,$cpid  : $cpp, $cown\n";
    $cpp = 1 if (!$cpp && $open && $open =~ /\b$cpid\b/); # override open project
print STDOUT "privilege $user,$cpid  : $cpp, $cown\n";
    my ($tpp,$town) = &hasPrivilegeOnProject($dbh,$p_id,$user); # target  project
print STDOUT "privilege $user,$p_id  : $tpp, $town\n";
    $tpp = 1 if (!$tpp && $open && $open =~ /\b$p_id\b/); # override open project
print STDOUT "privilege $user,$p_id  : $tpp, $town\n";

    unless ($cpp || $tpp) {
        return 0,"user $user has no privilege for a transfer from project "
                ."nr $cpid to project nr $p_id";
    }
  
    return 2,"transfer of contig to be confirmed" unless $options{confirm};

    print STDOUT "Entering request ... \n";
# OK, enter the new request with rstatus 'pending'; get its request ID

    my $rqid = 0;

    unless ($rqid = &enterContigTransferRequest($dbh,$user,$c_id,$cpid,$p_id)) {
        return 0, "failed to insert request; possibly invalid "
                . "contig ID or project ID?";
    }

# the request has been added with rstatus 'pending'
    print STDOUT "Insert successfull privileges: $cpp $tpp \n";

    my $message;
    if ($cpp && $tpp) {
# user has privilege on both the current and the target projects
        my $rc = &updateContigTransferRequest($dbh,$rqid,$user,'approved');
    }
    elsif ($tpp) {
# user has no privilege on the project the contig is currently in
        $message = "waiting for approval by $cown";
        $this->sendApprovalRequestToOwner($cown,$c_id,$cpid,$user); #..
    }
    else {
# user has no privilege on the target project
        $message = "waiting for approval by $town";
        $this->sendApprovalRequestToOwner($town,$c_id,$cpid,$user); #..
    }

# update the comment of the new request: we do a multi-table update to catch
# the possibility that we use a non-existent project ID; in that case no row 
# is returned

    &addTransferRequestComment($dbh,'CONTIG',$rqid,$message,$p_id) if $message;

# exit with happy message

    return 1, "request $rqid was created for user $user";
}

sub sendApprovalRequestToOwner {
    my $this = shift;
    print STDOUT "sendApprovalRequestToOwner: @_ TO BE COMPLETED\n";
}
sub grantContigTransferRequest {
# public
    my $this = shift;
    my $c_id = shift || 0; # contig ID
    my $p_id = shift || 0; # project ID
}

sub cancelContigTransferRequest {
# public
    my $this = shift;
    my $c_id = shift || 0; # contig ID
    my $p_id = shift || 0; # project ID

# put user verification in this section; user ID (or user 'role') should match

    my $user = $this->getArcturusUser();

    my $dbh = $this->getConnection();

# does the request exist?

    my $req = &existsContigTransferRequest($dbh,$c_id,$p_id);

    return 0, "no active request exists" unless $req;

    my $description = "$req->[0] (contig $c_id -> project $p_id)";

# do the users match?

    unless ($user eq $req->[1] || &userRoles($user,$req->[1])) {
        return 0, "request $description belongs to user '$req->[1]'";
    }

# preview option (no other entry in parameter list)


    return 1, "request $description is to be cancelled" unless shift;
    
# ok, do the update

    my $rc = &updateContigTransferRequest($dbh,$req->[0],'cancelled');

    return 1, "request $description was cancelled" if ($rc+0);

    return 0, "failed to cancel request $description";
}

sub processContigTransferRequest {
# process all approved requests, if needed for a specified user
    my $this = shift;

    return 0,"processContigTransferRequest to be developed";
}

sub existContigTransferRequest {
# public: return the status and possibly comment for the input request
    my $this = shift;
    my $cid = shift; # contig ID
    my $pid = shift; # project ID

# return 
print STDOUT "ENTER existContigTransferRequest $cid, $pid\n";

    my $dbh = $this->getConnection();

    my %options = (contig_id=>$cid,new_project_id=>$pid,rstatus=>'pending');

    my $rid = &findContigTransferRequestIDs($dbh,%options);

print STDOUT "RESULT existContigTransferRequest $rid\n";
    if (@$rid) {
# get the details
        my $output = &fetchContigTransferRequest($dbh,$rid->[0]);

        return 1,$output if @$output;
    }

    return 0;
}

# private

sub enterContigTransferRequest {
# private (parameters: user c_id  cpid  p_id)
    my $dbh  = shift;
    my $user = shift;

# first insert into the main table; we do a select insert to test 
# simultaneously the existence of the contig ID and project IDs:
# a non existent contig or project results in no insert
  
    my $query = "insert into CONTIGTRANSFERREQUEST"
              . "      (contig_id,old_project_id,new_project_id,owner) "
              . "select distinct CONTIG.contig_id"
              . "     , CONTIG.project_id as old_project_id"
              . "     , PROJECT.project_id as new_project_id" 
              . "     , '$user'"
              . "  from CONTIG join PROJECT"
              . " where CONTIG.contig_id = ?"
              . "   and CONTIG.project_id = ?"
              . "   and PROJECT.project_id = ?";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@_) || &queryFailed($query,@_);

&queryFailed($query,@_) unless ($rc+0);

    $sth->finish();

    return 0  unless ($rc && $rc == 1); # failed to insert into primary table
    
    my $rid = $dbh->{'mysql_insertid'}; # request ID

# ? then add a 'pending' record into the status table

#    return 0 unless &updateContigTransferRequest($rid,$user);

    return $rid; # return request ID
}

sub updateContigTransferRequest {
# private: add status record for request ID
    my $dbh = shift;
    my ($rid, $user, $status) = @_;

# add pid at end to do a multitable insert testing project as well

    my $query = "insert into CONTIGTRANSFERSTATUS (request_id,user,status) "
              . "values(?,?,?)";
print STDOUT "Enter updateContigTransferRequest (I)\n$query\n";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@_) || &queryFailed($query,@_);

    $sth->finish();

    if ($rc && $status =~ /\b(done|refused|cancelled)\b/) {
# the request is completed
        $query = "update CONTIGTRANSFERREQUEST set rstatus='completed'"
               . " where request_id = ?";
print STDOUT "Enter updateContigTransferRequest (II)\n$query\n";

        $sth = $dbh->prepare_cached($query);
        
        $sth->execute($rid) || &queryFailed($query,$rid);

        $sth->finish();
    }

    return ($rc && $rc == 1) ? 1 : 0;
}

sub findContigTransferRequestIDs {
# return a list of request IDs matching user, projects or status info
    my $dbh = shift;
    my %option = @_;

# build the where clause on the 
    
    my @data;
    my @clause;
    my $union = 1;
    foreach my $key (keys %option) {
# the union flag registers a query which does NOT include date in CR-STATUS
        $union = 0 if ($key eq "user");
        $union = 0 if ($key eq "status" && $option{status} ne "pending");
# keys: old-project_id, new_project_id,contig_id,owner,user,status,
        push @clause, "$key = ?" unless ($key eq 'before' or $key eq 'after');
# special cases: before,after (creation date)
        push @clause, "created <= ?" if ($key eq 'before');
        push @clause, "created >= ?" if ($key eq 'after');
        push @data,$option{$key};
    }

# ok compose the query, first the join for entries with data in both tables

    my $whereclause = join (' and ',@clause);
    $whereclause .= ' and '  if $whereclause;

    my $query = "select CONTIGTRANSFERREQUEST.request_id as rid"
              . "  from CONTIGTRANSFERREQUEST join CONTIGTRANSFERSTATUS"
              . " using (request_id)"
	      . " where $whereclause updated in "
              . "(select max(updated) from CONTIGTRANSFERSTATUS"
	      . "  where request_id=rid)";

#print STDOUT "Enter findContigTransferRequestIDs $query\n";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@data) || &queryFailed($query,@data);

    my @rids;
    while (my ($rid) = $sth->fetchrow_array()) {
        push @rids,$rid;
    }

    $sth->finish();

#print STDOUT "findContigTransferRequestIDs rids: @rids  (union $union)\n";
    return [@rids] unless $union;

# now search for (possible) pending requests without data in CONTIGTRANSFERSTATUS

    $query = "select CONTIGTRANSFERREQUEST.request_id as rid"
           . "  from CONTIGTRANSFERREQUEST left join CONTIGTRANSFERSTATUS"
           . " using (request_id)"
	   . " where $whereclause CONTIGTRANSFERSTATUS.request_id is null";

#print STDOUT "Continue findContigTransferRequestIDs $query\n";
    $sth = $dbh->prepare_cached($query);

    $sth->execute(@data) || &queryFailed($query,@data);

    while (my ($rid) = $sth->fetchrow_array()) {
        push @rids,$rid;
    }

    $sth->finish();

#print STDOUT "rids: @rids\n";
    return [@rids];
}

sub findPendingContigTransferRequestIDs { # OR getPendingContigTransferRequests
# private, get all requests which do not have an entry in the STATUS table
    my $dbh = shift;
    my %option = @_;

    $option{status} = 'pending';
    delete $option{user}; # if any

    return &findContigTransferRequestIDs($dbh,%option);
}

sub fetchContigTransferRequest {
# private, return all current data for a request identified by request ID
    my $dbh = shift;
    my $rid = shift;

# this query returns all current data for a request

    my $ritem = "contig_id, old_project_id, new_project_id, owner, created, "
	      . "rstatus, comment";
    my $sitem = "user, updated, status";
    my $uitem = "owner, created, 'pending'";

    my $query = "select CONTIGTRANSFERREQUEST.request_id, $ritem, $sitem"
              . "  from CONTIGTRANSFERREQUEST join CONTIGTRANSFERSTATUS"
              . " using (request_id)"
	      . " where CONTIGTRANSFERREQUEST.request_id = ?"
              . "   and updated in "
              . "(select max(updated) from CONTIGTRANSFERSTATUS"
	      . "  where request_id= ?)"
              . " union "
              . "select CONTIGTRANSFERREQUEST.request_id, $ritem, $uitem"
              . "  from CONTIGTRANSFERREQUEST left join CONTIGTRANSFERSTATUS"
              . " using (request_id)"
 	      . " where CONTIGTRANSFERREQUEST.request_id = ?"
              . "   and CONTIGTRANSFERSTATUS.request_id is null";

print STDOUT "Enter fetchContigTransferRequest $query\n";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($rid,$rid,$rid) || &queryFailed($query,$rid,$rid,$rid);

    print STDERR "Unexpected multiple result for query:\n$query\n" if ($rc > 1);
    
    my @result = $sth->fetchrow_array();

    $sth->finish();

    return [@result]; # either empty or length 11
}

#-----------------------------------------------------------------------------

sub addTransferRequestComment {
# private: update comment field for transfer request
    my $dbh = shift;
    my $table = shift;  # tablename (READ or CONTIG)
    my $rid = shift;    # request ID
    my $text = shift;

    return unless $text;

    my $query = "update ${table}TRANSFERREQUEST set comment = ?"
              . " where request_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($text,$rid) || &queryFailed($query,$text,$rid);
}

#------------------------------------------------------------------------------
# finding contigs for projects
#------------------------------------------------------------------------------

sub getContigIDsForProjectID {
# public method, retrieve contig IDs and current checked status
    my $this = shift;
    my $project_id = shift; 
# return reference to array of contig IDs and locked status
    return &fetchContigIDsForProjectID($this->getConnection(),$project_id);
}

sub checkOutContigIDsForProjectID {
# public method, lock the project and get contigIDs in it (re: Project.pm)
    my $this = shift;
    my $project_id = shift;

# acquire lock before exporting the contig IDs

    my ($islocked,$message) = $this->acquireLockForProjectID($project_id); 

    return (0,$message) unless $islocked;
 
# return reference to array of contig IDs and locked status
    
    return &fetchContigIDsForProjectID($this->getConnection(),$project_id);
}

sub fetchContigIDsForProjectID {
# private function: return contig IDs of contigs allocated to project with
# given project ID (age zero only) used in delayed loading mode from Project
    my $dbh = shift;
    my $project_id = shift;

    return (undef,"Undefined project ID") unless defined($project_id);

    my $query = "select CONTIG.contig_id"
              . "  from CONTIG left join C2CMAPPING"
              . "    on CONTIG.contig_id = C2CMAPPING.parent_id"
	      . " where CONTIG.project_id = ?"
              .	"   and C2CMAPPING.parent_id is null";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($project_id) || &queryFailed($query,$project_id);

    my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

    $sth->finish();

    my $report = "Project $project_id has ";
    $report .= scalar(@contigids)." contigs" if @contigids;
    $report .= "no contigs" unless @contigids;

    return \@contigids,$report;
}

#------------------------------------------------------------------------------
# finding project ID for contig ID, readname, projectname
#------------------------------------------------------------------------------

sub getProjectIDforContigID {
# return project ID and locked status for input contig ID
    my $this = shift;
    my $contig_id = shift;

    my $query = "select CONTIG.project_id,locked" .
                "  from CONTIG join PROJECT using (project_id)" .
                " where contig_id=?";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    my ($project_id,$islocked);
    while (my @ary = $sth->fetchrow_array()) {
        ($project_id,$islocked) = @ary;
    }

    $sth->finish();

    return ($project_id,$islocked);  
}

sub getProjectIDforReadName {
# return hash of project ID(s) keyed on contig ID for input readname
    my $this = shift;
    my $readname = shift;

    my $query = "select distinct CONTIG.contig_id,CONTIG.project_id"
              . "  from READS,SEQ2READ,MAPPING,CONTIG"
              . " where CONTIG.contig_id = MAPPING.contig_id"
              . "   and MAPPING.seq_id = SEQ2READ.seq_id"
              . "   and SEQ2READ.read_id = READS.read_id"
	      . "   and READS.readname = ?"
	      . " order by contig_id DESC";
#   $query   .= " limit 1" if $options{current};

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readname) || &queryFailed($query,$readname);

    my $resultlist = {};
    while (my ($contig_id,$project_id) = $sth->fetchrow_array()) {
        $resultlist->{$contig_id} = $project_id;
    }

    $sth->finish();

    return $resultlist;
}

sub getProjectInventory {
# returns a list of IDs of all projects with contigs assigned to them
    my $this = shift;

    my %options = @_;

    my $query = "select distinct PROJECT.project_id"
	      . "  from PROJECT ";
    unless ($options{includeempty}) {
        $query .= "  left join CONTIG using (project_id)"
	        . " where CONTIG.contig_id is not null";
    }

    if (defined($options{assembly})) {
        $query .= (($query =~ /where/) ? "and" : "where");
        if ($options{assembly} =~ /\D/) {
            $query .= " assembly_id in "
                    . "(select assembly_id from ASSEMBLY"
                    . "  where ASSEMBLY.name = '$options{assembly}')";
	}
	else {
            $query .= " assembly_id = $options{assembly}";
        } 
    }

    $query .= " order by assembly_id,project_id"; 

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    my $projectids = [];
    while (my ($pid) = $sth->fetchrow_array()) {
        push @$projectids, $pid;
    }

    $sth->finish();

    return $projectids;
}

sub getProjectIDsForProjectName {
# return project IDs (could be more than 1) for name (may contain wildcards)
    my $this = shift;

    my $query = "select project_id,assembly_id from PROJECT where name like ?";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@_) || &queryFailed($query,@_);

    my @projectids;
    while (my @ary = $sth->fetchrow_array()) {
        push @projectids,[@ary];
    }

    return [@projectids];
}

sub getHangingProjectIDs {
# return a list of project IDs in contigs, but not in PROJECT
    my $this = shift;

    my $query = "select distinct CONTIG.project_id"
              . "  from CONTIG left join PROJECT using (project_id)"
	      . " where PROJECT.project_id is null"
              . " order by project_id";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query) && return undef;

    my @projectids;
    while (my $projectid = $sth->fetchrow_array()) {
        push @projectids,$projectid;
    }

    return [@projectids];
}

#------------------------------------------------------------------------------
# meta data (delayed loading from Project class)
#------------------------------------------------------------------------------

sub getProjectStatisticsForProjectID {
# re: Project->getProjectData
    my $this = shift;
    my $project_id = shift || 0;

# get the number of contigs and reads in this project

    my $query = "select count(CONTIG.contig_id) as contigs,"
              .       " sum(nreads) as reads,"
              .       " sum(length) as tlength,"
              .       " min(length) as minlength,"
              .       " max(length) as maxlength,"
              .       " round(avg(length)) as meanlength,"
              .       " round(std(length)) as stdlength"
              . "  from CONTIG left join C2CMAPPING"
              . "    on CONTIG.contig_id = C2CMAPPING.parent_id"
	      . " where C2CMAPPING.parent_id is null"
	      . "   and CONTIG.project_id = ?"; # print "$query\n";

    my $dbh = $this->getConnection();
 
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($project_id) || &queryFailed($query,$project_id);
    
    my ($cs,$rs,$tl,$mn,$mx,$ml,$sd) = $sth->fetchrow_array();

    $sth->finish();

    return ($cs,$rs,$tl,$mn,$mx,$ml,$sd);
}

sub addCommentForProject {
# replace the current comment
    my $this = shift;
    my $project = shift;

    die "putProject expects a Project instance as parameter"
	unless (ref($project) eq 'Project');

    my $pid = $project->getProjectID();
    my $aid = $project->getAssemblyID();

    unless (defined($pid) && defined($aid)) {
        return 0,"undefined assembly or project identifier";
    }

    my $comment = $project->getComment() || 'null';
    $comment = "'$comment'" unless ($comment =~ /^null$/i);

    my $query = "update PROJECT set comment=$comment"
              . " where assembly_id=$aid and project_id=$pid";

    my $dbh = $this->getConnection();

    my $nrow = $dbh->do($query) || &queryFailed($query) || return undef;

    return 0,"Comment field was not updated ($query)" unless ($nrow+0);

    return 1,"New comment entered OK";
}

#------------------------------------------------------------------------------
# locked status  handling
#------------------------------------------------------------------------------

sub getLockedStatusForProjectID {
    my $this = shift;
    my $project_id = shift;
    return &getLockedStatus($this->getConnection(),$project_id);
}

sub getLockedStatusForContigID {
    my $this = shift;
    my $contig_id = shift;
    return &getLockedStatus($this->getConnection(),$contig_id,1);
}

# ------------- acquiring and releasing locks -----------------

sub acquireLockForProject {
    my $this = shift;
    my $project = shift;
    return 0,"Undefined project ID" unless defined($project->getProjectID());
    return $this->acquireLockForProjectID($project->getProjectID());
}

sub acquireLockForProjectID {
    my $this = shift;
    my $pid = shift;

    my $dbh = $this->getConnection();

# test the current lock status

    my ($islocked,$lockedby) = &getLockedStatus($dbh,$pid);

    my $user = $this->getArcturusUser();

# (try to) acquire a lock for this user

    if (!$islocked) { 
        my $islocked = &setLockedStatus($dbh,$pid,$user,1);  
        return (1,"Project $pid locked by $user") if $islocked;
        return (0,"Failed to acquire lock on project $pid");
    }
    elsif ($user eq $lockedby) {
        return (1,"Project $pid is already locked by user $lockedby");
    }
    else {
        return (0,"Project $pid cannot be locked; is owned by user $lockedby");
    }
}

sub releaseLockForProject {
    my $this = shift;
    my $project = shift;
    return 0,"Undefined project ID" unless defined($project->getProjectID());
    return $this->releaseLockForProjectID($project->getProjectID());
}

sub releaseLockForProjectID {
    my $this = shift;
    my $project_id = shift;
    return &unlockProject($this->getConnection(),$project_id,
                          $this->getArcturusUser());
}

sub releaseLockForProjectIDWithOverride { # ??? 
    my $this = shift;
    my $project_id = shift;
# test for valid user?
    return &unlockProject($this->getConnection(),$project_id);
}

# -------------------- meant for use by assembly pipeline ---------------------

sub acquireLockForProjectIDs {
# e.g. enabling the overnight assembly to lock its projects before (old) export
    my $this = shift;
    my $projectids = shift; # array ref with pIDs

    $projectids = $this->getProjectInventory() unless $projectids;

    my $message = '';
    foreach my $pid (@$projectids) {
        my ($lock,$status) = $this->acquireLockForProjectID($pid);
        $message .= $status."\n" unless $lock;
    }
    return $message;
}

sub releaseLockForProjectIDs {
# e.g. enabling the overnight assembly to unlock its projects after (new) import
    my $this = shift;
    my $projectids = shift; # array ref with pIDs

    $projectids = $this->getProjectInventory() unless $projectids;

    my $message = '';
    foreach my $pid (@$projectids) {
        my ($unlock,$status) = $this->releaseLockForProjectID($pid);
        $message .= $status."\n" unless $unlock;
    }
    return $message;
}

#---------------------------- private methods --------------------------

sub hasPrivilegeOnProject {
# private: has user modification privilege on project? (ignoring lockstatus)
    my $dbh = shift;
    my $project_id = shift;
    my $user = shift;

    my $owner1 = &getLockedStatus($dbh,$project_id,0,1);
print STDOUT "hasPrivilegeOnProject  owner1  $owner1\n";

    my ($islocked,$lockedby,$owner) = &getLockedStatus($dbh,$project_id,0,1);
print STDOUT "hasPrivilegeOnProject  owner  $owner, $lockedby ".($islocked || 'unlocked')."\n";

# user has privilege as owner or if the user's role overrides the ownership

    return (($user eq $owner || &userRoles($user,$owner)) ? 1 : 0), $owner;
}

sub unlockProject {
# private function (only here because two releaseLock methods, move to above?)
    my $dbh = shift;
    my $pid = shift;
    my $user = shift; # if not defined, override ownership test

    my ($islocked,$lockedby) = &getLockedStatus($dbh,$pid);

    if (!$islocked) {
        return (1,"Project $pid was not locked");
    }
    elsif ($user && $user ne $lockedby) {
#    elsif ($user && !($user eq $lockedby || $role->{$user} eq $role->{$lockedby})) {
        return (0,"Project $pid remains locked; belongs to user $lockedby");
    }

    if (&setLockedStatus($dbh,$pid,$lockedby,0)) {
        return (1,"Lock released OK on project $pid");
    }

    return (0,"Failed to release lock on project $pid");
}

sub getLockedStatus {
# private function
    my $dbh = shift;
    my $identifier = shift; # project ID or contig ID
    my $iscontigid = shift; # set TRUE for contig ID

    my $query = "select PROJECT.project_id, owner, locked, lockedby"
	      . "  from PROJECT";
                          
    if ($iscontigid) {
        $query .= " join CONTIG using (project_id) where contig_id = ?";
    }
    else {
        $query .= " where project_id = ?";
    }

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($identifier) || &queryFailed($query,$identifier);

    my ($pid,$owner,$islocked,$lockedby) = $sth->fetchrow_array();

    $sth->finish();

    $islocked = 0 if (!$islocked && $pid);

# returns  undef        if the project does not exists
#          0   , owner  if project exists with status: not locked
#          date, owner  if project exists and is locked

    return $islocked,$lockedby unless shift; # temporary
    return $islocked,$lockedby,$owner;
}

sub setLockedStatus {
# private function
    my $dbh = shift;
    my $projectid = shift || return undef;
    my $user = shift;
    my $getlock = shift; # True to acquire lock, false to release lock

    my $query = "update PROJECT ";

    if ($getlock) {
        $query .= "set locked = now(), lockedby = ? where project_id = ? "
	        . "and locked is null";
    }
    else {
        $query .= "set locked = null where lockedby = ? and project_id = ? "
	        . "and locked is not null";
    }

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($user,$projectid) || &queryFailed($query,$user,$projectid);

# returns 1 for success, 0 for failure

    return ($rc + 0);
}

#------------------------------------------------------------------------------

1;
