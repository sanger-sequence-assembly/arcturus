package ADBContig;

use strict;

use ArcturusDatabase::ADBRead;

use Compress::Zlib;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Contig;
use Mapping;

our (@ISA);
@ISA = qw(ADBRead);

# ----------------------------------------------------------------------------
# constructor and initialisation via constructor of superclass
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#------------------------------------------------------------------------------
# methods for exporting CONTIGs or CONTIG attributes
#------------------------------------------------------------------------------

sub getContig {
# return a Contig object  (under development)
# options: one of: contig_id=>N, withRead=>R, withChecksum=>C, withTag=>T 
# additional : metaDataOnly=>0 or 1 (default 1) age=>A default 0, or absent
    my $this = shift;

# decode input parameters and compose the query

    my $query  = "select CONTIG.contig_id,length,ncntgs,nreads,".
                 "newreads,cover,readnamehash "; 

    my $nextword;
    my $metadataonly = 0; # default export the lot
    my $value;

    while ($nextword = shift) {
	if ($nextword eq 'ID' || $nextword eq 'contig_id') {
            $query .= "from CONTIG where contig_id = ?";
            $value = shift;
        }
        elsif ($nextword eq 'withChecksum') {
# should include age specification?
            $query .= "from CONTIG where readnamehash = ? ";
            $value = shift;
        }
        elsif ($nextword eq 'withRead') {
# should include age specification?
            $query .= " from CONTIG, MAPPING, SEQ2READ, READS
                       where CONTIG.contig_id = MAPPING.contig_id
                         and MAPPING.seq_id = SEQ2READ.seq_id
                         and SEQ2READ.read_id = READS.read_id
                         and READS.readname = ?";
print STDERR "new getContig: $query\n";
             $value = shift;
       }
        elsif ($nextword eq 'withTag') {
# should include age specification?
            $query .= " from CONTIG join TAG2CONTIG using (contig_id)
                        where tag_id in 
                             (select tag_id from TAG where tagname = ?)";
print STDERR "new getContig: $query\n";
            $value = shift;
        }
        elsif ($nextword eq 'metaDataOnly') {
            $metadataonly = shift;
        }
        else {
            print STDERR "Invalid parameter in getContig : $nextword\n";
            $this->disconnect();
            exit 0;
        }
    }

    my $dbh = $this->getConnection();
        
    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

# get the metadataonly

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;
        $contig->setContigID($contig_id);

        my $length = shift @attributes;
        $contig->setConsensusLength($length);

        my $ncntgs= shift @attributes;
        $contig->setNumberOfContigs($ncntgs);

        my $nreads = shift @attributes;
        $contig->setNumberOfReads($nreads);

        my $newreads = shift @attributes;
        $contig->setNumberOfNewReads($newreads);

        my $cover = shift @attributes;
        $contig->setAverageCover($cover);

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return undef unless defined($contig);

    return $contig if $metadataonly;

# get the reads for this contig with their DNA sequences and tags

    $this->getReadsForContig($contig);

# get mappings (and implicit segments)

    $this->getMappingsForContig($contig);

# get contig tags

    $this->getTagsForContig($contig);

# for consensus sequence we use lazy instantiation in the Contig class

    return $contig if ($this->testContigForExport($contig));

    return undef; # invalid Contig instance
}

sub getSequenceAndBaseQualityForContigID {
# returns DNA sequence (string) and quality (array reference) for the specified contig
# this method is called from the Contig class when using delayed data loading
    my $this = shift;
    my $contig_id = shift;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from CONSENSUS where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    my ($sequence, $quality);

    if (my @ary = $sth->fetchrow_array()) {
	($sequence, $quality) = @ary;
    }

    $sth->finish();

    $sequence = uncompress($sequence) if defined($sequence);

    if (defined($quality)) {
	$quality = uncompress($quality);
	my @qualarray = unpack("c*", $quality);
	$quality = [@qualarray];
    }

    return ($sequence, $quality);
}

sub hasContig {
# test presence of contig with given contig_id;
# if so, return Contig instance with metadata only
    my $this = shift;
    my $contig_id = shift;

    return $this->getContig(ID=>$contig_id,metaDataOnly=>1);
}

#------------------------------------------------------------------------------
# methods for importing CONTIGs or CONTIG attributes into the database
#------------------------------------------------------------------------------

sub putContig {
# enter a contig into the database
    my $this = shift;
    my $contig = shift; # Contig instance
    my $list = shift; # optional

    die "ArcturusDatabase->putContig expects a Contig instance ".
        "as parameter" unless (ref($contig) eq 'Contig');

# do the statistics on this contig, allow zeropoint correction

    $contig->getStatistics(2);

# test the Contig reads and mappings for completeness (using readname)

    if (!$this->testContigForImport($contig)) {
        print STDERR "Contig ".$contig->getContigName." NOT loaded\n";
        return 0;
    }

# get readIDs/seqIDs for its reads, load new sequence for edited reads
 
    my $reads = $contig->getReads();
    return 0 unless $this->getSequenceIDForAssembledReads($reads);

# get the sequenceIDs (from Read); also build the readnames array 

    my @seqids;
    my %seqids;
    foreach my $read (@$reads) {
        my $seqid = $read->getSequenceID();
        my $readname = $read->getReadName();
        $seqids{$readname} = $seqid;
        push @seqids,$seqid;
    }
# and put the sequence IDs into the Mapping instances
    my $mappings = $contig->getMappings();
    foreach my $mapping (@$mappings) {
        my $readname = $mapping->getReadName();
        $mapping->setSequenceID($seqids{$readname});
    }

# test if the contig has been loaded before using the readname/sequence hash

    my $readhash = md5(sort @seqids);
# first try the sequence ID hash
    my $previous = $this->getContig(withChecksum=>$readhash,
                                    metaDataOnly=>1);
# if not found try the readname hash
    $previous = $this->getContig(withChecksum=>md5(sort keys %seqids),
                                 metaDataOnly=>1) unless $previous;
    if ($previous) {
# the read name hash or the sequence IDs hash do match
# pull out previous contig mappings and compare them one by one with contig
        $this->getMappingsForContig($previous);
        if ($contig->isSameAs($previous)) {
            print STDERR "Contig ".$contig->getContigName.
                         " is identical to contig ".
                         $previous->getContigName."\n" if $list;
            return $previous->getContigID();
        }
    }

# okay, the contig is new; find out if it is connected to existing contigs

    my $contigids = $this->getLinkedContigsForContig($contig);
# to be replaced later by this method using sub-queries:
#    my $contigids = $this->getLinkedContigsForContigID($contigid);

# pull out mappings for those previous contigs, if any

    if ($contigids && @$contigids) {
# compare with each previous contig and return/store mapings/segments
print "linked contigs: @$contigids for contig ".$contig->getContigName."\n";
        foreach my $contigid (@$contigids) {
            my $previous = $this->getContig(ID=>$contigid,
                                            metaDataOnly=>1);
            $this->getMappingsForContig($previous);
            unless ($contig->linkToContig($previous)) {
                print STDERR "Empty link to contig ".
                             $previous->getContigName().
                             " detected in contig ".
			     $contig->getContigName()."\n" if $list;
            }
        }
# to be removed after testing
foreach my $mapping (@{$contig->getContigToContigMapping}) {
print STDOUT "Contig ".$contig->getContigName." ".
              ($mapping->assembledFromToString || "\n");
}
# until here
    }
    elsif ($list) {
# the contig has no precursor, is completely new
        print STDERR "Contig ".$contig->getContigName." has no precursors\n";
    }

#return 0; # testing

# now load the contig into the database

    my $dbh = $this->getConnection();

    my $contigid = &putMetaDataForContig($dbh,$contig,$readhash);

    $this->{lastinsertedcontigid} = $contigid;

    return 0 unless $contigid;

    $contig->setContigID($contigid);

# then load the overall mappings (and put the mapping ID's in the instances)

    return 0 unless &putMappingsForContig($dbh,$contig,type=>'read');

# the CONTIG2CONTIG mappings

    return 0 unless &putMappingsForContig($dbh,$contig,type=>'contig');

# and contig tags?

# update the age counter in C2CMAPPING table (at very end of this insert)

# $this->ageByOne($contigid);

    return $contigid;
   
# 2) lock MAPPING and SEGMENT tables
# 3) enter record in MAPPING for each read and contig=0 (bulk loading)
# 4) enter segments for each mapping (bulk loading)
# 5) enter record in CONTIG with meta data, gets contig_id
# 6) replace contig_id=0 by new contig_id in MAPPING
# 7) release lock on MAPPING 
# BETTER? add a function deleteContig(contig_id) to remove contig if any error

}

sub putMetaDataForContig {
# private method
    my $dbh = shift; # database handle
    my $contig = shift; # Contig instance
    my $readhash = shift; 

    my $query = "insert into CONTIG " .
                "(length,ncntgs,nreads,newreads,cover".
                ",origin,updated,readnamehash) ".
                "VALUES (?,?,?,?,?,?,now(),?)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($contig->getConsensusLength() || 0,
                           $contig->hasPreviousContigs(),
                           $contig->getNumberOfReads(),
                           $contig->getNumberOfNewReads(),
                           $contig->getAverageCover(),
                           $contig->getOrigin(),
                           $readhash) || &queryFailed($query);

    return 0 unless ($rc == 1);
    
    return $dbh->{'mysql_insertid'}; # the contig_id
}

sub getSequenceIDForAssembledReads {
# put sequenceID, version and read_id into Read instances given their 
# readname (for unedited reads) or their sequence (edited reads)
# NOTE: this method may insert new read sequence
    my $this = shift;
    my $reads = shift;

# collect the readnames of unedited and of edited reads
# for edited reads, get sequenceID by testing the sequence against
# version(s) already in the database with method addNewSequenceForRead
# for unedited reads pull the data out in bulk with a left join

    my $unedited = {};
    foreach my $read (@$reads) {
        if ($read->isEdited) {
            my ($success,$errmsg) = $this->putNewSequenceForRead($read);
	    print STDERR "$errmsg\n" unless $success;
        }
        else {
            my $readname = $read->getReadName();
            $unedited->{$readname} = $read;
        }
    }

# get the sequence IDs for the unedited reads (version = 0)

    my $range = join "','",sort keys(%$unedited);
    my $query = "select READS.read_id,readname,seq_id" .
                "  from READS left join SEQ2READ using(read_id) " .
                " where readname in ('$range')" .
	        "   and version = 0";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        my ($read_id,$readname,$seq_id) = @ary;
        my $read = $unedited->{$readname};
        delete $unedited->{$readname};
        $read->setReadID($read_id);
        $read->setSequenceID($seq_id);
        $read->setVersion(0);
    }

    $sth->finish();

# have we collected all of them? then %unedited should be empty

    my $success = 1;
    if (keys %$unedited) {
        print STDERR "Sequence ID not found for reads: " .
	              join(',',sort keys %$unedited) . "\n";
        $success = 0;
    }
    return $success;
}

sub testContigForExport {
    &testContig(shift,shift,0);
}

sub testContigForImport {
    &testContig(shift,shift,1);
}

sub testContig {
# use via ForExport and ForImport aliases
    my $this = shift;
    my $contig = shift || return undef; # Contig instance
    my $level = shift;

# level 0 for export, test number of reads against mappings and metadata    
# for export: test reads against mappings using the sequence ID
# for import: test reads against mappings using the readname
# for both, the reads and mappings must correspond 1 to 1

    my %identifier; # hash for IDs

# test contents of the contig's Read instances

    my $ID;
    if ($contig->hasReads()) {
        my $success = 1;
        my $reads = $contig->getReads();
        foreach my $read (@$reads) {
# test identifier: for export sequence ID; for import readname (or both? for both)
            $ID = $read->getReadName()   if  $level; # import
	    $ID = $read->getSequenceID() if !$level;
            if (!defined($ID)) {
                print STDERR "Missing identifier in Read ".$read->getReadName."\n";
                $success = 0;
            }
            $identifier{$ID} = $read;
# test presence of sequence
            if ((!$level || $read->isEdited()) && !$read->hasSequence()) {
                print STDERR "Missing DNA or BaseQuality in Read ".
                              $read->getReadName."\n";
                $success = 0;
            }
        }
        return 0 unless $success;       
    }
    else {
        print STDERR "Contig ".$contig->getContigName." has no Reads\n";
        return 0;
    }

# test contents of the contig's Mapping instances and against the Reads

    if ($contig->hasMappings()) {
        my $success = 1;
	my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
# get the identifier: for export sequence ID; for import readname
            if ($mapping->hasSegments) {
                $ID = $mapping->getReadName()    if $level;
	        $ID = $mapping->getSequenceID() if !$level;
# is ID among the identifiers? if so delete the key from the has
                if (!$identifier{$ID}) {
                    print STDERR "Missing Read for Mapping ".
                            $mapping->getReadName." ($ID)\n";
                    $success = 0;
                }
                delete $identifier{$ID}; # delete the key
            }
	    else {
                print STDERR "Mapping ".$mapping->getReadName().
                         " for Contig ".$contig->getContigName().
                         " has no Segments\n";
                $success = 0;
            }
        }
        return 0 unless $success;       
    } 
    else {
        print STDERR "Contig ".$contig->getContigName." has no Mappings\n";
        return 0;
    }
# now there should be no keys left (when Reads and Mappings correspond 1-1)
    if (scalar(keys %identifier)) {
        foreach my $ID (keys %identifier) {
            my $read = $identifier{$ID};
            print STDERR "Missing Mapping for Read ".$read->getReadName." ($ID)\n";
        }
        return 0;
    }

# test the number of Reads against the contig meta data (info only; non-fatal)

    if (my $numberOfReads = $contig->getNumberOfReads()) {
        my $reads = $contig->getReads();
        my $nreads =  scalar(@$reads);
        if ($nreads != $numberOfReads) {
	    print STDERR "Read count error for contig ".$contig->getContigName.
                         " (actual $nreads, metadata $numberOfReads)\n";
        }
    }
    elsif (!$level) {
        print STDERR "Missing metadata for ".contig->getContigName."\n";
    }
    return 1;
}

sub deleteContig {
# remove data for a given contig_id from all tables
    my $this = shift;
    my $contigid = shift;

    $contigid = $this->{lastinsertedcontigid} unless $contigid;

    return unless $contigid;

    my @tables = ('CONTIG','MAPPING','SEGMENT','C2CMAPPING','C2CSEGMENT');

# to be completed
}

#----------------------------------------------------------------------------------------- 
# methods dealing with Mappings and links between Contigs
#----------------------------------------------------------------------------------------- 

sub getMappingsForContig {
# adds an array of read-to-read MAPPINGS to the input Contig instance
    my $this = shift;
    my $contig = shift;

    die "getMappingsForContig expects a Contig instance" 
         unless (ref($contig) eq 'Contig');

    return if $contig->hasMappings(); # already has its mappings

    my $dbh = $this->getConnection();

# first pull out the mapping_ids

    my $query = "select readname,SEQ2READ.seq_id,mapping_id,cstart,cfinish,direction" .
                "  from MAPPING, SEQ2READ, READS" .
                " where contig_id = ?" .
                "   and MAPPING.seq_id = SEQ2READ.seq_id" .
                "   and SEQ2READ.read_id = READS.read_id" .
                " order by cstart";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig->getContigID) || &queryFailed($query);

    my @mappings;
    my $mappings = {}; # to identify mapping instance with mapping ID
    while(my ($rn, $sid, $mid, $cs, $cf, $dir) = $sth->fetchrow_array()) {
# intialise and add readname and sequence ID
        my $mapping = new Mapping();
        $mapping->setReadName($rn);
        $mapping->setSequenceID($sid);
        $mapping->setAlignmentDirection($dir);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# ? add remainder of data (cstart, cfinish) ?
    }
    $sth->finish();

# second, pull out the segments

    $query = "select SEGMENT.mapping_id,SEGMENT.cstart,rstart,length" .
             "  from MAPPING join SEGMENT using (mapping_id)" .
             " where MAPPING.contig_id = ?";

    $sth = $dbh->prepare($query);

    $sth->execute($contig->getContigID()) || &queryFailed($query);

    while(my @ary = $sth->fetchrow_array()) {
        my ($mappingid, $cstart, $rstart, $length) = @ary;
        if (my $mapping = $mappings->{$mappingid}) {
            $mapping->addAlignmentFromDatabase($cstart, $rstart, $length);
        }
        else {
# what if not? should not occur at all
            print STDERR "Missing Mapping instance for ID $mappingid\n";
        }
    }

    $sth->finish();

    $contig->addMapping([@mappings]);
}

sub putMappingsForContig {
# private method, write mapping contents to (C2C)MAPPING & (C2C)SEGMENT tables
    my $dbh = shift; # database handle
    my $contig = shift;

# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# define the queries and the mapping source

    my $mquery; # for insert on the (C2C)MAPPING table 
    my $squery; # for insert on the (C2C)SEGMENT table
    my $mappings; # for the array of Mapping instances

my $test = 0; # to removed later
    while (my $nextword = shift) {
        my $value = shift;
        if ($nextword eq "type") {
# for read-to-contig mappings
            if ($value eq "read") {
                $mappings = $contig->getMappings();
                return 0 unless $mappings; # MUST have read-to-contig mappings
                $mquery = "insert into MAPPING " .
	                  "(contig_id,seq_id,cstart,cfinish,direction) ";
                $squery = "insert into SEGMENT " .
                          "(mapping_id,cstart,rstart,length) values ";
            }
# for contig-to-contig mappings
            elsif ($value eq "contig") {
                $mappings = $contig->getContigToContigMapping();
                return 1 unless $mappings; # MAY have contig-to-contig mappings
                $mquery = "insert into C2CMAPPING " .
	                  "(contig_id,linked_id,cstart,cfinish,direction) ";
                $squery = "insert into C2CSEGMENT " .
                          " (mapping_id,cstart,pstart,length) values ";
            }
            else {
                die "Invalid parameter value for ->putMappingsForContig";
            }
        }

# to be removed later
        elsif ($nextword eq "test") {
            $test = $value;
        }

        else {
            die "Invalid parameter $nextword for ->putMappingsForContig";
        }
    }

    die "Missing parameter for ->putMappingsForContig" unless $mappings;

    $mquery .= "values (?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($mquery);

    my $contigid = $contig->getContigID();

# 1) the overall mapping

    my $mapping;
    foreach $mapping (@$mappings) {

        my ($cstart, $cfinish) = $mapping->getContigRange();

        if ($test) {
# to be removed later
            print STDOUT "Mapping TEST: contig_id $contigid, seq_id ".
            $mapping->getSequenceID().
            " cstart $cstart, cfinal $cfinish, alignment ".
            $mapping->getAlignmentDirection()."\n";
            $mapping->setMappingID($test++);
            next;
        }

        my $rc = $sth->execute($contigid,
                               $mapping->getSequenceID(),
                               $cstart,
                               $cfinish,
                               $mapping->getAlignmentDirection()) 
              || &queryFailed($mquery);
        $mapping->setMappingID($dbh->{'mysql_insertid'}) if ($rc == 1);
    }

# 2) the individual segments (in block mode)

    my $success = 1;
    my $accumulated = 0;
    my $accumulatedQuery = $squery;
    my $lastMapping = $mappings->[@$mappings-1];
    foreach my $mapping (@$mappings) {
# test existence of mappingID
        my $mappingid = $mapping->getMappingID();
        if ($mappingid) {
            my $segments = $mapping->getSegments();
            foreach my $segment (@$segments) {
                my $length = $segment->normaliseOnX(); # order contig range
                my $cstart = $segment->getXstart();
                my $rstart = $segment->getYstart();
                $accumulatedQuery .= "," if $accumulated++;
                $accumulatedQuery .= "($mappingid,$cstart,$rstart,$length)";
            }
        }
        else {
            print STDERR "Mapping ".$mapping->getReadName().
		" has no mapping_id\n";
            $success = 0;
        }
# dump the accumulated query if a number of inserts has been reached
        if ($accumulated >= 100 || ($accumulated && $mapping eq $lastMapping)) {
            $sth = $dbh->prepare($accumulatedQuery); 
            my $rc = $sth->execute() || &queryFailed($squery);
            $success = 0 unless $rc;
            $accumulatedQuery = $squery;
            $accumulated = 0;
        }
    }
    return $success;
}

sub getLinkedContigsForContig {
# returns a list of connected contig(s) for input contig based on r-c mappings
    my $this = shift;
    my $contig = shift; # Contig Instance

    return undef unless $contig->hasReads();

    my $reads = $contig->getReads();

# get the sequenceIDs (from Read instances)

    my @seqids;
    foreach my $read (@$reads) {
        push @seqids,$read->getSequenceID();
    }

# we have to select linked contigs of age 0
# this query allows for empty entries in C2CMAPPING
# NOTE: the alternative query is getLinkedContigsForContigID using subqueries

    my $query = "select distinct(MAPPING.contig_id)".
                "  from MAPPING join C2CMAPPING using (contig_id)".
	        " where seq_id in (".join(',',@seqids).")".
                "   and age = 0 ".
                "UNION ".
                "select distinct(MAPPING.contig_id)".
                "  from MAPPING left join C2CMAPPING using (contig_id)".
	        " where seq_id in (".join(',',@seqids).")".
	        "   and age is null";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

    return [@contigids];
}

sub getLinkedContigsForContigID {
# returns a list of IDs of connected contig(s) using sub-queries
    my $this = shift;
    my $contig_id = shift;

# we have to select linked contigs of age 0 or missing from C2CMAPPING

    my $query = "select distinct(MAPPING.contig_id)".
                "  from MAPPING join C2CMAPPING using (contig_id)".
	        " where seq_id in ".
                "      (select seq_id from MAPPING where contig_id=$contig_id)".
                "   and age = 0 ".
                "UNION ".
                "select distinct(MAPPING.contig_id)".
                "  from MAPPING left join C2CMAPPING using (contig_id)".
	        " where seq_id in ".
                "      (select seq_id from MAPPING where contig_id=$contig_id)".
	        "   and age is null";
    
    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    my @contigids;
    while (my ($contigid) = $sth->fetchrow_array()) {
        push @contigids, $contigid;
    }

    $sth->finish();

    return [@contigids];
}

sub ageByOne {
# EXPERIMENTAL cascade age increase from the top
    my $this = shift;
    my @contigids = (shift); # initialise with one contig_id

    my $dbh = $this->getConnection();

# accumulate IDs of linked contigs by recursive query

    my @updateids;
    while (@contigids) {

        my $query = "select linked_id from C2CMAPPING" .
	            " where contig_id in (".join(',',@contigids).")";

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        undef @contigids;
        while (my ($linked_id) = $sth->fetchrow_array()) {
            push @updateids, $linked_id;
            push @contigids, $linked_id;
	}
    }

# here we have accumulated all IDs of contigs linked to input contig_id    
}

sub rebuildHistory {
# EXPERIMENTAL build contig links from scratch
    my $this = shift;

    my $dbh = $this->getConnection();

# step 1: reset the complete table to age 0

    my $query = "update C2CMAPPING set age=0";

    $dbh->do($query) || &queryFailed($query);

# step 2: get all contig_ids not among the linked_ids, i.e. true generation 0

    $query = "select C2C1.contig_id from C2CMAPPING as C2C1 left join".
             "                           C2CMAPPING as C2C2".
             "    on C2C1.contig_id = C2C2.linked_id".
             "   and C2C2.linked_id is null";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    undef my @contigids;
    while (my ($contig_id) = $sth->fetchrow_array()) {
        push @contigids, $contig_id;
    }

# step 3: each contig id is the starting point for tree build from the top

    foreach my $contig_id (@contigids) {
        $this->ageByOne($contig_id);
    }
}

#------------------------------------------------------------------------------
# methods dealing with contig TAGs
#------------------------------------------------------------------------------

sub getTagsForContig {
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getTagsForContig expects a Contig instance" 
    unless (ref($contig) eq 'Contig');

    return if $contig->hasTags(); # only 'empty' instance allowed

# to be completed
}

#------------------------------------------------------------------------------

1;
