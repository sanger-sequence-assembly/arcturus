package Project;
 
use strict;
 
#-------------------------------------------------------------------
# Constructor new
#------------------------------------------------------------------- 
 
sub new {
    my $class = shift;
    my $identifier = shift; # optional
 
    my $this = {};
 
    bless $this, $class;
 
    $this->setProjectName($identifier) if $identifier;
 
    return $this;
}

#-------------------------------------------------------------------
# import/export of handles to related objects
#-------------------------------------------------------------------

sub setArcturusDatabase {
    my $this = shift;
    my $ADB  = shift;

    if (ref($ADB) eq 'ArcturusDatabase') {
        $this->{ADB} = $ADB;
    }
    else {
        die "Invalid object passed: $ADB";
    }
}
  
sub setAssemblyID {
    my $this = shift;
    $this->{assembly} = shift;
}
  
sub getAssemblyID {
    my $this = shift;
    return $this->{assembly};
}

sub addContigID {
# import a contig ID
    my $this = shift;
    my $contigid = shift;

    $this->{contigIDs} = [] unless defined $this->{contigIDs};

    push @{$this->{contigIDs}}, $contigid;
}

sub getContigIDs {
# export reference to the contig IDs array
    my $this = shift;
    my $force = shift; # override retrieval block if checked out status set 

# use delayed instantiation to get the contig IDs for this project

    unless (defined($this->{contigIDs})) {
        my $ADB = $this->{ADB} || return undef;
        my ($contigids, $checkoutstatus) = $ADB->getContigIDsForProjectID($this->getProjectID());
        if (!$checkoutstatus || $force) {
            foreach my $contigid (@$contigids) {
                $this->addContigID($contigid);
            }
        }
        else {
            print STDERR "Project ".$this->getProjectName().
                         " has checked 'out' status set";
        }
    }

    return $this->{contigIDs};
}

#-------------------------------------------------------------------    
# importing & exporting meta data
#-------------------------------------------------------------------    
  
sub setComment {
    my $this = shift;
    $this->{data}->{comment} = shift;
}
  
sub getComment {
    my $this = shift;
    return $this->{data}->{comment};
}
  
sub setCreated {
    my $this = shift;
    $this->{data}->{created} = shift;
}
  
sub getCreated {
    my $this = shift;
    return $this->{data}->{created};
}
  
sub setCreator {
    my $this = shift;
    $this->{data}->{creator} = shift;
}
  
sub getCreator {
    my $this = shift;
    return $this->{data}->{creator};
}
  
sub setNumberOfContigs {
    my $this = shift;
    $this->{data}->{numberofcontigs} = shift;
}

sub getNumberOfContigs {
    my $this = shift;
    return $this->{data}->{numberofcontigs};
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;
}
  
sub getNumberOfReads {
    my $this = shift;
    return $this->{data}->{numberofreads};
}
  
sub setOwner {
    my $this = shift;
    $this->{data}->{owner} = shift;
}
  
sub getOwner {
    my $this = shift;
    return $this->{data}->{owner};
}
  
sub setProjectID {
    my $this = shift;
    $this->{data}->{project_id} = shift;
}
  
sub getProjectID {
    my $this = shift;
    return $this->{data}->{project_id};
}
  
#sub setProjectName {
#    my $this = shift;
#    $this->{data}->{projectname} = shift;
#}
  
#sub getProjectName {
#    my $this = shift;
#    return $this->{data}->{projectname};
#}  
  
sub setUpdated {
    my $this = shift;
    $this->{data}->{updated} = shift;
}
  
sub getUpdated {
    my $this = shift;
    return $this->{data}->{updated};
}
  
sub setUserName {
    my $this = shift;
    $this->{data}->{user} = shift;
}
  
sub getUserName {
    my $this = shift;
    return $this->{data}->{user};
}

#-------------------------------------------------------------------    
# exporting of this project's contig as CAF or fasta file
#-------------------------------------------------------------------    
  
sub writeContigsToCAF {
# write contigs to CAF
    my $this = shift;
    my $FILE = shift; # obligatory file handle

    my $contigids = $this->getContigIDs(@_) || print STDERR "Project ".
	$this->getProjectName()." has no contigs\n" && return;

    my $ADB = $this->{ADB} || return;
    foreach my $contig_id (@$contigids) {
        my $contig = $ADB->getContig(contig_id=>$contig_id);
        print STDERR "FAILED to retrieve contig $contig_id\n";
        $contig->writeToCaf($FILE) if $contig;
    }
}

sub writeContigsToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data

    my $contigids = $this->getContigIDs(@_) || print STDERR "Project ".
	$this->getProjectName()." has no contigs\n" && return;

    my $ADB = $this->{ADB} || return;
    foreach my $contig_id (@$contigids) {
        my $contig = $ADB->getContig(contig_id=>$contig_id);
        print STDERR "FAILED to retrieve contig $contig_id\n";
        $contig->writeToFasta($DFILE,$QFILE) if $contig;
    }
}

#-------------------------------------------------------------------    
# exporting meta data as formatted string
#-------------------------------------------------------------------    
  
sub toString {
    my $this = shift;

    my $string = "\n";

    $string .= "Project name       ".$this->getProjectName()."\n";
    $string .= "Project ID         ".$this->getProjectID()."\n";
    $string .= "Allocated contigs  ".$this->getNumberOfContigs()."\n";
    $string .= "Allocated reads    ".$this->getNumberOfReads()."\n";
    $string .= "Assembly           ".$this->getAssemblyID()."\n";
    $string .= "Last update        ".$this->getUpdated().
                           "  by   ".($this->getUserName() || '')."\n";
    $string .= "Created on         ".$this->getUpdated().
                           "  by   ".$this->getCreator()."\n";
    $string .= "Comment            ".($this->getComment() || '')."\n";

    return $string;
}

#-------------------------------------------------------------------
# relocating a contig to another project
#-------------------------------------------------------------------

sub moveContigToProject {
    my $this = shift;
    my $contig_id = shift;
    my $project = shift;

# 1) get the current projectID and checked status for contigID
# if it's the same then return, if it's different and not checked in, 
# exit with error status

# 2) if the contig_id was not allocated before add to C2P table
#    or, if it was, update the C2P table.
#    both are handled by assignContigIDtoProjectID
}
 
#-------------------------------------------------------------------
 
1;
