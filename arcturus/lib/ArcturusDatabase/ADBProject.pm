package ArcturusDatabase::ADBProject;

use strict;

use ArcturusDatabase::ADBContig;

use Project;

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
    my ($key,$value,@junk) = @_;

    my $query;

    my $itemlist = "PROJECT.project_id,PROJECT.assembly_id,"
                 . "PROJECT.updated,PROJECT.owner," # (locked not included here)
		 . "PROJECT.created,PROJECT.creator,PROJECT.comment";

    if ($key eq "project_id") {
        $query = "select $itemlist from PROJECT where project_id =?"; 
    }
    elsif ($key eq "comment" || $key eq "projectname") {
        $query = "select $itemlist from PROJECT where comment like ?";
    }
    elsif ($key eq "contig_id") { 
        $query = "select $itemlist from PROJECT join CONTIG" .
                 " using (project_id)" .
                 " where CONTIG.contig_id = ?";
    }
#    elsif ($key eq "contigIDs") {
# determine the project ID from a number of contig_ids
#        if (ref($value) ne 'ARRAY') {
#	    return $this->getProject(contig_id=>$value);
#        }
#        elsif (!@$value) {
#            return undef; # empty array
#        }
# determine the project based on a number of project_ids?       
#    }
    else {
        print STDERR "Invalid keyword $key for ->getProject";
        return undef;
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

    my $project;
    if (my @ary = $sth->fetchrow_array()) {
        $project = new Project();
        $project->setProjectID(shift @ary);
        $project->setAssemblyID(shift @ary);
        $project->setUpdated(shift @ary);
        $project->setOwner(shift @ary);
        $project->setCreated(shift @ary);
        $project->setCreator(shift @ary);
        $project->setComment(shift @ary);
# assign ADB reference
        $project->setArcturusDatabase($this);
    }

    $sth->finish();

    return $project;
}

sub putProject {
# add a new project to the database
    my $this = shift;
    my $project = shift;

    die "putProject expects a Project instance as parameter"
	unless (ref($project) eq 'Project');

    my $pitems = "updated,owner,created,creator,comment";
    my $values = "now(),?,now(),?,?";
    my @data   = ($this->getArcturusUser() || 'unknown',
                  $this->getArcturusUser() || 'arcturus',
                  $project->getComment() || '');

# if no project ID specified use autoincrement mode, else add ID to query

    if (my $pid = $project->getProjectID()) {
        $pitems .= ",project_id";
        $values .= ",?";
        push @data,$pid;
    }

    my $query = "insert into PROJECT ($pitems) VALUES ($values)";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@data) || &queryFailed($query);

    $sth->finish();

    return 0 unless ($rc && $rc == 1);
    
    my $projectid = $dbh->{'mysql_insertid'};
    $project->setProjectID($projectid);

    return $projectid;
}

sub deleteProject {
# remove project for project ID / name, but only if no associated contigs
    my $this = shift;
    my ($key,$value,$dummy) = @_;

    my $tquery;
    my $dquery;
    if ($key eq 'project_id' && defined($value)) {
        $tquery = "select contig_id from CONTIG join PROJECT"
                . " using (project_id)"
	        . " where PROJECT.project_id = $value";
        $dquery = "delete from PROJECT where project_id = $value ";
    }
    elsif ($key eq 'comment' && defined($value)) {
        $tquery = "select contig_id from CONTIG join PROJECT"
                . " using (project_id)" .
		  " where PROJECT.comment like '$value'";
        $dquery = "delete from PROJECT where comment like '$value' ";
        $value = "like '$value'"; # display purpose
    }
    else {
        return (0,"Invalid parameters");
    }

    $dquery .= "limit 1"; # one at the time

    my $dbh = $this->getConnection();

# safeguard: project_id may not have contigs assigned to it

    my $hascontig = $dbh->do($tquery) || &queryFailed($tquery);

    return 0,"Project $value has $hascontig contigs and can't be deleted" 
        if (!$hascontig || $hascontig > 0); # also exits on failed query
    
# delete from the primary tables

    my $nrow = $dbh->do($dquery) || &queryFailed($dquery);

    return 0,"Failed to delete project $value" unless $nrow;

    return 1,"Project $value does not exists" unless ($nrow+0);
    
    return 1,"Project $value deleted";
}

#------------------------------------------------------------------------------
# methods dealing with Contigs and contig IDs
#------------------------------------------------------------------------------

sub assignContigToProject {
# public method
    my $this = shift;
    my $contig = shift;
    my $project = shift;

    my $contig_id  = $contig->getContigID()   || return undef;
    my $project_id = $project->getProjectID() || return undef;

    return $this->assignContigIDToProjectID($contig_id,$project_id,@_);
}

sub assignContigIDToProjectID {
# public method
    my $this = shift;
    my $cid  = shift; # scalar contig ID
    my $pid  = shift; # scalar project ID

    return $this->assignContigIDsToProjectID([($cid)],$pid,@_);
}

sub assignContigIDsToProjectID {
# public method
    my $this  = shift;
    my $cids  = shift; # array ref for contig IDs
    my $pid   = shift; # scalar project ID
    my $force = shift; # try for forced change

    return &linkContigIDsToProjectID($this->getConnection(),
                                     $this->getArcturusUser(),
                                     $cids,$pid,$force);
}

sub linkContigIDsToProjectID {
# private method : allocate contig IDs to project ID
    my $dbh = shift;
    my $user = shift;
    my $contig_ids = shift || return undef;
    my $project_id = shift || return undef;
    my $forced = shift;

# check if project specified can be modified by the user

    my ($lock,$owner) = &getLockedStatus($dbh,$project_id);
    if ($lock && $owner ne $user) {
        return (0,"Project $project_id is locked by user $owner");
    }

# now assign the contigs to the project, except for those contigs
# which have been assigned to (other) projects; the 'forced' flag
# overrides this restriction, BUT even then contigs are re-assigned
# from their current project to the new one only if the current project
# is not locked by someone else (this cannot be overridden; you have to
# have those contigs unlocked first by their owners)

    my $query = "update CONTIG join PROJECT using (project_id)"
              . "   set CONTIG.project_id = $project_id"
              . " where CONTIG.contig_id in (".join(',',@$contig_ids).")"
              . "   and CONTIG.project_id != $project_id"
	      . "   and (PROJECT.locked is null or PROJECT.owner = '$user')";
    $query   .= "   and CONTIG.project_id = 0" unless $forced;

    my $nrow = $dbh->do($query) || &queryFailed($query) && return undef;

# compare the number of lines changed with contigIDs

    my $message = "$nrow Contigs assigned to project $project_id";

    if ($nrow == scalar(@$contig_ids)) {
        return (1,$message);
    }

# not all expected rows have changed; find out why

    $query = "select CONTIG.contig_id,CONTIG.project_id,"
           . "       PROJECT.locked,PROJECT.owner"
           . "  from CONTIG join PROJECT using (project_id)"
           . " where CONTIG.contig_id in (".join(',',@$contig_ids).")"
	   . "   and CONTIG.project_id != $project_id";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query) && return undef;

    my $notAssigned = 0;
    if (my ($cid,$pid,$locked,$owner) = $sth->fetchrow_array()) {
        $message .= "\n- contig $cid is in project $pid ";
        $message .= "(owned and locked by user $owner)" if $locked;
        $notAssigned++;
    }

    $message .= "\n$notAssigned contigs NOT assigned to project $project_id";

    return (2,$message);
}

#------------------------------------------------------------------------------

sub unlinkContigID {
# remove link between contig_id and project_id (set project_id to 0)
    my $this = shift;
    my $contig_id = shift || return undef; 

# does the user have modifify privileges on this project

    my $dbh = $this->getConnection();

    my ($lock,$owner) = &getLockedStatus($dbh,$contig_id,1);
    return (0,"Contig $contig_id is locked by user $owner") if $lock;


    my $query = "update CONTIG join PROJECT using (project_id)"
              . "   set CONTIG.project_id = 0"
              . " where CONTIG.contig_id = ?"
	      . "   and PROJECT.locked is null";

    my $sth = $dbh->prepare_cached($query);

    my $success = $sth->execute($contig_id) || &queryFailed($query);

    $sth->finish();

    return $success;
}

#------------------------------------------------------------------------------

sub getContigIDsForProjectID {
# public method, retrieve contig IDs and current checked status
    my $this = shift;
    my $project_id = shift; 
# return reference to array of contig IDs and locked status
    return &fetchContigIDsForProjectID($this->getConnection(),$project_id);
}

sub checkOutContigIDsForProjectID {
# public method, lock the project and get contigIDs for this project
    my $this = shift;
    my $project_id = shift;

# acquire lock before exporting the contig IDs

    my ($locked,$message) = $this->acquireLockForProjectID($project_id); 

    return (0,$message) unless $locked;
 
# return reference to array of contig IDs and locked status
    
    return &fetchContigIDsForProjectID($this->getConnection(),$project_id);
}

sub fetchContigIDsForProjectID {
# private function: return contig IDs of contigs allocated to project with
# given project ID (age zero only) used in delayed loading mode from Project
    my $dbh = shift;
    my $project_id = shift;

    return undef unless defined($project_id);

    my $query = "select CONTIG.contig_id"
              . "  from CONTIG left join C2CMAPPING"
              . "    on CONTIG.contig_id = C2CMAPPING.parent_id"
	      . " where CONTIG.project_id = ?"
              .	"   and C2CMAPPING.parent_id is null";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($project_id) || &queryFailed($query);

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

#--------------------------------------------------------------------------------

sub getProjectIDforContigID {
# return project ID and locked status for input contig ID
    my $this = shift;
    my $contig_id = shift;

    my $query = "select project_id,locked" .
                "  from CONTIG join PROJECT using (project_id)" .
                " where contig_id=?";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    my ($project,$locked);
    while (my @ary = $sth->fetchrow_array()) {
        ($project,$locked) = @ary;
    }

    $sth->finish();

    return ($project,$locked);  
}

sub getProjectInventory {
# returns a list of all projects with contigs
    my $this = shift;

    my $query = "select distinct PROJECT.project_id"
              . "  from PROJECT left join CONTIG using (project_id)"
	      . " where CONTIG.contig_id is not null"
	      . " order by project_id";

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

#------------------------------------------------------------------------------
# meta data (delayed loading from Project class)
#------------------------------------------------------------------------------

sub getProjectStatisticsForProjectID {
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

    $sth->execute($project_id) || &queryFailed($query);
    
    my ($cs,$rs,$tl,$mn,$mx,$ml,$sd) = $sth->fetchrow_array();

    $sth->finish();

    return ($cs,$rs,$tl,$mn,$mx,$ml,$sd);
}

sub addCommentForProject {
# comment, status, projecttype ?
    my $this = shift;
    my $project = shift;


}

#------------------------------------------------------------------------------
# locked status  handling
#------------------------------------------------------------------------------

sub hasPrivilegeOnProject { # REDUNDANT ??
# does the current user have modification privilege on project?
    my $this = shift;
    my $project_id = shift;

    my ($lock,$owner) = &getLockedStatus($this->getConnection(),$project_id);

    if ($lock && $owner ne $this->getArcturusUser()) {
        return (0,"Project $project_id is locked by user $owner");
    }

    return(1,"OK");
}

sub getLockedStatusForProjectID {
    my $this = shift;
    my $project_id = shift;
    return &getLockedStatus($this->getConnection(),$project_id);
}

sub getLockedStatusForContigID {
    my $this = shift;
    my $project_id = shift;
    return &getLockedStatus($this->getConnection(),$project_id,1);
}

# ------------- acquiring and releasing locks -----------------

sub acquireLockForProjectID {
    my $this = shift;
    my $pid = shift;

    my $dbh = $this->getConnection();

# test the current lock status

    my ($lock,$owner) = &getLockedStatus($dbh,$pid);

    my $user = $this->getArcturusUser();

# (try to) acquire a lock for this user

    if (!$lock) { 
        my $islocked = &setLockedStatus($dbh,$pid,$user,1);  
        return (1,"Project $pid locked by $user") if $islocked;
        return (0,"Failed to acquire lock on project $pid");
    }
    elsif ($user eq $owner) {
        return (1,"Project $pid is already locked by user $owner");
    }
    else {
        return (0,"Project $pid cannot be locked; is owned by user $owner");
    }
}

sub releaseLockForProjectIDWithOverride { # ??? 
    my $this = shift;
    my $project_id = shift;
# test for valid user?
    return &unlockProject($this->getConnection(),$project_id);
}

sub releaseLockForProjectID {
    my $this = shift;
    my $project_id = shift;
    return &unlockProject($this->getConnection(),$project_id,
                          $this->getArcturusUser());
}

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

sub unlockProject {
# private function (only here because two releaseLock methods, move to above?)
    my $dbh = shift;
    my $pid = shift;
    my $user = shift; # if not defined, override ownership test

    my ($lock,$owner) = &getLockedStatus($dbh,$pid);

    if (!$lock) {
        return (1,"Project $pid was not locked");
    }
    elsif ($user && $user ne $owner) {
        return (0,"Project $pid remains locked; belongs to user $owner");
    }

    if (&setLockedStatus($dbh,$pid,$owner,0)) {
        return (1,"Lock released OK on project $pid");
    }

    return (0,"Failed to release lock on project $pid");
}

sub getLockedStatus {
# private function
    my $dbh = shift;
    my $identifier = shift; # project ID or contig ID
    my $iscontigid = shift; # set TRUE for contig ID

    my $query = "select PROJECT.project_id,PROJECT.locked,PROJECT.owner"
	      . "  from PROJECT";

    if ($iscontigid) {
        $query .= " join CONTIG using (project_id) where contig_id = ?";
    }
    else {
        $query .= " where project_id = ?";
    }

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($identifier) || &queryFailed($query);

    my ($pid,$locked,$owner) = $sth->fetchrow_array();

    $sth->finish();

    $locked = 0 if (!$locked && $pid);

# returns  undef        if the project does not exists
#          0   , owner  if project exists with status: not locked
#          date, owner  if project exists and is locked

#print "ADBP getLockedStatus: $pid,$locked,$owner \n" if $DEBUG;
    return $locked,$owner;
}

sub setLockedStatus {
# private function
    my $dbh = shift;
    my $projectid = shift || return undef;
    my $owner = shift;
    my $lockstatus = shift; # True to acquire lock, false to release lock

    my $query = "update PROJECT ";

    if ($lockstatus) {
        $query .= "set locked = now(), owner = ? where project_id = ? "
	        . "and locked is null";
    }
    else {
        $query .= "set locked = null where owner = ? and project_id = ? "
	        . "and locked is not null";
    }

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($owner,$projectid) || &queryFailed($query) && return;

# returns 1 for success, 0 for failure

    return ($rc + 0);
}

#------------------------------------------------------------------------------

1;
