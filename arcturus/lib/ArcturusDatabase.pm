package ArcturusDatabase;

use strict;

use DBI;
use Compress::Zlib;

use DataSource;
use Read;
use Contig;
use Mapping;
#use Bridge;

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = {};
    bless $this, $class;

    my $ds = @_[0];

    if (defined($ds) && ref($ds) && ref($ds) eq 'DataSource') {
	$this->{DataSource} = $ds;
    }
    else {
	$this->{DataSource} = new DataSource(@_);
    }

    $this->init();

    return $this;
}

sub init {
    my $this = shift;

    return if defined($this->{inited});

    my $ds = $this->{DataSource};

    $this->{Connection} = $ds->getConnection();

    $this->populateDictionaries();

    $this->{prepared} = {}; # placeholder for prepared queries

    $this->{inited} = 1;
}

sub getConnection {
    my $this = shift;

    if (!defined($this->{Connection})) {
	my $ds = $this->{DataSource};
	$this->{Connection} = $ds->getConnection() if defined($ds);
    }

    return $this->{Connection};
}

sub getURL {
    my $this = shift;

    my $ds = $this->{DataSource};

    if (defined($ds)) {
	return $ds->getURL();
    }
    else {
	return undef;
    }
}

# ----------------------------------------------------------------------------
# methods dealing with READs
#-----------------------------------------------------------------------------

sub populateDictionaries {
    my $this = shift;

    my $dbh = $this->{Connection};

    $this->{Dictionary} = {};

    $this->{Dictionary}->{insertsize}   = &createDictionary($dbh, 'LIGATIONS', 'ligation', 'silow, sihigh');
    $this->{Dictionary}->{ligation}     = &createDictionary($dbh, 'LIGATIONS', 'ligation', 'identifier');
    $this->{Dictionary}->{clone}        = &createDictionary($dbh, 'CLONES', 'clone', 'clonename');
    $this->{Dictionary}->{primer}       = &createDictionary($dbh, 'PRIMERTYPES', 'primer', 'type');
    $this->{Dictionary}->{status}       = &createDictionary($dbh, 'STATUS', 'status', 'identifier');
    $this->{Dictionary}->{strand}       = &createDictionary($dbh, 'STRANDS', 'strand', 'direction');
    $this->{Dictionary}->{basecaller}   = &createDictionary($dbh, 'BASECALLER', 'basecaller', 'name');
    $this->{Dictionary}->{svector}      = &createDictionary($dbh, 'SEQUENCEVECTORS', 'svector', 'name');
    $this->{Dictionary}->{cvector}      = &createDictionary($dbh, 'CLONINGVECTORS', 'cvector', 'name');
# special case for CHEMISTRY/CHEMTYPES
    $this->{Dictionary}->{chemistry}    = &createDictionary($dbh, 'CHEMISTRY LEFT JOIN arcturus.CHEMTYPES',
							    'chemistry', 'type', 'USING(chemtype)');
}

sub createDictionary {
    my ($dbh, $table, $pkey, $vals, $where, $junk)  = @_;

    #print STDERR "createDictionary($table, $pkey, $vals)\n";

    my $query = "SELECT $pkey,$vals FROM $table";

    $query .= " $where" if defined($where);

    my $sth = $dbh->prepare($query);

    if ($DBI::err) {
	my $msg = "createDictionary: prepare($query) failed";
	print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
	return undef;
    }

    $sth->execute();

    if ($DBI::err) {
	my $msg = "createDictionary: execute($query) failed";
	print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
	return undef;
    }

    my $dict = {};

    while(my @ary = $sth->fetchrow_array()) {
	my $key = shift @ary;
	if (scalar(@ary) > 1) {
	    $dict->{$key} = [@ary];
	} else {
	    $dict->{$key} = shift @ary;
	}
    }

    $sth->finish();

    return $dict;
}

sub dictionaryLookup {
    my ($dict, $pkey, $junk) = @_;

    if (defined($dict)) {
	my $value = $dict->{$pkey};
	return $value;
    }
    else {
	return undef;
    }
}

sub dictionaryInsert {
# add a new line to the dictionary table, if it does not exist
    my $this = shift;

}

sub processReadData {
# dictionary lookup
    my $this = shift;
    my $hashref = shift;

    $hashref->{'insertsize'} = $hashref->{'ligation'};

    foreach my $key (keys %{$hashref}) {
	my $dict = $this->{Dictionary}->{$key};
	my $value = $hashref->{$key};

	if (defined($dict)) {
	    $value = &dictionaryLookup($dict, $value);
	    if (ref($value) && ref($value) eq 'ARRAY') {
		$value = join(' ', @{$value});
	    }
	    $hashref->{$key} = $value;
	}
    }

# ligation info ?
}

#-----------------------------------------------------------------------------

sub getReadByID {
# returns a Read instance with (meta data only) for input read IDs 
    my $this = shift;

    my $readid = shift;

    my $sth = $this->{prepared}->{getReadByID};

    if (!defined($sth)) {

        my $dbh = $this->getConnection();

        $sth = $dbh->prepare("select * from READS where read_id=$readid");

        $this->{prepared}->{getReadByID} = $sth;
    }

    $sth->execute();

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {
	my $read = new Read();

	$this->processReadData($hashref);

	$read->importData($hashref);

	$read->setArcturusDatabase($this);

	return $read;
    } 
    else {
	return undef;
    }
}

sub getReadsByID {
# returns an array of Read instances with (meta data only) for input array of read IDs 
    my $this    = shift;
    my $readids = shift; # array ref

# in case a single read ID is passed as parameter, recast it as a one element array

    my @reads;

    $reads[0] = $readids;

    $readids = \@reads if (ref($readids) ne 'ARRAY');

# prepare the range list

    my $range = join ',',@$readids;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare("select * from READS where read_id in ($range)");

    $sth->execute();

    my @Reads;

    while (my $hashref = $sth->fetchrow_hashref()) {

	my $Read = new Read();

	$this->processReadData($hashref);

	$Read->importData($hashref);

	$Read->setArcturusDatabase($this);

        push @Reads, $Read;
    }

    $sth->finish();

    return \@Reads;
}

sub getReadsForContigID{
# returns an array of Reads (meta data only) for the given contig
    my $this = shift;
    my $cid  = shift; # contig_id

    my $sth = $this->{prepared}->{getReadsForContigID};

    if (!defined($sth)) {

        my $dbh = $this->getConnection();

        my $query = "select READS.* from READS join READS2CONTIG on (read_id) ";
        $query   .= "where READS2CONTIG.contig_id = $cid";

        $sth = $dbh->prepare($query);

        $this->{prepared}->{getReadsForContigID} = $sth;
    }

    $sth->execute();

    my @Reads;

    while (my $hashref = $sth->fetchrow_hashref()) {

	my $Read = new Read();

	$this->processReadData($hashref);

	$Read->importData($hashref);

	$Read->setArcturusDatabase($this);

        $Read->addToInventory;

        push @Reads, $Read;
    }

    $sth->finish();

    return \@Reads;
}

#-----------------------------------------------------------------------------

sub getSequenceAndBaseQualityForRead {
# returns DNA sequence (string) and quality (array reference)
# this method is called from the Read class when using lazy instantiation
    my $this = shift;
    my ($key, $value, $junk) = @_;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from ";

    if ($key eq 'id' || $key eq 'read_id') {
	$query .= "SEQUENCE where read_id=?";
    }
    elsif ($key eq 'name' || $key eq 'readname') {
	$query .= "READS left join SEQUENCE using(read_id) where readname=?";
    }

    my $sth = $dbh->prepare($query);

    $sth->execute($value);

    my ($sequence, $quality);

    while(my @ary = $sth->fetchrow_array()) {
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

sub putSequenceAndBaseQualityInReads {
# takes an array of Read instances and puts the DNA and quality sequence in
    my $this  = shift;
    my $Reads = shift; # array of Reads objects

# build a list of read IDs / or use the Read instances inventory

    my %rids;
    my $rids = \%rids;
    foreach my $Read (@$Reads) {
        $rids->{$Read->getReadID} = $Read;
    }
# my $rids = Read->getInventory; # handle to Read instances inventory

    my $range = join ',',keys(%$rids);

    my $dbh = $this->getConnection();

    my $query = "select read_id,sequence,quality from SEQUENCE where read_id in ($range)";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    while(my @ary = $sth->fetchrow_array()) {

	my ($read_id, $sequence, $quality) = @ary;

        if (my $Read = $rids->{$read_id}) {

            $sequence = uncompress($sequence) if defined($sequence);

            if (defined($quality)) {
	        $quality = uncompress($quality);
	        my @qualarray = unpack("c*", $quality);
	        $quality = [@qualarray];
            }
            $Read->setSequence($sequence);
            $Read->setQuality($quality);
        }
    }

    $sth->finish();

# test if all objects have been completed
}

sub getCommentForRead {
# returns a list of comments, if any, for the specifed read
    my $this = shift;
    my ($key,$value,$junk) = @_;

    my $query = "select comment from ";

    if ($key eq 'id' || $key eq 'read_id') {
	$query .= "READCOMMENT where read_id=?";
    }
    elsif ($key eq 'name' || $key eq 'readname') {
	$query .= "READS left join READCOMMENT using(read_id) where readname=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare($query);

    $sth->execute($value);

    my @comment;

    while(my @ary = $sth->fetchrow_array()) {
	push @comment, @ary;
    }

    $sth->finish();

    return \@comment;
}

#----------------------------------------------------------------------------------------- 

sub putRead {
# insert read into the database
    my $this = shift;
    my $Read = shift || return;

# a) test consistence and completeness
# b) encode dictionary items; specical case: TEMPLATE
# c) insert (if not exists) 1) readname, then for read_id=last_insert_id: 2) meta data READS
#                                             3) sequence into SEQUENCE 4) comments
}

sub updateRead {
# update items for an existing read
    my $this = shift;
    my $Read = shift || return;
}

sub pingRead {
# test if a readname is in the READS database table; return read_id, if exists
    my $this = shift;
    my $name = shift;
}

#----------------------------------------------------------------------------------------- 
# methods dealing with CONTIGs
#----------------------------------------------------------------------------------------- 

sub getContigByID {
# return a Contig object with the meta data only for the specified contig ID
    my $this       = shift;
    my $contig_id  = shift;

    my $sth = $this->{prepared}->{getContigByID};

    if (!defined($sth)) {

        my $dbh = $this->getConnection();

        $sth = $dbh->prepare("select * from CONTIGS where contig_id = ? ");

        $this->{prepared}->{getContigByID} = $sth;
    }

    $sth->execute();

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish($contig_id);

    if (defined($hashref)) {

	my $Contig = new Contig();

	$Contig->importData($hashref);

	$Contig->setArcturusDatabase($this);

        return $Contig;
    }
    else {
# no such contig found
        return undef;
    }
}

sub getContigByName {
# returns a Contig object with the meta data only for the specified contigname
    my $this = shift;
    my $name = shift;


    my $sth = $this->{prepared}->{getContigByName};

    if (!defined($sth)) {

        my $dbh = $this->getConnection();

        $sth = $dbh->prepare("select * from CONTIGS where contigname = ? or aliasname = ? ");

        $this->{prepared}->{getContigByName} = $sth;
    } 

    $sth->execute($name,$name);

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {

	my $Contig = new Contig();

	$Contig->importData($hashref);

	$Contig->setArcturusDatabase($this);

        return $Contig;
    }
    else {
# no such contig found
        return undef;
    }
}

sub getContigWithRead {
# returns a Contig object with the meta data only which contains the read specified by name
    my $this = shift;
    my $name = shift;


    my $sth = $this->{prepared}->{getContigWithRead};

    if (!defined($sth)) {

        my $dbh = $this->getConnection();

        my $query  = "select CONTIGS.* from CONTIGS join READS2CONTIG on (contig_id) where ";
           $query .= "read_id = (select read_id from READS where readname = ?)";
# ensure the latest contig
        $sth = $dbh->prepare($query);

        $this->{prepared}->{getContigWithRead} = $sth;
    } 

    $sth->execute($name);

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {

	my $Contig = new Contig();

	$Contig->importData($hashref);

	$Contig->setArcturusDatabase($this);

        return $Contig;
    }
    else {
# no such contig found
        return undef;
    }
}

sub getContigWithTag {
# returns a Contig object with the meta data only which contains the specified read
    my $this = shift;
    my $name = shift;

    my $dbh = $this->getConnection();

    my $query = "select CONTIGS.* from CONTIGS join TAGS2CONTIG on (contig_id) where ";
    $query   .= "tag_id = (select tag_id from TAGS where tagname = ?)";

# note: use the merge table concept for tag table, else query should be several UNIONs

    my $sth = $dbh->prepare($query);

# ? replace by prepared query 

    $sth->execute($name);

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {

	my $Contig = new Contig();

	$Contig->importData($hashref);

	$Contig->setArcturusDatabase($this);

        return $Contig;
    }
    else {
# no such contig found
        return undef;
    }
}

sub getContig {
# return a Contig instance with its Reads, Mappings and Tags for the given identification
    my $this  = shift;
    my $key   = shift;
    my $value = shift;

# create a new Contig instance and load the meta data

    my $Contig;

    if ($key eq 'id' || $key eq 'contig_id') {
	$Contig = $this->getContigByID($value);
    }
    elsif ($key eq 'name' || $key eq 'contigname') {
        $Contig = $this->getContigByName($value);
    }
    elsif ($key eq 'read') {
	$Contig = $this->getContigWithRead($value);
    }
    elsif ($key eq 'tag') {
	$Contig = $this->getContigWithTag($value);
    }

    return undef unless $Contig;

# get the reads for this contig with their DNA sequences

    Reads->clearInventory;

    my $Reads = $this->getReadsForContigID($Contig->getContigID); # an array ref

    $this->putSequenceAndBaseQualityForReads($Reads);

    $Contig->importReads($Reads);

# get mappings

    my $Mappings = $this->getMappingsForContigID($Contig->getContigID); # an array ref

    $Contig->importMappings($Mappings);

# link the Mappings to the Reads and vice versa

    foreach my $Mapping (@$Mappings) {
# find the Read instance for read_id taken from Mapping
        my $readid = $Mapping->getReadID;
# first test if there is such a Read
        if ( !(my $Read = Read->fingerRead($readid)) ) {
            print STDERR "! Incomplete contig $key=$value : no read for mapping ".$readid;
        }
# okay, now put the Mapping in and test if read and mapping correspond
        elsif (!$Read->setMapping($Mapping)) {
            print STDERR "! Inconsistent Read and Mapping instances for read ".$readid;
        }
        else {
# okay, finally put the reference to the in the read in the mapping
            $Mapping->setRead($Read);
        }
    }

# get tags

    my $Tags = $this->getTagsForContigID($Contig->getContigID); # an array ref

    $Contig->importTags($Tags);

# for consensus sequence we use lazy instantiation in the Contig class

    return $Contig;
}

sub getSequenceAndBaseQualityForContig {
# returns DNA sequence (string) and quality (array reference) for the specified contig
# this method is called from the Contig class when using lazy instantiation
    my $this = shift;
    my ($key, $value, $junk) = @_;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from ";

    if ($key eq 'id' || $key eq 'contig_id') {
	$query .= "SEQUENCE where contig_id = ?";
    }
    elsif ($key eq 'name' || $key eq 'contigname') {
	$query .= "CONTIGS left join SEQUENCE using(contig_id) where ";
        $query .= "contigname = ? or aliasname = ?";
    }

    my $sth = $dbh->prepare($query);

    $sth->execute($value,$value);

    my ($sequence, $quality);

    while(my @ary = $sth->fetchrow_array()) {
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

#----------------------------------------------------------------------------------------- 
# methods dealing with Mappings and links between Contigs
#----------------------------------------------------------------------------------------- 

sub getMappingsForContigID {
# returns an array of MAPPINGS for the input contig_id
    my $this = shift;
    my $cid  = shift;

    my $dbh = $this->getConnection();

# pull maps out in one step

    my $query = "select read_id, pcstart, pcfinal, prstart, prfinal, label ";
    $query   .= "from READS2CONTIG join R2CMAPPING using (mapping) ";
    $query   .= "where contig_id = ? and deprecated in ('M','N')";
    $query   .= "order by read_id,pcstart";

    my $sth = $dbh->prepare($query);

    $sth->execute($cid);

    my @Mappings;

    my $previousread_id = 0;
    while(my @ary = $sth->fetchrow_array()) {
# create a new Mapping instance and define its mapping number (signal it's from the database)
        my $label = pop @ary;
        my $read_id = shift @ary;
        if ($read_id != $previousread_id) {
# a Mapping instance does not yet exist for this read_id
            my $Mapping = new Mapping();
            $Mapping->setReadID($read_id);
            push @Mappings, $Mapping;
        }
        $Mapping->addUnpaddedAlignment(@ary) if ($label < 20);
        $Mapping->addOverallAlignment(@ary) if ($label >= 10);
    }

    $sth->finish();

    return [@Mappings];
}

sub getMappingsOfReadsInLinkedContigs {
# returns mappings in contigs of age=1 for an input array of read_ids
    my $this = shift;
    my $rids = shift; # array reference

    my $query = "select read_id, contig_id ";
    $query   .= "from READS2CONTIG as R2C, CONTIGS2CONTIG as C2C where ";
    $query   .= "C2C.newcontig = R2C.contig_id and age = 1 and ";
    $query   .= "R2C.read_id in (".join(',',@$rids).") and";
    $query   .= "R2C.deprecated in ('M','N')";

}

#----------------------------------------------------------------------------------------- 
# methods dealing with PROJECTs
#----------------------------------------------------------------------------------------- 

#----------------------------------------------------------------------------------------- 
# methods dealing with ASSEMBLYs
#----------------------------------------------------------------------------------------- 

1;
