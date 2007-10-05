package ArcturusDatabase::ADBRead;

use strict;

use ArcturusDatabase::ADBRoot;

use ArcturusDatabase::ADBContig;

use Compress::Zlib;

use Read;

use Tag;

our @ISA = qw(ArcturusDatabase::ADBRoot);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_) || return undef;

    $this->defineReadMetaData();

    return $this;
}

# ----------------------------------------------------------------------------
# methods dealing with READs
#-----------------------------------------------------------------------------

sub defineReadMetaData {
    my $this = shift;

    $this->{read_attributes} = 
           "readname,asped,READINFO.strand,primer,chemistry,basecaller,status";
    $this->{template_addons} = 
           "TEMPLATE.name as template,TEMPLATE.ligation_id";
}

sub populateDictionaries {
    my $this = shift;

    return if defined($this->{Dictionary});

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

    return if defined($this->{LoadingDictionary});

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

    &verifyPrivate($dbh,'createDictionary');

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

    &verifyParameter($hashref,'translateDictionaryReadItems','HASH');

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
        $query .= "TEMPLATE.ligation_id from READINFO,TEMPLATE 
                   where READINFO.template_id=TEMPLATE.template_id 
                   group by ligation_id";
    }
    elsif ($item eq 'clone') {
# build the clone names dictionary on clone_id (different from the one on ligation_id)
        $this->{Dictionary}->{clonename} =
	       &createDictionary($dbh, 'CLONE','clone_id', 'name');
        $query .= "LIGATION.clone_id from READINFO,TEMPLATE,LIGATIONS 
                   where READINFO.template_id=TEMPLATE.template_id 
                     and TEMPLATE.ligation_id=LIGATION.ligation_id 
                   group by clone_id";
        $item = 'clonename';
    }
    elsif ($item =~ /\b(strand|primer|chemistry|basecaller|status)\b/) {
        $query .= "$item from READINFO group by $item";
    }
    elsif ($item eq 'svector') {
        $query .= "SEQVEC.svector_id, from READINFO,SEQ2READ,SEQVEC
                   where READINFO.read_id = SEQ2READ.read_id
                   and   SEQ2READ.seq_id = SEQVEC.seq_id
                   and   SEQ2READ.version = 0
                   group by svector_id";
    }
    elsif ($item eq 'cvector') {
        $query .= "CLONEVEC.cvector_id, from READINFO,SEQ2READ,CLONEVEC
                   where READINFO.read_id = SEQ2READ.read_id
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

sub oldgetRead { # to be DEPRECATED 
# returns a Read instance with (meta data only) for input read IDs 
# parameter usage: read_id=>ID or readname=>NAME, version=>VERSION
    my $this = shift;

# compose the query

    $this->defineReadMetaData(); # unless $this->{read_attributes};

    my $query = "select READINFO.read_id,SEQ2READ.seq_id,SEQ2READ.version,
                 $this->{read_attributes},$this->{template_addons}
                  from READINFO,SEQ2READ,TEMPLATE 
                 where READINFO.read_id = SEQ2READ.read_id
                   and READINFO.template_id = TEMPLATE.template_id ";

    my $nextword;
    my $readitem;
    undef my $version;
    while ($nextword = shift) {

        if ($nextword eq 'seq_id') {
            $query .= "and SEQ2READ.seq_id = ?";
            $readitem = shift;
        }
        elsif ($nextword eq 'read_id') {
            $query .= "and READINFO.read_id = ?";
            $readitem = shift;
            $version = 0 unless defined($version); # define default
        }
        elsif ($nextword eq 'readname') {
            $query .= "and READINFO.readname like ?";
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

# add version specification if it is defined

    $query .= " and SEQ2READ.version = $version" if defined ($version);

    $query =~ s/like/=/ unless ($readitem =~ /\%/);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

my $logger = $this->verifyLogger('getRead');
$logger->info("getRead: $query  ($readitem)");


    $sth->execute($readitem) || &queryFailed($query,$readitem);

    my ($read_id, $seq_id, $db_version,@attributes) = $sth->fetchrow_array();

    $sth->finish();

    if (defined($read_id)) {
	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion($db_version);

        $this->addMetaDataForRead($read, @attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

	return $read;
    } 
    else {
#	print "no results for query:\n$query\ndata: $readitem\n";
	return undef;
    }
}

sub getRead {
# returns a Read instance with (meta data only) for input read IDs 
# parameter usage: read_id=>ID or readname=>NAME, version=>VERSION
    my $this = shift;
    my %options = @_;

# return $this->oldgetRead(@_);

# compose the query; the union construct allows for undefined template 

    $this->defineReadMetaData();

    my $query = "select READINFO.read_id,SEQ2READ.seq_id,SEQ2READ.version,
                 $this->{read_attributes},$this->{template_addons}
                  from READINFO,SEQ2READ,TEMPLATE 
                 where READINFO.read_id = SEQ2READ.read_id
                   and READINFO.template_id = TEMPLATE.template_id";
    my $union = "select READINFO.read_id,SEQ2READ.seq_id,SEQ2READ.version,
                 $this->{read_attributes},'undefined',0
                  from READINFO,SEQ2READ
                 where READINFO.read_id = SEQ2READ.read_id";

    my $nextword;
    my $readitem;
    my $conditions = '';
    my @data;

    my $like = 1;
    undef my $defaultversion;
    if (defined($options{seq_id})) {
        $conditions .= "and SEQ2READ.seq_id = ?"; # no default version
        push @data, $options{seq_id};
    }
    if (defined($options{read_id})) {
        $conditions .= "and READINFO.read_id = ?";
        push @data, $options{read_id};
	$defaultversion = 0;
    }
    if (defined($options{readname})) {
        $conditions .= "and READINFO.readname like ?";
        push @data, $options{readname};
        $like = 0 unless ($options{readname} =~ /\%/);
	$defaultversion = 0;
    }

    return undef unless $conditions; # no valid selection specified

    if (defined($options{version}) || defined($defaultversion)) {
# version specified explicitly or default to be used (input takes precedence)
        $options{version} = $defaultversion unless defined $options{version};
        $conditions .= " and SEQ2READ.version = ?";
        push @data, $options{version};
    }

# compose the full query and bindvalues; the limit causes the 'union' part to
# kick in if the 'query' part gives no result, i.e. the read has no template

    $conditions =~ s/like/=/ unless $like;    
    my $fullquery = "$query $conditions union $union $conditions limit 1";
    my @bindvalues  = @data;
    push @bindvalues, @data; # the union part

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($fullquery);

    $sth->execute(@bindvalues) || &queryFailed($fullquery,@bindvalues);

    my ($read_id, $seq_id, $db_version,@attributes) = $sth->fetchrow_array();

    $sth->finish();

    if (defined($read_id)) {
	my $read = new Read();

        $read->setReadID($read_id);

        $read->setSequenceID($seq_id);

        $read->setVersion($db_version);

        $this->addMetaDataForRead($read, @attributes);

        $this->addSequenceMetaDataForRead($read);

	$read->setArcturusDatabase($this);

	return $read;
    }

# no resdult returned

    return undef;
}

sub getAllVersionsOfRead {
# returns a hash of Read instances keyed on sequence ID for a single read
    my $this = shift;
    my %options = @_;

# note: 'version' option specification is ignored; use getRead or getReads instead

    my $reads = {};
    for (my $version = 0 ; ; $version++) {
        my $read = $this->getRead(version=>$version,%options); # options ported
        last unless $read;
        my $seq_id = $read->getSequenceID();
        $reads->{$seq_id} = $read;
    }

    return $reads; # returns a hash
}

# aliases, taking parameters as values to be used

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

# populate a Read

sub addMetaDataForRead {
# private method: set meta data for input Read 
    my $this = shift;
    my $read = shift; # Read instance
    my ($readname,$asped,$strand,$primer,$chemistry,$basecaller_id,$status_id,$template,$ligation_id) = @_;

    &verifyParameter($read,'addMetaDataForRead');

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

    &verifyParameter($read,'addSequenceMetaDataForRead');

    my $dbh = $this->getConnection() || return;

    my $seq_id = $read->getSequenceID;

# sequencing vector

    my $query = "select svector_id,svleft,svright from SEQVEC where seq_id=?";

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query,$seq_id);

    while (my ($svector_id, $svleft, $svright) = $sth->fetchrow_array()) {
	my $svector = &dictionaryLookup($this->{Dictionary}->{svector},$svector_id);

	$read->addSequencingVector([$svector, $svleft, $svright]);
    }

    $sth->finish();

# cloning vector, if any

    $query = "select cvector_id,cvleft,cvright from CLONEVEC where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query,$seq_id);

    while (my ($cvector_id, $cvleft, $cvright) = $sth->fetchrow_array()) {
        my $cvector = &dictionaryLookup($this->{Dictionary}->{cvector},$cvector_id);

	$read->addCloningVector([$cvector, $cvleft, $cvright]);
    }

    $sth->finish();

# quality clipping

    $query = "select qleft,qright from QUALITYCLIP where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query,$seq_id);

    if (my ($qleft, $qright) = $sth->fetchrow_array()) {

        $read->setLowQualityLeft($qleft);
        $read->setLowQualityRight($qright);
    }

    $sth->finish();

# multiple align to trace records, if any

    return unless $read->getVersion();

    $query = "select startinseq,startinscf,length from ALIGN2SCF where seq_id=?";

    $sth = $dbh->prepare_cached($query);

    $sth->execute($seq_id) || &queryFailed($query,$seq_id);

    while (my($startinseq, $startinscf, $length) = $sth->fetchrow_array()) {
# convert to intervals
        my $finisinseq = $startinseq + $length - 1;
        my $finisinscf = $startinscf + $length - 1;

	$read->addAlignToTrace([$startinseq,$finisinseq,$startinscf,$finisinscf]);
    }

    $sth->finish();   
}

#------------------------------------------------------------------------------
# methods returning a list of Read instances
#------------------------------------------------------------------------------

sub getReads{
# all of them or with a date specification
    my $this = shift;
    my %options = @_;

    my $constraints;

    my @constraints;

# process (possible) constraints

    if ($options{after}) {
        push @constraints, "asped >= '$options{after}'";
    }
    elsif ($options{aspedafter}) {
        push @constraints, "asped >= '$options{aspedafter}'";
    }

    if ($options{before}) {
        push @constraints, "asped < '$options{before}'";
    }
    elsif ($options{aspedbefore}) {
        push @constraints, "asped < '$options{aspedbefore}'";
    }

# process name selection option(s)

    if ($options{namelike}) {
        push @constraints, "readname like '$options{namelike}'";
    }
    if ($options{namenotlike}) {
        push @constraints, "readname not like '$options{namenotlike}'";
    }
    if ($options{nameregexp}) {
        push @constraints, "readname regexp '$options{nameregexp}'";
    }
    if ($options{namenotregexp}) {
        push @constraints, "readname not regexp '$options{namenotregexp}'";
    }

# process ID range specification

    if ($options{from}) {
        push @constraints, "read_id >= $options{from}";
    }
    elsif ($options{ridbegin}) {
        push @constraints, "read_id >= $options{ridbegin}";
    }

    if ($options{to}) {
        push @constraints, "read_id <= $options{to}";
    }
    elsif ($options{ridend}) {
        push @constraints, "read_id <= $options{ridend}";
    }

# process possible TAG selection (if none, version 0 is to be used), which
# implicitly selects on version because tags are put on sequence

    my @linkconstraints;
    my $additionaltable = '';
    if ($options{tagtype} || $options{tagname}) {
# for tag type or tag name add link to READTAG table
        $options{tagtype} =~ s/\,/','/ if $options{tagtype}; # used in "in" clause
        push @constraints, "tagtype in ('$options{tagtype}')" if $options{tagtype};
        push @linkconstraints, "SEQ2READ.seq_id = READTAG.seq_id";
        $additionaltable .= ",READTAG";
# for tag name add link to the TAGSEQUENCE table as well (TO BE TESTED)
#       if ($options{tagname}) {
#            $options{tagname} =~ s/\,/','/; # to use in "in" clause
#            push @constraints,"tagseqname in ('$options{tagname}')";
#            push @linkconstraints, "READTAG.tag_seq_id = TAGSEQUENCE.tag_seq_id";
#            $additionaltable .= ",TAGSEQUENCE";
#        }
    }
    else {
# retrieve version 0 (un-edited reads only, the raw data)
        push @constraints,"version = 0";
# possibly here version selection? TO BE TESTED
#        push @constraints,"version = ".($options{version} || 0);
    }
    if ($options{tagname}) {
        $options{tagname} =~ s/\,/','/; # to use in "in" clause
        push @constraints,"tagseqname in ('$options{tagname}')";
        push @linkconstraints, "READTAG.tag_seq_id = TAGSEQUENCE.tag_seq_id";
        $additionaltable .= ",TAGSEQUENCE";
    }
	
    push @constraints,@linkconstraints if @linkconstraints;

    $constraints = join(" and ", @constraints) if @constraints;

    $constraints .= " order by $options{orderby}" if $options{orderby};

    $constraints .= " limit $options{limit}" if $options{limit};

    return &getReadsForCondition($this,$constraints,$additionaltable);
}

sub getReadsByReadID {
# returns array of Read instances (meta data only) for input array of read IDs 
    my $this    = shift;
    my $readids = shift; # array ref
    my %options = @_;

    &verifyParameter($readids,'getReadsByReadID','ARRAY');

    my @reads;

    return \@reads unless scalar(@$readids); # return ref to empty array

    my $blocksize = $options{blocksize} || 10000;

    while (my $block = scalar(@$readids)) {

        $block = $blocksize if ($block > $blocksize);

        my @block = splice @$readids, 0, $block;

        my $range = join ',',sort {$a <=> $b} @block;

        my $constraints = "READINFO.read_id in ($range) and version = 0";

        my $reads = $this->getReadsForCondition($constraints);

        push @reads, @$reads if ($reads && @$reads);

    }

    return [@reads];
}

sub getReadsForCondition {
# private method
    my $this = shift;
    my $condition = shift;
    my $tables = shift || ''; # optional extra tables

# retrieve version 0 (un-edited reads only, the raw data)

$this->defineReadMetaData(); # unless $this->{read_attributes};

    my $query = "select READINFO.read_id,SEQ2READ.seq_id,"
              .        "$this->{read_attributes},$this->{template_addons}"
              . "  from READINFO,SEQ2READ,TEMPLATE $tables"
              . " where READINFO.read_id = SEQ2READ.read_id"
              . "   and READINFO.template_id = TEMPLATE.template_id";
# add the other conditions
    $query   .= "    and $condition" if $condition;

    $this->logQuery('getReadsForCondition',$query);

# execute

    my $dbh = $this->getConnection();

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
	$query = "select seq_id from READINFO left join SEQ2READ using (read_id) " .
                 "where READINFO.readname=? " .
	         "and version=?";
    } else {
	$query = "select seq_id from SEQ2READ where read_id=? and version=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($idvalue,$version) || &queryFailed($query,$idvalue,$version);

    my ($seq_id) = $sth->fetchrow_array();

    $sth->finish();   

    return $seq_id;
}

sub getReadsBySequenceID {
# returns an array of Read instances with (meta data only) for input array of sequence IDs
    my $this = shift;
    my $seqids = shift; # array ref

    &verifyParameter($seqids,'getReadsBySequenceID','ARRAY');

# prepare the range list

    my $range = join ',',sort @$seqids;

    my $dbh = $this->getConnection();

# retrieve version 0 (un-edited reads only, the raw data)

$this->defineReadMetaData(); # unless $this->{read_attributes};

    my $query = "select READINFO.read_id,SEQ2READ.seq_id,SEQ2READ.version," .
                "$this->{read_attributes},$this->{template_addons}" .
                " from SEQ2READ,READINFO,TEMPLATE ".
                "where READINFO.read_id = SEQ2READ.read_id".
                "  and READINFO.template_id = TEMPLATE.template_id". 
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
    my %options = @_; # notags =>  , nosequence => 

    &verifyParameter($contig,'getReadsForContig','Contig');

    return if $contig->hasReads(); # only 'empty' instance allowed

    my $dbh = $this->getConnection();

# NOTE: this query is to be TESTED may have to be optimized

    my $query = "select READINFO.read_id,SEQ2READ.seq_id,SEQ2READ.version," .
                "$this->{read_attributes},$this->{template_addons}" .
                " from MAPPING,SEQ2READ,READINFO,TEMPLATE " .
                "where MAPPING.contig_id = ?" .
                "  and MAPPING.seq_id = SEQ2READ.seq_id" .
                "  and SEQ2READ.read_id = READINFO.read_id" .
                "  and READINFO.template_id = TEMPLATE.template_id";

    my $sth = $dbh->prepare_cached($query);
 
    my $cid = $contig->getContigID();

    my $nr = $sth->execute($cid) || &queryFailed($query,$cid);

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

# add the sequence (in bulk) unless delayed loading is used

    $this->getSequenceForReads([@reads]) unless $options{nosequence};

# add read tags (in bulk)

    $this->getTagsForReads(\@reads) unless $options{notags};

# and add to the contig

    $contig->addRead([@reads]);
}

#------------------------------------------------------------------------------
# returning a list of read IDs
#------------------------------------------------------------------------------

sub getNamesForUnassembledReads {
# public: returns a list of readnames of reads not occurring in any contig
    my $this = shift;

# for options see getUnassembledReads

    return &getUnassembledReads($this->getConnection(),$this,'readname',@_);
}

sub getIDsForUnassembledReads {
# public: returns a list of readIDs of reads not occurring in any contig
    my $this = shift;

# for options see getUnassembledReads

    return &getUnassembledReads($this->getConnection(),$this,'read_id',@_);
}

sub getUnassembledReads {
# private: returns a list of readids of reads not figuring in any contig
    my $dbh  = shift;
    my $this = shift;
    my $item = shift;
    my %options = @_;

    &verifyPrivate($dbh,'getUnassembledReads');

# options: method (standard,subquery,temporarytables)
#          after  / aspedafter  (after and equal!)
#          before / aspedbefore (strictly before)
#          nosingleton : do not include reads in singleton contigs
#          namelike / namenotlike / nameregexp / namenotregexp
#          status : add selection on status, otherwise only 'PASS'

# process possible date selection option(s)

    my @constraint;

    if ($options{after}) {
        push @constraint, "asped >= '$options{after}'";
    }
    elsif ($options{aspedafter}) {
        push @constraint, "asped >= '$options{aspedafter}'";
    }

    if ($options{before}) {
        push @constraint, "asped < '$options{before}'";
    }
    elsif ($options{aspedbefore}) {
        push @constraint, "asped < '$options{aspedbefore}'";
    }

# process possible name selection option(s)

    if ($options{namelike}) {
        push @constraint, "readname like '$options{namelike}'";
    }
    if ($options{namenotlike}) {
        push @constraint, "readname not like '$options{namenotlike}'";
    }
    if ($options{nameregexp}) {
        push @constraint, "readname regexp '$options{nameregexp}'";
    }
    if ($options{namenotregexp}) {
        push @constraint, "readname not regexp '$options{namenotregexp}'";
    }

# add status selection (default PASS only); specify name or id

    my $status = "PASS"; # default
    $status = $options{status} if defined($options{status}); # could equal 0
    my $status_id = $options{status_id}; # if defined, takes precedence
    if ($status || $status_id) {
# identify the status in the dictionary; if not, assign 0 to status_id
        unless ($status_id) {
            my $dictionary = &createDictionary($dbh,"STATUS","name","status_id");
            $status_id = &dictionaryLookup($dictionary,$status) || 0;
	}
        push @constraint, "status = $status_id";
    }

# add limit if specified

    my $limit = $options{limit};

# choose your method and go

    my $method = $options{method};
    unless (defined($method)) {
        $method = 'usetemporarytables' unless @constraint;
	$method = 'usesubselect' if @constraint;
    }

    my $readitems = []; # for output list

    if ($method && (($method eq 'usetemporarytables')
                or  ($method eq 'intemporarytable'))) {

# first get a list of current generation contigs (those that are not parents)

        my $query  = "create temporary table CURCTG as "
                   . "select CONTIG.contig_id,CONTIG.project_id"
                   . "  from CONTIG left join C2CMAPPING "
                   . "    on CONTIG.contig_id = C2CMAPPING.parent_id "
                   . " where C2CMAPPING.parent_id is null";
        $query    .= "  and nreads > 1" unless $options{nosingleton};

        $dbh->do($query) || &queryFailed($query) && return undef;

# create a table of sequence IDs in those contigs
 
        $query = "create temporary table CURSEQ "
               . "(seq_id integer not null, contig_id integer not null,"
               .                                 " key (contig_id)) as "
               . "select seq_id,CURCTG.contig_id"
               . "  from CURCTG left join MAPPING using(contig_id)";

        $dbh->do($query) || &queryFailed($query) && return undef;

# create a table of the corresponding reads in those contigs
 
        $query = "create temporary table CURREAD "
               . "(read_id integer not null, seq_id integer not null,"
               . "     contig_id integer not null, key (read_id)) as "
               . "select read_id,SEQ2READ.seq_id,contig_id"
               . "  from CURSEQ left join SEQ2READ using(seq_id)";

        $dbh->do($query) || &queryFailed($query) && return undef;

# finally, get a list of unassembled reads

        if ($method eq 'intemporarytable') {

            $query  = "create temporary table FREEREAD as "
                    . "select READINFO.read_id"
                    . "  from READINFO left join CURREAD using(read_id)"
                    . " where seq_id is null";
            $query .= "   and ".join(" and ",@constraint) if @constraint;

            $dbh->do($query) || &queryFailed($query) && return undef;

            return 1; # table FREEREAD created
        }

        else {
            $query  = "select READINFO.$item"
                    . "  from READINFO left join CURREAD using(read_id)"
                    . " where seq_id is null";
            $query .= "   and ".join(" and ",@constraint) if @constraint;
            $query .= " limit $limit" if $limit;

            my $sth = $dbh->prepare($query);

            $sth->execute() || &queryFailed($query) && return undef;
        
            while (my ($readitem) = $sth->fetchrow_array()) {
                push @{$readitems}, $readitem;
            }

            $sth->finish();

            return $readitems;
        }
    }

# two methods without using temporary tables

# step 1: get a list of contigs of age 0 (long method)

    my $contigids = [];

    my $withsingletoncontigs = 0; # default INCLUDE reads in singleton contigs

    $withsingletoncontigs = 1 if $options{nosingleton}; # EXCLUDE those reads

    $contigids = $this->getCurrentContigIDs(singleton=>$withsingletoncontigs);
# somehow the next query does not work because the method is not known
#    $contigids = &getCurrentContigs($dbh,singleton=>$withsingletoncontigs);

# find the read IDs which do not occur in these contigs

    if (($method && $method eq 'usesubselect') || !@$contigids) {
# step 2: if there are no contigs, only a possible constraint applies; if there
# are current contigs use a subselect to get the complement of their reads
        my $query  = "select READINFO.$item from READINFO ";
        $query    .= " where " if (@constraint || @$contigids);
        $query    .=  join(" and ", @constraint) if @constraint;
        $query    .= " and " if (@constraint && @$contigids);
        $query    .= "read_id not in (select distinct SEQ2READ.read_id "
                   . "  from SEQ2READ join MAPPING using (seq_id)"
	           . " where MAPPING.contig_id in ("
                   . join(",",@$contigids)."))" if @$contigids;
        $query    .= " limit $limit" if $limit;

        my $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($readitem) = $sth->fetchrow_array()) {
            push @{$readitems}, $readitem;
        }

        $sth->finish();

	return $readitems;
    }

# step 2: find read IDs in contigs, using a join on SEQ2READ and MAPPING

    my $query = "select distinct SEQ2READ.read_id "
	      . "  from SEQ2READ join MAPPING using (seq_id)"
              . " where MAPPING.contig_id in (".join(",",@$contigids).")"
              . " order by read_id";

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query);
        
    my @tempids;
    while (my ($read_id) = $sth->fetchrow_array()) {
        push @tempids, $read_id;
    }

    $sth->finish();

# step 3 : get the read IDs NOT found in the contigs

    if (!scalar(@tempids)) {
# no reads found (should not happen except for empty assembly)
        $query  = "select READINFO.$item from READINFO";
        $query .= " where ".join(" and ", @constraint) if @constraint;
        $query .= " limit $limit" if $limit;
  
        $sth = $dbh->prepare($query);

        $sth->execute() || &queryFailed($query);

        while (my ($readitem) = $sth->fetchrow_array()) {
            push @{$readitems}, $readitem;
        }

        $sth->finish();
    }
    else {
        my $ridstart = 0;
        while (my $remainder = scalar(@tempids)) {

            my $blocksize = 10000;
            $blocksize = $remainder if ($blocksize > $remainder);
            my @readblock = splice (@tempids,0,$blocksize);
            my $ridfinal = $readblock[$#readblock];
            $ridfinal = 0 unless @tempids; # last block no upper limit

            $query  = "select READINFO.$item from READINFO";
            $query .= " where read_id > $ridstart ";
            $query .= "   and read_id <= $ridfinal" if $ridfinal;
            $query .= "   and ".join(" and ", @constraint) if @constraint;
            $query .= "   and read_id not in (".join(",",@readblock).")";
            $query .= " order by read_id";
            if ($limit) {
                my $remainder = $limit - scalar(@$readitems);
                last unless ($remainder > 0);
                $query .= " limit $remainder";
	    }
 
            $sth = $dbh->prepare($query);

            $sth->execute() || &queryFailed($query) && exit;

            while (my ($readitem) = $sth->fetchrow_array()) {
	        push @{$readitems}, $readitem;
            }

            $sth->finish();

            $ridstart = $ridfinal;
	}
    }

    return $readitems; # array of readnames
}

sub isUnassembledRead {
# check if a read_id or readname is of an unassembled read
    my $this = shift;
    my $readitem = shift; # obligatory read ID or name
    my $value = shift; # obligatory

# returns 1 if the read ID/readname is unassembled, else returns 0
# if query errors prevent determination of this status, false is returned

    return undef unless (defined($readitem) && defined($value));

# compose the query SHOULD INCLUDE GENERATION 0 test

    my $query = "select * from MAPPING"; 

    if ($readitem eq 'read_id') {
        $query .= "  join SEQ2READ using (seq_id)"
	        . " where SEQ2READ.read_id = ?";
    }
    elsif ($readitem eq 'readname') {
        $query .= ",SEQ2READ,READINFO"
                . " where MAPPING.seq_id = SEQ2READ.seq_id"
                . "   and SEQ2READ.read_id = READINFO.read_id"
	        . "   and READINFO.readname = ?";
    }
    else {
        return undef;
    }

# add the generation selection term as a subselect using a left join

    my $subquery = "select CONTIG.contig_id"
                 . "  from CONTIG left join C2CMAPPING"
                 . "    on (CONTIG.contig_id = C2CMAPPING.parent_id)"
		 . " where C2CMAPPING.parent_id is null";


    $query .= " and MAPPING.contig_id in ($subquery) limit 1";

    $this->logQuery('isUnassembledRead',$query,$value);

    my $dbh = $this->getConnection();
    my $sth = $dbh->prepare_cached($query);
    my $row = $sth->execute($value) || return &queryFailed($query,$value);
    $sth->finish();

# returns 1 if the read ID/readname is unassembled, else returns 0

    return ($row+0) ? 0 : 1; 
}

sub testReadAllocation {
# return a list of doubly allocated reads using MySQL5 view CURRENTCONTIGS
    my $this = shift;
    my %options = @_;

    my $logger = $this->verifyLogger('testReadAllocation');

# build temporary tables to faciltate easy search

    my $dbh = $this->getConnection();

# do a complex query on the CURRENTCONTIG views

    my $query = "select LSR.read_id, "
              . "       LC.contig_id, LC.project_id, "    
              . "       RC.contig_id, RC.project_id  " 
              . "  from CURRENTCONTIGS as LC, MAPPING as LM, SEQ2READ as LSR,"
              . "       CURRENTCONTIGS as RC, MAPPING as RM, SEQ2READ as RSR"
              . " where LC.contig_id = LM.contig_id" 
              . "   and LM.seq_id = LSR.seq_id"
              . "   and RC.contig_id = RM.contig_id" 
              . "   and RM.seq_id = RSR.seq_id"
              . "   and LC.contig_id != RC.contig_id"  # different contigs
    	      . "   and LSR.read_id = RSR.read_id";    # but same read

# add (optional) project selection

    if ($options{insideprojects} && !$options{betweenprojects}) {
# requires only a line to specify project selection
        $query .= " and LC.project_id = RC.project_id";
    }
    if (!$options{insideprojects} && $options{betweenprojects}) {
# requires only a line to specify project selection
        $query .= " and LC.project_id != RC.project_id";
    }
    my @data;
    if ($options{project_id}) {
# requires only a line to specify project selection
        $query .= " and LC.project_id = ?";
        push @data,$options{project_id};
    }
    if ($options{projectname}) {
# requires an extra join with PROJECT table
        $query =~ s/ where/, PROJECT where/;
        $query .= " and LC.project_id = PROJECT.project_id"
               .  " and name = ? ";
        push @data,$options{projectname};
    }

    my $sth = $dbh->prepare_cached($query);

    my $rows = $sth->execute(@data) || &queryFailed($query,@data);

    my $resulthash = {};

    while (my ($read,$lc,$lp,$rc,$rp) = $sth->fetchrow_array()) {
$logger->debug("result $read,$lc,$lp    $rc,$rp");
        $resulthash->{$read} = [] unless $resulthash->{$read};
        push @{$resulthash->{$read}}, $lc, $rc;
    }

    $sth->finish();

    return $resulthash;
}

sub getReadNamesLike {
# returns a list of readnames matching a pattern or name
    my $this = shift;
    my $name = shift; # name or pattern
    my %options = @_;

    my $dbh = $this->getConnection();

# options: unassembled

    if ($options{unassembled}) {
# if name contains a wildcard, also use namelike
	$options{namelike} = $name;
# ignore single read contigs (unless otherwise specified)
        $options{nosingleton} = 1 unless defined $options{nosingleton};
        return &getUnassembledReads($dbh,$this,'readname',%options);
    }

# else search the whole database

    return $this->getListOfReadNames(readNameLike=>$name,%options);
}

#------------------------------------------------------------------------------
# adding sequence to Reads
#------------------------------------------------------------------------------

sub getSequenceForReads {
# takes an array of Read instances and adds the DNA and BaseQuality (in bulk)
    my $this  = shift;
    my $reads = shift; # array of Reads objects
    my $blocksize = shift || 10000;

    &verifyParameter($reads,"getSequenceForReads",'ARRAY');

    &verifyParameter($reads->[0],"getSequenceForReads");

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


    my @sids = sort {$a <=> $b} keys(%$sids);

    return unless @sids;

    my $added = 0;
    while (my $block = scalar(@sids)) {

        $block = $blocksize if ($block > $blocksize);

        my @block = splice @sids, 0, $block;

        my $range = join ',',@block;

        my $query = "select seq_id,sequence,quality from SEQUENCE " .
                    " where seq_id in ($range)";

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
#? replace dashes by N if it's the original read
#?                $sequence =~ s/\-/N/g unless $read->getVersion();
                $read->setSequence($sequence);
                $read->setBaseQuality($quality);
                $added++ if $read->hasSequence();
            }
        }

        $sth->finish();
    }

# NOTE : test outside this method if all Read objects now have a sequence

    return $added;
}

#-----------------------------------------------------------------------------

sub getSequenceForRead {
# adds DNA sequence (string) and quality (array reference) to read
# this method is called from the Read class when using delayed data loading
    my $this = shift;
    my $read = shift;

    &verifyParameter($read,"getSequenceForRead");

# try successively: sequence id, read id and readname, whichever comes first

    my @bindvalue;

    my $query = "select sequence,quality from ";

    if (my $seq_id = $read->getSequenceID()) {
	$query .= "SEQUENCE where seq_id=?";
        push @bindvalue, $seq_id;
    }
    elsif (my $read_id = $read->getReadID()) {
        my $version = $read->getVersion() || 0;
	$query .= "SEQUENCE,SEQ2READ " . 
                  "where SEQUENCE.seq_id=SEQ2READ.seq_id" .
                  "  and SEQ2READ.version = ?" .
                  "  and SEQ2READ.read_id = ?";
        push @bindvalue, $version,$read_id;
    }
    elsif (my $readname = $read->getReadName()) {
        my $version = $read->getVersion() || 0;
	$query .= "SEQUENCE,SEQ2READ,READINFO " .
                  "where SEQUENCE.seq_id=SEQ2READ.seq_id" .
                  "  and SEQ2READ.version = ?" .
                  "  and READINFO.read_id = SEQ2READ.read_id" .
                  "  and READINFO.readname = ?";
        push @bindvalue, $version,$readname;
    }
    else {
	return 0; # can't do
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@bindvalue) || &queryFailed($query,@bindvalue);

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
  
    $read->setSequence($sequence);   # a string
    $read->setBaseQuality($quality); # reference to an array of integers

    return 1;
}

sub getCommentForRead {
# returns a list of comments, if any, for the specifed read
# this method is called from Read class when using delayed data loading
    my $this = shift;
    my $read = shift;

    &verifyParameter($read,"getCommentForRead");

    my $value;

    my $query = "select comment from ";
    if ($value = $read->getReadID()) {
	$query .= "READCOMMENT where read_id=?";
    }
    elsif ($value = $read->getReadName()) {
	$query .= "READINFO join READCOMMENT using (read_id) where readname=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query,$value);

    my $added;
    while(my ($comment) = $sth->fetchrow_array()) {
        $read->addComment($comment);
	$added++;
    }

    $sth->finish();

    return $added;
}

sub getTraceArchiveIdentifierForRead {
    my $this = shift;
    my $read = shift;

    &verifyParameter($read,"getTraceArchiveIdentifierForRead");

    my $value;

    my $query = "select traceref from ";
    if ($value = $read->getReadID()) {
	$query .= "TRACEARCHIVE where read_id=?";
    }
    elsif ($value = $read->getReadName()) {
	$query .= "READINFO join TRACEARCHIVE using (read_id) 
                   where readname=?";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query,$value);

    my $traceref;

    while(my @ary = $sth->fetchrow_array()) {
	$traceref = shift @ary;
    }

    $sth->finish();

    $read->setTraceArchiveIdentifier($traceref) if $traceref;
}

#-----------------------------------------------------------------------------

sub getListOfReadNames {
# returns an array of (all) readnames occurring in the database 
    my $this = shift;
    my %options = @_;

# decode extra  input

    my $onlySanger = 0;
    my $noTraceRef = 0;

    my $nextword;
    while ($nextword = shift) {
        $onlySanger = shift if ($nextword eq "onlySanger");
        $noTraceRef = shift if ($nextword eq "noTraceRef");
    }

# compose the query

    my $query = "select readname from READINFO ";

    if ($options{noTraceRef}) {
        $query .= "left join TRACEARCHIVE as TA using (read_id) 
                   where TA.read_id IS NULL ";
    }

    if ($options{onlySanger}) {
        $query .= "where " unless ($query =~ /where/);
       $query .= "and " if ($query =~ /where\s+\w+/);
         $query .= "readname like \"%.%\"";
    }

    if ($options{readNameLike}) {
        $query .= "where " unless ($query =~ /where/);
        $query .= "and " if ($query =~ /where\s+\w+/);
        $query .= "readname like '$options{readNameLike}'";
    }

    if ($options{limit}) {
	$query .= "limit $options{limit}";
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare($query);

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
    my $this = shift;
    my %options = @_; # read_id=> or readname=> 

    my $dbh = $this->getConnection();
   
    my $query = "select read_id from READINFO ";

    my $bindvalue;
    if ($bindvalue = $options{readname}) {
        $query .= "where readname = ?";
    }
    elsif ($bindvalue = $options{read_id}) {
        $query .= "where read_id = ?";
    }
    else {
print STDERR "INVALID call hasRead : @_\n"; # to be removed
        return undef;
    }

    my $sth = $dbh->prepare_cached($query);

    my $read_id;

    $sth->execute($bindvalue) || &queryFailed($query,$bindvalue);

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

    &verifyParameter($readnames,"areReadsNotInDatabase",'ARRAY');

    my %namehash;
    foreach my $name (@$readnames) {
        $namehash{$name}++;
    }

    my $dbh = $this->getConnection();
   
    my $query = "select readname from READINFO 
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

#------------------------------------------------------------------------------
# importing reads as Read objects
#------------------------------------------------------------------------------

sub putRead {
# insert read into the database
    my $this = shift;
    my $read = shift;
    my %options = @_;

    &verifyParameter($read,'putRead');

# a) test consistency and completeness

    my ($rc, $errmsg);

   ($rc, $errmsg) = &checkReadForCompleteness($read, @_);
    return (0, "failed completeness check ($errmsg)") unless $rc;

#return 0,"TEST ABORT checkReadForCompletenes: $errmsg";

   ($rc, $errmsg) = &checkReadForConsistency($read, @_);
    return (0, "failed consistency check ($errmsg)") unless $rc;

# b) encode dictionary items; special case: template & ligation

#    $this->populateLoadingDictionaries(); # autoload (ignored if already done)
    my $dbh = $this->getConnection();

# CLONE

    my $clone_id = &getReadAttributeID($read->getClone(),
				       $this->{LoadingDictionary}->{'clone'},
				       $this->{SelectStatement}->{'clone'},
				       $this->{InsertStatement}->{'clone'});
    $clone_id = 0 unless defined($clone_id); # ensure its definition

# LIGATION

    my ($sil,$sih);
    if (my $insertsize = $read->getInsertSize()) {
       ($sil,$sih) = @{$read->getInsertSize()};
    }

#    my $ligation_id = $this->getReadAttributeID('ligation',$read->getLigation(),
#					   [$sil, $sih, $clone_id]);
    my $ligation_id = &getReadAttributeID($read->getLigation(),
					  $this->{LoadingDictionary}->{'ligation'},
					  $this->{SelectStatement}->{'ligation'},
					  $this->{InsertStatement}->{'ligation'},
					  [$sil, $sih, $clone_id]);

# the next line set ligation_id to defined but 0 to handle undefined ligation

    $ligation_id = 0 unless ($ligation_id || $read->getLigation());

# the next line traps an unidentified ligation

    return (0, "failed to retrieve ligation_id") unless defined($ligation_id);

# TEMPLATE

#    my $template_id = $this->getReadAttributeID('template',$read->getTemplate(),
#					   [$ligation_id]);
    my $template_id = &getReadAttributeID($read->getTemplate(),
					  $this->{LoadingDictionary}->{'template'},
					  $this->{SelectStatement}->{'template'},
					  $this->{InsertStatement}->{'template'},
					  [$ligation_id]);

# the next line set template_id to defined but 0 to handle undefined template

    $template_id = 0 unless ($template_id || $read->getTemplate());

# the next line traps an unidentified template

    return (0, "failed to retrieve template_id") unless defined($template_id);

# c) encode dictionary items basecaller, status

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
	" READINFO(readname,asped,template_id,strand,chemistry,primer,basecaller,status)" .
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

    return (0, "failed to insert readname and core data into READINFO table;DBI::errstr=$DBI::errstr")
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

sub putSequenceForRead {
# private method to load all sequence related data
    my $this = shift;
    my $read = shift; # Read instance
    my $version = shift || 0;

    &verifyParameter($read,'putSequenceForRead');

    my $readid = $read->getReadID();

    my $readname = $read->getReadName();

    return (0,"Failed to add sequence for $readname: missing read_id") unless $readid;

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

    my $basequality = compress(pack("c*", @{$read->getBaseQuality()}));

    $query = "insert into SEQUENCE(seq_id,seqlen,sequence,quality) VALUES(?,?,?,?)";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($seqid, $read->getSequenceLength(), $sequence, $basequality);

# shouldn't we undo the insert in READINFO? if it fails

    return (0, "failed to insert sequence and base-quality for $readname ($readid);" .
	    "DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

    $sth->finish();

# Insert quality clipping

    my $lqleft = $read->getLowQualityLeft();
    my $lqright = $read->getLowQualityRight();

    if (defined($lqleft) && defined($lqright)) {
	$query = "insert into QUALITYCLIP(seq_id, qleft, qright) VALUES(?,?,?)";

	$sth = $dbh->prepare_cached($query);

	$rc = $sth->execute($seqid, $lqleft, $lqright);

# shouldn't we undo the insert in READINFO? if it fails

	return (0, "failed to insert quality clipping data for $readname ($readid);" .
		"DBI::errstr=$DBI::errstr") unless (defined($rc) && $rc == 1);

	$sth->finish();
    }

# insert sequencing vector data, if any

    my $seqveclist = $read->getSequencingVector();

    if (defined($seqveclist)) {
	$query = "insert into SEQVEC(seq_id,svector_id,svleft,svright) VALUES(?,?,?,?)";

	$sth = $dbh->prepare_cached($query);

	foreach my $entry (@{$seqveclist}) {

	    my ($seqvec, $svleft, $svright) = @{$entry};

            next unless $seqvec;

#	    my $seqvecid = $this->getReadAttributeID('svector',$seqvec) || 0;
	    my $seqvecid = &getReadAttributeID($seqvec,
				               $this->{LoadingDictionary}->{'svector'},
				               $this->{SelectStatement}->{'svector'},
				               $this->{InsertStatement}->{'svector'}) || 0;

unless ($seqvecid) {
print STDOUT "unidentified sequencing vector '$seqvec, $svleft, $svright' \n"; 
}

	    $rc = $sth->execute($seqid, $seqvecid, $svleft, $svright);

            unless (defined($rc) && $rc == 1) {
#                print STDERR "read $readname: \n";
#                foreach my $entry (@{$seqveclist}) {
#                    my ($seqvec, $svleft, $svright) = @{$entry};
#                    print STDERR "($seqvec, $svleft, $svright)\n";
#                }
      	        return (0, "failed to insert seq_id,svector_id,svleft,svright "
                     . "into SEQVEC for $readname ($readid, $seqid, $seqvecid, "
                     . "$svleft, $svright) DBI::errstr=$DBI::errstr"); 
            }
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

# insert align to SCF data , if more than one record

    my $alignToSCF = $read->getAlignToTrace();
    if (ref($alignToSCF) eq 'Mapping' && $alignToSCF->hasSegments() > 1) {
# NEW version using Mapping is to be tested
        $query = "insert into ALIGN2SCF (seq_id,startinseq,startinscf,length) ".
                 "VALUES(?,?,?,?)";
	$sth = $dbh->prepare_cached($query);

        my $segments = $alignToSCF->getSegments();
        foreach my $segment (@$segments) {
            my ($startseq,$finisseq,$startscf,$finisscf) = $segment->getSegment();
            my $slength = $finisseq - $startseq + 1;
            $sth->execute($seqid,$startseq,$startscf,$slength)
            || &queryFailed($query,$seqid,$startseq,$startscf,$slength);
        } 
	$sth->finish();
    }
# standard method used until now
    elsif (defined($alignToSCF) && scalar(@$alignToSCF) > 1) {
        $query = "insert into ALIGN2SCF (seq_id,startinseq,startinscf,length) VALUES(?,?,?,?)";
	$sth = $dbh->prepare_cached($query);

        foreach my $entry (@$alignToSCF) {
            my ($startinseq,$finisinseq,$startinscf,$finisinscf) = @$entry;
            my $slength = $finisinseq - $startinseq + 1;
            my $tlength = $finisinscf - $startinscf + 1;
            unless ($slength == $tlength) {
		print STDERR "Length mismatch in SCF alignment ($slength, $tlength)\n";
                next;
            }
            $sth->execute($seqid,$startinseq,$startinscf,$slength) 
            || &queryFailed($query,$seqid,$startinseq,$startinscf,$slength);
        } 
	$sth->finish();
    }

    return ($seqid, "OK");
}

sub putNewSequenceForRead {
# add the sequence of this read as a new (edited) sequence for existing read
# on success put the new sequence ID and version number into the input Read
    my $this = shift;
    my $read = shift; # a Read instance
    my $noload = shift; # optional

    &verifyParameter($read,'putNewSequenceForRead');

# a) test if the readname already occurs in the database

    my $readname = $read->getReadName();
    return (0,"incomplete Read instance: missing readname") unless $readname; 
    my $read_id = $this->hasRead(readname=>$readname);

# test db read_id against (possible) Read read_id (we don't know how $read was made)

    if (!$read_id) {
        return (0,"unknown read $readname");
    }
    elsif (!$read->getReadID()) {
        $read->setReadID($read_id);
    }
    elsif ($read->getReadID() && $read->getReadID() != $read_id) {
        return (0,"incompatible read IDs (".$read->getReadID." vs. $read_id)");
    }
    
# b) test if it is an edited read by counting alignments to the trace file

    my $alignToSCF = $read->getAlignToTrace();
    if (ref($alignToSCF) eq 'Mapping' && $alignToSCF->hasSegments() <= 1) { 
        return (0,"insufficient alignment information (using Mapping)");
    }
# old representation; to be removed after update to Read.pm
    elsif (ref($alignToSCF) eq 'ARRAY' && scalar(@$alignToSCF) <= 1) {
        return (0,"insufficient alignment information");
    }

# c) ok, now we get the previous versions of the read and compare

    my $first;
    my $prior = 1;  
    my $version = 0;
    while ($prior) {
        $prior = $this->getRead(read_id=>$read_id,version=>$version); # a Read
        if ($prior && $read->compareSequence($prior)) {
	    my $seq_id = $prior->getSequenceID();
            $read->setSequenceID($seq_id);
            $read->setVersion($version);
            return ("sequence ".$seq_id,"is identified as version $version "
                   ."of read $readname");
        }
        elsif ($prior) {
            $first = $prior unless defined $first;
            $version++;
        }
        elsif ($noload) {
# read not completed, missing seq_id
            return 0,"New sequence version $version for read $readname "
                     ."detected but not loaded";
        }
    }

# d) ok, we have a new sequence version for the read which has to be loaded
#    we only allow sequence without pad '-' symbols to entered 

    if ($read->getSequence() =~ /\-/) {
# fatal error: sequence contains non-DNA symbols ? /[^ACGTN]/ 
        return 0,"Invalid new sequence for read $readname: contains non-DNA symbols";
    }

# what about test/copying missing data from previous version? method on Read?

# e) load the new version of the sequence

my $logger = $this->verifyLogger('putNewSequenceForRead');
$logger->debug("new sequence version detected ($version) for read $readname");

    my ($seq_id,$errmsg) = $this->putSequenceForRead($read,$version); 
    unless ($seq_id) {
        return (0,"failed to load new sequence (version $version: $errmsg)");
    }

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

    my $rc = $sth->execute($read_id,$comment);

    $sth->finish();

    return $rc ? 1 : 0;
}

sub putCommentForReadName {
# add a comment for a given readname (finishers entry of comment?)
    my $this = shift;
    my $name = shift;

    my $readid = $this->hasRead(readname=>$name);
    return 0 unless $readid;
    return $this->putCommentForReadID($readid,shift);
}

sub testRead {
# public method to check read for validity
    my $this = shift;
    my $read = shift;

    &verifyParameter($read,'testRead');

    my $report = '';

    my ($status,$msg);
   ($status,$msg) = &checkReadForCompleteness($read,@_);
    $report .= 'completeness : '.($status ? 'passed' : 'FAILED');
    $report .= " ($msg)" unless $status;

    return $report;

   ($status,$msg) = &checkReadForConsistency($read,@_);
    $report .= 'consistency  : '.($status ? 'passed' : 'FAILED');
    $report .= " ($msg)" unless $status;
    $report .= "\n";

    return $report;
}

sub checkReadForCompleteness {
# private
    my $read = shift;
    my %options = @_;

    &verifyPrivate($read,'checkReadForCompleteness');

    return (0, "undefined readname")
	unless defined($read->getReadName());

    return (0, "undefined sequence")
	unless defined($read->getSequence());

    return (0, "undefined base-quality")
        unless defined($read->getBaseQuality());

    return (0, "undefined strand")
	unless defined($read->getStrand());

# the following checks can be switched off

    unless ($options{skipaspedcheck}) {

        return (0, "undefined asped-date")
	    unless defined($read->getAspedDate());
    }

    unless ($options{skipqualityclipcheck}) {
	return (0, "undefined low-quality-left")
	    unless defined($read->getLowQualityLeft());

	return (0, "undefined low-quality-right")
	    unless defined($read->getLowQualityRight());
    }

    unless ($options{skipligationcheck}) {

        return (0, "undefined template")
	    unless defined($read->getTemplate());

        return (0, "undefined ligation")
            unless defined($read->getLigation());

        return (0, "undefined insert-size")
	    unless defined($read->getInsertSize());
    }

    unless ($options{skipchemistrycheck}) {

        return (0, "undefined chemistry")
	    unless defined($read->getChemistry());

        return (0, "undefined primer")
            unless defined($read->getPrimer());
    }

    return (1, "OK");
}

sub checkReadForConsistency {
# private
    my $read = shift;
    my %options = @_;

    &verifyPrivate($read,'checkReadForConsistency');

# check process status 

    if (my $status = $read->getProcessStatus()) {
        return (0,$status) if ($status =~ /Completely\ssequencing\svector/i);
        return (0,"Low $status") if ($status =~ /Trace\squality/i);
        unless ($options{acceptlikeyeast}) {
            return (0,$status) if ($status =~ /Matches\sYeast/i);
	}
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

    &verifyPrivate($identifier,'getReadAttributeID');

# 1 try to find it in the stored dictionary hashes

    my $id = &dictionaryLookup($dict, $identifier);

    return $id if defined($id);

# 2 try to read it from the database (if found, the dictionary was not loaded)
   
    return undef unless defined($select_sth);

    my $rc = $select_sth->execute($identifier);

    if (defined($rc)) {
	($id) = $select_sth->fetchrow_array();
    }

# return the identification found

    if (defined($id)) {
        $select_sth->finish();
        return $id;
    }

# 3 it's a new dictionary item: add to the database and to the dictionary hash

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

    $select_sth->finish();
    $insert_sth->finish();

    &dictionaryInsert($dict, $identifier, $id) if defined($id);

    return $id;
}

sub putTraceArchiveIdentifierForRead {
# put a trace archive reference in the database
    my $this = shift;
    my $read = shift; # a Read instance

    &verifyParameter($read,'putTraceArchiveIdentifierForRead');

    my $TAI = $read->getTraceArchiveIdentifier() || return; # item absent

    my $readid = $read->getReadID() || return; # must have readid defined

    my $dbh = $this->getConnection();

    my $query = "insert into TRACEARCHIVE(read_id,traceref) VALUES (?,?)";

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($readid,$TAI);

    $sth->finish();

    return (0,"failed to insert trace archive identifier for readID $readid;" .
	      "DBI::errstr=$DBI::errstr") unless $rc;

    return (1,"OK");
}

sub deleteRead { # TO BE TESTED
# delete a read for the given read_id and all its data
    my $this = shift;
    my $key  = shift;  # read_id or readname
    my $value = shift; # its value

# user protection 

    my $user = $this->getArcturusUser();
    unless ($user eq 'ejz') {
        return (0,"user $user has no privilege to delete reads");
    }

    my $readid;
    if ($key eq 'id' || $key eq 'read_id') {
	$readid = $this->hasRead(read_id=>$value); # test existence
        return (0,"Read $value does not exist") unless $readid;
    }
    elsif ($key eq 'name' || $key eq 'readname') {
        return $this->deleteReadsLike($value,@_) if ($value =~ /[\%\_]/);
	$readid = $this->hasRead(readname=>$value); # get read_id for readname
        return (0,"Read $value does not exist") unless $readid;
    }
    else {
        return (0,"invalid input");
    }

# here read the confirmation (or not) from input parameters

    my ($confirm,$execute) = @_; # accept only confirm=>execute
    $execute = 0 if (!$confirm || $confirm && $confirm ne 'confirm' || !$execute);

    my $dbh = $this->getConnection();

# test if read is unassembled, i.e. does not occur in any contig

    my $query = "select * from MAPPING left join SEQ2READ using (seq_id) 
                 where SEQ2READ.read_id = ?";
    my $sth = $dbh->prepare_cached($query);
    my $row = $sth->execute($readid) || &queryFailed($query,$readid);
    $sth->finish();

    return (0,"Assembled read $value cannot be removed") if (!$row || $row > 0);

    return (0,"Read $value to be deleted") unless $execute;

# remove for readid from all tables it could be in (should be separate cleanup?)

    my $logger = $this->verifyLogger("deleteRead");

    my $delete = 0;
# delete seq_id items
    my @stables = ('SEQVEC','CLONEVEC','SEQUENCE','QUALITYCLIP','READTAG');
    foreach my $table (@stables) {
        $query = "delete $table from $table left join SEQ2READ using (seq_id)"
               . " where read_id=?";
        $logger->info($query);
        $sth = $dbh->prepare_cached($query);
        $row = $sth->execute($readid) || &queryFailed($query,$readid);
        $delete++ if ($row > 0);
        $sth->finish();
    }

# delete read_id items

    my @rtables = ('READCOMMENT','TRACEARCHIVE','SEQ2READ','READINFO');
    foreach my $table (@rtables) {

        $query = "delete from $table where read_id=?";
        $logger->info($query);
        $sth = $dbh->prepare_cached($query);
        $row = $sth->execute($readid) || &queryFailed($query,$readid);
        $delete++ if ($row > 0);
        $sth->finish();
    }

    return ($delete,"Records for read $readid removed from $delete tables");
}

sub deleteReadsLike { # TO BE TESTED
    my $this = shift;
    my $name = shift || return 0,undef;

    my $query = "select read_id from READINFO where readname like ?";

    $query =~ s/like/=/ unless ($name =~ /\%/);

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($name) || &queryFailed($query,$name);

    my @readids;
    while (my ($read_id) = $sth->fetchrow_array()) {
        push @readids,$read_id;
    }
    $sth->finish();

    return 0,"no reads found with readname like '$name'" unless @readids;

    my $result = 0;
    my $report = '';
    foreach my $read_id (@readids) {
        my ($success,$message) = $this->deleteRead(read_id=>$read_id,@_);
        $report .= "\n".$message unless $success;
        $result++ if $success;
    }

    return $result,$report;
}

sub getSequenceIDsForReads {
# put sequenceID, version and read_id into Read instances given their 
# readname (for unedited reads) or their sequence (edited reads)
# NOTE: this method may insert new read sequence
# (see also getSequenceIDForAssembledReads in ADBContig)
    my $this = shift;
    my $reads = shift; # array ref
    my $noload = shift; # flag inhibiting insertion of new read sequence

    &verifyParameter($reads,"getSequenceIDForReads",'ARRAY');

    &verifyParameter($reads->[0],"getSequenceIDForReads");
	
    my $log = $this->verifyLogger('getSequenceIDForReads');

# collect the readnames of unedited and of edited reads
# for edited reads, get sequenceID by testing the sequence against
# version(s) already in the database with method putNewSequenceForRead
# for unedited reads pull the data out in bulk with a left join

    my $success = 1;

    my $unedited = {};
    foreach my $read (@$reads) {
        if ($read->getSequenceID()) { 
            next; # already loaded
	}
        elsif ($read->isEdited) {
# assume the edited version is new, hence (try to) load it
            my ($added,$errmsg) = $this->putNewSequenceForRead($read,$noload);
	    $log->info("Edited $added $errmsg") if $added;
	    $log->warning("$errmsg") unless $added;
            $success = 0 unless $added;
        }
        else {
            my $readname = $read->getReadName();
            $unedited->{$readname} = $read;
        }
    }

# get the sequence IDs for the unedited reads (sequence version = 0)

    my @readnames = sort keys(%$unedited);

    my $dbh = $this->getConnection();

    my $blocksize = 10000;
    while (my $block = scalar(@readnames)) {

        $block = $blocksize if ($block > $blocksize);

        my @names = splice @readnames, 0, $block;

        my $query = "select READINFO.read_id,readname,seq_id" .
                    "  from READINFO left join SEQ2READ using (read_id) " .
                    " where readname in ('".join("','",@names)."')" .
	            "   and version = 0";

        my $sth = $dbh->prepare($query);

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
    }

# have we collected all of them? then %unedited should be empty

    if (keys %$unedited) {
        my $log = $this->verifyLogger('getSequenceIDsForReads');
        $log->error("Sequence ID not found for reads: "
	            . join(',',sort keys %$unedited));
        foreach my $key (keys %$unedited) {
            $log->special("Missing sequence ID for read : $key");
	}
        $success = 0;
    }

    return $success;
}

#----------------------------------------------------------------------------- 
# methods dealing with read TAGs
#----------------------------------------------------------------------------- 

sub getTagsForReads {
# bulk mode extraction; use as private method only
    my $this = shift;
    my $reads = shift; # array of Read instances

    &verifyParameter($reads,"getTagsForReads",'ARRAY');

    &verifyParameter($reads->[0],"getTagsForReads");

# build a list of sequence IDs (all sequence IDs must be defined)

    my $readlist = {};
    foreach my $read (@$reads) {
# test if sequence ID is defined
        if (my $seq_id = $read->getSequenceID()) {
            $readlist->{$seq_id} = $read;
        }
        else {
# warning message
            my $logger = $this->verifyLogger("getTagsForReads");
            $logger->error("getTagsForReads: Missing sequence identifier ".
                           "in read ".$read->getReadName());
        }
    }

    my @sids = sort {$a <=> $b} keys(%$readlist);

    return unless @sids;

    my $dbh = $this->getConnection();

    my $tags = &getReadTagsForSequenceIDs($dbh,\@sids,1000);

# add tag(s) to each read (use sequence ID as identifier)

    foreach my $tag (@$tags) {
        my $seq_id = $tag->getSequenceID();
        my $read = $readlist->{$seq_id};
        $read->addTag($tag);
    }

    return $tags;
}

sub getReadTagsForSequenceIDs {
# use as private method only; blocked retrieval of read tags
    my $dbh = shift;
    my $seqIDs = shift; # array ref; array will be emptied
    my $blocksize = shift || 1000;

    &verifyPrivate($dbh,"getReadTagsForSequenceIDs");

    my @tags;
    while (my $block = scalar(@$seqIDs)) {

        $block = $blocksize if ($block > $blocksize);

        my @sids = splice @$seqIDs, 0, $block;

        my $tags = &getTagsForSequenceIDs ($dbh,\@sids);

        push @tags, @$tags;
    }

    return [@tags];
}

sub getTagsForSequenceIDs {
# use as private method only
    my $dbh = shift;
    my $sequenceIDs = shift; # array of seq IDs
    my %options = @_;

    &verifyPrivate($dbh,"getTagsForSequenceIDs");

# compose query: use left join to retrieve data also if none in TAGSEQUENCE

    my $excludetags = $options{excludetags};
#    $excludetags =~ s/\W+/,/g if $excludetags; # replace any separator by ',' 

    my $items = "seq_id,tagtype,pstart,pfinal,strand,comment," # tagcomment
              . "tagseqname,sequence,TAGSEQUENCE.tag_seq_id";

    my $query = "select $items from READTAG left join TAGSEQUENCE"
              . " using (tag_seq_id)"
	      . " where seq_id in (".join (',',@$sequenceIDs) .")"
              . "   and deprecated != 'Y'"
#?             . "   and tagtype not in ($excludetags) " if $excludetags;
		  . " order by seq_id";

    my @tag;

    my $sth = $dbh->prepare($query);

    $sth->execute() || &queryFailed($query) && exit;

    while (my @ary = $sth->fetchrow_array()) {
# create a new Tag instance 
        my $tag = new Tag('Read'); # assign host class (re: putTagsForReads)
# and define its contents
        $tag->setSequenceID      (shift @ary); # seq_id
        $tag->setType            (shift @ary); # tagtype
        $tag->setPosition        (shift @ary, shift @ary); # pstart, pfinal
        $tag->setStrand          (shift @ary); # strand
        $tag->setTagComment      (shift @ary); # tagcomment
        $tag->setTagSequenceName (shift @ary); # tagseqname
        $tag->setDNA             (shift @ary); # sequence
	$tag->setTagSequenceID   (shift @ary); # tag sequence identifier
# add to output array
        push @tag, $tag;
    }

    $sth->finish();

    return [@tag];
}


sub putTagsForReads {
# bulk insertion of tag data
    my $this = shift;
    my $reads = shift; # array of Read instances
    my %options = @_; # autoload=> 

    &verifyParameter($reads,'putTagsForReads','ARRAY');

    &verifyParameter($reads->[0],'putTagsForReads');

    my $logger = $this->verifyLogger("putTagsForReads");

$logger->debug("ENTER getSequenceIDsForRead");

    my $success = $this->getSequenceIDsForReads($reads,1); # noload flag set

$logger->setPrefix("putTagsForReads");
$logger->debug("AFTER getSequenceIDsForRead");

# build a list of sequence IDs in tags (all sequence IDs must be defined)

    my $readlist = {};
    foreach my $read (@$reads) {
        next unless $read->hasTags();
        if (my $seq_id = $read->getSequenceID()) {
            $readlist->{$seq_id} = $read;
        }         
        else {
            $logger->error("putTagsForReads: missing sequence identifier ".
                           "in read ".$read->getReadName());
        }
    }

# get all tags for these reads already in the database

    my @sids = sort {$a <=> $b} keys(%$readlist);

    return '0.0' unless @sids; # no tags to be stored

# test against tags which have already been stored previously

    my $dbh = $this->getConnection();

$logger->debug("ENTER getReadTagsForSequenceIDs sids: ".scalar(@sids));

    my $existingtags = &getReadTagsForSequenceIDs($dbh,\@sids,1000); # empties @sids

$logger->debug("AFTER getReadTagsForSequenceIDs existing: ".scalar(@$existingtags));

# run through both reads and existing tags to weed out tags to be ignored

    my $ignore = {};

    my $scounter = 0; # sequence
    my $tcounter = 0; # tag

    @sids = sort {$a <=> $b} keys(%$readlist);

    my %isequaloptions = (ignoreblankcomment=>1);
    $isequaloptions{ignorenameofpattern} = "oligo\\w+";

$isequaloptions{logger} = $logger; # test purposes   

    while ($scounter < @sids && $tcounter < @$existingtags) {
 
	my $etag = $existingtags->[$tcounter];

        my $tagseq_id = $etag->getSequenceID();

        if ($sids[$scounter] < $tagseq_id) {
            $scounter++;
        }
        elsif ($sids[$scounter] > $tagseq_id) {
            $tcounter++;
        }
        else {
            my $read = $readlist->{$tagseq_id};
# test if the tags in the read are among the existing tags
            my $rtags = $read->getTags();

            foreach my $rtag (@$rtags) {
# skip if the tag is already marked
$logger->debug("processing tag $rtag");
                next if $ignore->{$rtag};
$logger->debug("testing tag $rtag");
# OBSOLETE process possible placeholder names (to enable the name comparison)
# &processTagPlaceHolderName($rtag,$logger); DEPRECATED
# and compare the tag with the current existing tag (including host class)
                $ignore->{$rtag}++ if $rtag->isEqual($etag,%isequaloptions);
$logger->setPrefix("putTagsForReads");
            }
            $tcounter++;
        }
    }

# finally collect all tags in the reads not marked to be ignored

    my @tags;
    foreach my $read (@$reads) {
        next unless $read->hasTags();
#        next unless $read->getSequenceID();
        my $rtags = $read->getTags();
        foreach my $rtag (@$rtags) {
            next if $ignore->{$rtag};
# process possible placeholder names (again! there may be no existing tags)
# &processTagPlaceHolderName($rtag,$logger); DEPRECATED
            push @tags,$rtag;
	}
    }

# here we have a list of new tags which have to be loaded

$logger->setPrefix("putTagsForReads");
$logger->debug("new tags to be loaded : ".scalar(@tags));

    return '0.0' unless @tags; # returns True for success but empty

    my $autoload = $options{autoload} || 0;
    $this->getTagSequenceIDsForTags(\@tags, autoload => $autoload);

    return [@tags] if $options{noload}; # test option

    return &putReadTags($dbh,\@tags);
}

sub getTagSequenceIDsForTags {
# add tag sequence IDs to input tags
    my $this = shift;
    my $tags = shift;
    my %options = @_; # print STDERR "getTagSequenceIDsForTags: @_\n";

# check input

    &verifyParameter($tags,'getTagSequenceIDsForTags','ARRAY');

    &verifyParameter($tags->[0],'getTagSequenceIDsForTags','Tag');

    my $tagIDhash = {};

    return $tagIDhash unless ($tags && @$tags); # return empty hash

    my $logger = $this->verifyLogger("getTagSequenceIDsForTags");

# get tag_seq_id using tagseqname for link with the TAGSEQUENCE reference list

    my %tagdata;
    foreach my $tag (@$tags) {
        my $tagseqname = $tag->getTagSequenceName();
        $tagdata{$tagseqname}++ if $tagseqname;
    }

# build the tag ID hash keyed on (unique) tag sequence name

    if (my @tagseqnames = keys %tagdata) {

$logger->debug("tagseqnames: @tagseqnames to be identified");

        my $tagSQhash = {};

# get tag_seq_id, tagsequence for tagseqnames

        my $query = "select tag_seq_id,tagseqname,sequence from TAGSEQUENCE"
	          . " where tagseqname = ?";
# my $query = "select tag_seq_id,tagseqname,sequence from TAGSEQUENCE"
#           . " where tagseqname in ('".join("','",@tagseqnames)."')";

        my $dbh = $this->getConnection();

        my $sth = $dbh->prepare_cached($query);

        foreach my $tagseqname (@tagseqnames) {

            $sth->execute($tagseqname) || &queryFailed($query,$tagseqname);

            while (my ($tag_seq_id,$tagseqname,$sequence) = $sth->fetchrow_array()) {
                $tagIDhash->{$tagseqname} = $tag_seq_id;
                $tagSQhash->{$tagseqname} = $sequence;
            }
 	}
        
        $sth->finish();

# test the sequence against the one specified in the tags

        foreach my $tag (@$tags) {
            my $tagseqname = $tag->getTagSequenceName();
            next unless $tagseqname;
	    my $sequence = $tag->getDNA();
            if (!$tagIDhash->{$tagseqname}) {
                $logger->error("Missing tag name $tagseqname ("
                              . ($sequence || 'no sequence available')
                              . ") in TAGSEQUENCE list");
                next unless $options{autoload}; # allow sequence to be null
# add tag name and sequence, if any, to TAGSEQUENCE list
	        my $tag_seq_id = &insertTagSequence($dbh,$tagseqname,$sequence);
         	if ($tag_seq_id) {
                    $tagIDhash->{$tagseqname} = $tag_seq_id;                
                    $tagSQhash->{$tagseqname} = $sequence if $sequence;
                }
            }
# test for a possible mismatch of sequence with the one in the database
            elsif ($sequence && $sequence ne $tagSQhash->{$tagseqname}) {
# test if the sequence is already in the database for another name (with a query)
                my $query = "select tag_seq_id,tagseqname,sequence"
                          . "  from TAGSEQUENCE"
	                  . " where sequence = '$sequence'";
                my $sth = $dbh->prepare($query);  
 
                $sth->execute() || &queryFailed($query);
                while (my ($tag_seq_id,$tagseqname,$sequence) = $sth->fetchrow_array()) {
                    $tagIDhash->{$tagseqname} = $tag_seq_id;
                    $tagSQhash->{$tagseqname} = $sequence;
                }
                $sth->finish();
                foreach my $name (keys %$tagSQhash) {
                    next unless defined($tagSQhash->{$name});
                    next unless ($tagSQhash->{$name} eq $sequence);
                    $tag->setTagSequenceName($name); # replace
                    $tagseqname = $name;
                    last;
		}
# if the sequence was not found, then generate a new entry with a related name
                unless ($sequence && $sequence eq $tagSQhash->{$tagseqname}) {
                    $logger->error("Tag sequence mismatch for tag $tagseqname : (tag) ".
                                   "$sequence  (taglist) $tagSQhash->{$tagseqname}");
# generate a new tag sequence name by appending a random string
                    my $randomnumber = int(rand(100)); # from 0 to 99
                    $tagseqname .= sprintf ('n%02d',$randomnumber);
# add tag name and sequence, if any, to TAGSEQUENCE list
	            my $tag_seq_id = &insertTagSequence($dbh,$tagseqname,$sequence);
         	    if ($tag_seq_id) {
                        $tagIDhash->{$tagseqname} = $tag_seq_id;                
                        $tagSQhash->{$tagseqname} = $sequence if $sequence;
                        $tag->setTagSequenceName($tagseqname); # replace
                    }
		}
	    }
# add the tag sequence ID to the tag object
            $tag->setTagSequenceID($tagIDhash->{$tagseqname});
        }
    }
}
   
sub putReadTags {
# use as private method only
    my $dbh = shift;
    my $tags = shift;

    &verifyPrivate($dbh,"putReadTags");

    return undef unless ($tags && @$tags);

# insert in bulkmode

    my $query = "insert into READTAG " # insert ignore ?
              . "(seq_id,tagtype,tag_seq_id,pstart,pfinal,strand,comment) "
              . "values ";

    my $success = 1;
    my $block = 100; # insert block size

    my $accumulated = 0;
    my $accumulatedQuery = $query;
    my $lastTag = $tags->[@$tags-1];

    foreach my $tag (@$tags) {

        my $seq_id           = $tag->getSequenceID();
        my $tagtype          = $tag->getType();
        my $tagseqname       = $tag->getTagSequenceName() || '';
        my ($pstart,$pfinal) = $tag->getPosition();
        my $tag_seq_id       = $tag->getTagSequenceID() || 0;
        my $strand           = $tag->getStrand();
        $strand =~ s/(\w)\w*/$1/;
        my $comment          = $tag->getTagComment();
# we quote the comment string because it may contain odd characters
        $comment = $dbh->quote($comment);

# protect against missing sequence ID: if missing do not add to insert data

        if ($seq_id) {
            $accumulatedQuery .= ',' if $accumulated++;
            $accumulatedQuery .= "($seq_id,'$tagtype',$tag_seq_id,";
            $accumulatedQuery .=  "$pstart,$pfinal,'$strand',$comment)";
        }

        if ($accumulated >= $block || $accumulated && $tag eq $lastTag) {

            my $sth = $dbh->prepare($accumulatedQuery);        
            my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
            $sth->finish();

            $success = 0 unless $rc;
            $accumulatedQuery = $query;
            $accumulated = 0;
        }
    }

    return $success; 
}


sub putTagSequence {
# public method add tagseqname and sequence to TAGSEQUENCE table
    my $this = shift;
    my %options = @_;

    my $tagseqname  = $options{tagseqname}  || return 0;

    my $tagsequence = $options{tagsequence} || return 0;

    my $dbh = $this->getConnection();

    return &insertTagSequence($dbh,$tagseqname,$tagsequence,$options{update});
}

sub insertTagSequence {
# private method; populate the TAGSEQUENCE table
    my $dbh = shift;
    my $tagseqname = shift || return undef;
    my $sequence = shift;
    my $update = shift;

    &verifyPrivate($dbh,"insertTagSequence");

# test if an update needs to be made

    if ($update && $sequence) {

        my $query = "select tag_seq_id,sequence from TAGSEQUENCE"
                  . " where tagseqname like ?"
                  . " order by tagseqname limit 1";

        my $sth = $dbh->prepare_cached($query);

        $sth->execute($tagseqname) || (&queryFailed($query,$tagseqname) && return);

        my ($tag_seq_id, $tagsequence) = $sth->fetchrow_array();

        $sth->finish();

# if tagsequence is already in the database, update only if $update>1

        if ($tag_seq_id) {

            return $tag_seq_id if ($tagsequence && $update<=1);
  
# replace/update the sequence

            $query = "update TAGSEQUENCE set sequence=?"
                   . " where tagseqname like ?"
                   . " limit 1";

            $sth = $dbh->prepare_cached($query);

            my $rc = $sth->execute($sequence,$tagseqname) 
            || &queryFailed($query,$sequence,$tagseqname);

            $sth->finish();

            return undef unless $rc; # a failed update

            return $tag_seq_id;
        }
    }

# insert a new tagseqname, sequence combination into TAGSEQUENCE

    my $query;
    my @values;
    if ($sequence) {
        $query = "insert ignore into TAGSEQUENCE (tagseqname,sequence) values (?,?)";
        @values = ($tagseqname,$sequence);
    }
    else {
        $query = "insert ignore into TAGSEQUENCE (tagseqname) values (?)";
        push @values, $tagseqname;
    }

    my $sth = $dbh->prepare_cached($query);        
                    
    my $rc = $sth->execute(@values) || &queryFailed($query,@values);

    $sth->finish();

    return undef unless $rc; # a failed query

    return $dbh->{'mysql_insertid'} if ($rc > 0); # a successfull insert

# the insert did not take place because the tag sequence name already exists
# get the  tag_seq_id  with a select on the tag sequence name

    $query = "select tag_seq_id from TAGSEQUENCE where tagseqname like ?";

    $sth = $dbh->prepare_cached($query);

    $rc = $sth->execute($tagseqname) || &queryFailed($query,$tagseqname);

    return undef unless $rc; # a failed query

    my ($tag_seq_id) = $sth->fetchrow_array();

    $sth->finish();

    return $tag_seq_id;
}

#------------------------------------------------------------------------------
# verification of method parameter and access mode
#------------------------------------------------------------------------------

sub verifyParameter {
    my $object = shift;
    my $method = shift || 'UNDEFINED';
    my $class  = shift || 'Read';

    return if ($object && ref($object) eq $class);
    print STDOUT "method 'ADBRead->$method' expects a $class instance "
               . "as parameter (instead of ".($object || 'UNDEF')."\n";
    exit 1;
}

sub verifyPrivate {
    my $caller = shift;
    my $method = shift;

    unless (defined($caller)) {
	print STDOUT "ignore diagnostic on verifyPrivate: $method\n";
	return;
    }

    if (ref($caller) eq 'Arcturusdatabase' || $caller =~ /^ADB\w+/) {
        print STDOUT "Invalid use of private method ADBRead->$method\n";
	exit 1;
    }
}

#-----------------------------------------------------------------------------

1;
