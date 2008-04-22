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

#-------------------------------------------------------------------
# lock status
#-------------------------------------------------------------------

sub getLockedStatus {
# return the momentary lock status
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    return $ADB->getLockedStatusForProject($this);
}

sub acquireLock {
# acquire a lock on the project
    my $this = shift;
    my %options = @_; # user => ..  confirm => ..

    my $ADB = $this->{ADB} || return undef;

    $options{confirm} = 1 unless defined $options{confirm};

    return $ADB->acquireLockForProject($this,%options);
}

sub releaseLock {
# acquire a lock on the project
    my $this = shift;
    my %options = @_; # confirm => ..

    my $ADB = $this->{ADB} || return undef;

    $options{confirm} = 1 unless defined $options{confirm};

    return $ADB->releaseLockForProject($this,%options);
}

sub transferLock {
# transfer an existing lock on the project to another user
    my $this = shift;
    my %options = @_; # newowner => ...   confirm => ..

    my $ADB = $this->{ADB} || return undef;

    $options{confirm} = 1 unless defined $options{confirm};

    return $ADB->transferLockOwnershipForProject($this,%options);
}

#-------------------------------------------------------------------
# import-export status
#-------------------------------------------------------------------

sub getImportExportStatus {
# get the I-E status the project
    my $this = shift;
    my %options = @_; # keys: import, export, changed, pending (default)

    my $ADB = $this->{ADB} || return undef;

    return $ADB->getLastImportOfProject($this) if $options{import};  # date

    return $ADB->getLastExportOfProject($this) if $options{export};  # date

    return $ADB->getLastChangeOfProject($this) if $options{changed}; # date

    return $ADB->exportPendingOfProject($this); # default 0 or 1
}

sub markImport {
# get the I-E status the project
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    return $ADB->putImportMarkForProject($this); # 0 or 1
}

sub markExport {
# get the I-E status the project
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    return $ADB->putExportMarkForProject($this); # 0 or 1  
}

#-------------------------------------------------------------------
# attributes
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
#    my %options = @_;

    undef $this->{contigIDs} unless $contigid; # reset option

    $this->{contigIDs} = [] unless defined $this->{contigIDs};

    push @{$this->{contigIDs}}, $contigid if $contigid;

print STDOUT "added contigID $contigid to project : o  @_\n" if @_;
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
#            $this->addContigID($contigid,"Project->fetchContigIDs");
        }
    }

    return ($cids,$status);
}

sub hasNewContigs {
# compares the set of contig IDs stored after an earlier fetch with the
# current state of the database; return undef if it can't be decided 
    my $this = shift;
    my %options = @_;

    my $previouscontigids = $this->getContigIDs(); # as is

    my ($currentcontigids,$status) = $this->fetchContigIDs(); # refresh

    unless ($currentcontigids) {
# fetch failed; default return 1, optionally return undef
	$options{undef_on_undecided} ? return undef : return 1;
    }

# return true if the number of contigs or the last elements are different  

#print STDERR "Project->hasNewContigs p:".scalar(@$previouscontigids)
#            ." c:".scalar(@$currentcontigids)."\n";
 
    return 1 if (@$previouscontigids != @$currentcontigids);

    my $l = scalar(@$previouscontigids) - 1; # last element

    return 1 if ($previouscontigids->[$l] != $currentcontigids->[$l]);

#print STDERR "No new contigs loaded\n";

    return 0; # there are no new contigs
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
    $this->updateProjectData() unless ($this->{data}->{contigstats});
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
  
sub setDirectory {
    my $this = shift;
    $this->{data}->{directory} = shift;
}
  
sub getDirectory {
    my $this = shift;
    return $this->{data}->{directory};
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
    $this->updateProjectData() unless ($this->{data}->{numberofcontigs});
    return $this->{data}->{numberofcontigs};
}
  
sub setNumberOfReads {
    my $this = shift;
    $this->{data}->{numberofreads} = shift;
}
  
sub getNumberOfReads {
    my $this = shift;
    $this->updateProjectData() unless ($this->{data}->{numberofreads});
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
# gap 4 database corresponding to this project
#-------------------------------------------------------------------    

sub setGap4Name {
    my $this = shift;
    $this->{data}->{gap4name} = shift;
}

sub getGap4Name {
    my $this = shift;
    return $this->{data}->{gap4name};
}
  
#-------------------------------------------------------------------    
# exporting of this project's contig as CAF or fasta file
#-------------------------------------------------------------------    
  
sub writeContigsToCaf {
# write all contigs in this project to CAF; standard project export
    my $this = shift;
    my $FILE = shift; # obligatory file handle
    my %options = @_; # frugal=> , logger=>

    my ($contigids,$status) = $this->fetchContigIDs($options{notacquirelock});

    return (0,1,$status) unless ($contigids && @$contigids);

    my $ADB = $this->{ADB} || return (0,1,"Missing database connection");

    my $export = 0;
    my $report = '';
    my $errors = 0;

    $options{frugal} = 100 unless defined $options{frugal};

    my $frugal = $options{frugal};
    my $logger = $options{logger};
    $logger = 0 unless ($logger && ref($logger) eq 'Logging'); # protect

    if ($logger) {
        my $pd = $this->getProjectData();
        $logger->error("$pd->{contigs} CONTIGS $pd->{reads} READS");
    }

    foreach my $contig_id (@$contigids) {

# use frugal mode if number of reads >= $frugal 

        my $contig = $ADB->getContig(contig_id=>$contig_id,metadataonly=>1,
                                                           frugal=>$frugal);
 
        unless ($contig) {
            my $message = "FAILED to retrieve contig $contig_id";
            $logger->error($message) if $logger;
            $report .= $message."\n";
            $errors++;
            next;
        }

        if ($contig->writeToCaf($FILE)) { # returns 0 if no errors
            my $message= "FAILED to export contig $contig_id";
            $logger->error($message) if $logger;
            $report .= $message."\n";
            $errors++;
        }
        else {
            my $nrofreads = $contig->getNumberOfReads();
	    $logger->error("CONTIG $contig_id $nrofreads") if $logger;
            $export++;
        }

        $contig->erase();
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
            $report .= "FAILED to retrieve contig $contig_id\n";
            $errors++;
            next;
        }
# end region trimming
        if (my $cliplevel = $options{endregiontrim}) {
             $contig->endRegionTrim(cliplevel=>$cliplevel);
        }
# apply quality clipping
        if ($options{qualityclip}) {
            my %qoptions; # only quality clipping options
            foreach my $option ('threshold','minimum','window','hqpm','symbols') {
	        next unless defined $options{$option};
                $qoptions{$option} = $options{$option};
	    }
# get a clipped version of the current consensus
#print STDERR "quality clipping ".$contig->getContigName()."\n";
            my ($new,$status) = $contig->deleteLowQualityBases(nonew=>1,%qoptions);

            $contig = $new if ($status);
            unless ($status) {
 	        print STDERR "No quality clipped for ".$contig->getContigName()."\n";
	    }
        }

        my %woptions;
        foreach my $option ('readsonly','gap4name','minNX') {
	    next unless defined $options{$option};
            $woptions{$option} = $options{$option};
	}

        if ($contig->writeToFasta($DFILE,$QFILE,%woptions)) {
# writeToFasta returns 0 for no errors
            $report .= "FAILED to export contig $contig_id\n";
            $errors++;
        }
        else {
            $export++;
        }
    }

# returns number of contigs exported without errors, number of errors and report

    return $export,$errors,$report;
}

sub writeContigsToMaf { # TO BE DEPRECATED
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
            $report .= "FAILED to retrieve contig $contig_id\n";
            $errors++;
            next;
        }

        if ($options{endregiontrim}) {
            my %eoption = (cliplevel=>$options{endregiontrim});
            $contig->endRegionTrim(%eoption);
	}

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
 
sub updateProjectData {
# return the momentary project statistics
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    $ADB->getProjectStatisticsForProject($this);
}

#-------------------------------------------------------------------    
# exporting meta data as hash
#-------------------------------------------------------------------    

sub getProjectData {
    my $this = shift;

    $this->updateProjectData(); # Make sure that the data are current

    my $pd = {};

    $pd->{'id'} = $this->getProjectID();

    $pd->{'assembly_id'} = $this->getAssemblyID() || 0;

    $pd->{'name'} = $this->getProjectName();

    $pd->{'contigs'} = $this->getNumberOfContigs() || 0;

    $pd->{'reads'} = $this->getNumberOfReads() || 0;

    my $stats = $this->getContigStatistics();

    $pd->{'total_sequence_length'} = $stats->[0] || 0;

    $pd->{'largest_contig_length'} = $stats->[2] || 0;

    $pd->{'locked'} = $this->getLockedStatus();

    $pd->{'owner'} = $this->getOwner() || 'no owner';

    $pd->{'status'} = $this->getProjectStatus();

    $pd->{'comment'} = $this->getComment();

    $pd->{'directory'} = $this->getDirectory();

    return $pd;
}
#-------------------------------------------------------------------    
# exporting meta data as formatted string
#-------------------------------------------------------------------    

sub toStringShort {
# short writeup (one line)
    my $this = shift;

    # Make sure that the data are current
    $this->updateProjectData();

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
    push @line,($this->getOwner() || 'no owner');
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

    # Make sure that the data are current
    $this->updateProjectData();

    my $string = "\n";

    $string .= "Project ID         ". $this->getProjectID()."\n";
    $string .= "Assembly           ".($this->getAssemblyID() || 0)."\n";
    $string .= "Project name       ". $this->getProjectName()."\n";
    $string .= "Project owner      ".($this->getOwner() || 'no owner')."\n";

    $string .= "Project status     ". $this->getProjectStatus()."\n";
    $string .= "Project directory  ".($this->getDirectory() || 'unknown')."\n";

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
        $string .= " Total sequence    " . ($stats->[0] || 0)."\n";
        $string .= " Minimum length    " . ($stats->[1] || 0)."\n";
        $string .= " Maximum length    " . ($stats->[2] || 0)."\n";
        $string .= " Average length    " . ($stats->[3] || 0)."\n";
        $string .= " Variance          " . ($stats->[4] || 0)."\n";
# lastly added contig here
        $string .= " Last added        " 
                .  sprintf("contig%08d",($stats->[6] || 0)) 
                .  " (" . ($stats->[7] || 0) . ") on "
                .  ($stats->[5] || 0) . "\n";
    }

    return $string;
}

#-------------------------------------------------------------------
 
1;
