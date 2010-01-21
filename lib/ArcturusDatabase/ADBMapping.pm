package ArcturusDatabase::ADBMapping;

use strict;

use RegularMapping;

use CanonicalMapping;

use CanonicalSegment;

use ArcturusDatabase::ADBRead;

our @ISA = qw(ArcturusDatabase::ADBRead);

#use ArcturusDatabase;

#our @ISA = qw(ArcturusDatabase);

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
# insert using the canonical mapping 
#-----------------------------------------------------------------------------

sub putReadMappingsForContig {
# insert contig-to-read mappings and new canonical mappings
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    my $regularmappings = $contig->getMappings();

    return 0 unless ($regularmappings && @$regularmappings);

# get the canonical IDs for the mappings; insert new canonical mappings 

    my $dbh = $this->getConnection();

    &getCanonicalIDsForRegularMappings($dbh,$regularmappings,%options);

# write the mappings to database in blocks (one record per mapping)

    my $contig_id = $contig->getContigID();

    my $block = $options{block} || 100;

    my $insert = "insert into SEQ2CONTIG " # ORDER of pars?
      	       . "(contig_id,seq_id,mapping_id,coffset,roffset,direction)"
               . " values "; # values to be added in blocks

    my $success = 1;
    my $accumulated = 0;
    my $accumulatedinsert = $insert;
    my $lastmapping = pop @$regularmappings;
    foreach my $mapping (@$regularmappings,$lastmapping) {
        my $seq_id = $mapping->getSequenceID();
        my $cmid = $mapping->getCanonicalMappingID() || next;
        my $coffset = $mapping->getCanonicalOffsetX();
        my $roffset = $mapping->getCanonicalOffsetY();
        my $direction = $mapping->getAlignmentDirection();
        $accumulatedinsert .= "," if $accumulated++;
        $accumulatedinsert .= "($contig_id,$seq_id,$cmid,"
                            .  "$coffset,$roffset,'$direction')";
        next unless ($accumulated >= $block || $mapping eq $lastmapping);      
# the preset number of inserts has been reached: execute the query
        my $sth = $dbh->prepare($accumulatedinsert);
        my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
        $success = 0 unless $rc;
        $sth->finish();
# prepare for new insert accumulator
        $accumulatedinsert = $insert;
        $accumulated = 0;
    }

}

sub putContigMappingsForContig {
# insert contig-to-contig mappings and new canonical mappings
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    my $regularmappings = $contig->getContigToContigMappings();

    return 0 unless ($regularmappings && @$regularmappings);

# get the canonical IDs for the mappings; insert new canonical mappings 

    my $dbh = $this->getConnection();

    &getCanonicalIDsForRegularMappings($dbh,$regularmappings,%options);

#  write the mappings to database individually

    my $contig_id = $contig->getContigID();

    my $insert = "insert into C2CMAPPING " 
   	       . "(contig_id,parent_id,mapping_id,coffset,poffset,direction"
               . " values (?,?,?,?,?,?,?,?,?,?)";
#   	       . "(contig_id,parent_id,mapping_id,coffset,poffset,direction,cstart,cfinish" (prange from yspan)

    my $sth = $dbh->prepare_cached($insert);

    foreach my $mapping (@$regularmappings) {

#        my ($cstart,$cfinish) = $mapping->getContigRange();

        my @data = ($contig_id,
                    $mapping->getSequenceID(),
                    $mapping->getCanonicalMappingID(),
                    $mapping->getCanonicalOffsetX(),
                    $mapping->getCanonicalOffsetY(),
                    $mapping->getAlignmentDirection() );
#                    $cstart, $cfinish,
        my $rc = $sth->execute(@data) || &queryFailed($insert,@data);                
    }
    $sth->finish();
}

sub putTagMappingsForContig {
# adbcontig 2890 e.o. (+13)
    my $this = shift;
    my $contig = shift;
    my %options = @_;
}

#-----------------------------------------------------------------------------

sub getCanonicalIDsForRegularMappings {
# private helper method: find canonical IDs using checksum
# load canonical mappings for checksums not found 
    my $dbh = shift; # database handle
    my $regularmappings;
    my %options = @_;

# collect all checksums in a hash table; each mapping must have a canonical
# mapping defined, but only new canonicals must have their segments defined

    my $report = '';

    my $checksum_hashref = {};
    foreach my $regularmapping (@$regularmappings) {
        my $canonicalmapping = $regularmapping->getCanonicalMapping();
	unless ($canonicalmapping) {
            $report .= "Missing canonical mapping for regular mapping "
                     .  $regularmapping->getMappingName()."\n";
            next;
	}
        next if $canonicalmapping->getMappingID();
        my $checksum = $canonicalmapping->getCheckSum();
# the checksum can exist even if the segments do not 
        unless ($checksum) {
            $report .= "Missing checksum for mapping "
                    .  $regularmapping->getMappingName()."\n";
	    next;
	}
        $checksum_hashref->{$checksum} = 0;
    }

# identify existing checksums in the database; set hash entry for those found

    my @checksumlist = sort keys %$checksum_hashref;

    my $notfound = &probeCheckSumIDs($dbh,\@checksumlist,$checksum_hashref);

# identify new mappings (having the checksum hash entry still undefined)

    my $newcanonicalmapping_hashref = {};
    my $newcanonicalmapping_arrayref = [];
    foreach my $regularmapping (@$regularmappings) {
        my $canonicalmapping = $regularmapping->getCanonicalMapping();
        next unless $canonicalmapping;
	my $checksum = $canonicalmapping->getCheckSum();
        if (my $cmid = $checksum_hashref->{$checksum}) {
# the checksum is already stored in the database; add the id to canonical mapping
            $canonicalmapping->setMappingID($cmid);
            delete $checksum_hashref->{$checksum};
 	    next;
        }
# the canonical mapping is new; check that it has segments
        unless ($canonicalmapping->hasSegments()) {
	    $report .= "Canonical mapping for ".$regularmapping->getMappingName()
                     . " has no segments\n";
	    next;
	}
        next if $newcanonicalmapping_hashref->{$checksum}++; # only keep the first occurrance
        push @$newcanonicalmapping_arrayref,$canonicalmapping;
    }

# insert the new canonical mappings into the database

    &putCanonicalMappings($dbh,$newcanonicalmapping_arrayref);

    return $report;
}

sub putCanonicalMappings {
# private helper method: insert new canonical mappings into the database
    my $dbh = shift;
    my $canonicalmapping_arrayref = shift;

# first enter the canonical metadata and get a mapping identifier

    my $minsert = "insert into CANONICALMAPPING (cspan,rspan,checksum) "
                . "values (?,?,?)";

    my $sth = $dbh->prepare_cache($minsert);

    my $failed = 0;
    foreach my $canonicalmapping (@$canonicalmapping_arrayref) {
# protect against empty mappings
        next unless $canonicalmapping->hasSegments();

        my @data = ($canonicalmapping->getSpanX(),
                    $canonicalmapping->getSpanY(),
                    $canonicalmapping->getCheckSum());

        my $rc = $sth->execute(@data) || &queryFailed($minsert,@data);

        $failed++ unless ($rc == 1);

        $canonicalmapping->setMappingID($dbh->{'mysql_insertid'}) if ($rc == 1);
    }

    $sth->finish();

# then insert the segments in batches of 100 
    
    my $sinsert = "insert into CANONICALSEGMENT (mapping_id,cstart,pstart,length) "
                . "values "; # to be inserted in blocks

    my $blocksize = 100;
    my $accumulated = 0;
    my $accumulatedinsert = $sinsert;

    foreach my $canonicalmapping (@$canonicalmapping_arrayref) {
        my $mid = $canonicalmapping->getMappingID();
        next unless $mid;
        my $segments = $canonicalmapping->getSegments();
        foreach my $segment (@$segments) {
            my $xstart = $segment->getXstart();
            my $ystart = $segment->getYstart();
            my $length = $segment->getSegmentLength();
            $accumulatedinsert .= "," if $accumulated++;
            $accumulatedinsert .= "($mid,$xstart,$ystart,$length)";
            next unless ($accumulated >= $blocksize);
# the preset number of inserts has been reached: execute the query
            my $sth = $dbh->prepare($accumulatedinsert);
            my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
            $failed++ unless $rc;
            $sth->finish();
# prepare for new insert
            $accumulatedinsert = $sinsert;
            $accumulated = 0;
	}
    }

# if there is anything left ...
   
    if ($accumulated) {
        my $sth = $dbh->prepare($accumulatedinsert);
        my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
        $failed++ unless $rc;
        $sth->finish();
    }

    return $failed;
}

sub probeCheckSumIDs {
# private helper method : retrieve checksum and ID for an input list of checksums
    my $dbh = shift; # database handle
    my $csa = shift; # array ref to list of checksum values to be retrieved
    my $csh = shift; # hash ref for values which are retrieved
    my %options = @_;

    my $blocksize = $options{blocksize} || 1000;

    my $bquery = "select mapping_id,checksum from CANONICALMAPPING where checksum in ";

    my $notretrieved = scalar(@$csa);

    while (my $checksumsleft = scalar(@$csa)) {
        $blocksize = $checksumsleft if ($blocksize > $checksumsleft);
        my @block = splice @$csa, 0, $blocksize;
        my $select = $bquery."('". join("'),('", @block) ."')";
        my $sth = $dbh->prepare($select);
        my $rc = $sth->execute() || &queryFailed($select) && next;
	while (my ($id, $csum) = $sth->fetchrow_array()) {
	    $csh->{$csum} = $id;
            $notretrieved--;
	}
        $sth->finish();
    }

    return $notretrieved;
}

#-----------------------------------------------------------------------------
# retrieval of mappings
#-----------------------------------------------------------------------------

sub newgetReadMappingsForContig {
# adds an array of read-to-contig MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;
    my %options = @_;

#    &verifyParameter($contig,"getReadMappingsForContig");
print STDERR "newgetReadMappingsForContig TO BE DEVELOPED and tested for speed\n";

    return if $contig->hasMappings(); # already has its mappings

    my $nosegments = $options{nosegments}; # do not load segments; use delayed loading

    my $verifycache = $options{verify}; # test cached canonical mappings against database

    my $mquery = "select readname,SEQ2READ.seq_id,coffset,roffset,direction,"
               . "       CANONICALMAPPING.mapping_id,checksum,cspan,rspan" 
               . "  from CANONICALMAPPING, SEQ2CONTIG, SEQ2READ, READINFO"
               . " where contig_id = ?"
               . "   and CANONICALMAPPING.mapping_id = SEQ2CONTIG.mapping_id"
               . "   and SEQ2CONTIG.seq_id = SEQ2READ.seq_id"
               . "   and SEQ2READ.read_id = READINFO.read_id"
               . " order by coffset";

    my $dbh = $this->getConnection();

# first pull out the mapping IDs

    my $sth = $dbh->prepare_cached($mquery);

    my $cid = $contig->getContigID();

    $sth->execute($cid) || &queryFailed($mquery,$cid);

    my $canonicalmapping_hashref = {};
    my $canonicalmapping_arrayref = [];
    while(my ($rnm, $sid, $xo, $yo, $dir, $mid, $cs, $xs, $ys) = $sth->fetchrow_array()) {
# intialise and add readname and sequence ID
        my $regularmapping = new RegularMapping(undef,empty=>1);
        $regularmapping->setMappingName($rnm); # readname
        $regularmapping->setSequenceID($sid);       
        $regularmapping->setCanonicalOffsetX($xo);
        $regularmapping->setCanonicalOffsetY($yo);
        $regularmapping->setAlignmentDirection($dir);
        $regularmapping->setHostSequenceID($cid);
# add the mapping to the contig
        $contig->addMapping($regularmapping);
# probe the cache for presence of the canonical mapping to ensure unique instances
        my $canonicalmapping = CanonicalMapping->lookup($cs);
        if ($canonicalmapping) {
#print STDERR "canonical mapping for $rnm found in cache\n";
# if the mapping ID is not defined (i.e. mapping was not built from database), assign
            unless ($canonicalmapping->getMappingID()) {
print STDERR "canonical mapping ID $mid assigned for $rnm found in cache\n";
#                $canonicalmapping->setMappingID($mid);
# optionally verify the cached version against the database parameters (test mode)
                if ($verifycache) {
                    my $verified = 1;
                    $verified = 0 unless ($xs == $canonicalmapping->getSpanX());
                    $verified = 0 unless ($ys == $canonicalmapping->getSpanY());
                    $verified = 0 unless ($cs == $canonicalmapping->getCheckSum());
# failure to verify signals inconsistency between mapping and database version; abort?
                    unless ($verified) {
                        $sth->finish();
                        die "Inconsistency between canonical mapping for $rnm "
			  . "and database (mapping ID $mid)";
		    }
		}
	    }
	}
	else {
# the canonical mapping was not found in the cache: build it and add to cache
            $canonicalmapping = new CanonicalMapping();
            $canonicalmapping->setMappingID($mid);
            $canonicalmapping->setSpanX($xs);
            $canonicalmapping->setSpanY($ys);
            $canonicalmapping->setCheckSum($cs); # also caches
	}
        $regularmapping->setCanonicalMapping($canonicalmapping);
# use the hash to accumulate unique canonicalmappings
        next if $canonicalmapping_hashref->{$canonicalmapping}++;
        push @$canonicalmapping_arrayref,$canonicalmapping;
    }

    $sth->finish();

    return if $nosegments;

print STDERR "Loading mapping segments\n";
# all canonical mapppings here are unique 

    &fetchMappingSegmentsForCanonicalMappings($dbh,$canonicalmapping_arrayref);
print STDERR "Loading mapping segments DONE\n";

    return;
}

sub getCanonicalSegmentsForRegularMappings {
# (delayed) loading of canonical mapping segments using Mapping ID
    my $this = shift;
    my $regularmapping_arrayref = shift;

# collect unique canonical mappings which do not have segments yet
    
    my $mappingid_hashref = {};
    my $canonicalmapping_arrayref = [];
    foreach my $regularmapping (@$regularmapping_arrayref) {
        my $mapping_id = $regularmapping->getMappingID();
        next unless $mapping_id; # no canonical mapping or one with no mapping_id
        next if $mappingid_hashref->{$mapping_id}++; # accept only the first
        my $canonicalmapping = $regularmapping->getCanonicalMapping(); 
        next if $canonicalmapping->hasSegments();
        push @$canonicalmapping_arrayref,$canonicalmapping;
    }

    my $dbh = $this->getConnection();

    &fetchMappingSegmentsForCanonicalMappings($dbh,$canonicalmapping_arrayref);
}


sub newgetContigMappingsForContig {
# adds an array of contig-to-contig MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;
    my %options = @_;
print STDERR "newgetContigMappingsForContig TO BE DEVELOPED\n";
# TO BE DEVELOPED
    &verifyParameter($contig,"getContigMappingsForContig");
                
    return if $contig->hasContigToContigMappings(); # already done

    return unless $contig->getContigID(); # must have contig ID defined and > 0

    my $log = $this->verifyLogger("getContigMappingsForContig");

    my $mquery = "select age,parent_id,mapping_id," .
                 "       cstart,cfinish,direction" .
                 "  from C2CMAPPING" .
                 " where contig_id = ?" .
                 " order by ".($options{orderbyparent} ? "parent_id,cstart" : "cstart");
 
    my $squery = "select C2CSEGMENT.mapping_id,C2CSEGMENT.cstart," .
                 "       C2CSEGMENT.pstart,length" .
                 "  from C2CMAPPING join C2CSEGMENT using (mapping_id)".
                 " where C2CMAPPING.contig_id = ?";

    my $dbh = $this->getConnection();

# 1) pull out the mapping_ids

    my $sth = $dbh->prepare_cached($mquery);

    my $cid = $contig->getContigID();

    my $rows = $sth->execute($cid) || &queryFailed($mquery,$cid);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    my $generation;
    while(my ($age,$pid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# protect against empty contig-to-contig links 
        $dir = 'Forward' unless defined($dir);
# intialise and add parent name and parent ID as sequence ID
        my $mapping = new Mapping();
#        $mapping->setMappingName(sprintf("contig%08d",$pid)); # to the parent
        $mapping->setMappingName("contig_".sprintf("%08d",$pid)); # the parent
        $mapping->setSequenceID($pid);
        $mapping->setAlignmentDirection($dir);
        $mapping->setMappingID($mid);
        $mapping->setHostSequenceID($cid);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# add remainder of data (cstart, cfinish) ?
# do an age consistence check for this mapping
        $generation = $age unless defined ($generation);
        next if ($generation == $age);
        $log->severe("Inconsistent generation in links for contig $cid");
    }
    $sth->finish();

# 2) pull out the segments

    $sth = $dbh->prepare($squery);

    $sth->execute($cid) || &queryFailed($squery,$cid);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rpstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rpstart, $length);
        }
        else {
# what if not? (should not occur at all)
            $log->severe("Missing Mapping instance for ID $mappingid");
        }
    }

    $sth->finish();

    $contig->addContigToContigMapping([@mappings]);

    return $generation;
}

sub getTagMappingsForContig {
    print STDERR "TO BE DEVELOPED\n";
}


#-----------------------------------------------------------------------------
# private
#-----------------------------------------------------------------------------

sub fetchMappingSegmentsForCanonicalMappings {
# private method: add segments to canonical mappings which do not have them
    my $dbh = shift;
    my $canonicalmapping_arrayref = shift;
    my %options = @_; # blocksize, force

print STDERR "fetchMappingSegmentsForCanonicalMappings TO BE DEVELOPED\n";
# make an inventory of mappings; mapping IDs have to be unique

    my $report = '';

    my $canonicalmapping_hashref = {};
    foreach my $canonicalmapping (@$canonicalmapping_arrayref) {
        $canonicalmapping->{Segments} = [] if $options{force};
        next if $canonicalmapping->hasSegments();
        my $mapping_id = $canonicalmapping->getMappingID();
        if ($canonicalmapping_hashref->{$mapping_id}) {
            $report .= "mapping ID $mapping_id is not unique\n";
	}
        $canonicalmapping_hashref->{$mapping_id} = $canonicalmapping;
    }

    my @mappingids = sort {$a <=> $b} keys %$canonicalmapping_hashref;
print STDERR "Number of mappings for which segments are to be retrieved : ".scalar(@mappingids)."\n";

    my $blocksize = $options{blocksize} || 1000;
    while (my $remainder = scalar(@mappingids)) {
        $blocksize = $remainder if ($blocksize > $remainder);
        my @block = splice @mappingids,0,$blocksize;
        my $query = "select mapping_id,cstart,rstart,length"
                  . "  from CANONICALSEGMENT" 
                  . " where mapping_id in (". (join ',',@block) .")"
                  . " order by mapping_id,cstart";
        my $sth = $dbh->prepare($query);
#print STDERR "q: $query\n";
        $sth->execute() || &queryFailed($query);
        while (my ($mapping_id,$cstart,$rstart,$length) = $sth->fetchrow_array()) {
            my $canonicalmapping = $canonicalmapping_hashref->{$mapping_id};
#print STDERR "r: $mapping_id,$cstart,$rstart,$length   $canonicalmapping\n";
            $canonicalmapping->addCanonicalSegment($cstart, $rstart, $length);
        }
        $sth->finish();
    }

    return $report;
}

#-----------------------------------------------------------------------------

1;
