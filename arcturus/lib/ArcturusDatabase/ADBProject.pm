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

    my $itemlist = "PROJECT.project_id,PROJECT.name,PROJECT.assembly_id,"
                 . "PROJECT.updated,PROJECT.owner," #?locked not included here
		 . "PROJECT.created,PROJECT.creator,PROJECT.comment";

    my $query = "select $itemlist from PROJECT ";

    my @data;
    my $assembly = 0;
    my $binautoload = 1;
    while (my $nextword = shift) {
        my $datum = shift;
        return (0,"Missing parameter value") unless defined ($datum);
# this should usually be the only item given
        if ($nextword eq "project_id") {
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
            $query .= (@data ? "and " : "where ");
            $query .= "PROJECT.name like ? "; # re_ allowing assembly name
            push @data, $datum;
	}
        elsif ($nextword eq "comment") {
            $query .= (@data ? "and " : "where ");
            $query .= "comment like ? ";
            push @data, $datum;
	}
# if contig_id is used, it should be the only specification 
        elsif ($nextword eq "contig_id") { 
            return (0,"only contig_id can be specified") if (@data || shift);
            $query .= "join CONTIG using (project_id)"
                    . " where CONTIG.contig_id = ? ";
            push @data, $datum;
        }
        elsif ($nextword eq "contigname") { 
            return (0,"only contig name can be specified") if (@data || shift);
            $query .= ",CONTIG,MAPPING,SEQ2READ,READS"
                    . " where CONTIG.project_id = PROJECT.project_id"
                    . "   and MAPPING,contig_id = CONTIG.contig_id"
                    . "   and SEQ2READ.seq_id = MAPPING.seq_id"
                    . "   and READS.read_id = SEQ2READ.read_id"
		    . "   and READS.readname = ?";
            push @data, $datum;
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
        elsif ($nextword eq "binautoload") {
	    $binautoload = shift;
	}
        else{
            return (0,"Invalid keyword '$nextword'");     
	}
    }

    $query .= "order by assembly_id,project_id"; 

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);


    $sth->execute(@data) || &queryFailed("$query @data") && return undef;

# cater for the case of more than one project !

    my @projects;
    while (my @ary = $sth->fetchrow_array()) {
        my $project = new Project();
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
        push @projects,$project;
    }

    $sth->finish();

    return ([@projects],"OK") if @projects;

# if no project found, test the special case that it's the bin we need
# needs updating for the chosen assembly

#    if ($key eq "contig_id" || $value =~ /^bin$/i || $value == 0) {
# it's the bin we are after, but it doesn't exist; create it if autoload
#        if ($binautoload) {
#            &createBinProject($dbh,$this->getArcturusUser()); # add assembly
#            $project = $this->getProject($key,$value,binautoload=>0);
#        } 
#    }

    return 0,"unknown project or assembly";
}

sub createBinProject {
# private method to create the project BIN in assembly 0
    my $dbh = shift;
    my $user = shift || 'arcturus';

print "trying to create project BIN for assembly 0\n";

# first create a new project row 

    my $pid = &insertProject($dbh,0,'BIN',$user,'arcturus','autogenerated');

# then update the table and set the row to project ID = 0

    if ($pid) {

        my $query = "update PROJECT set project_id=0 where project_id=$pid";

        $dbh->do($query) || &queryFailed($query);
    }
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

    my $rc = $sth->execute(@_) || &queryFailed("'$query' data: '@_'");

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
    my ($key,$value,$dummy) = @_;

# upgrade to include assembly_id/assembly name

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

    return $this->linkContigIDsToProjectID($this->getConnection(),
                                           $this->getArcturusUser(),
                                           [($contig_id)],
                                           $project_id,
                                           @_); # transfer of 'forced' switch
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
                                     @_); # transfer of 'forced' switch
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

    my ($islocked,$owner) = &getLockedStatus($dbh,$project_id);
    if ($islocked && $owner ne $user) {
        return (0,"Project $project_id is locked by user $owner");
    }
    elsif ($islocked && $owner eq $user) {
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

    my $message = '';

    my $query = "update CONTIG,PROJECT"
              . "   set CONTIG.project_id = $project_id"
              . " where CONTIG.project_id = PROJECT.project_id"
              . "   and CONTIG.contig_id in (".join(',',@$contig_ids).")"
              . "   and CONTIG.project_id != $project_id"
	      . "   and (PROJECT.locked is null or PROJECT.owner = '$user')";
    $query   .= "   and CONTIG.project_id = 0" unless $forced;

    my $nrow = $dbh->do($query) || &queryFailed($query) && return undef;

# compare the number of lines changed with input contigIDs

    $message .= ($nrow+0)." Contigs were (re-)assigned to project $project_id\n" if ($nrow+0);

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

    my $mrow = $dbh->do($query) || &queryFailed($query) && return undef;

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
        $message .= "(owned and locked by user $owner)\n" if $locked;
        $na++;
    }

    $sth->finish();

    &setLockedStatus($dbh,$project_id,$user,0) unless $donotreleaselock;

    $message .= "$na contigs were NOT assigned to project $project_id\n" if $na;

    $message .= ($na ? (scalar(@$contig_ids)-$na) : "All")
	      . " contigs specified are assigned to project $project_id\n";
    
    return (2,$message);
}

sub assignReadsToProject {
# public method for allocating reads to a project
    my $this = shift;
    my $reads = shift;
    my $project = shift;

    unless (ref($reads) eq 'Array' && ref($reads->[0]) eq 'Read') {
        die "assignContigToProject expects an Array of Read instances "
          . "as parameter";
    }

    unless (ref($project) eq 'Project') {
        die "assignContigToProject expects a Project instance as parameter";
    }

# a create a contig for each read and assign to project

    my $project_id = $project->getProjectID() || return (0,"Missing data");

    return $this->linkContigIDsToProjectID($this->getConnection(),
                                           $this->getArcturusUser(),
#                                           [($contig_id)],
                                           $project_id,
                                           @_);
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

    return (undef,"Undefined project ID") unless defined($project_id);

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

#------------------------------------------------------------------------------
# finding project ID for contig ID or readname
#------------------------------------------------------------------------------

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

    my ($project_id,$locked);
    while (my @ary = $sth->fetchrow_array()) {
        ($project_id,$locked) = @ary;
    }

    $sth->finish();

    return ($project_id,$locked);  
}

sub getProjectIDforReadName { # TO BE TESTED
# return project ID and locked status for input contig ID
    my $this = shift;
    my $readname = shift;

    my $query = "select CONTIG.contig_id,CONTIG.project_id"
              . "  from READS,SEQ2READ,MAPPING,CONTIG"
              . " where CONTIG.contig_id = MAPPING.contig_id"
              . "   and MAPPING.seq_id = SEQ2READ.seq_id"
              . "   and SEQ2READ.read_id = READS.read_id"
              . "   and SEQ2READ.version = 0"
	      . "   and READS.readname = ?"
              . " order by contig_id DESC"
              . " limit 1";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readname) || &queryFailed($query);

    my ($contig_id,$project_id);
    while (my @ary = $sth->fetchrow_array()) {
        ($contig_id,$project_id) = @ary;
    }

    $sth->finish();

    return ($contig_id,$project_id);  
}

sub getProjectInventory {
# returns a list of IDs of all projects with contigs assigned to them
    my $this = shift;

    my %options = @_;

    my $query = "select distinct PROJECT.project_id"
	      . "  from PROJECT ";
    unless ($options{addempty}) {
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
