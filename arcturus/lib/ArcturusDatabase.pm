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

sub errorStatus {
# return 0 for correctly opened database
    my $this = shift;

    return 1 unless $this->getConnection();

    return &dataBaseError();
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

sub populateDictionaries {
    my $this = shift;

    my $dbh = $this->getConnection();

    $this->{Dictionary} = {};

    $this->{Dictionary}->{insertsize} =
	&createDictionary($dbh, 'LIGATIONS', 'ligation_id', 'silow, sihigh');

    $this->{Dictionary}->{ligation} =
	&createDictionary($dbh, 'LIGATIONS', 'ligation_id', 'name');

    $this->{Dictionary}->{clone} =
	&createDictionary($dbh, 'LIGATIONS left join CLONES using (clone_id)',
			  'ligation_id', 'CLONES.name');

    $this->{Dictionary}->{status} =
	&createDictionary($dbh, 'STATUS', 'status_id', 'name');

    $this->{Dictionary}->{basecaller} =
	&createDictionary($dbh, 'BASECALLER', 'basecaller_id', 'name');

    $this->{Dictionary}->{svector} =
	&createDictionary($dbh, 'SEQUENCEVECTORS', 'svector_id', 'name');

    $this->{Dictionary}->{cvector} =
	&createDictionary($dbh, 'CLONINGVECTORS', 'cvector_id', 'name');

# template name will be loaded in individual read extraction queries
}

sub populateLoadingDictionaries {
    my $this = shift;

    my $dbh = $this->getConnection;

    $this->{LoadingDictionary} = {};

    $this->{LoadingDictionary}->{ligation} =
	&createDictionary($dbh, "LIGATIONS", "name", "ligation_id");

    $this->{LoadingDictionary}->{svector} =
	&createDictionary($dbh, "SEQUENCEVECTORS", "name", "svector_id");

    $this->{LoadingDictionary}->{cvector} =
	&createDictionary($dbh, "CLONINGVECTORS", "name", "cvector_id");

    $this->{LoadingDictionary}->{template} =
	&createDictionary($dbh, "TEMPLATE", "name", "template_id");

    $this->{LoadingDictionary}->{basecaller} =
	&createDictionary($dbh, "BASECALLER", "name", "basecaller_id");

    $this->{LoadingDictionary}->{clone} =
	&createDictionary($dbh, "CLONES", "name", "clone_id");

    $this->{LoadingDictionary}->{status} =
	&createDictionary($dbh, "STATUS", "name", "status_id");

    $this->{SelectStatement} = {};
    $this->{InsertStatement} = {};

    my %attributeQueries =
	('ligation',   ["select ligation_id from LIGATIONS where name=?",
			"insert ignore into LIGATIONS(name,silow,sihigh) VALUES(?,?,?)"],
	 'template',   ["select template_id from TEMPLATE where name=?",
			"insert ignore into TEMPLATE(name, ligation_id) VALUES(?,?)"],
	 'basecaller', ["select basecaller_id from BASECALLER where name=?",
			"insert ignore into BASECALLER(name) VALUES(?)"],
	 'status',     ["select status_id from STATUS where name=?",
			"insert ignore into STATUS(name) VALUES(?)"],
	 'clone',      ["select clone_id from CLONES where name=?",
			"insert ignore into CLONES(name) VALUES(?)"],
	 'svector',    ["select svector_id from SEQUENCEVECTORS where name=?",
			"insert ignore into SEQUENCEVECTORS(name) VALUES(?)"],
	 'cvector',    ["select cvector_id from CLONINGVECTORS where name=?",
			"insert ignore into CLONINGVECTORS(name) VALUES(?)"]
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

    if (defined($dict)) {
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

#-----------------------------------------------------------------------------

sub getReadByID {
# returns a Read instance with (meta data only) for input read IDs 
    my $this = shift;
    my $readid = shift;

    my $dbh = $this->getConnection();

    my $read_attributes = "read_id,readname,asped,strand,primer,chemistry,basecaller,lqleft,lqright,status";

    my $query = "select $read_attributes,TEMPLATE.name as template,TEMPLATE.ligation_id 
                 from READS left join TEMPLATE using (template_id) 
                 where read_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readid);

    my ($read_id,$readname,$asped,$strand,$primer,$chemistry,$basecaller_id,$lqleft,$lqright,$status_id,$template,$ligation_id) = $sth->fetchrow_array();

    $sth->finish();

    if (defined($readname)) {
	my $read = new Read();

        $read->setReadID($read_id);
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

        $read->setLowQualityLeft($lqleft);

        $read->setLowQualityRight($lqright);

	$query = "select svector_id,svleft,svright from SEQVEC where read_id=?";

	$sth = $dbh->prepare_cached($query);

        $sth->execute($readid);

	while (my ($svector_id, $svleft, $svright) = $sth->fetchrow_array()) {
	    my $svector = &dictionaryLookup($this->{Dictionary}->{svector},
					    $svector_id);

	    $read->addSequencingVector([$svector, $svleft, $svright]);
	}

	$sth->finish();

	$query = "select cvector_id,cvleft,cvright from CLONEVEC where read_id=?";

	$sth = $dbh->prepare_cached($query);

        $sth->execute($readid);

	while (my ($cvector_id, $cvleft, $cvright) = $sth->fetchrow_array()) {
	    my $cvector = &dictionaryLookup($this->{Dictionary}->{cvector},
					    $cvector_id);

	    $read->addCloningVector([$cvector, $cvleft, $cvright]);
	}

	$sth->finish();
	
	$read->setArcturusDatabase($this);

	return $read;
    } 
    else {
	return undef;
    }
}

sub getVectorDataForRead {
    my $this = shift;
    my $read = shift; # Read instance

    my $read_id = $read->getReadID;

    my $query = "select svector_id,svleft,svright from SEQVEC where read_id = ?
      UNION select cvector_id,cvleft,cvright from CLONEVEC where read_id = ?"; 
}

sub getReadByName {
# returns a Read instance with (meta data only) for input read name 
    my $this = shift;
    my $readname = shift;

    my $dbh = $this->getConnection();

    my $query = "select READS.*,TEMPLATE.name as template,TEMPLATE.ligation_id 
                 from READS left join TEMPLATE using (template_id) 
                 where readname = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($readname);

    my $hashref = $sth->fetchrow_hashref();

    $sth->finish();

    if (defined($hashref)) {
	my $read = new Read();

#	$this->processReadData($hashref);

#	$read->importData($hashref);

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

    if (ref($readids) ne 'ARRAY') {
        die "'getReadsByID' method expects an array of readIDs";
    }

# prepare the range list

    my $range = join ',',@$readids;

    my $dbh = $this->getConnection();

    my $query = "select READS.*,TEMPLATE.name as template
                 from READS left join TEMPLATE using (template_id) 
                 where read_id in ($range)";
    my $sth = $dbh->prepare("select * from READS where read_id in ($range)");

    $sth->execute();

    my @reads;

    while (my $hashref = $sth->fetchrow_hashref()) {

	my $read = new Read();

#	$this->processReadData($hashref);

#	$read->importData($hashref);

	$read->setArcturusDatabase($this);

        push @reads, $read;
    }

    $sth->finish();

    return \@reads;
}

sub getReadsForContigID{
# returns an array of Reads (meta data only) for the given contig
    my $this = shift;
    my $cid  = shift; # contig_id

    my $dbh = $this->getConnection();

    my $query = "select READS.*,TEMPLATE.name as template 
                 from  READS2CONTIG, READS, TEMPLATE 
                 where READS2CONTIG.contig_id = ?  
                 and READS2CONTIG.read_id = READS.read_id
                 and READS.template_id = TEMPLATE.template_id";
# my $query = "select READS.* from READS2CONTIG left join READS on (read_id) ";
# $query   .= "where READS2CONTIG.contig_id = ?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($cid);

    my @reads;

    while (my $hashref = $sth->fetchrow_hashref()) {

	my $read = new Read();

#	$this->processReadData($hashref);

#	$read->importData($hashref);

	$read->setArcturusDatabase($this);

        push @reads, $read;
    }

    $sth->finish();

    return \@reads;
}

sub getSequenceForReads {
# takes an array of Read instances and puts the DNA and quality sequence in
    my $this  = shift;
    my $reads = shift; # array of Reads objects

    if (ref($reads) ne 'ARRAY' or ref($reads->[0]) ne 'Read') {
        print STDERR "getSequenceForReads expects an array of Read objects\n";
        return undef;
    }

    my $dbh = $this->getConnection();

# build a list of read IDs / or use the Read instances inventory

    my %rids;
    my $rids = \%rids;
    foreach my $read (@$reads) {
        $rids->{$read->getReadID} = $read;
    }

# pull the data from the SEQUENCE table in bulk

    my $range = join ',',keys(%$rids);

    my $query = "select read_id,sequence,quality from SEQUENCE 
                 where read_id in ($range)";

    my $sth = $dbh->prepare($query);

    $sth->execute();

    while(my @ary = $sth->fetchrow_array()) {

	my ($read_id, $sequence, $quality) = @ary;

        if (my $read = $rids->{$read_id}) {

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

# test if all objects have been completed ?
}

#-----------------------------------------------------------------------------

sub getSequenceForRead {
# returns DNA sequence (string) and quality (array reference)
# this method is called from the Read class when using delayed data loading
    my $this = shift;
    my ($key, $value, $junk) = @_;

    my $dbh = $this->getConnection();

    my $query = "select sequence,quality from ";

    if ($key eq 'id' || $key eq 'read_id') {
	$query .= "SEQUENCE where read_id=?";
    }
    elsif ($key eq 'name' || $key eq 'readname') {
	$query .= "READS left join SEQUENCE using (read_id) where readname=?";
    }

    my $sth = $dbh->prepare_cached($query);

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

    $sth->execute($value);

    my @comment;

    while(my @ary = $sth->fetchrow_array()) {
	push @comment, @ary;
    }

    $sth->finish();

    return \@comment;
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

    $sth->execute($value);

    my $traceref;

    while(my @ary = $sth->fetchrow_array()) {
	$traceref = shift @ary;
    }

    $sth->finish();

    return $traceref;
}

sub setTraceArchiveIdentifier {
# enters the trace archive reference for the specifed read
    my $this = shift;
    my ($read_id,$tracearchiveref,$junk) = @_;


# TO BE COMPLETED
}

#-----------------------------------------------------------------------------

sub getListOfReadNames {
# returns an array of (all) readnames occurring in the database 
    my $this = shift;

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare("select readname from READS");
    $sth->execute();

    my @reads;
    while (my @ary = $sth->fetchrow_array()) {
        push @reads, $ary[0];
    }

    $sth->finish();

    return \@reads;
}

sub hasRead {
# test presence of read with specified readname; return (first) read_id
    my $this      = shift;
    my $readname  = shift || return; # readname to be tested

    my $dbh = $this->getConnection();
   
    my $query = "select read_id from READS where readname=?";

    my $sth = $dbh->prepare_cached($query);

    my $read_id;

    my $row = $sth->execute($readname);

    while ($row && (my @ary = $sth->fetchrow_array())) {
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
    my $row = $sth->execute();

    while ($row && (my @ary = $sth->fetchrow_array())) {
        delete $namehash{$ary[0]};
    }

    $sth->finish();

    my @notPresent = keys %namehash; # the left over

    return \@notPresent;
}
  
sub addReadsToPending {
# OBSOLETE, but TEMPLATE for bulk loading add readnames to the PENDING table
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

#-----------------------------------------------------------------------------------------

sub putRead {
# insert read into the database
    my $this = shift;
    my $read = shift || return;
    my $options = shift;

    if (ref($read) ne 'Read') {
        print STDERR "putRead expects an instance of the Read class\n";
        return undef;
    }

# a) test consistency and completeness

    my ($rc, $errmsg) = $this->checkReadForCompleteness($read, $options);
    return (0, "failed completeness check: $errmsg") unless $rc;

    ($rc, $errmsg) = $this->checkReadForConsistency($read);
    return (0, "failed consistency check: $errmsg") unless $rc;

# b) encode dictionary item; special case: template & ligation

    my $dbh = $this->getConnection();

    # LIGATION

    my ($sil,$sih) = @{$read->getInsertSize()}; 

    my $ligation_id = &getReadAttributeID($read->getLigation(),
					  $this->{LoadingDictionary}->{'ligation'},
					  $this->{SelectStatement}->{'ligation'},
					  $this->{InsertStatement}->{'ligation'},
					  [$sil, $sih]);

    return (0, "failed to retrieve ligation_id") unless defined($ligation_id);

    # TEMPLATE

    my $template_id = &getReadAttributeID($read->getTemplate(),
					  $this->{LoadingDictionary}->{'template'},
					  $this->{SelectStatement}->{'template'},
					  $this->{InsertStatement}->{'template'},
					  [$ligation_id]);

    return (0, "failed to retrieve template_id") unless defined($template_id);

# c) encode dictionary items basecaller, clone, status

    # BASECALLER

    my $basecaller = &getReadAttributeID($read->getBaseCaller(),
					 $this->{LoadingDictionary}->{'basecaller'},
					 $this->{SelectStatement}->{'basecaller'},
					 $this->{InsertStatement}->{'basecaller'});

    # STATUS

    my $status = &getReadAttributeID($read->getProcessStatus(),
				     $this->{LoadingDictionary}->{'status'},
				     $this->{SelectStatement}->{'status'},
				     $this->{InsertStatement}->{'status'});

    # CLONE

    my $clone = &getReadAttributeID($read->getClone(),
				    $this->{LoadingDictionary}->{'clone'},
				    $this->{SelectStatement}->{'clone'},
				    $this->{InsertStatement}->{'clone'});

# d) insert Read meta data

    return (0, "no database connection") unless defined($dbh);

    my $readname = $read->getReadName();

    my $query = "insert into" .
	" READS(readname,asped,template_id,strand,chemistry,primer,slength,lqleft,lqright,basecaller)" .
	    " VALUES(?,?,?,?,?,?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($readname,
			$read->getAspedDate(),
			$template_id,
			$read->getStrand(),
			$read->getChemistry(),
			$read->getPrimer(),
                        $read->getSequenceLength(),
			$read->getLowQualityLeft(),
			$read->getLowQualityRight(),
			$basecaller);

    return (0, "failed to insert readname and core data into READS table;DBI::errstr=$DBI::errstr")
	unless (defined($rc) && $rc == 1);

    my $readid = $dbh->{'mysql_insertid'};

    $sth->finish();

# insert sequence and base quality

    my $sequence = compress($read->getSequence());

    my $basequality = compress(pack("c*", @{$read->getQuality()}));

    $query = "insert into SEQUENCE(read_id,sequence,quality) VALUES(?,?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($readid, $sequence, $basequality);

# shouldn't we undo the insert in READS? if it fails

    return (0, "failed to insert sequence and base-quality for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

# insert sequencing vector data, if any

    my $seqveclist = $read->getSequencingVector();

    if (defined($seqveclist)) {
	$query = "insert into SEQVEC (read_id,svector_id,svleft,svright) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$seqveclist}) {

	    my ($seqvec, $svleft, $svright) = @{$entry};

	    my $seqvecid = &getReadAttributeID($seqvec,
				               $this->{LoadingDictionary}->{'svector'},
				               $this->{SelectStatement}->{'svector'},
				               $this->{InsertStatement}->{'svector'}) || 0;

	    $rc = $sth->execute($readid, $seqvecid, $svleft, $svright);

	    return (0, "failed to insert read_id,svector_id,cvleft,cvright into SEQVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

# insert cloning vector data, if any

    my $cloneveclist = $read->getCloningVector();

    if (defined($cloneveclist)) {
	$query = "insert into CLONEVEC (read_id,cvector_id,cvleft,cvright) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$cloneveclist}) {
	    my ($clonevec, $cvleft, $cvright) = @{$entry};

	    my $clonevecid = &getReadAttributeID($clonevec,
				                 $this->{LoadingDictionary}->{'cvector'},
				                 $this->{SelectStatement}->{'cvector'},
				                 $this->{InsertStatement}->{'cvector'}) || 0;

	    $rc = $sth->execute($readid,$clonevecid, $cvleft, $cvright);

	    return (0, "failed to insert read_id,cvector_id,cvleft,cvright into CLONEVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

# insert READCOMMENT, TRACEARCHIVE, TAGS

    return (1, "OK");
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
    my $read = shift;

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

    return undef unless (defined($identifier) && defined($dict));

    my $id = &dictionaryLookup($dict, $identifier);

    return $id if defined($id);

    return undef unless defined($select_sth);

    my $rc = $select_sth->execute($identifier);

    if (defined($rc)) {
	($id) = $select_sth->fetchrow_array();
	$select_sth->finish();
    }

    return $id if defined($id);

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

sub updateRead {
# update items for an existing read
    my $this = shift;
    my $read = shift || return;
}

sub pingRead {
# test if a readname is in the READS database table; return read_id, if exists
    my $this = shift;
    my $name = shift;
}

sub addTagsForRead {
    my $this = shift;

}

#----------------------------------------------------------------------------------------- 
# methods dealing with CONTIGs
#----------------------------------------------------------------------------------------- 

sub getContigByID {
# return a Contig object with the meta data only for the specified contig ID
    my $this       = shift;
    my $contig_id  = shift;

    my $dbh = $this->getConnection();

    my $sth = $this->{prepared}->{getContigByID};

    if (!defined($sth)) {

        $sth = $dbh->prepare("select * from CONTIGS where contig_id = ?");

        $this->{prepared}->{getContigByID} = $sth;
    }

    $sth->execute($contig_id);

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

    my $dbh = $this->getConnection();

    my $sth = $this->{prepared}->{getContigByName};

    if (!defined($sth)) {

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

    my $dbh = $this->getConnection();

    my $sth = $this->{prepared}->{getContigWithRead};

    if (!defined($sth)) {

        my $query  = "select CONTIGS.* from CONTIGS join READS2CONTIG using (contig_id) where ";
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

    my $query = "select CONTIGS.* from CONTIGS join TAGS2CONTIG using (contig_id) where ";
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

sub getContigWithChecksum {
# returns a Contig object with the meta data only which contains the specified read
    my $this = shift;
    my $name = shift;

    my $dbh = $this->getConnection();

# note: use the merge table concept for tag table, else query should be several UNIONs

    my $sth = $dbh->prepare("select * from CONTIGS where readnamehash = ? ");

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
    elsif ($key eq 'containsRead') {
	$Contig = $this->getContigWithRead($value);
    }
    elsif ($key eq 'containsTag') {
	$Contig = $this->getContigWithTag($value);
    }
    elsif ($key eq 'checksum') {
	$Contig = $this->getContigWithChecksum($value);
    }

    return undef unless $Contig;

# get the reads for this contig with their DNA sequences

    my $reads = $this->getReadsForContigID($Contig->getContigID); # array ref

    $this->putSequenceAndBaseQualityForReads($reads);

    $Contig->importReads($reads);

# get mappings

    my $Mappings = $this->getMappingsForContigID($Contig->getContigID); # an array ref

    $Contig->importMappings($Mappings);

# link the Mappings to the Reads and vice versa NO! put this in Contig instance

    foreach my $Mapping (@$Mappings) {
# find the Read instance for read_id taken from Mapping
        my $readid = $Mapping->getReadID;
# first test if there is such a Read
        if ( !(my $read = Read->fingerRead($readid)) ) {
            print STDERR "! Incomplete contig $key=$value : no read for mapping ".$readid;
        }
# okay, now put the Mapping in and test if read and mapping correspond
        elsif (!$read->setMapping($Mapping)) {
            print STDERR "! Inconsistent Read and Mapping instances for read ".$readid;
        }
        else {
# okay, finally put the reference to the in the read in the mapping
            $Mapping->setRead($read);
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
# this method is called from the Contig class when using delayed data loading
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

    my $Mapping;
    my $previousread_id = 0;
    while(my @ary = $sth->fetchrow_array()) {
# create a new Mapping instance and define its mapping number (signal it's from the database)
        my $label = pop @ary;
        my $read_id = shift @ary;
        if ($read_id != $previousread_id) {
# a Mapping instance does not yet exist for this read_id
            $Mapping = new Mapping();
            $Mapping->setReadID($read_id);
            push @Mappings, $Mapping;
        }
        elsif ($Mapping) {
            $Mapping->addUnpaddedAlignment(@ary) if ($label < 20);
            $Mapping->addOverallAlignment(@ary) if ($label >= 10);
        }
        else {
# something seriously wrong, error message ?
        }
    }

    $sth->finish();

    return [@Mappings];
}

sub getMappingsOfReadsInLinkedContigs {
# returns mappings in contigs of age=1 for an input array of read_ids
    my $this = shift;
    my $rids = shift || return; # array reference

    my $query = "select read_id, contig_id ";
    $query   .= "from READS2CONTIG as R2C, CONTIGS2CONTIG as C2C where ";
    $query   .= "C2C.newcontig = R2C.contig_id and age = 1 and ";
    $query   .= "R2C.read_id in (".join(',',@$rids).") and";
    $query   .= "R2C.deprecated in ('M','N')";

}

sub addContig {

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
