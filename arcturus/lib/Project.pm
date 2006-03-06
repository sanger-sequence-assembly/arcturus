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
# database handle (export from Arcturus) and delayed loading
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

sub getLockedStatus {
# return the momentary lock status
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    return $ADB->getLockedStatusForProject($this);
}
 
sub getProjectData {
# return the momentary project statistics
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    $ADB->getProjectStatisticsForProject($this);
}

#-------------------------------------------------------------------
  
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

    undef $this->{contigIDs} unless $contigid; # reset option

    $this->{contigIDs} = [] unless defined $this->{contigIDs};

    push @{$this->{contigIDs}}, $contigid if $contigid;
}

sub getContigIDs {
# export reference to the contig IDs array as is
    my $this = shift;

    $this->{contigIDs} = [] unless defined $this->{contigIDs};

    return $this->{contigIDs}; # return array reference
}

sub fetchContigIDs {
# get IDs from database, export reference to the contig IDs array
    my $this = shift;
    my $nolockcheck = shift; # set true to return only unlocked data

# get the contig IDs for this project always by reference to the database

    my $ADB = $this->{ADB} || return (0,"Missing database connection");

    my ($cids, $status);

    if ($nolockcheck) {
# get all contig IDs belonging to this project without locking
       ($cids, $status) = $ADB->getContigIDsForProject($this);
    }
    else {
# access project only if the current user can acquire a lock on the project
       ($cids, $status) = $ADB->checkOutContigIDsForProject($this);
        $status = "No accessible contigs: $status" unless ($cids && @$cids);
    }

    if ($cids) {
        $this->{contigIDs} = undef;
        foreach my $contigid (@$cids) {
            $this->addContigID($contigid);
        }
    }

    return ($cids,$status);
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

sub setContigStatistics {
    my $this = shift;
    my @data = @_;
    $this->{data}->{contigstats} = [@data];
}

sub getContigStatistics {
    my $this = shift;
    $this->getProjectData() unless ($this->{data}->{contigstats});
    return $this->{data}->{contigstats};
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
  
sub setLockDate {
    my $this = shift;
    $this->{data}->{lockdate} = shift;
}
  
sub getLockDate {
    my $this = shift;
    return $this->{data}->{lockdate};
}
  
sub setLockOwner {
    my $this = shift;
    $this->{data}->{lockowner} = shift;
}
  
sub getLockOwner {
    my $this = shift;
    return $this->{data}->{lockowner};
}
    
sub setNumberOfContigs {
    my $this = shift;
    $this->{data}->{numberofcontigs} = shift;
}

sub getNumberOfContigs {
    my $this = shift;
    $this->getProjectData() unless ($this->{data}->{numberofcontigs});
    return $this->{data}->{numberofcontigs};
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;
}
  
sub getNumberOfReads {
    my $this = shift;
    $this->getProjectData() unless ($this->{data}->{numberofreads});
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
    return $this->{data}->{project_id} || 0;
}
  
sub setProjectName {
    my $this = shift;
    $this->{data}->{projectname} = shift;
}
  
sub getProjectName {
    my $this = shift;
    return $this->{data}->{projectname} || '';
}
  
sub setProjectStatus {
    my $this = shift;
    $this->{data}->{projectstatus} = shift;
}
  
sub getProjectStatus {
    my $this = shift;
    return $this->{data}->{projectstatus} || '';
}
  
sub setUpdated {
    my $this = shift;
    $this->{data}->{updated} = shift;
}
  
sub getUpdated {
    my $this = shift;
    return $this->{data}->{updated};
}
  
#-------------------------------------------------------------------    
# exporting of this project's contig as CAF or fasta file
#-------------------------------------------------------------------    
  
sub writeContigsToCaf {
# write contigs to CAF
    my $this = shift;
    my $FILE = shift; # obligatory file handle
    my %options = @_;

    my ($contigids,$status) = $this->fetchContigIDs($options{notacquirelock});

    return (0,1,$status) unless ($contigids && @$contigids);

    my $ADB = $this->{ADB} || return (0,1,"Missing database connection");

    my $export = 0;
    my $report = '';
    my $errors = 0;

    foreach my $contig_id (@$contigids) {

        my $contig = $ADB->getContig(contig_id=>$contig_id);

        unless ($contig) {
            $report .= "FAILED to retrieve contig $contig_id\n";
            $errors++;
            next;
        }

        $contig->endregiontrim($options{endregiontrim});

        $contig->toPadded() if $options{padded};

        if (my $status = $contig->writeToCaf($FILE)) {
            $report .= "$status\n";
            $errors++;
        }
        else {
            $export++;
        }
    }

# returns number of contigs exported without errors, number of errors and report

    return $export,$errors,$report;
}

sub writeContigsToFasta {
# write DNA of this read in FASTA format to FILE handle
    my $this  = shift;
    my $DFILE = shift; # obligatory, filehandle for DNA output
    my $QFILE = shift; # optional, ibid for Quality Data
    my %options = @_;

    my ($contigids,$status) = $this->fetchContigIDs($options{notacquirelock}); 

    return (0,1,$status) unless ($contigids && @$contigids);

    my $ADB = $this->{ADB} || return (0,1,"Missing database connection");

    my $export = 0;
    my $report = '';
    my $errors = 0;

    foreach my $contig_id (@$contigids) {

        my $contig = $ADB->getContig(contig_id=>$contig_id);

        unless ($contig) {
            $report .= "FAILED to retrieve contig $contig_id";
            $errors++;
            next;
        }

        $contig->endregiontrim($options{endregiontrim});

        if (my $status = $contig->writeToFasta($DFILE,$QFILE,%options)) {
            $report .= "$status\n";
            $errors++;
        }
        else {
            $export++;
        }
    }

# returns number of contigs exported without errors, number of errors and report

    return $export,$errors,$report;
}

sub writeContigsToMaf {
# write contig bases, contig quality data, reads placed to specified directory
    my $this  = shift;
    my $DFILE = shift; # obligatory file handle for DNA
    my $QFILE = shift; # obligatory file handle for QualityData
    my $RFILE = shift; # obligatory file handle for Placed Reads
    my %options = @_;

    my ($contigids,$status) = $this->fetchContigIDs($options{notacquirelock}); 

    return (0,1,$status) unless ($contigids && @$contigids);

    my $ADB = $this->{ADB} || return (0,1,"Missing database connection");

    my $export = 0;
    my $report = '';
    my $errors = 0;

    foreach my $contig_id (@$contigids) {

        my $contig = $ADB->getContig(contig_id=>$contig_id);

        unless ($contig) {
            $report .= "FAILED to retrieve contig $contig_id";
            $errors++;
            next;
        }

        $contig->endregiontrim($options{endregiontrim});

        my ($status,$r) = $contig->writeToMaf($DFILE,$QFILE,$RFILE,%options);

        if ($status) {
            $export++;
	}
        elsif ($r =~ /file/) { # missing file handle(s)
            $report .= $r; 
            return 0,1,$report;
	}
        else {
            $report .= $r;
            $errors++;
        }
    }

# returns number of contigs exported without errors, number of errors and report

    return $export,$errors,$report;
}

#-------------------------------------------------------------------    
# exporting meta data as formatted string
#-------------------------------------------------------------------    

sub toStringShort {
# short writeup (one line)
    my $this = shift;

    my @line;
    push @line, $this->getProjectID();
    push @line, $this->getAssemblyID() || 0;
    push @line,($this->getProjectName() || '');
    push @line,($this->getNumberOfContigs() || 0);
    push @line,($this->getNumberOfReads() || 0);
    my $stats = $this->getContigStatistics();
    push @line,($stats->[0] || 0); # total sequence length 
    push @line,($stats->[2] || 0); # largest contig
    my $locked = ($this->getLockedStatus() ? 'LOCKED' : ' free ');
    push @line,($this->getOwner() || 'undef');
    push @line,($locked || '');
    my $comment = $this->getProjectStatus();
    $comment .= "  " if $comment;
    $comment .= ($this->getComment() || '');
    push @line,$comment;
  
    return sprintf ("%4d %2d %-8s %7d %8d %9d %9d  %-8s %6s %-24s\n",@line);
}
  
sub toStringLong {
# long writeup
    my $this = shift;

    my $string = "\n";

    $string .= "Project ID         ".$this->getProjectID()."\n";
    $string .= "Assembly           ".($this->getAssemblyID() || 0)."\n";
    $string .= "Project name       ".$this->getProjectName()."\n";
    $string .= "Project owner      ".($this->getOwner() || 'undef')."\n";

    $string .= "Project status     ".$this->getProjectStatus()."\n";

    $string .= "Lock status        ";
    if (my $lock = $this->getLockedStatus()) {
        $string .= "locked by user '".($this->getLockOwner() || 'unknown')."'";
        $string .= " on ".$this->getLockDate() if $this->getLockDate();
        $string .= "  lock level $lock\n";
    }
    else {
        $string .= "not locked\n";
    }
    $string .= "Allocated contigs  ".($this->getNumberOfContigs() || 0)."\n";
    $string .= "Allocated reads    ".($this->getNumberOfReads() || 0)."\n";
    $string .= "Last update on     ".($this->getUpdated() || 'unknown')."\n";

    if ($this->getCreator()) {
        $string .= "Created on         ".($this->getCreated() || 'unknown').
                               "  by user '".$this->getCreator()."'\n";
    }
    $string .= "Comment            ".($this->getComment() || '')."\n";

    my $stats = $this->getContigStatistics();

    if ($this->getNumberOfContigs()) {
        $string .= "Contig statistics:\n";
        $string .= " Total sequence    ".($stats->[0] || 0)."\n";
        $string .= " Minimum length    ".($stats->[1] || 0)."\n";
        $string .= " Maximum length    ".($stats->[2] || 0)."\n";
        $string .= " Average length    ".($stats->[3] || 0)."\n";
        $string .= " Variance          ".($stats->[4] || 0)."\n";
    }

    return $string;
}

#-------------------------------------------------------------------
 
1;
