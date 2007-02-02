package ArcturusDatabase::ADBAssembly;

use strict;

use Assembly;

use ArcturusDatabase::ADBProject;

our @ISA = qw(ArcturusDatabase::ADBProject);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub putAssembly {
# create a new assembly
    my $this = shift;
    my $assembly = shift;

    die "putAssembly expects an Assembly instance as parameter"
	unless (ref($assembly) eq 'Assembly');

    return undef unless $this->userCanCreateProject(); # check privilege

    my $items = "name,chromosome,progress,created,creator,comment";

    my @idata = ($assembly->getAssemblyName(),
                 $assembly->getChromosome(),
                 $assembly->getProgressStatus(),
                 $assembly->getCreator(),
                 $assembly->getComment()      );

    my $query = "insert into ASSEMBLY ($items) values (?,?,?,now(),?,?)";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@idata) || &queryFailed($query,@idata);

    $sth->finish();

    return 0 unless ($rc && $rc == 1);
    
    my $assemblyid = $dbh->{'mysql_insertid'};

    $assembly->setProjectID($assemblyid);

    return $assemblyid;
}

#-----------------------------------------------------------------------------
# 
#-----------------------------------------------------------------------------

sub getAssembly {
# return an array of assembly objects, or undef
    my $this = shift;
    my %options = @_; # no options returns all

    my $items = "ASSEMBLY.assembly_id,ASSEMBLY.name,"
              . "chromosome,progress,updated,creator,comment";
    my $query = "select $items from ASSEMBLY";

    my @data;
    foreach my $key (sort {$b cmp $a} keys %options) { # p before a !
        push @data, $options{$key};
        if ($key eq 'project_id' || $key eq 'projectname') {
            unless ($query =~ /join/) {
                $query .= " join PROJECT using (assembly_id)";
	    }
            $query .= ($query =~ /where/ ? ' and' : ' where');
            $query .= " PROJECT.project_id = ?" if ($key eq 'project_id');
            $query .= " PROJECT.name like ?"    if ($key eq 'projectname');
        }
        elsif ($key eq 'assembly_id' || $key eq 'assemblyname') {
            $query .= ($query =~ /where/ ? ' and' : ' where');
            $query .= " ASSEMBLY.assembly_id = ?" if ($key eq 'assembly_id');
            $query .= " ASSEMBLY.name like ?"     if ($key eq 'assemblyname');
        }
	else {
            my $log = $this->verifyLogger("getAssembly");
            $log->error("Invalid option $key");
	}
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $nr = $sth->execute(@data) || &queryFailed($query,@data);

    return undef unless ($nr && $nr > 0);

# return an array of assembly objects

    my @assemblys;
    undef my %assemblys;
    while (my @ary = $sth->fetchrow_array()) {
# prevent multiple copies of the same assembly
        my $assembly = $assemblys{$ary[0]};
        unless ($assembly) {
            $assembly = new Assembly();
	    $assemblys{$ary[0]} = $assembly;
            push @assemblys,$assembly;
            $assembly->setAssemblyID(shift @ary);
            $assembly->setAssemblyName(shift @ary);
            $assembly->setChromosome(shift @ary);
            $assembly->setProgressStatus(shift @ary);
            $assembly->setUpdated(shift @ary);
            $assembly->setCreator(shift @ary);
            $assembly->setComment(shift @ary);
# assign ADB reference
            $assembly->setArcturusDatabase($this);
        }
    }

    $sth->finish();

    return [@assemblys],$assemblys[0]; # array ref
}


#------------------------------------------------------------------------------
# miscellaneous methods
#------------------------------------------------------------------------------

sub getProjectIDsForAssemblyID {
# return list of project IDs for given assembly ID
    my $this = shift;
    my $assembly_id = shift;

# the query implicitly tests the existence of the assembly

    my $query = "select project_id from PROJECT join ASSEMBLY"
              . " using (assembly_id)"
	      . " where assembly_id = ?";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($assembly_id) || &queryFailed($query,$assembly_id);

    my @pids;
    while (my ($pid) = $sth->fetchrow_array()) {
        push @pids, $pid;
    }

    $sth->finish();

    return [@pids]; # array ref
}

sub getAssemblyDataforReadName {
# return project data keyed on contig_id for input readname
    my $this = shift;
    my %options = @_;

    my ($readitem,$value) = each %options;

    my $contig_items = "CONTIG.contig_id,gap4name,CONTIG.created";
    my $projectitems = "PROJECT.name,PROJECT.owner,assembly_id";

    my $query = "select distinct $contig_items,$projectitems,CONTIG.nreads"
              . "  from READINFO,SEQ2READ,MAPPING,CONTIG,PROJECT"
              . " where CONTIG.project_id = PROJECT.project_id"
              . "   and CONTIG.contig_id = MAPPING.contig_id"
	      . "   and MAPPING.seq_id = SEQ2READ.seq_id"
	      . "   and SEQ2READ.read_id = READINFO.read_id"
	      . "   and READINFO.$readitem = ?"
              . " order by contig_id DESC";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query,$value);

    my $resultlist = {};
    while (my ($contig_id,@items) = $sth->fetchrow_array()) {
        $resultlist->{$contig_id} = [@items];
    }

    $sth->finish();

    return $resultlist;
}

#------------------------------------------------------------------------------

1;
