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

    my $dbh = $this->getConnection;

    $this->{Dictionary} = {};

    $this->{Dictionary}->{insertsize}   = &createDictionary($dbh, 'LIGATIONS', 'ligation_id', 'silow, sihigh');
    $this->{Dictionary}->{ligation}     = &createDictionary($dbh, 'LIGATIONS', 'ligation_id', 'identifier');
    $this->{Dictionary}->{clone}        = &createDictionary($dbh, 'CLONES', 'clone', 'clonename');
    $this->{Dictionary}->{status}       = &createDictionary($dbh, 'STATUS', 'status', 'identifier');
    $this->{Dictionary}->{basecaller}   = &createDictionary($dbh, 'BASECALLER', 'basecaller', 'name');
    $this->{Dictionary}->{svector}      = &createDictionary($dbh, 'SEQUENCEVECTORS', 'svector_id', 'name');
    $this->{Dictionary}->{cvector}      = &createDictionary($dbh, 'CLONINGVECTORS', 'cvector_id', 'name');
# a place holder for template dictionary which will be built on the fly
#    $this->{Dictionary}->{template} = {};
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
# dictionary lookup (recall)
    my $this = shift;
    my $hashref = shift;

    $hashref->{'insertsize'} = $hashref->{'ligation'};

    foreach my $key (keys %{$hashref}) {
	my $dict = $this->{Dictionary}->{$key};
	my $value = $hashref->{$key};

# template is a special case for which the dictionary is built on the fly
        if ($key eq 'template') {
#	    $value = &dictionaryLookup($dict, $value);                        
        }

	elsif (defined($dict)) {
            
	    $value = &dictionaryLookup($dict, $value);
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

    my $sth = $this->{prepared}->{getReadByID};

    if (!defined($sth)) {

# or ?: "select READS.*,TEMPLATE.name as template from READS join TEMPLATE using (template_id) where read_id = ?"
        $sth = $dbh->prepare("select * from READS where read_id=?");

        $this->{prepared}->{getReadByID} = $sth;
    }

    $sth->execute($readid);

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

sub getReadByName {
# returns a Read instance with (meta data only) for input read name 
    my $this = shift;
    my $readname = shift;

    my $dbh = $this->getConnection();

    my $sth = $this->{prepared}->{getReadByName};

    if (!defined($sth)) {

        my $query = "select READS.*,TEMPLATE.name as template
                     from READS leftjoin TEMPLATE using (template_id) 
                     where readname = ?";

        $sth = $dbh->prepare($query);

        $this->{prepared}->{getReadByName} = $sth;
    }

    $sth->execute($readname);

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

# or ?: "select READS.*,TEMPLATE.name as template from READS join TEMPLATE using (template_id) where read_id in ($range)"
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

sub getSequenceForReads {
# takes an array of Read instances and puts the DNA and quality sequence in
    my $this  = shift;
    my $Reads = shift; # array of Reads objects

    if (ref($Reads) ne 'ARRAY' or ref($Reads->[0]) ne 'Read') {
        print STDERR "getSequenceForReads expects an array of Read objects\n";
        return undef;
    }

    my $dbh = $this->getConnection();

# build a list of read IDs / or use the Read instances inventory

    my %rids;
    my $rids = \%rids;
    foreach my $Read (@$Reads) {
        $rids->{$Read->getReadID} = $Read;
    }

# pull the data from the SEQUENCE table in bulk

    my $range = join ',',keys(%$rids);

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

    my $sth = $dbh->prepare($query);

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
	$query .= "READS left join TRACEARCHIVE using(read_id) where readname=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare($query);

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
    my ($key,$value,$junk) = @_;
}

#-----------------------------------------------------------------------------

sub getListOfReadNames {
# returns an array of readnames occurring in the database 
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

    if (ref($read) ne 'Read') {
        print STDERR "putRead expects an instance of the Read class\n";
        return undef;
    }

    #my $errorstatus = $read->status;

# a) test consistency and completeness

    my ($rc, $errmsg) = $this->checkReadForCompleteness($read);
    return (0, "failed completeness check: $errmsg") unless $rc;

    ($rc, $errmsg) = $this->checkReadForConsistency($read);
    return (0, "failed consistency check: $errmsg") unless $rc;

# b) encode dictionary items; special case: TEMPLATE

    my $template_id = $this->getTemplateID($read);

    return (0, "failed to retrieve template_id") unless defined($template_id);

# c) insert (if not exists) 1) readname, then for read_id=last_insert_id: 2) meta data READS
#                                             3) sequence into SEQUENCE 4) comments

    my $dbh = $this->getConnection();

    return (0, "no database connection") unless defined($dbh);

    my $readname = $read->getReadName();

    my $query = "insert into READS(readname) VALUES(?)";

    my $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($readname);

    return (0, "failed to insert readname into READS table;DBI::errstr=$DBI::errstr")
	unless (defined($rc) && $rc == 1);

    $sth->finish();

    my $readid = $dbh->{'mysql_insertid'};

    $query = "update READS set asped=?,template_id=?,strand=?,chemistry=?,primer=? where read_id=?";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($read->getAspedDate(), $template_id, $read->getStrand(),
			$read->getChemistry(), $read->getPrimer(), $readid);

    return (0, "failed to set asped,template_id,strand,chemistry,primer for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

    my $seqlen = length($read->getSequence());

    $query = "update READS set slength=?,lqleft=?,lqright=? where read_id=?";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($seqlen, $read->getLowQualityLeft(),
			$read->getLowQualityRight(), $readid);

    return (0, "failed to set slength,lqleft,lqright for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

    $query = "insert into SEQUENCE(read_id,sequence,quality) VALUES(?,?,?)";

    $sth = $dbh->prepare_cached($query);

    my $sequence = compress($read->getSequence());
    my $basequality = compress(pack("c*", @{$read->getQuality()}));

    $rc = $sth->execute($readid, $sequence, $basequality);

    return (0, "failed to insert sequence and base-quality for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

    my $seqveclist = $read->getSequencingVector();

    if (defined($seqveclist)) {
	$query = "insert into SEQVEC(read_id,svector_id,begin,end) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$seqveclist}) {
	    my ($seqvec, $svleft, $svright) = @{$entry};

	    my $seqvecid = $this->getSequencingVectorID($seqvec);

	    $rc = $sth->execute($readid, $seqvecid, $svleft, $svright);

	    return (0, "failed to insert read_id,seqvec_id,begin,end into SEQVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

    my $cloneveclist = $read->getCloningVector();

    if (defined($cloneveclist)) {
	$query = "insert into CLONEVEC(read_id,cvector_id,begin,end) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$cloneveclist}) {
	    my ($clonevec, $cvleft, $cvright) = @{$entry};

	    my $clonevecid = $this->getCloningVectorID($clonevec);

	    $rc = $sth->execute($clonevecid, $cvleft, $cvright, $readid);

	    return (0, "failed to insert read_id,ceqvec_id,begin,end into CLONEVEC for $readname ($readid);" .
		    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);
	}

	$sth->finish();
    }

    return (1, "OK");
}

sub checkReadForCompleteness {
    my $this = shift;
    my $read = shift;

    return (0, "invalid argument")
	unless (defined($read) && ref($read) && ref($read) eq 'Read');

    return (0, "undefined readname")
	unless defined($read->getReadName());

    return (0, "undefined sequence")
	unless defined($read->getSequence());

    return (0, "undefined base-quality")
	unless defined($read->getQuality());

    return (0, "undefined asped-date")
	unless defined($read->getAspedDate());

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

sub getTemplateID {
    my $this = shift;
    my $read = shift;

    my $dbh = $this->getConnection();

    return undef unless defined($dbh);

    my $query = "select template_id from TEMPLATE where name=?";

    my $sth = $dbh->prepare_cached($query);

    my $template = $read->getTemplate();

    my $rc = $sth->execute($template);

    my ($template_id) = $sth->fetchrow_array();

    $sth->finish();

    return $template_id if defined($template_id);

    my $ligation_id = $this->getLigationID($read);

    $query = "insert into TEMPLATE(name,ligation_id) VALUES(?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($template, $ligation_id);

    if ($rc == 1) {
	$template_id = $dbh->{'mysql_insertid'};
    } else {
	undef $template_id;
    }

    $sth->finish();

    return $template_id;
}

sub getCloningVectorID {
    my $this = shift;
    my $cvec = shift;

    my $dbh = $this->getConnection();

    return undef unless defined($dbh);

    my $query = "select cvector_id from CLONINGVECTORS where name=?";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($cvec);

    my ($cvec_id) = $sth->fetchrow_array();

    $sth->finish();

    return $cvec_id if defined($cvec_id);

    $query = "insert into CLONINGVECTORS(name) VALUES(?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($cvec);

    if ($rc == 1) {
	$cvec_id = $dbh->{'mysql_insertid'};
    } else {
	undef $cvec_id;
    }

    $sth->finish();

    return $cvec_id;
}

sub getSequencingVectorID {
    my $this = shift;
    my $seqvec = shift;

    my $dbh = $this->getConnection();

    return undef unless defined($dbh);

    my $query = "select svector_id from SEQUENCEVECTORS where name=?";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($seqvec);

    my ($seqvec_id) = $sth->fetchrow_array();

    $sth->finish();

    return $seqvec_id if defined($seqvec_id);

    $query = "insert into SEQUENCEVECTORS(name) VALUES(?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($seqvec);

    if ($rc == 1) {
	$seqvec_id = $dbh->{'mysql_insertid'};
    } else {
	undef $seqvec_id;
    }

    $sth->finish();

    return $seqvec_id;
}

sub getLigationID {
    my $this = shift;
    my $read = shift;

    my $dbh = $this->getConnection();

    return undef unless defined($dbh);

    my $query = "select ligation_id from LIGATIONS where identifier=?";

    my $sth = $dbh->prepare_cached($query);

    my $ligation = $read->getLigation();

    my $rc = $sth->execute($ligation);

    my ($ligation_id) = $sth->fetchrow_array();

    $sth->finish();

    return $ligation_id if defined($ligation_id);

    my ($silow, $sihigh) = @{$read->getInsertSize()};

    $query = "insert into LIGATIONS(identifier,silow,sihigh) VALUES(?,?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($ligation, $silow, $sihigh);

    if ($rc == 1) {
	$ligation_id = $dbh->{'mysql_insertid'};
    } else {
	undef $ligation_id;
    }

    $sth->finish();

    return $ligation_id;
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

    Reads->clearInventory;

    my $Reads = $this->getReadsForContigID($Contig->getContigID); # an array ref

    $this->putSequenceAndBaseQualityForReads($Reads);

    $Contig->importReads($Reads);

# get mappings

    my $Mappings = $this->getMappingsForContigID($Contig->getContigID); # an array ref

    $Contig->importMappings($Mappings);

# link the Mappings to the Reads and vice versa NO! put this in Contig instance

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
