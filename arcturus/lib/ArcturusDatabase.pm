package ArcturusDatabase;

use strict;

use DBI;
use Compress::Zlib;

use DataSource;
use Read;
use Contig;
use Mapping;
#use Bridge;
#use Tag;

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = {};
    bless $this, $class;

    my $ds = $_[0];

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

    my $ds = $this->{DataSource} || return; 

    $this->{Connection} = $ds->getConnection();

    return unless $this->{Connection};

    $this->populateDictionaries();

    $this->defineMetaData();

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

sub dataBaseError {
# local function error message on STDERR
    my $msg  = shift;

    print STDERR "$msg\n" if $msg;

    print STDERR "MySQL error: $DBI::err ($DBI::errstr)\n\n" if ($DBI::err);

    return $DBI::err;
}

sub queryFailed {
    my $query = shift;

    $query =~ s/\s+/ /g; # remove redundent white space

    &dataBaseError("FAILED query: $query");
}

sub errorStatus {
# returns DBI::err or 0
    my $this = shift;

    return "Can't get a database handle" unless $this->getConnection();

    return &dataBaseError() || 0;
}

sub disconnect {
# disconnect from the database
    my $this = shift;

    my $dbh = $this->{Connection};

    if (defined($dbh)) {
        $dbh->disconnect;
        undef $this->{Connection};
    }
}

# ----------------------------------------------------------------------------
# methods dealing with READs
#-----------------------------------------------------------------------------

sub defineMetaData {
    my $this = shift;

    $this->{read_attributes} = "readname,asped,strand,primer,chemistry,basecaller,status";
    $this->{template_addons} = "TEMPLATE.name as template,TEMPLATE.ligation_id";

    $this->{contig_attributes} = "length,ncntgs,nreads,newreads,cover,readnamehash";
}

sub populateDictionaries {
    my $this = shift;

    my $dbh = $this->getConnection();

    $this->{Dictionary} = {};

    $this->{Dictionary}->{insertsize} =
	&createDictionary($dbh, 'LIGATION', 'ligation_id', 'silow, sihigh');

    $this->{Dictionary}->{ligation} =
	&createDictionary($dbh, 'LIGATION', 'ligation_id', 'name');

    $this->{Dictionary}->{clone} =
	&createDictionary($dbh, 'LIGATION left join CLONE using (clone_id)',
			  'ligation_id', 'CLONE.name');

    $this->{Dictionary}->{status} =
	&createDictionary($dbh, 'STATUS', 'status_id', 'name');

    $this->{Dictionary}->{basecaller} =
	&createDictionary($dbh, 'BASECALLER', 'basecaller_id', 'name');

    $this->{Dictionary}->{svector} =
	&createDictionary($dbh, 'SEQUENCEVECTOR', 'svector_id', 'name');

    $this->{Dictionary}->{cvector} =
	&createDictionary($dbh, 'CLONINGVECTOR', 'cvector_id', 'name');

# template name will be loaded in individual read extraction queries
}

sub populateLoadingDictionaries {
    my $this = shift;

    my $dbh = $this->getConnection;

    $this->{LoadingDictionary} = {};

    $this->{LoadingDictionary}->{ligation} =
	&createDictionary($dbh, "LIGATION", "name", "ligation_id");

    $this->{LoadingDictionary}->{svector} =
	&createDictionary($dbh, "SEQUENCEVECTOR", "name", "svector_id");

    $this->{LoadingDictionary}->{cvector} =
	&createDictionary($dbh, "CLONINGVECTOR", "name", "cvector_id");

    $this->{LoadingDictionary}->{template} = {}; # dummy dictionary
#	&createDictionary($dbh, "TEMPLATE", "name", "template_id");

    $this->{LoadingDictionary}->{basecaller} =
	&createDictionary($dbh, "BASECALLER", "name", "basecaller_id");

    $this->{LoadingDictionary}->{clone} =
	&createDictionary($dbh, "CLONE", "name", "clone_id");

    $this->{LoadingDictionary}->{status} =
	&createDictionary($dbh, "STATUS", "name", "status_id");

    $this->{SelectStatement} = {};
    $this->{InsertStatement} = {};

    my %attributeQueries =
	('ligation',   ["select ligation_id from LIGATION where name=?",
			"insert ignore into LIGATION(name,silow,sihigh,clone_id) VALUES(?,?,?,?)"],
	 'template',   ["select template_id from TEMPLATE where name=?",
			"insert ignore into TEMPLATE(name, ligation_id) VALUES(?,?)"],
	 'basecaller', ["select basecaller_id from BASECALLER where name=?",
			"insert ignore into BASECALLER(name) VALUES(?)"],
	 'status',     ["select status_id from STATUS where name=?",
			"insert ignore into STATUS(name) VALUES(?)"],
	 'clone',      ["select clone_id from CLONE where name=?",
			"insert ignore into CLONE(name) VALUES(?)"],
	 'svector',    ["select svector_id from SEQUENCEVECTOR where name=?",
			"insert ignore into SEQUENCEVECTOR(name) VALUES(?)"],
	 'cvector',    ["select cvector_id from CLONINGVECTOR where name=?",
			"insert ignore into CLONINGVECTOR(name) VALUES(?)"]
	 );

    foreach my $key (keys %attributeQueries) {
	my ($squery, $iquery) = @{$attributeQueries{$key}};
	$this->{SelectStatement}->{$key} = $dbh->prepare_cached($squery);
	print STDERR "\"$squery\" failed: $DBI::errstr\n" if !defined($this->{SelectStatement}->{$key});
	$this->{InsertStatement}->{$key} = $dbh->prepare_cached($iquery);
	print STDERR "\"$iquery\" failed: $DBI::errstr\n" if !defined($this->{InsertStatement}->{$key});
    }
}

sub createDictionary {
    my ($dbh, $table, $pkey, $vals, $where, $junk)  = @_;

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

    if (defined($dict) && defined($pkey)) {
	my $value = $dict->{$pkey};
	return $value;
    }
    else {
	return undef;
    }
}

sub dictionaryInsert {
    my ($dict, $pkey, $value, $junk) = @_;

    if (defined($dict) && defined($pkey)) {
	$dict->{$pkey} = $value;
    }
}

sub translateDictionaryReadItems {
# dictionary lookup (recall mode: IDs to values)
    my $this = shift;
    my $hashref = shift;

    $hashref->{'insertsize'} = $hashref->{'ligation'};
    $hashref->{'clone'}      = $hashref->{'ligation'};

    foreach my $key (keys %{$hashref}) {
	my $dict = $this->{Dictionary}->{$key};
	my $k_id = $hashref->{$key};

	if (defined($dict)) {
            
	    my $value = &dictionaryLookup($dict, $k_id);
	    if (ref($value) && ref($value) eq 'ARRAY') {
		$value = join(' ', @{$value});
	    }
	    $hashref->{$key} = $value;
	}
    }
}

sub countReadDictionaryItem {
# return list with number of occurences for read dictionary items 
    my $this = shift;
    my $item = shift;

    my $dbh = $this->getConnection();

# compose the counting query

    my $query = "select count(*) as count,";

    if ($item eq 'ligation') {
        $query .= "TEMPLATE.ligation_id from READS,TEMPLATE 
                   where READS.template_id=TEMPLATE.template_id 
                   group by ligation_id";
    }
    elsif ($item eq 'clone') {
# build the clone names dictionary on clone_id (different from the one on ligation_id)
        $this->{Dictionary}->{clonename} =
	       &createDictionary($dbh, 'CLONE','clone_id', 'name');
        $query .= "LIGATION.clone_id from READS,TEMPLATE,LIGATIONS 
                   where READS.template_id=TEMPLATE.template_id 
                     and TEMPLATE.ligation_id=LIGATION.ligation_id 
                   group by clone_id";
        $item = 'clonename';
    }
    elsif ($item =~ /\b(strand|primer|chemistry|basecaller|status)\b/) {
        $query .= "$item from READS group by $item";
    }
    elsif ($item eq 'svector') {
        $query .= "SEQVEC.svector_id, from READS,SEQ2READ,SEQVEC
                   where READS.read_id = SEQ2READ.read_id
                   and   SEQ2READ.seq_id = SEQVEC.seq_id
                   and   SEQ2READ.version = 0
                   group by svector_id";
    }
    elsif ($item eq 'cvector') {
        $query .= "CLONEVEC.cvector_id, from READS,SEQ2READ,CLONEVEC
                   where READS.read_id = SEQ2READ.read_id
                   and   SEQ2READ.seq_id = CLONEVEC.seq_id
                   and   SEQ2READ.version = 0
                   group by cvector_id";
    }
    else {
        return undef; 
    }

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my %outputhash;

    while (my @ary = $sth->fetchrow_array()) {
        my ($count,$value) = @ary;
# translate value if it is an identifier
        if (my $dict = $this->{Dictionary}->{$item}) {
            $value = &dictionaryLookup($dict, $value) if $value;
        }
        $value = 'NULL' unless defined($value); # deal with NULL 
        $outputhash{$value} = $count;
    }

    $sth->finish();

    return \%outputhash;
}

#-----------------------------------------------------------------------------

sub getRead {
# returns a Read instance with (meta data only) for input read IDs 
# parameter usage: read_id=>ID or readname=>NAME, version=>VERSION
    my $this = shift;

# compose the query

    my $query = "select READS.read_id,SEQ2READ.seq_id,
                 $this->{read_attributes},$this->{template_addons}
                  from READS,SEQ2READ,TEMPLATE 
                 where READS.read_id = SEQ2READ.read_id
                   and READS.template_id = TEMPLATE.template_id ";

    my $nextword;
    my $readitem;
    undef my $version;
    while ($nextword = shift) {

        if ($nextword eq 'seq_id') {
            $query .= "and SEQ2READ.seq_id = ?";
            $readitem = shift;
        }
        elsif ($nextword eq 'read_id') {
            $query .= "and READS.read_id = ?";
            $readitem = shift;
            $version = 0 unless defined($version); # define default
        }
        elsif ($nextword eq 'readname') {
            $query .= "and READS.readname = ?";
            $readitem = shift;
            $version = 0 unless defined($version); # define default
        }
        elsif ($nextword eq 'version') {
            $version = shift;
        }
        else {
            print STDERR "Invalid parameter '$nextword' for ->getRead\n";
        }
    }

# add version sepecification if it is defined

    $query .= " and SEQ2READ.version = $version" if defined ($version);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readitem) || &queryFailed($query);

    my ($read_id, $seq_id, @attributes) = $sth->fetchrow_array();

    $sth->finish();

    if (defined($read_id)) {
	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion($version);

        $this->addMetaDataForRead($read, @attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

	return $read;
    } 
    else {
	return undef;
    }
}

sub getReadBySequenceID {
    my $this = shift;
    $this->getRead(seq_id=>shift);
}

sub getReadByReadID {
    my $this = shift;
    $this->getRead(read_id=>shift,version=>shift);
}

sub getReadByName {
    my $this = shift;
    $this->getRead(readname=>shift,version=>shift);
}

sub addMetaDataForRead {
# private method: set meta data for input Read 
    my $this = shift;
    my $read = shift; # Read instance
    my ($readname,$asped,$strand,$primer,$chemistry,$basecaller_id,$status_id,$template,$ligation_id) = @_;

    $read->setReadName($readname);

    $read->setAspedDate($asped);
    $read->setStrand($strand);
    $read->setPrimer($primer);
    $read->setChemistry($chemistry);

    my $basecaller = &dictionaryLookup($this->{Dictionary}->{basecaller},
				       $basecaller_id);
    $read->setBaseCaller($basecaller);

    my $status = &dictionaryLookup($this->{Dictionary}->{status},
				   $status_id);
    $read->setProcessStatus($status);

    $read->setTemplate($template);

    my $ligation = &dictionaryLookup($this->{Dictionary}->{ligation},
				     $ligation_id);
    $read->setLigation($ligation);

    my $insertsize = &dictionaryLookup($this->{Dictionary}->{insertsize},
				       $ligation_id);
    $read->setInsertSize($insertsize);

    my $clone = &dictionaryLookup($this->{Dictionary}->{clone},
			          $ligation_id);
    $read->setClone($clone);
}

sub addSequenceMetaDataForRead {
# private method : add sequence vector and cloning vector data to Read
    my $this = shift;
    my $read = shift; # Read instance

    my $dbh = $this->getConnection() || return;

    my $seq_id = $read->getSequenceID;

# sequencing vector

    my $query = "select svector_id,svleft,svright from SEQVEC where seq_id=?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query);

    while (my ($svector_id, $svleft, $svright) = $sth->fetchrow_array()) {
	my $svector = &dictionaryLookup($this->{Dictionary}->{svector},$svector_id);

	$read->addSequencingVector([$svector, $svleft, $svright]);
    }

    $sth->finish();

# cloning vector, if any

    $query = "select cvector_id,cvleft,cvright from CLONEVEC where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query);

    while (my ($cvector_id, $cvleft, $cvright) = $sth->fetchrow_array()) {
        my $cvector = &dictionaryLookup($this->{Dictionary}->{cvector},$cvector_id);

	$read->addCloningVector([$cvector, $cvleft, $cvright]);
    }

    $sth->finish();

# quality clipping

    $query = "select qleft,qright from QUALITYCLIP where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query);

    if (my ($qleft, $qright) = $sth->fetchrow_array()) {

        $read->setLowQualityLeft($qleft);
        $read->setLowQualityRight($qright);
    }

    $sth->finish();

# multiple align to trace records, if any

    return unless $read->getVersion();

    $query = "select startinseq,startinscf,length from ALIGN2SCF where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query);

    while (my($startinseq, $startinscf, $length) = $sth->fetchrow_array()) {
# convert to intervals
        my $finisinseq = $startinseq + $length - 1;
        my $finisinscf = $startinscf + $length - 1;

	$read->addAlignToTrace([$startinseq,$finisinseq,$startinscf,$finisinscf]);
    }

    $sth->finish();   
}

sub getReadsByReadID {
# returns array of Read instances with (meta data only) for input array of read IDs 
    my $this    = shift;
    my $readids = shift; # array ref

    if (ref($readids) ne 'ARRAY') {
        die "'getReadsByReadID' method expects an array of readIDs";
    }

# prepare the range list

    my $range = join ',',sort @$readids;

    my $dbh = $this->getConnection();

# retrieve version 0 (un-edited reads only, the raw data)

    my $query = "select READS.read_id,SEQ2READ.seq_id,
                 $this->{read_attributes},$this->{template_addons}
                  from READS,SEQ2READ,TEMPLATE 
                 where READS.read_id = SEQ2READ.read_id and version = 0 
                   and READS.template_id = TEMPLATE.template_id 
                   and READS.read_id in ($range)";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my @reads;

    while (my ($read_id, $seq_id, @attributes) = $sth->fetchrow_array()) {

	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion(0);

        $this->addMetaDataForRead($read,@attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

        push @reads, $read;
    }

    $sth->finish();

    return \@reads;
}

sub getSequenceIDForRead {
    my $this = shift;

    my $idtype = shift;
    my $idvalue = shift;

    my $version = shift;

    $version = 0 unless defined($version);

    my $query;

    if ($idtype eq 'readname') {
	$query = "select seq_id from READS left join SEQ2READ using(read_id) " .
                 "where READS.readname=? " .
	         "and version=?";
    } else {
	$query = "select seq_id from SEQ2READ where read_id=? and version=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($idvalue, $version) || &queryFailed($query);

    my ($seq_id) = $sth->fetchrow_array();

    $sth->finish();   

    return $seq_id;
}

sub getReadsBySequenceID {
# returns an array of Read instances with (meta data only) for input array of sequence IDs
    my $this = shift;
    my $seqids = shift; # array ref

    if (ref($seqids) ne 'ARRAY') {
        die "'getReadsBySequenceID' method expects an array of seqIDs";
    }

# prepare the range list

    my $range = join ',',sort @$seqids;

    my $dbh = $this->getConnection();

# retrieve version 0 (un-edited reads only, the raw data)

    my $query = "select READS.read_id,SEQ2READ.seq_id,SEQ2READ.version," .
                "$this->{read_attributes},$this->{template_addons}" .
                " from SEQ2READ,READS,TEMPLATE ".
                "where READS.read_id = SEQ2READ.read_id".
                "  and READS.template_id = TEMPLATE.template_id". 
                "  and SEQ2READ.seq_id in ($range)";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    my @reads;

    while (my ($read_id, $seq_id, $version, @attributes) = $sth->fetchrow_array()) {

	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion($version);

        $this->addMetaDataForRead($read,@attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

        push @reads, $read;
    }

    $sth->finish();

    return \@reads;
}

sub getReadsForContig {
# puts an array of (complete, for export) Read instances for the given contig
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getReadsForContig expects a Contig instance" unless (ref($contig) eq 'Contig');

    return if $contig->hasReads(); # only 'empty' instance allowed

    my $dbh = $this->getConnection();

# NOTE: this query is to be TESTED may have to be optimized

    my $query = "select READS.read_id,SEQ2READ.seq_id,SEQ2READ.version," .
                "$this->{read_attributes},$this->{template_addons}" .
                " from MAPPING,SEQ2READ,READS,TEMPLATE " .
                "where MAPPING.contig_id = ?" .
                "  and MAPPING.seq_id = SEQ2READ.seq_id" .
                "  and SEQ2READ.read_id = READS.read_id" .
                "  and READS.template_id = TEMPLATE.template_id";

    my $sth = $dbh->prepare_cached($query);

# print STDERR "getReadsForContig ContigID: $query\n";
    my $nr = $sth->execute($contig->getContigID) || &queryFailed($query);

    my @reads;

    while (my ($read_id, $seq_id, $version, @attributes) = $sth->fetchrow_array()) {
# print STDERR "results: $read_id, $seq_id, $version, @attributes\n";
	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion($version);

        $this->addMetaDataForRead($read,@attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

        push @reads, $read;
    }

    $sth->finish();

# add the sequence (in bulk)

    $this->getSequenceForReads([@reads]);

# add tags (in bulk)

#    $this->getTagsForReads(\@reads);

# and add to the contig

    $contig->addRead([@reads]);
}

sub getSequenceForReads {
# takes an array of Read instances and adds the DNA and BaseQuality (in bulk)
    my $this  = shift;
    my $reads = shift; # array of Reads objects

    if (ref($reads) ne 'ARRAY' or ref($reads->[0]) ne 'Read') {
        print STDERR "getSequenceForReads expects an array of Read objects\n";
        return undef;
    }

    my $dbh = $this->getConnection();

# build a list of sequence IDs (all sequence IDs must be defined)

    my $sids = {};
    foreach my $read (@$reads) {
# test if sequence ID is defined
        if (my $seq_id = $read->getSequenceID()) {
            $sids->{$seq_id} = $read;
        }
        else {
# warning message
            print STDERR "Missing sequence identifier in read ".
                          $read->getReadName."\n";
        }
    }

    return unless keys(%$sids);

    my $range = join ',',sort keys(%$sids);

    my $query = "select seq_id,sequence,quality from SEQUENCE " .
                " where seq_id in ($range)";

#print STDERR "getSequenceForReads : $query \n";
    my $sth = $dbh->prepare($query);

# pull the data from the SEQUENCE table in bulk

    $sth->execute() || &queryFailed($query);

    while(my @ary = $sth->fetchrow_array()) {

	my ($seq_id, $sequence, $quality) = @ary;

        if (my $read = $sids->{$seq_id}) {

            $sequence = uncompress($sequence) if defined($sequence);

            if (defined($quality)) {
	        $quality = uncompress($quality);
	        my @qualarray = unpack("c*", $quality);
	        $quality = [@qualarray];
            }
            $read->setSequence($sequence);
            $read->setQuality($quality);
        }
    }

    $sth->finish();

# NOTE : test if all objects have been completed to be done outside this method
#        see getUnassembledReads and testContig
}

#-----------------------------------------------------------------------------

sub getSequenceForRead {
# returns DNA sequence (string) and quality (array reference) for read_id,
# readname or seq_id
# this method is called from the Read class when using delayed data loading
    my $this = shift;
    my ($key, $value, $version) = @_;

    my $query = "select sequence,quality from ";

    if ($key eq 'seq_id') {
	$query .= "SEQUENCE where seq_id=?";
    }
    elsif ($key eq 'id' || $key eq 'read_id') {
        $version = 0 unless defined($version);
	$query .= "SEQUENCE,SEQ2READ " . 
                  "where SEQUENCE.seq_id=SEQ2READ.seq_id" .
                  "  and SEQ2READ.version = $version" .
                  "  and SEQ2READ.read_id = ?";
    }
    elsif ($key eq 'name' || $key eq 'readname') {
        $version = 0 unless defined($version);
	$query .= "SEQUENCE,SEQ2READ,READS " .
                  "where SEQUENCE.seq_id=SEQ2READ.seq_id" .
                  "  and SEQ2READ.version = $version" .
                  "  and READS.read_id = SEQ2READ.read_id" .
                  "  and READS.readname = ?";
    }
# print STDERR "getSequenceForRead: $query ($value)\n";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

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

sub getCommentForRead {
# returns a list of comments, if any, for the specifed read
# this method is called from Read class when using delayed data loading
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

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

    my @comment;

    while(my @ary = $sth->fetchrow_array()) {
	push @comment, @ary;
    }

    $sth->finish();

    return [@comment];
}

sub getTraceArchiveIdentifier {
# returns the trace archive reference, if any, for the specifed read
# this method is called from the Read class when using delayed data loading
    my $this = shift;
    my ($key,$value,$junk) = @_;

    my $query = "select traceref from ";

    if ($key eq 'id' || $key eq 'read_id') {
	$query .= "TRACEARCHIVE where read_id=?";
    }
    elsif ($key eq 'name' || $key eq 'readname') {
	$query .= "READS left join TRACEARCHIVE using(read_id) 
                   where readname=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query);

    my $traceref;

    while(my @ary = $sth->fetchrow_array()) {
	$traceref = shift @ary;
    }

    $sth->finish();

    return $traceref;
}

#-----------------------------------------------------------------------------

sub getListOfReadNames {
# returns an array of (all) readnames occurring in the database 
    my $this = shift;

# decode extra  input

    my $onlySanger = 0;
    my $noTraceRef = 0;

    my $nextword;
    while ($nextword = shift) {
        $onlySanger = shift if ($nextword eq "onlySanger");
        $noTraceRef = shift if ($nextword eq "noTraceRef");
    }

# compose the query

    my $query = "select readname from READS ";

    if ($noTraceRef) {
        $query .= "left join TRACEARCHIVE as TA using (read_id) 
                   where TA.read_id IS NULL ";
    }
    if ($onlySanger) {
        $query .= "and readname like \"%.%\"";
        $query =~ s/\band\b/where/ if ($query !~ /\bwhere\b/);
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    my @reads;
    while (my @ary = $sth->fetchrow_array()) {
        push @reads, $ary[0];
    }

    $sth->finish();

    return \@reads;
}

sub getListOfEditedSequences {
# return a list of sequence IDs where version>0
    my $this = shift;

    my $query = "select seq_id from SEQ2READ where version > 0";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    my @seqids;
    while (my @ary = $sth->fetchrow_array()) {
        push @seqids, $ary[0];
    }

    $sth->finish();

    return \@seqids;
# use getReadBySequenceID to access the individual reads
}

sub hasRead {
# test presence of read with specified readname; return (first) read_id
    my $this      = shift;
    my $readname  = shift || return; # readname to be tested

    my $dbh = $this->getConnection();
   
    my $query = "select read_id from READS where readname=?";

    my $sth = $dbh->prepare_cached($query);

    my $read_id;

    $sth->execute($readname) || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        $read_id = $ary[0];
        last; # just in case
    }

    $sth->finish();

    return $read_id;
}

sub areReadsNotInDatabase {
# return a list of those readnames from an input list which are NOT present
    my $this      = shift;
    my $readnames = shift; # array reference with readnames to be tested

    if (ref($readnames) ne 'ARRAY') {
        print STDERR "areReadsNotInDatabase expects an array of readnames\n";
        return undef;
    }

    my %namehash;
    foreach my $name (@$readnames) {
        $namehash{$name}++;
    }

    my $dbh = $this->getConnection();
   
    my $query = "select readname from READS 
                 where  readname in ('".join ("','",@$readnames)."')";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        delete $namehash{$ary[0]};
    }

    $sth->finish();

    my @notPresent = keys %namehash; # the left over

    return \@notPresent;
}

sub getUnassembledReads {
# return an array of Read instances with unassembled reads
    my $this = shift;

# to be  completed

    my @reads;

# add the sequence (in bulk)

    $this->getSequenceForReads([@reads]);

    my $complete = 1;
    foreach my $read (@reads) {
        next if $read->hasSequence();
        print STDERR "Missing sequence for Read ".$read->getReadName()."\n";
        $complete = 0;
    }

    return $complete;

}

#------------------------------------------------------------------------------

sub putRead {
# insert read into the database
    my $this = shift;
    my $read = shift;
    my $options = shift;

    if (ref($read) ne 'Read') {
        return (0,"putRead expects an instance of the Read class");
    }

# a) test consistency and completeness

    my ($rc, $errmsg) = $this->checkReadForCompleteness($read, $options);
    return (0, "failed completeness check ($errmsg)") unless $rc;

    ($rc, $errmsg) = $this->checkReadForConsistency($read);
    return (0, "failed consistency check ($errmsg)") unless $rc;

# b) encode dictionary items; special case: template & ligation

    my $dbh = $this->getConnection();

    # CLONE

#    my $clone_id = $this->getReadAttributeID('clone',$read->getClone());
    my $clone_id = &getReadAttributeID($read->getClone(),
				       $this->{LoadingDictionary}->{'clone'},
				       $this->{SelectStatement}->{'clone'},
				       $this->{InsertStatement}->{'clone'});
    $clone_id = 0 unless defined($clone_id); # ensure its definition

    # LIGATION

    my ($sil,$sih) = @{$read->getInsertSize()}; 

#    my $ligation_id = $this->getReadAttributeID('ligation',$read->getLigation(),
#					   [$sil, $sih, $clone_id]);
    my $ligation_id = &getReadAttributeID($read->getLigation(),
					  $this->{LoadingDictionary}->{'ligation'},
					  $this->{SelectStatement}->{'ligation'},
					  $this->{InsertStatement}->{'ligation'},
					  [$sil, $sih, $clone_id]);

    return (0, "failed to retrieve ligation_id") unless defined($ligation_id);

    # TEMPLATE

#    my $template_id = $this->getReadAttributeID('template',$read->getTemplate(),
#					   [$ligation_id]);
    my $template_id = &getReadAttributeID($read->getTemplate(),
					  $this->{LoadingDictionary}->{'template'},
					  $this->{SelectStatement}->{'template'},
					  $this->{InsertStatement}->{'template'},
					  [$ligation_id]);

    return (0, "failed to retrieve template_id") unless defined($template_id);

# c) encode dictionary items basecaller, clone, status

    # BASECALLER

#    my $basecaller = $this->getReadAttributeID('basecaller',$read->getBaseCaller());
    my $basecaller = &getReadAttributeID($read->getBaseCaller(),
					 $this->{LoadingDictionary}->{'basecaller'},
					 $this->{SelectStatement}->{'basecaller'},
					 $this->{InsertStatement}->{'basecaller'});

    # STATUS

#    my $status = $this->getReadAttributeID('status',$read->getProcessStatus());
    my $status = &getReadAttributeID($read->getProcessStatus(),
				     $this->{LoadingDictionary}->{'status'},
				     $this->{SelectStatement}->{'status'},
				     $this->{InsertStatement}->{'status'});

# d) insert Read meta data

    return (0, "no database connection") unless defined($dbh);

    my $readname = $read->getReadName();

    my $query = "insert into" .
	" READS(readname,asped,template_id,strand,chemistry,primer,basecaller,status)" .
	    " VALUES(?,?,?,?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($readname,
			$read->getAspedDate(),
			$template_id,
			$read->getStrand(),
			$read->getChemistry(),
			$read->getPrimer(),
			$basecaller,
                        $status);

    return (0, "failed to insert readname and core data into READS table;DBI::errstr=$DBI::errstr")
	unless (defined($rc) && $rc == 1);

    my $readid = $dbh->{'mysql_insertid'};

    $sth->finish();

    $read->setReadID($readid);

    my ($seq_id,$report) = $this->putSequenceForRead($read);
    return (0,$report) unless $seq_id;

# insert READCOMMENT, if any

    if (my $comments = $read->getComment()) {
        foreach my $comment (@$comments) {
            $rc = $this->putCommentForReadID($readid,$comment);
	    return (0, "failed to insert comment for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless $rc;
        }
    }

    $read->setSequenceID($seq_id);
    $read->setVersion(0);

    return (1, "OK"); # or $readid?
}

# SPLIT this part of because we will need it to insert edited sequences

sub putSequenceForRead {
# private method to load all sequence related data
    my $this = shift;
    my $read = shift; # Read instance
    my $version = shift || 0;

    my $readid = $read->getReadID();
    my $readname = $read->getReadName();

    my $dbh = $this->getConnection();

# Get a seq_id for this read

    my $query = "insert into SEQ2READ(read_id,version) VALUES(?,?)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($readid,$version);

    return (0, "failed to insert read_id into SEQ2READ table;DBI::errstr=$DBI::errstr")
	unless (defined($rc) && $rc == 1);

    my $seqid = $dbh->{'mysql_insertid'};

    $sth->finish();

# insert sequence and base quality

    my $sequence = compress($read->getSequence());

    my $basequality = compress(pack("c*", @{$read->getQuality()}));

    $query = "insert into SEQUENCE(seq_id,seqlen,sequence,quality) VALUES(?,?,?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($seqid, $read->getSequenceLength(), $sequence, $basequality);

# shouldn't we undo the insert in READS? if it fails

    return (0, "failed to insert sequence and base-quality for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

# Insert quality clipping

    $query = "insert into QUALITYCLIP(seq_id, qleft, qright) VALUES(?,?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($seqid, $read->getLowQualityLeft(), $read->getLowQualityRight());

# shouldn't we undo the insert in READS? if it fails

    return (0, "failed to insert quality clipping data for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();


# insert sequencing vector data, if any

    my $seqveclist = $read->getSequencingVector();

    if (defined($seqveclist)) {
	$query = "insert into SEQVEC(seq_id,svector_id,svleft,svright) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$seqveclist}) {

	    my ($seqvec, $svleft, $svright) = @{$entry};

#	    my $seqvecid = $this->getReadAttributeID('svector',$seqvec) || 0;
	    my $seqvecid = &getReadAttributeID($seqvec,
				               $this->{LoadingDictionary}->{'svector'},
				               $this->{SelectStatement}->{'svector'},
				               $this->{InsertStatement}->{'svector'}) || 0;

	    $rc = $sth->execute($seqid, $seqvecid, $svleft, $svright);

	    return (0, "failed to insert seq_id,svector_id,svleft,svright into SEQVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

# insert cloning vector data, if any

    my $cloneveclist = $read->getCloningVector();

    if (defined($cloneveclist)) {
	$query = "insert into CLONEVEC (seq_id,cvector_id,cvleft,cvright) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$cloneveclist}) {
	    my ($clonevec, $cvleft, $cvright) = @{$entry};

#	    my $clonevecid = $this->getReadAttributeID('cvector',$clonevec) || 0;
	    my $clonevecid = &getReadAttributeID($clonevec,
				                 $this->{LoadingDictionary}->{'cvector'},
				                 $this->{SelectStatement}->{'cvector'},
				                 $this->{InsertStatement}->{'cvector'}) || 0;

	    $rc = $sth->execute($seqid,$clonevecid, $cvleft, $cvright);

	    return (0, "failed to insert seq_id,cvector_id,cvleft,cvright into CLONEVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

    return (1, "OK");
}

sub putNewSequenceForRead {
# add the sequence of this read as a new (edited) sequence for existing read
    my $this = shift;
    my $read = shift; # a Read instance

    die "ArcturusDatabase->putNewSequenceForRead expects a Read instance " .
        "as parameter" unless (ref($read) eq 'Read');

# a) test if the readname already occurs in the database

    my $readname = $read->getReadName();
    return (0,"incomplete Read instance: missing raedname") unless $readname; 

# get and/or test readname against read_id (we don't know how $read was made)

    my $read_id = $this->hasRead($readname);

    if (!$read_id) {
        return (0,"unknown read $readname");
    } 
    elsif ($read->getReadID() && $read->getReadID() != $read_id) {
        return (0,"incompatible read IDs (".$read->getReadID." vs $read_id)");
    }
    
# b) test if it is an edited read by counting alignments to the trace file

    my $alignToSCF = $read->getAlignToTrace();
    if ($alignToSCF && scalar(@$alignToSCF) <= 1) {
     return (0,"insufficient alignment information") unless $read->isEdited();
print STDERR "read slipped through edited test:",$read->getReadName()."\n";
return;
    }

# c) ok, now we get the previous versions of the read and compare

    my $prior;  
    my $version = 0;
    while ($version == 0 || $prior) {
        $prior = $this->getRead(read_id=>$read_id,version=>$version);
        if ($prior && $prior->compareSequence($read)) {
	    my $seq_id = $prior->getSequenceID();
            $read->setSequenceID($seq_id);
            $read->setVersion($version);
            return ($seq_id,"is identical to version $version");
        }
        $version++;
    }

# d) load this new version of the sequence

    my ($seq_id, $errmsg) = $this->putSequenceForRead($read,$version); 
    return (0, "failed to load new sequence ($errmsg)") unless $seq_id;

    $read->setSequenceID($seq_id);
    $read->setVersion($version);

    return ($seq_id,"OK");
}


sub putCommentForReadID {
# add a comment for a given read_id (finishers entry of comment?)
    my $this = shift;
    my $read_id = shift;
    my $comment = shift;

    return 0 unless ($read_id && $comment =~ /\S/);

    my $dbh = $this->getConnection();

    my $query = "insert into READCOMMENT (read_id,comment) VALUES (?,?)";

    my $sth = $dbh->prepare_cached($query);

    return $sth->execute($read_id,$comment) ? 1 : 0;
}

sub putCommentForReadName {
# add a comment for a given readname (finishers entry of comment?)
    my $this = shift;

    my $readid = $this->hasRead(shift);
    return $this->putCommentForReadID($readid,shift);
}

sub checkReadForCompleteness {
    my $this = shift;
    my $read = shift;
    my $options = shift;

    my $skipAspedCheck = 0;

    if (defined($options) && ref($options) && ref($options) eq 'HASH') {
	$skipAspedCheck = $options->{skipaspedcheck} || 0;
    }

    return (0, "invalid argument")
	unless (defined($read) && ref($read) && ref($read) eq 'Read');

    return (0, "undefined readname")
	unless defined($read->getReadName());

    return (0, "undefined sequence")
	unless defined($read->getSequence());

    return (0, "undefined base-quality")
	unless defined($read->getQuality());

    return (0, "undefined asped-date")
	unless (defined($read->getAspedDate()) || $skipAspedCheck);

    return (0, "undefined template")
	unless defined($read->getTemplate());

    return (0, "undefined ligation")
	unless defined($read->getLigation());

    return (0, "undefined insert-size")
	unless defined($read->getInsertSize());

    return (0, "undefined strand")
	unless defined($read->getStrand());

    return (0, "undefined chemistry")
	unless defined($read->getChemistry());

    return (0, "undefined primer")
	unless defined($read->getPrimer());

    return (0, "undefined low-quality-left")
	unless defined($read->getLowQualityLeft());

    return (0, "undefined low-quality-right")
	unless defined($read->getLowQualityRight());

    return (1, "OK");
}

sub checkReadForConsistency {
    my $this = shift;
    my $read = shift || return (0,"Missing Read instance");

# check process status 

    if (my $status = $read->getProcessStatus()) {
        return (0,$status) if ($status =~ /Completely\ssequencing\svector/i);
        return (0,"Low $status") if ($status =~ /Trace\squality/i);
        return (0,$status) if ($status =~ /Matches\sYeast/i);
    }

    # This method should check the template, ligation and insert size to ensure
    # that they are mutually consistent.

    #
    # For now, assume everything is okay and return 1.

    return (1, "OK");
}

###
### This method is used to return the database ID of a read attribute
### such as a template or ligation, given its identifier.
###
### The lookup follows a three-stage strategy:
###
### 1. Search the supplied dictionary hash. If the identifier is a
###    key of the hash, then return the value.
###
### 2. Search the database table using the supplied SELECT statement
###    handle. The statement is executed with a single parameter, the
###    identifier. It should return a single item, the attribute ID.
###    If the query returns a non-empty result set, add the identifier
###    and its corresponding ID to the dictionary and return the ID.
###
### 3. Attempt to insert a new identifier into the database table
###    using the supplied INSERT statement handle. This can also
###    take additional data, if the fifth parameter is defined.
###    If the insert was successful, extract the attribute ID value
###    that was assigned by the database server, add it to the
###    dictionary and return it.
###
###    The insert may have been a MySQL "INSERT IGNORE" command, so
###    a zero inserted row count is possible. In this case, we re-try
###    the SELECT query.
###
###    If all three stages fail, return undef.
###

sub getReadAttributeID {
    my $identifier = shift;
    my $dict = shift;
    my $select_sth = shift;
    my $insert_sth = shift;
    my $extra_data = shift;

# ALTERNATIVE?
# sub getReadAttributeID {
#     my $this = shift;
#     my $section = shift; # ('cvector','ligation' etc)
#     my $identifier = shift;
#     my $extra_data = shift;

#     my $dict = $this->{LoadingDictionary}->{$section} || return undef;
#     my $select_sth = $this->{SelectStatement}->{$section};
#     my $insert_sth = $this->{InserttStatement}->{$section};

    return undef unless (defined($identifier) && defined($dict));

# 1

    my $id = &dictionaryLookup($dict, $identifier);

    return $id if defined($id);

# 2
   
    return undef unless defined($select_sth);

    my $rc = $select_sth->execute($identifier);

    if (defined($rc)) {
	($id) = $select_sth->fetchrow_array();
	$select_sth->finish();
    }

    return $id if defined($id);

# 3

    return undef unless defined($insert_sth);

    if (defined($extra_data)) {
	$rc = $insert_sth->execute($identifier, @{$extra_data});
    } else {
	$rc = $insert_sth->execute($identifier);
    }

    if (defined($rc)) {
	my $rows = $insert_sth->rows();

	if ($rows == 0) {
	    $rc = $select_sth->execute($identifier);

	    if (defined($rc)) {
		($id) = $select_sth->fetchrow_array();
		$select_sth->finish();
	    }
	} elsif ($rows == 1) {
	    my $dbh = $insert_sth->{'Database'};
	    $id = $dbh->{'mysql_insertid'};
	}
    }

    &dictionaryInsert($dict, $identifier, $id) if defined($id);

    return $id;
}

sub putTraceArchiveIdentifierForRead {
# put a trace archive reference in the database
    my $this = shift;
    my $read = shift; # a Read instance

    my $TAI = $read->getTraceArchiveIdentifier() || return;

    my $readid = $read->getReadID() || return; # must have readid defined

    my $dbh = $this->getConnection();

    my $query = "insert into TRACEARCHIVE(read_id,traceref) VALUES (?,?)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($readid,$TAI);

    return (0,"failed to insert trace archive identifier for readID $readid;" .
	      "DBI::errstr=$DBI::errstr") unless $rc;

    return (1,"OK");
}

sub deleteRead {
# delete a read for the given read_id and all its data (to be TESTED)
    my $this = shift;
    my ($key, $value, $junk) = @_;

    my $readid;
    if ($key eq 'id' || $key eq 'read_id') {
	$readid = $value;
    }
    elsif ($key eq 'name' || $key eq 'readname') {
	$readid = $this->hasRead($value); # get read_id for readname
        return (0,"Read does not exist") unless $readid;
    }

    my $dbh = $this->getConnection();

# test if read is unassembled

    my $query = "select * from MAPPING left join SEQ2READ using (seq_id) 
                 where SEQ2READ.read_id = ?";
    my $sth = $dbh->prepare_cached($query);
    my $rn = $sth->execute($readid) || &queryFailed($query);
    $sth->finish();

    return (0,"Cannot delete an assembled read") if (!defined($rn) || $rn);

# remove for readid from all tables it could be in

    my @stables = ('SEQVEC','CLONEVEC','SEQUENCE','QUALITYCLIP','READTAG',);

    my $delete = 0;
# delete seq_id items
    foreach my $table (@stables) {
        $query = "delete $table from $table left join SEQ2READ using (seq_id) where read_id=?";
        $sth = $dbh->prepare_cached($query);
        $delete++ if $sth->execute($readid);
        $sth->finish();
    }

    my @rtables = ('READCOMMENT','TRACEARCHIVE','STATUS','SEQ2READ','READS');
# delete read_id items
    foreach my $table (@stables) {
        $query = "delete from $table where read_id=?";
        $sth = $dbh->prepare_cached($query);
        $delete++ if $sth->execute($readid);
        $sth->finish();
    }

    return (1,"Records for read $readid removed from $delete tables");
}

#----------------------------------------------------------------------------------------
# methods dealing with CONTIGs
#----------------------------------------------------------------------------------------

sub getContigByID {
# return a Contig object with the meta data only for the specified contig ID
    my $this       = shift;
    my $contig_id  = shift;

    my $dbh = $this->getConnection();

    my $query = "select $this->{contig_attributes} from CONTIG where contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($contig_id) || &queryFailed($query);

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        $contig->setContigID($contig_id);

        $this->addMetaDataForContig($contig,@attributes);

# if connecting contigs, add linked contig IDs and maps?

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return $contig; # returns undef if no such contig found
}

sub addMetaDataForContig {
# private method: insert meta data into input Contig object
    my $this = shift;
    my $contig = shift; # instyance of Contig class
    my ($length,$ncntgs,$nreads,$newreads,$cover,$readnamehash) = @_;
print STDERR "Contig attributes: $length,$ncntgs,$nreads,$newreads,$cover\n";

    $contig->setReadNameHash($readnamehash);    

    $contig->setConsensusLength($length);

    $contig->setPreviousContigs($ncntgs);

    $contig->setNumberOfReads($nreads);

    $contig->setNumberOfNewReads($newreads);

    $contig->setAverageCover($cover);
}

sub getContigWithChecksum {
# returns a Contig object with the meta data only which contains the specified read
    my $this = shift;
    my $checksum = shift;

    my $dbh = $this->getConnection();

    my $query = "select contig_id,$this->{contig_attributes} from CONTIG 
                 where readnamehash = ? ";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($checksum) || &queryFailed($query);

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;

        $contig->setContigID($contig_id);

        $this->addMetaDataForContig($contig,@attributes);

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return $contig; # returns undef if no such contig found
}

# NOTE: the next two method can return several contig_ids. Better return ids and call 
# getContigByID for each of them

sub getContigWithRead {
# returns a Contig object (meta data only) which contains the read specified by name
    my $this = shift;
    my $name = shift;

    my $dbh = $this->getConnection();

    my $query  = "select CONTIG.contig_id,$this->{contig_attributes} 
                    from CONTIG2CONTIG, CONTIG, MAPPING, READS
                   where CONTIG2CONTIG.newcontig = CONTIG.contig_id
                     and CONTIG.contig_id = MAPPING.contig_id
                     and MAPPING.read_id = READS.read_id
                     and READS.readname = ?";
# and CONTIG2CONTIG.age = 0"; NO could be missing
# INSTEAD, if more than one entry found then do a query on CONTIG2CONTIG
        
    my $sth = $dbh->prepare_cache($query);

    $sth->execute($name) || &queryFailed($query);

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;

        $contig->setContigID($contig_id);

        $this->addMetaDataForContig($contig,@attributes);

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return $contig; # returns undef if no such contig found
}

sub getContigWithTag {
# returns a Contig object with the meta data only which contains the specified read
    my $this = shift;
    my $name = shift;

    my $dbh = $this->getConnection();

    my $query = "select CONTIG.contig_id,$this->{contig_attributes}
                 from CONTIG join TAG2CONTIG using (contig_id)
                 where tag_id = (select tag_id from TAG where tagname = ?)";
# NOTE: uses subquery ; use age = 0 ? NO, see above
# NOTE: use the merge table concept for tag table, else query should be several UNIONs

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($name) || &queryFailed($query);

    undef my $contig;

    if (my @attributes = $sth->fetchrow_array()) {

	$contig = new Contig();

        my $contig_id = shift @attributes;

        $contig->setContigID($contig_id);

        $this->addMetaDataForContig($contig,@attributes);

	$contig->setArcturusDatabase($this);
    }

    $sth->finish();

    return $contig; # returns undef if no such contig found
}

sub getContig {
# return a Contig instance with its Reads, Mappings and Tags for the given identification
    my $this  = shift;
    my $key   = shift;
    my $value = shift;

# create a new Contig instance and load the meta data

    my $contig;

    if ($key eq 'id' || $key eq 'contig_id') {
print STDERR "getContigByID $value\n";
	$contig = $this->getContigByID($value);
    }
    elsif ($key eq 'withChecksum') {
	$contig = $this->getContigWithChecksum($value);
    }
# the next two options may give more than one contig
    elsif ($key eq 'withRead') {
	$contig = $this->getContigWithRead($value); # should be latest version
    }
    elsif ($key eq 'withTag') {
	$contig = $this->getContigWithTag($value); # should be latest version
    }

    return undef unless $contig;

# get the reads for this contig with their DNA sequences and tags

print STDERR "enter getReadsForContig\n";
    $this->getReadsForContig($contig);

# get mappings (and implicit segments)

print STDERR "enter getMappingsForContig\n";
    $this->getMappingsForContig($contig);

# get contig tags

print STDERR "enter getTagsForContig\n";
    $this->getTagsForContig($contig);

# for consensus sequence we use lazy instantiation in the Contig class

print STDERR "enter testContigForExport\n";
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
# test presence of contig with given contig_id and/or readchecksum
    my $this = shift;
    my $hash = shift; 

# compose the query

    my $query = "select contig_id from CONTIG where";

    my @params;
    if ($hash->{contig_id}) {
        $query .= "contig_id=?";
        push @params, $hash->{contig_id};
    }
    if ($hash->{readnamehash}) {
        $query .= " and" if @params;
        $query .= " readnamehash=?";
        push @params, $hash->{readnamehash};
    }

    die "hasContig expects a contig_id or readnamehash value" unless @params;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@params);

    undef my $contig_id;

    if (my @ary = $sth->fetchrow_array()) {
	($contig_id) = @ary;
    }

    $sth->finish();

    return $contig_id; # returns undefined if no such contig found
}
#---

sub putContig {
    my $this = shift;
    my $contig = shift; # Contig instance

    die "ArcturusDatabase->putContig expects a Contig instance ".
        "as parameter" unless (ref($contig) eq 'Contig');

    print STDERR "Contig ".$contig->getContigName." to be added\n";

# get readIDs/seqIDs for its reads, load new sequence for edited reads
 
    my $reads = $contig->getReads();
    $this->getSequenceIDforReads($reads);

# put the sequenceIDs in the mappings, given the readname

# test the Contig, its reads and mappings for completeness and consistency

    if (!$this->testContigForImport($contig)) {
        print STDERR "Contig ".$contig->getContigName." NOT loaded";
    }

# test if contig already loaded; i.e. test against existing contigs 
# based on a.o. readnamehash; if same test in more detail?

   # return 0 if ($identical);

# put the sequence IDs in the mappings

# 2) lock MAPPING and SEGMENT tables
# 3) enter record in MAPPING for each read and contig=0 (bulk loading)
# 4) enter segments for each mapping (bulk loading)
# 5) enter record in CONTIGS with meta data, gets contig_id
# 6) replace contig_id=0 by new contig_id in MAPPING
# 7) release lock on MAPPING 
# BETTER? add a function deleteContig(contig_id) to remove contig if any error

}

sub getSequenceIDforReads {
# put sequenceID, version and read_id into Read instances given readname 
    my $this = shift;
    my $reads = shift;

# collect the readnames of unedited and of edited reads
# for edited reads, get sequenceID by testing the sequence against
# version(s) already in the database with method addNewSequenceForRead
# for unedited reads pull the data out in bulk with a left join

    my %unedited;
    foreach my $read (@$reads) {
        if ($read->isEdited) {
            my ($success,$errmsg) = $this->putNewSequenceForRead($read);
	    print STDERR "$errmsg\n" unless $success;
        }
        else {
            my $readname = $read->getReadName();
            $unedited{$readname} = $read;
        }
    }

# get the sequence IDs for the unedited reads (version = 0)

    my $range = join ',',sort keys(%unedited);
    my $query = "select READS.read_id,readname,seq_id" .
                "  from READS left join SEQ2READ using(read_id) " .
                " where readname in ($range)" .
	        "   and version = 0";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute() || &queryFailed($query);

    while (my @ary = $sth->fetchrow_array()) {
        my ($read_id,$readname,$seq_id) = @ary;
        my $read = $unedited{$readname};
        delete $unedited{$readname};
        $read->setReadID($read_id);
        $read->setSequenceID($seq_id);
        $read->setVersion(0);
    }

    $sth->finish();

# have we collected all of them? then %unedited should be empty

    if (keys %unedited) {
        print STDERR "Sequence ID not found for reads: " .
	              join(',',sort keys %unedited) . "\n";
    }
}

#****************  
sub addReadsToPending {
# OBSOLETE, but TEMPLATE for bulk loading  of SEGMENT and MAPPING
    my $this      = shift;
    my $readnames = shift; # array reference
    my $multiline = shift; # 

    if (ref($readnames) ne 'ARRAY') {
        print STDERR "addReadsToPending expects an array as input\n";
        return undef;
    }

# this section deals with multiline inserts; active when multiline defined
# a buffer is filled up until the buffer exceeds the limit set

    if (defined($multiline)) {
    }

# okay

    my $dbh = $this->getConnection();

    my $query = "insert ignore into PENDING (readname) VALUES ('".join("'),('",@$readnames)."')";

    my $sth = $dbh->prepare($query);

    return 1 if $sth->execute();

    &dataBaseError("addReadsToPending: failed");

    return 0;
}
  
sub flushReadsToPending {
# flush any remaining entries in the buffer
    my $this = shift;

    my @dummy;
    
    $this->addReadsToPending(\@dummy, 0);
}
#****************

sub testContigForExport {
    &testContig(shift,shift,0);
}

sub testContigForImport {
    &testContig(shift,shift,1);
}

sub testContig {
# private method
    my $this = shift;
    my $contig = shift || return undef; # Contig instance
    my $level = shift;

# level 0 for export, test number of reads against mappings and metadata    
# for import: all reads and mappings must have a sequence ID defined
# for export: all reads and mappings must have a readname defined
# for both, the reads and mappings must correspond 1 to 1

    my %identifier; # hash for IDs

# test contents of the contig's Read instances

    my $ID;
    if ($contig->hasReads()) {
        my $success = 1;
        my $reads = $contig->getRead();
        foreach my $read (@$reads) {
# test identifier: for export sequence ID; for import readname (or both? for both)
            $ID = $read->getReadName() if $level;
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

# test contents of the contig's Mapping instances against the Reads

    if ($contig->hasMappings()) {
        my $success = 1;
	my $mappings = $contig->getMapping();
        foreach my $mapping (@$mappings) {
# get the identifier: for export sequence ID; for import readname
            $ID = $mapping->getReadName() if $level;
	    $ID = $mapping->getSequenceID() if !$level;
# is ID among the identifiers? if so delete the key from the has
            if (!$identifier{$ID}) {
                print STDERR "Missing Read for Mapping ".$mapping->getReadName.
                             " ($ID)\n";
                $success = 0;
            }
            delete $identifier{$ID}; # delete the key
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

# test the number of Reads found against the contig metadata (info only; non-fatal)

    if (my $numberOfReads = $contig->getNumberOfReads()) {
        my $reads = $contig->getRead();
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

#----------------------------------------------------------------------------------------- 
# methods dealing with Mappings and links between Contigs
#----------------------------------------------------------------------------------------- 

sub getMappingsForContig {
# private method, returns an array of MAPPINGS for the input contig_id
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getMappingsForContig expects a Contig instance" unless (ref($contig) eq 'Contig');

    return if $contig->hasMappings(); # only 'empty' instance allowed

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
#print STDERR "mapping:  $rn, $sid, $mid, $cs, $cf, $dir \n";
# intialise and add readname and sequence ID
        my $mapping = new Mapping();
        $mapping->setReadName($rn);
        $mapping->setSequenceID($sid);
        $mapping->setAlignmentDirection($dir);
# add Mapping instance to output list and hash list keyed on mapping ID
        push @mappings, $mapping;
        $mappings->{$mid} = $mapping;
# add remainder of data (cstart, cfinish) ?
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

sub getMappingsOfReadsInLinkedContigs {
# ??? returns mappings in contigs of age=1 for an input array of read_ids
    my $this = shift;
    my $rids = shift || return; # array reference

    my $query = "select read_id, contig_id ";
    $query   .= "from MAPPING as R2C, CONTIG2CONTIG as C2C where ";
    $query   .= "C2C.newcontig = R2C.contig_id and age = 1 and ";
    $query   .= "R2C.read_id in (".join(',',@$rids).") and";
    $query   .= "R2C.deprecated in ('M','N')";

}

#----------------------------------------------------------------------------------------- 
# methods dealing with TAGs
#----------------------------------------------------------------------------------------- 

sub getTagsForReads {
    my $this = shift;
    my $reads = shift; # array of Read instances

}

sub getTagsForContig {
    my $this = shift;
    my $contig = shift; # Contig instance

    die "getMappingsForContig expects a Contig instance" unless (ref($contig) eq 'Contig');

    return if $contig->hasTags(); # only 'empty' instance allowed

# to be completed
}

#----------------------------------------------------------------------------------------- 
# methods dealing with PROJECTs
#----------------------------------------------------------------------------------------- 

#----------------------------------------------------------------------------------------- 
# methods dealing with ASSEMBLYs
#----------------------------------------------------------------------------------------- 

#----------------------------------------------------------------------------------------- 
# methods dealing with BRIDGEs
#----------------------------------------------------------------------------------------- 

1;



