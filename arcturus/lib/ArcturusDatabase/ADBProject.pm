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

    $sth->execute(@data) || &queryFailed($query,@data) && return undef;

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

# check if it is a valid read by getting the read_id and quality ranges

    my $lqleft  = $read->getLowQualityLeft();
    my $lqright = $read->getLowQualityRight();

    return 0,"incomplete read $identifier : missing quality range"
        unless (defined($lqleft) && defined($lqright));

# check read does not belong to any contig

    return 0,"read $identifier is an assembled read"
        unless $this->isUnassembledRead(read_id=>$read->getReadID());

# check if it meets the minimum quality range

    my $minimumlength = $poption{minimumlength};
    $minimumlength = 50 unless $minimumlength;
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

    my $success = $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    $sth->finish();

    return ($success,"OK") if $success;

# report an unexpected lock status for the contig_id 

    return (0,"Contig $contig_id was (unexpectedly) found to be locked");
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

    $sth->execute($contig_id) || &queryFailed($query,$contig_id);

    my ($project_id,$locked);
    while (my @ary = $sth->fetchrow_array()) {
        ($project_id,$locked) = @ary;
    }

    $sth->finish();

    return ($project_id,$locked);  
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

    my $nrow = $dbh->do($query) || &queryFailed($query) && return undef;

    return 0,"Comment field was not updated ($query)" unless ($nrow+0);

    return 1,"New comment entered OK";
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
#    elsif ($user && !($user eq $owner || $role->{$user} eq $role->{$owner})) {
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

    $sth->execute($identifier) || &queryFailed($query,$identifier);

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
    my $getlock = shift; # True to acquire lock, false to release lock

    my $query = "update PROJECT ";

    if ($getlock) {
        $query .= "set locked = now(), owner = ? where project_id = ? "
	        . "and locked is null";
    }
    else {
        $query .= "set locked = null where owner = ? and project_id = ? "
	        . "and locked is not null";
    }

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($owner,$projectid) 
    || &queryFailed($query,$owner,$projectid) && return;

# returns 1 for success, 0 for failure

    return ($rc + 0);
}

#------------------------------------------------------------------------------

1;
