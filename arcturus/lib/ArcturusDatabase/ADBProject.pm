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

    my $itemlist = "PROJECT.project_id,projectname," .
                   "assembly_id,updated,owner,locked," .
		   "created,creator,comment";

    if ($key eq "project_id") {
        $query = "select $itemlist from PROJECT where project =?"; 
    }
    elsif ($key eq "projectname") {
        $query = "select $itemlist from PROJECT where projectname =?"; 
    }
    elsif ($key eq "contig_id") { 
        $query = "select $itemlist from PROJECT join CONTIG" .
                 " using (project_id)" .
                 " where CONTIG.contig_id = ?";
    }
    elsif ($key eq "contigIDs") {
# determine the project ID from a number of contig_ids
        if (ref($value) ne 'ARRAY') {
	    return $this->getProject(contig_id=>$value);
        }
        elsif (!@$value) {
            return undef; # empty array
        }
# determine the project based on a number of project_ids
# to be developed

        
    }
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
        $project->setProjectName(shift @ary);
        $project->setAssemblyID(shift @ary);
        $project->setUpdated(shift @ary);
        $project->setUserName(shift @ary);
        $project->setUserName(shift @ary);
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

    my $query = "insert into PROJECT (projectname,updated,owner,created,creator,comment) ".
                "VALUES (?,now(),?,now(),?,?)";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($project->getProjectName(),
                           $this->getArcturusUser() || 'unknown',
                           $this->getArcturusUser() || 'arcturus',
                           $project->getComment());

    $sth->finish();

    return 0 unless ($rc == 1);
    
    my $projectid = $dbh->{'mysql_insertid'};
    $project->setProjectID($projectid);

    return $projectid;
}

sub deleteProject {
# remove project for project ID or project name
    my $this = shift;
    my ($key, $value) = shift;

    my $tquery;
    my $dquery;
    if ($key eq 'project_id' && defined($value)) {
        $tquery = "select contig_id from CONTIG2PROJECT" .
	          " where project = $value";
        $dquery = "delete from PROJECT where project_id = $value";
    }
    elsif ($key eq 'projectname' && defined($value)) {
        $tquery = "select contig_id from CONTIG2PROJECT join PROJECT" .
                  " using (project)" .
		  " where projectname = '$value'";
        $dquery = "delete from PROJECT where projectname = '$value'";
    }
    else {
       return undef;
    } 

    my $dbh = $this->getConnection();

# safeguard: project_id may not have contigs assigned to it

    my $hascontig = $dbh->do($tquery) || &queryFailed($tquery);

    return 0,"Project $value has contigs and can't be deleted" 
        if (!$hascontig || $hascontig > 0); # also exits on failed query
    
# delete from the primary tables

    return $dbh->do($dquery) || &queryFailed($dquery);
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
    return $this->assignContigIDToProjectID($contig_id,$project_id);
}

sub assignContigIDToProjectID {
# public method
    my $this = shift;
    my $dbh = $this->getConnection();
    return &linkContigIDToProjectID($dbh,shift,shift,0); # pass contig & project ID
}

sub checkInContigIDforProjectID {
# public method
    my $this = shift;
    my $dbh = $this->getConnection();
    return &linkContigIDToProjectID($dbh,shift,shift,1); # pass contig & project ID
}

sub linkContigIDToProjectID {
# private method
    my $dbh = shift;
    my $contig_id = shift  || return undef;
    my $project_id = shift || return undef;
    my $forced = shift;

# allocate contig ID to project ID

# we have to deal with these cases
# 1) if the contig_id not yet present, insert a new record
# 2) if the contig_id is present and the project_id is the same, 
#     then update the existing record set checked to 'in'
# 3) if the contig_id is present and the project_id is NOT the same, 
#     then update the existing record set new project_id BUT ONLY if
#     checked is 'in'
# 4) if the contig_id is present and the project_id is NOT the same
#     and checked is 'out' update only if the $forced flag is set

    my $query = "select project,checked from CONTIG2PROJECT where contig_id=?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query) && return undef;

    my %pidtoupdate;
    if (my ($pid,$checked) = $sth->fetchrow_array()) {
# use update mode, or abort if checked status is 'out'
        return undef unless ($checked eq 'in' || $forced);
        $query = "update CONTIG2PROJECT set project=?, checked='in'" .
                 " where contig_id=?";
        $pidtoupdate{$pid}++ unless ($pid == $project_id);
    }
    else {
# use insert mode
        $query = "insert into CONTIG2PROJECT (project,contig_id) values (?,?)";
    }

    $sth->finish();

    $sth = $dbh->prepare_cached($query);

    my $success = $sth->execute($project_id,$contig_id) || &queryFailed($query);

    $sth->finish();
    
    $pidtoupdate{$project_id}++;

    foreach $project_id (keys %pidtoupdate) {
#        &updateMetaDataForProject($this,$project_id);
    }

    return $success;
}

#--------------------------------------------------------------------------------

sub unlinkContigID {
# remove link between contig_id and project_id
    my $this = shift;
    my $contig_id = shift || return undef; 

# only if checked status not 'out'

    my ($project_id,$checked) = $this->getProjectIDforContigID($contig_id);

    return unless ($checked eq 'in');

    my $dbh = $this->getConnection();

    my $query = "delete from CONTIG2PROJECT where checked='in' and contig_id=?";

    my $sth = $dbh->prepare_cached($query);

    my $success = $sth->execute($contig_id) || &queryFailed($query);

    $sth->finish();

#    &updateMetaDataForProject($this,$project_id);

    return $success;
}

#--------------------------------------------------------------------------------

sub getContigIDsForProjectID {
# public method, retrieve contig IDs and current checked status
    my $this = shift;
    my $dbh = $this->getConnection();
    return &fetchContigIDsForProjectID(shift,0); # pass project_id
}

sub checkOutContigIDsForProjectID {
# public method, get contig IDs & current checked status & checked status 'out'
    my $this = shift;
    my $dbh = $this->getConnection();
    return &fetchContigIDsForProjectID(shift,1); # pass project_id
}

sub fetchContigIDsForProjectID {
# private function: return contig IDs of contigs allocated to project with
# given project ID (age zero only) used in delayed loading mode from Project
    my $dbh = shift || return undef;
    my $project_id = shift;
    my $setcheckstatus = shift; # optional, set checkout status to 'out'

    my $query = "select CONTIG2PROJECT.contig_id,checked".
                "  from CONTIG2PROJECT left join C2CMAPPING".
                "    on CONTIG2PROJECT.contig_id = C2CMAPPING.parent_id".
                " where C2CMAPPING.parent_id is null".
	        "   and CONTIG2PROJECT.project_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($project_id) || &queryFailed($query);

    my @contigids;
    my $checkoutstatus = 0;
    while (my ($contig_id, $checked) = $sth->fetchrow_array()) {
        $checkoutstatus++ if ($checked eq 'out');
        push @contigids, $contig_id;
    }

    $sth->finish();

# set the checkout status to 'out'; this affect some subsequent queries; for
# inverse operation (setting checked to 'in') use checkInContigIDforProjectID

    if ($setcheckstatus && @contigids) {
        $query = "update CONTIG2PROJECT set checked='out'".
                 " where contig_id in (".join (',',@contigids).")";
        $sth = $dbh->prepare_cached($query);
        $sth->execute($project_id) || &queryFailed($query);
        $sth->finish();
    }

    return \@contigids, $checkoutstatus;
}

#--------------------------------------------------------------------------------

sub getProjectIDforContigID {
# return project ID and checked status for input contig ID
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

#------------------------------------------------------------------------------
# meta data
#------------------------------------------------------------------------------

sub getCountsForProject {
    my $this = shift;
    my $project_id = shift || return undef;

    my $dbh = $this->getConnection();

# get the number of contigs and reads in this project

    my $query = "select count(distinct CONTIG.contig_id) as contigs," .
                "       count(distinct MAPPING.seq_id) as reads" .
                "  from MAPPING join CONTIG using (contig_id)" .
                " where CONTIG.project_id=?";
 
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($project_id) || &queryFailed($query) && return 0;

    my ($cnr, $rnr) = $sth->fetchrow_array(); # number of contigs, reads

    $sth->finish();

    return ($cnr, $rnr);
}

sub getProjectInventory {
    my $this = shift;
    my ($key,$value) = @_;

    my $contigs;

    if ($key eq 'generation') {
        if ($value eq 'parent') {
            $contigs = $this->getCurrentParentIDs();
        }
        elsif ($value eq 'current') {
            $contigs = $this->getCurrentContigIDs();
        }
        else {
            return undef;
        }
    }
    elsif ($key) {
        return undef;
    }
    else {
        $contigs = $this->getCurrentContigIDS();
    }

    my @output;
    return [@output] unless @$contigs; # empty query

    my $dbh = $this->getConnection();

# get the number of contigs and reads in this project

    my $query = "select PROJECT.project_id, PROJECT.projectname,".
                "       PROJECT.locked,".
                "       count(CONTIG.contig_id) as contigs,".
                "       sum(nreads) as reads,".
                "       sum(length) as tlength,".
                "       round(avg(length)) as meanlength,".
                "       round(std(length)) as stdlength,".
                "       max(length) as maxlength".
                "  from PROJECT join CONTIG".
                " using (project_id)".
                " where CONTIG.contig_id in (".join(',',@$contigs).")".
                " group by project_id".
                " order by project_id asc";
 
    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        push @output,[@ary];
    }
    $sth->finish();

    return [@output]; # array of arrays
}

sub addCommentForProject {
# comment, status, projecttype ?
}

#------------------------------------------------------------------------------

1;
