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

    return $ADB->putImportMarkForProject($this,@_); # insert ID
}

sub markExport {
# get the I-E status the project
    my $this = shift;

    my $ADB = $this->{ADB} || return undef;

    return $ADB->putExportMarkForProject($this); # insert ID
}

#-------------------------------------------------------------------
# comparison
#-------------------------------------------------------------------

sub isEqual {
# compare two project instances
    my $this = shift;
    my $that = shift;

    return 1 if ($this eq $that); # instance equality
    return 0 unless (ref($that) eq 'Project');
    return 0 if ($this->getProjectID()   != $that->getProjectID());
    return 0 if ($this->getProjectName() ne $that->getProjectName());
    return 1;
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
    my %options = @_;

    my $idsetkey = ($options{scaffold} ? "scaffold" : "project") . "ContigIDs";

    undef $this->{$idsetkey} unless $contigid; # reset option

    $this->{$idsetkey} = [] unless defined $this->{$idsetkey};

    push @{$this->{$idsetkey}}, $contigid if $contigid;
}

sub getContigIDs {
# export reference to the contig IDs array as is
    my $this = shift;
    my %options = @_;

    my $idsetkey = ($options{scaffold} ? "scaffold" : "project") . "ContigIDs";

    $this->{$idsetkey} = [] unless defined $this->{$idsetkey};

    return $this->{$idsetkey}; # return array reference
}

sub fetchContigIDs {
# get and export IDs of all current contigs of this project; get possible scaffold
    my $this = shift;
    my %options = @_;

# get the contig IDs for this project

    my $ADB = $this->{ADB} || return (0,"Missing database connection");

    my ($cids, $status);

# get all current contigs with or without lock check

    if ($options{nolockcheck} || $options{notacquirelock}) {
# get all contig IDs belonging to this project without locking
       ($cids, $status) = $ADB->getContigIDsForProject($this);
    }
    else {
# access project only if the current user can acquire a lock on the project
       ($cids, $status) = $ADB->checkOutContigIDsForProject($this);
        $status = "No accessible contigs: $status" unless ($cids && @$cids);
    }

    return $this->getContigIDs(),$status if $options{noscaffold};    

# get contigs in scaffold, either from the last import, or by scaffold number 

    if (my $identifiers = $options{scaffoldids}) {
        $identifiers =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        my @identifiers = split /\W+/,$identifiers;
        foreach my $identifier (@identifiers) {
            my $result = $ADB->getScaffoldByIDforProject($this,$identifier);
            $status .= "; no scaffold like $identifier" unless $result;
        }
    }
    elsif (!$ADB->getScaffoldForProject($this)) { # adds last scaffold from import if any
        $status .= "; no scaffolded contigs found";
    }

    return $this->getContigIDs(),$status; # return all IDs in project (not-scaffolded)
}

sub getContigIDsForExport {
# returns an ordered list of contigs for export
    my $this = shift;
    my %options = @_; # nolockcheck, ignorescaffold, noabortoninterlopers

# nolockcheck (notacquirelock) - unless set project lock has to be acquired
# noscaffold                   - ignore scaffold info, use current contigs for project
# scaffoldids                  - comma separated list of scaffold identifier to use
#                                > if not defined, use scaffold info from last import 
#                                > if not defined, append un-scaffolded contigs from
#                                  project after the scaffolded ones. 
#                                > with scaffoldids you get only the contigs in them
# abortoninterlopers           - if set, abort if any scaffold contig not in current 
#                                contigs for project; else ignore the contig

    my ($dbcids,$sfcids,$status);

# get all current contigs for this project

   ($dbcids,$status) = $this->fetchContigIDs(@_); # pass on options

    return 0,$status unless @$dbcids; # empty project

    return $dbcids,$status if $options{noscaffold};

    $sfcids = $this->getContigIDs(scaffold=>1);

# test if all scaffold entries are among the project current contigs

    my $contigidhash = {};
    foreach my $dbcid (@$dbcids) {
        $contigidhash->{$dbcid}++;
    }
    my @acceptedcontigs;
    my @rejectedcontigs;
    foreach my $sfcid (@$sfcids) {
        if ($contigidhash->{abs($sfcid)}) {
            push @acceptedcontigs,$sfcid;
            delete $contigidhash->{abs($sfcid)};
	}
	elsif (my $ADB = $this->{ADB}) {
            my $offspring = $ADB->getCurrentContigIDsForAncestorIDs([(abs($sfcid))]);
            unless ($offspring && @$offspring) {
                push @rejectedcontigs,$sfcid;
		next;
	    }
            foreach my $pair (@$offspring) {
                my $contig = $pair->[0];
                if ($contigidhash->{$contig}) {
                    push @acceptedcontigs,$contig;
                    delete $contigidhash->{$contig};
		}
		else {
                    push @rejectedcontigs,$contig;
                }
	    }
	}
    }

# remaining contighashid keys are contigs in project, but not in scaffold (if any)

    if (my @remainder = sort {$a <=> $b} keys %$contigidhash) {
	$status = "Project contains contigs not in scaffold (@remainder)" if @$sfcids;
        push @acceptedcontigs,@remainder unless $options{scaffoldids};
    }

# rejected contigs are in scaffold, but not in project (will normally not occur)
# actually woccurs after moving a contig out of the project

    if (@rejectedcontigs) {
        $status = "Scaffold has duplicated contigs or contigs not in "
                . "current contigs for project (@rejectedcontigs)";
        return 0, $status                      if $options{abortoninterlopers}; 
        push @acceptedcontigs,@rejectedcontigs if $options{acceptinterlopers};
    }

    return [@acceptedcontigs],$status;
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
 
    return 1 if (@$previouscontigids != @$currentcontigids);

    my $l = scalar(@$previouscontigids) - 1; # last element

    return 0 unless ($l >= 0 && $currentcontigids->[$l]); # empty current contigs

    return 1 if ($previouscontigids->[$l] != $currentcontigids->[$l]);

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
    my %options = @_; # frugal=> , logger=>, endregiontrim=> & options for getContigIDsForExport

    my ($contigids,$status) = $this->getContigIDsForExport(%options);
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

    my $minimum = $options{minnrofreads};
    my $maximum = $options{maxnrofreads};

    my %woptions;
    foreach my $option ('readsonly','notags','alltags','includetag','excludetag') {
        next unless defined $options{$option};
        $woptions{$option} = $options{$option};
    } 

    foreach my $contig_id (@$contigids) {

        next unless $contig_id; # just in case

# use frugal mode if number of reads >= $frugal 

        my $contig = $ADB->getContig(contig_id=>abs($contig_id),
                                     metadataonly=>1,
                                     frugal=>$frugal);

        $contig->reverse(nonew=>1) if ($contig_id < 0); 

        unless ($contig) {
            my $message = "FAILED to retrieve contig $contig_id";
            $logger->error($message) if $logger;
            $report .= $message."\n";
            $errors++;
            next;
        }

        my $nrofreads = $contig->getNumberOfReads();
	next if ($minimum && $nrofreads < $minimum);
	next if ($maximum && $nrofreads > $maximum);

# end region trimming (for export to gap4 database, re: prefinishing)

        if (my $cliplevel = $options{endregiontrim}) {
            my $newcontig = $contig->endRegionTrim(cliplevel=>$cliplevel);
            $contig = $newcontig if $newcontig;
        }

        if ($contig->writeToCaf($FILE,%woptions)) { # returns 0 if no errors
            my $message= "FAILED to export contig $contig_id";
            $logger->error($message) if $logger;
            $report .= $message."\n";
            $errors++;
        }
        else {
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

    my ($contigids,$status) = $this->getContigIDsForExport(%options);
    return (0,1,$status) unless ($contigids && @$contigids);

    my $ADB = $this->{ADB} || return (0,1,"Missing database connection");

    my $minimum = $options{minnrofreads};
    my $maximum = $options{maxnrofreads};

    my $export = 0;
    my $report = '';
    my $errors = 0;

    my %woptions;
    foreach my $option ('readsonly','gap4name','minNX') {
        next unless defined $options{$option};
        $woptions{$option} = $options{$option};
    }

    foreach my $contig_id (@$contigids) {

        my $contig = $ADB->getContig(contig_id=>$contig_id,metadataonly=>1);

        unless ($contig) {
            $report .= "FAILED to retrieve contig $contig_id\n";
            $errors++;
            next;
        }

# selection on number of reads

        my $nrofreads = $contig->getNumberOfReads();
	next if ($minimum && $nrofreads < $minimum);
	next if ($maximum && $nrofreads > $maximum);

# apply quality clipping, if any, first

        if ($options{qualityclip}) {
            my %qoptions; # only quality clipping options
            foreach my $option ('threshold','minimum','window','hqpm','symbols') {
	        next unless defined $options{$option};
                $qoptions{$option} = $options{$option};
	    }
# get a clipped version of the current consensus
            my ($new,$status) = $contig->deleteLowQualityBases(nonew=>1,%qoptions);

            $contig = $new if ($status);
            unless ($status) {
 	        print STDERR "No quality clipped for ".$contig->getContigName()."\n";
	    }
        }

# end region trimming

        if (my $cliplevel = $options{endregiontrim}) {
            my $newcontig = $contig->endRegionTrim(cliplevel=>$cliplevel);
            $contig = $newcontig if $newcontig;
        }

# end region only masking

        if (my $masking = $options{endregiononly}) {
            my $symbol = $options{maskingsymbol} || 'X';
            my $gaplength = $options{shrink} || $masking;
            my $newcontig = $contig->extractEndRegion(endregionsize=>$masking,
				                      sfill => $symbol,
                                                      lfill => $gaplength,
                                                      qfill => 1);
            $contig = $newcontig if $newcontig;
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

    my ($contigids,$status) = $this->getContigIDsForExport(%options);
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
