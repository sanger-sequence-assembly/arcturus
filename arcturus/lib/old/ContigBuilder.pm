package ContigBuilder;

#############################################################################
#
# build a contig given all reads
#
#############################################################################

use strict;

use ReadMapper;
use Compress;

#############################################################################
# Global variables
#############################################################################

my %ContigBuilder; # hash for references to instances of this class
my %forward;       # hash for forward mapping of contig ranges from generation 1

my $ReadMapper; # handle to ReadMapper module
my $Compress;   # handle to Compress   module
my $MyTimer;    # handle to the timer module

my $CONTIGS;    # database table handle to CONTIGS
my $CCTOCC;     # database table handle to CONTIGS2CONTIG
my $CCTOSS;     # database table handle to CONTIGS2SCAFFOLD
my $READS;      # database table handle to READS 
my $RRTOCC;     # database table handle to READS2CONTIG 
my $GAP4TAGS;   # database table handle to GAP4TAGS
my $TTTOCCS;    # database table handle to TAGS2CONTIG
my $ASSEMBLY;   # database table handle to ASSEMBLY
my $SEQUENCE;   # database table handle to CONSENSUS

my $break;
my $CGI;
my $TIMER;

#############################################################################
# constructor init: initialise the global (class) variables
#############################################################################

sub init {
# initialise module by setting class variables
    my $prototype = shift;
    my $tblhandle = shift; # handle to any table in the database
    my $nopreload = shift; # set True if no caching should be used

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    &setEnvironment; # define $break and $CGI

# if $CONTIGS was defined previously, check if same database

    if (!$tblhandle) {
        return 0; # missing table handle
    }
    elsif ($CONTIGS && $tblhandle->{database} ne $CONTIGS->{database}) {
        print "! Inconsistent databases in ContigBuilder: ";
        print "$tblhandle->{database} vs $CONTIGS->{database} $break";
        return 0;
    }

# get table handles (class variables, so work on one database only)

    $CONTIGS    = $tblhandle->spawn('CONTIGS');
    $CCTOCC     = $tblhandle->spawn('CONTIGS2CONTIG');
    $CCTOSS     = $tblhandle->spawn('CONTIGS2SCAFFOLD');
    $READS      = $tblhandle->spawn('READS');
    $RRTOCC     = $tblhandle->spawn('READS2CONTIG');
    $GAP4TAGS   = $tblhandle->spawn('GAP4TAGS');
    $TTTOCCS    = $tblhandle->spawn('TAGS2CONTIG');
    $ASSEMBLY   = $tblhandle->spawn('ASSEMBLY');
    $SEQUENCE   = $tblhandle->spawn('CONSENSUS');

# get the ReadMapper handle (class variable)

    $ReadMapper = ReadMapper->init($tblhandle);

    $ReadMapper->preload(0,'1100') if !$nopreload;  # build table handle caches (READS and PENDING)

    $self->{preload}     = 1 if !$nopreload;
    $self->{minOfReads}  = 2; # accept contigs having at least this number of reads 
    $self->{ignoreEmpty} = 1; # default ignore empty reads; else treat as error status 
    $self->{nameChange}  = 0; # default name change only for generation 0
    $self->{TESTMODE}    = 0; # test mode for caf file parser
    $self->{REPAIR}      = 0; # test/repair mode for read attributes
    $self->{READSCAN}    = 0; # test only for presence of assembled reads in database
    $self->{WRITEDNA}    = 0; # test only for presence of assembled reads in database
$self->{nameChange}  = 1; # TEST override

    bless ($self, $class);

# get the Compress handle

    $Compress = new Compress('ACGTN ');

#    &buildForwardMap;

    return $self;
}

#############################################################################
# constructor item new
#############################################################################

sub new {
# create instance for new contig
    my $prototype  = shift;
    my $contigname = shift;
    my $assembly   = shift || 0; # the assembly number
    my $userid     = shift || 'arcturus';

    my $class = ref($prototype) || $prototype;
    return $ContigBuilder{$contigname} if $ContigBuilder{$contigname};

    my $self  = {};

    $self->{cnames}   = []; # array for name of this contig (and parents)
    $self->{readmap}  = {}; # hash for read names and mapping data
    $self->{cntgmap}  = {}; # hash for contig id's and mapping data
    $self->{DNA}      = ''; # consensus sequence 
    $self->{'length'} =  0; # consensus sequence length (from caf)
    $self->{status}   = {}; # error status report
    $self->{counts}   = []; # counters
    $self->{tags}     = []; # array of tag hashes 

# store the name of this contig as first element in the instance array variable
 
    my $cnames   = $self->{cnames};
    $cnames->[0] = $contigname; # unique full name
    $cnames->[1] = $contigname; # (not unique) alias name
    my $counts   = $self->{counts};
    $counts->[0] = 0; # nr of reads 
    $counts->[1] = 0; # length of the contig 
    $counts->[2] = 0; # total mapped read length
    $counts->[3] = 0; # nr of linked contigs
    $counts->[4] = 0; # newly added read 
    my $status   = $self->{status};
    $status->{warnings} = 0;
    $status->{inerrors} = 0; # reading errors
    $status->{errors}   = 0; # dumping errors

# if new instance is spawned of an existing instance, inherit some variables

    if ($class eq ref($prototype)) {
        $self->{minOfReads}  = $prototype->{minOfReads}  || 1; 
        $self->{ignoreEmpty} = $prototype->{ignoreEmpty} || 1;     
        $self->{nameChange}  = $prototype->{nameChange}  || 0;     
        $self->{TESTMODE}    = $prototype->{TESTMODE}    || 0;
        $self->{REPAIR}      = $prototype->{REPAIR}      || 0;
        $self->{READSCAN}    = $prototype->{READSCAN}    || 0;
        $self->{WRITEDNA}    = $prototype->{WRITEDNA}    || 0;
# test only for presence of assembled reads in database
        $self->{preload}     = $prototype->{preload}     || 0;
#print STDOUT "new ContigBuilder inherits from prototype $prototype  (class $class)$break";
#print STDOUT "$self->{minOfReads},$self->{ignoreEmpty},$self->{TESTMODE},$self->{REPAIR} $break";
    }
    else {  
# use defaults
print STDOUT "new ContigBuilder (from scratch) $class $prototype $break";
        $self->{minOfReads}  = 1; # accept contigs having at least this number of reads 
        $self->{ignoreEmpty} = 1; # default ignore empty reads; else treat as error status 
        $self->{nameChange}  = 0; # default name change only for generation 0
        $self->{TESTMODE}    = 0; # test mode for caf file parser
        $self->{REPAIR}      = 0; # test/repair mode for read attributes
        $self->{READSCAN}    = 0; # test only for presence of assembled reads in database
        $self->{WRITEDNA}    = 0; # test only for presence of assembled reads in database
        $self->{preload}     = 0;
    }

#my $self->{ignoreEmpty} = 1; # default ignore empty reads; else treat as error status 

# get assembly and user id if defined

    $self->{ASSEMBLY} = $assembly;
    $self->{USERID}   = $userid;

# add the name of this contig to the class variable %ContigBuilder

    $ContigBuilder{$contigname} = $self;

    bless ($self, $class);
    return $self;
}

#############################################################################

sub setOwnership {
# (re)define class variables assembly number and/or user ID
    my $self     = shift;
    my $assembly = shift;
    my $userid   = shift;

    $self->{ASSEMBLY} = $assembly if defined($assembly);
    $self->{USERID}   = $userid   if defined($userid);
}

#############################################################################

sub testAssembly {
    my $self     = shift;
    my $assembly = shift;

# test assembly status and blocked status on READS2CONTIG table

    my $hashref = $ASSEMBLY->associate('hashref',$assembly,'assembly',{traceQuery=>0});
    
    my $report = 0;
    if (!$hashref || $hashref->{status} eq 'error') {
        $report = "Error status detected on assembly $assembly: $hashref->{comment}";
    }

# now test if any blocked entries found

    elsif ($RRTOCC->probe('contig_id',undef,"assembly=$assembly and blocked='1'")) {
        $report = "Blocked entries detected in assembly $assembly";
    }

    return $report;
}

#############################################################################

sub setMinOfReads {
# (re)define class variable $minOfReads;
    my $self  = shift;
    my $value = shift;

    $self->{minOfReads} = $value;
    $self->{minOfReads} = 1 if !defined($value);
}


#############################################################################

sub ignoreEmptyReads {
# (re)define class variable $ignoreEmpty;
    my $self  = shift;
    my $value = shift;

    $self->{ignoreEmpty} = $value;
    $self->{ignoreEmpty} = 1 if !defined($value);
}

#############################################################################

sub buildForwardMap {
# build a table with all mapped interval on contigs in the previous generation
    undef %forward;

# load all contig_ids referenced by readmaps in generation 1  

    my $query = "select distinct oldcontig,oranges,orangef from ";
    $query .= "CONTIGS2CONTIG,READS2CONTIG where CONTIGS2CONTIG.oldcontig ";
    $query .= "= READS2CONTIG.contig_id and READS2CONTIG.generation=1";

    my $hashes = $CCTOCC->query($query,{traceQuery=>0});

    return if (ref($hashes) ne 'ARRAY');

    foreach my $hash (@$hashes) {
        my $contig = $hash->{oldcontig};
        &addForwardRange($hash->{oldcontig},$hash->{oranges},$hash->{orangef});
    }
}

#############################################################################

sub addForwardRange {
    my $previous = shift; # contig_id in previous generation
    my $srange   = shift; # start of range mapped to late contig
    my $frange   = shift; # end of range

# the mapped ranges are accumulated one after the other in an array

    $forward{$previous} = [] if (ref($forward{$previous}) ne 'ARRAY');

    my $forward = $forward{$previous};
    
    push @$forward, $srange, $frange;
}

#############################################################################

sub setTestMode {
# (re)define class variables;
    my $self = shift;
    my $item = shift || 0; # either TESTMODE, REPAIR or READSCAN have meaning
    my $mode = shift || 0;

    if ($item =~ /\b(TESTMODE|REPAIR|READSCAN|WRITEDNA)\b/i) {
        $self->{$item} = $mode;
    }
    elsif ($item =~ /\bTIMER\b/i) {
        $TIMER = $mode;
    }
}

#############################################################################

sub assembledFrom {
# add a new read to contig alignment
    my $self     = shift;
    my $readname = shift;
    my $mapping  = shift; # mapping info as string of 4 integers

    my $readmap = $self->{readmap};
    my $counts  = $self->{counts};
    my $status  = $self->{status};

    $mapping =~ s/^\s+|\s+$//; # remove leading/trailing blanks
    my @fields = split /\s+|\:/,$mapping if ($mapping);

print "assembledFrom $break";
    if (defined($readname) && defined($mapping) && @fields == 4) {
# pick up an already exiting ReadMapper or create a new one
        my $readmapper = $ReadMapper->new($readname);
# add the mapping to the ReadMapper instance
        my $entry = $readmapper->addAssembledFrom(\@fields); 
        $counts->[0]++ if ($entry == 1); # count number of reads (at first alignment presented)
        $status->{inerrors}++ if !$entry;
        $readmap->{$readname}++;
    } 
    else {
        $readmap->{$readname} = 0;
        $status->{inerrors}++;
        $status->{diagnosis} .= "! Invalid or missing data for read $readname:";
        $status->{diagnosis} .= " \"$readname\" \"$mapping\"$break";
    }
}

################################################################################

sub addTag {
# store all tags encountered in this read in an array of hashes
    my $self  = shift;
    my $name  = shift; 
    my $sbase = shift;
    my $fbase = shift;
    my $info  = shift;

    my $rdtags = $self->{tags};

    undef my %newtag;
    $newtag{tagname}  = $name;
    $newtag{tcpstart} = $sbase;
    $newtag{tcpfinal} = $fbase;
    $newtag{taglabel} = $info;
    push @$rdtags, \%newtag;

    return @$rdtags+0;
}

#############################################################################

sub tagList {
# e.g. list = tagList('FTAGS')
    my $self = shift;
    my $name = shift;

# Finishers tags

    my @FTAGS = ('FINL','FINR','ANNO','COMP','FICM','RCMP','POLY',
                 'REPT','OLIG','COMM','RP20','TELO','REPC','WARN',
                 'CONF','DRPT','LEFT','RGHT','TLCM','UNCL','VARI');

# software TAGS

    my @STAGS = ('ADDI','AFOL','AMBG','CVEC','SVEC','FEAT','REPT',
                 'MALX','MALI','SILR');

# tags to be ignored (read tags)

    my @ITAGS = ('CpGI','CLIP','MISS','XMAT','CONS');

    my $list  = eval "join '|',\@$name";
}

#############################################################################

sub addDNA {
# enter the DNA consensus sequence (from e.g. caf file)
    my $self = shift;
    my $dna  = shift;
    my $lgt  = shift;

    $dna =~ s/^\s*|\s*$//; # chop leading and trailing blanks

    $self->{DNA} .= $dna;

    $self->{'length'} = $lgt if $lgt;
}

#############################################################################

sub dumpDNA {
# enter the DNA consensus sequence
    my $self = shift;
    my $c_id = shift;
    my $size = shift;

    print "Dumping DNA :\n$self->{DNA}\nsize=$size length=";
    print length($self->{DNA});
    print "\n";

    return 0 if (!$self->{DNA} || !length($self->{DNA}));

# there are three sizes which should all be the same
# 1) the size of the DNA string
# 2) size specified in caf file (may be missing)
# 3) size from the readmaps ($size) 

    my $length = length($self->{DNA});
    $self->{'length'} = $length if !$self->{'length'}; # to have it defined

    if ($self->{'length'} != $length || $size != $length) {
        print "Warning: consensus sequence mismatch ($length $size)$break";
    }

# compress the string

    my $compress = 99; # Huffman

    my ($count, $sequence) = $Compress->sequenceEncoder($self->{DNA},$compress);

    $length = length($sequence); print "Consensus sequence count $count length $length $break";

    my $quality;


# enter 

    my @columns = ('contig_id','sequence','quality');#,'length');
    my @cvalues = ($c_id      ,$sequence ,$quality );#,$length );
#    if (!$SEQUENCE->newrow(\@columns, \@cvalues)) {
#        print STDOUT "$SEQUENCE->{qerror} $break";
#    }
}

#############################################################################

sub dump {
# write the contig to database after tests
    my $self     = shift;
    my $assembly = shift;
    my $userid   = shift;
    my $forced   = shift;

# process parameter input

    my %options = (forcedLoad   => 0,  # override fatal errors
                   showWarnings => 0); # print warnings                  

# get the assembly and user name (input values override defaults)

    $userid      = $self->{USERID}   if !$userid;
    $assembly    = $self->{ASSEMBLY} if !$assembly;

# output format

    my $fonts = &fonts;

# we keep track of error conditions with the variable $complete

    my $cnames   = $self->{cnames};
    my $readmap  = $self->{readmap}; # hash of the maps read e.g. from caf file 
    my $cntgmap  = $self->{cntgmap};
    my $status   = $self->{status};
    my $counts   = $self->{counts};

    my $complete = 1;

    my $report = "${break}Attempting to dump contig $cnames->[0] ....$break";

    &timer('ContigBuilder dump',0) if $TIMER;

#############################################################################
# (0) test error status on ASSEMBLY for this assembly
#############################################################################

    my $estatus = $self->testAssembly($assembly);
# block the dump if error (protect against corrupting READS2CONTIG table)
    return $estatus if $estatus;

#############################################################################
# (I) first test: any input errors on this contig?
#############################################################################

    if ($status->{inerrors}) {
        $status->{inerrors}  = $status->{errors};
        $status->{diagnosis} = $status->{inputlog};
        $complete = 0; # will force skip to exit
    } 
    else {
# reset the diagnosis info (build error status from scratch)
        $status->{errors} = 0;
        undef $status->{diagnosis};
    }

#############################################################################
# (II) second test: are ReadMapper objects listed in 'readmap' all built?
# test if all reads are found in the READS table (we need the read_id's)
# by using the ->isInDataBase  method of the ReadMapper objects
#############################################################################

    my @reads = sort keys %$readmap; # all reads specified for this contig
    $ReadMapper->preload(\@reads,'0011'); # preload data into ReadMapper buffer (R2C + EDITS) 

# NOTE: we use keys %$readmap (instead of @reads) throughout because readmap keys may be deleted

    undef my %readmapper; # hash for reference to readmapper objects for reads in this contig

    my $missed = 0;
    my $tested = 0;
    my $nrOfReads = 0;

    if ($complete) {
        &timer('ContigBuilder dump part II',0) if $TIMER;
        foreach my $readname (keys (%$readmap)) {
            print "Testing read $readname (nr $tested)$break" if ($CGI && !((++$tested)%50));
            my $readobject = $ReadMapper->lookup($readname);
            if (defined($readobject)) {
# add pointer to ReadMapper to internal list
                $readmapper{$readname} = $readobject;
# now test if the read is in the database using ReadMapper
                if (my $dbrref = $readobject->isInDataBase(0,1,$assembly)) {
                    $status->{diagnosis} .= "Read $readname found in ARCTURUS database$break";
                }
                elsif (!$forced) {
                    $status->{diagnosis} .= "Read $readname not in ARCTURUS database$break";
                    $missed++;
                }
                else {
                    $status->{warnings}++;
                    $status->{diagnosis} .= "Read $readname not in ARCTURUS database: ";
                    $status->{diagnosis} .= "FORCED to ignore its absence $break";
                    delete  $readmap->{$readname};
                    delete $readmapper{$readname};
                    $readobject->delete();
                    $counts->[0] -= 1;
                }
	    } 
            else {
# no ReadMapper, but still test if read in database; will add read to PENDING if missing
                $status->{diagnosis} .= "ReadMapper $readname missing $break";
                $ReadMapper->inDataBase($readname,0,1,$assembly);
                $missed++;
            }
        }
# test number of ReadMapper instances found or missed
        my $ntotal = keys %$readmap;
        $nrOfReads = keys %readmapper; # get number of ReadMappers found
# complete 0 forces skip to exit
        $complete = 0 if (!$nrOfReads || $missed);
        $complete = 0 if (($nrOfReads+$missed) != $ntotal);
        $complete = 0 if ($ntotal > $counts->[0]); # the != test is in the next (III) block
        $status->{diagnosis} .= "$nrOfReads ReadMappers defined, $missed missed or incomplete out ";
        $status->{diagnosis} .= "of $ntotal ($counts->[0]) for contig $cnames->[0]$break";
        &timer('ContigBuilder dump part II',1) if $TIMER;
    }

    $report = "I&II: number of reads: $nrOfReads complete $complete $break";

#############################################################################
# (III) third test: are the mappings defined, complete and do they make sense
#############################################################################

    $tested = 0;
    my $cover = 0;

    if ($complete) {

        &timer('ContigBuilder dump part III',0) if $TIMER;

        my $progress = '';
        my $nreads = 0;
        $counts->[2] = 0; # for total read length
        undef my $cmin; undef my $cmax;
        undef my $minread; undef my $maxread;
        undef my $minspan; undef my $maxspan;
        undef my @names; # of first and last reads
        foreach my $readname (keys (%$readmap)) {
# get the mapping of this read to the contig and test the range
            print "Testing readmapper $readname (nr $tested)$break" if ($CGI && !((++$tested)%50));

# my $readMap = $readmap->{$readname} if $PADDED; # to be SUPERceded
# the assemble method will organise the mapping information stored in the ReadMapper instance
# and return the (padded) read-to-contig alignment (one single map) as an array of length 4
            my $readobject = $readmapper{$readname};
            my $readMap = $readobject->alignToContig; # data stored in readmapper (padded/unpadded)

            if ($readMap && @$readMap == 4) {
                my $pcstart = $readMap->[0];
                my $pcfinal = $readMap->[1];
                my $prstart = $readMap->[2];
                my $prfinal = $readMap->[3];
                $progress .= "read $readname: $pcstart $pcfinal $prstart  $prfinal $break";
                my $lastmin = $cmin;
	        $cmin = $pcstart if (!defined($cmin) || $pcstart<$cmin);
	        $cmin = $pcfinal if (!defined($cmin) || $pcfinal<$cmin);
                my $lastmax = $cmax;
	        $cmax = $pcfinal if (!defined($cmax) || $pcfinal>$cmax);
	        $cmax = $pcstart if (!defined($cmax) || $pcstart>$cmax);
# get range covered by this read
                my $readspan = abs($prfinal-$prstart)+1;
                $counts->[2] += $readspan; # total length of reads
# keep track of first and last reads
                $names[0] = $readname; 
                $progress .= "read $readname: $pcstart $pcfinal $cmin  $cmax $break";
                if ($pcstart == $cmin || $pcfinal == $cmin) {
# this read aligns with start of the contig
                    if (!defined($minspan) || $readspan < $minspan || $cmin != $lastmin) {
                        $minread = $readname;
                        $minspan = $readspan;
                    }
                    elsif ($readspan == $minspan) {
                        $names[1] = $minread;
                        @names = sort @names; # alphabetically sorted
                        $minread = $names[0]; # the first one
                    }
                    $progress .= "read: $readname, minread=$minread readspan=$readspan cmin=$cmin$break";
                }
                if ($pcfinal == $cmax || $pcstart == $cmax) {
# this read aligns with end of the contig
                    if (!defined($maxspan) || $readspan < $maxspan || $cmax != $lastmax) {
                        $maxread = $readname;
                        $maxspan = $readspan;
                    }
                    elsif ($readspan == $maxspan) {
                        $names[1] = $maxread;
                        @names = sort @names; # alphabetically sorted
                        $maxread = $names[0]; # the first one again! re: inverted contigs
                    }
                    $progress .= "read: $readname, maxread=$maxread readspan=$readspan cmax=$cmax$break";
                }
                $nreads++;
	    }
            else {
                $status->{diagnosis} .= "! Invalid mapping for read $readname in contig ";
                $status->{diagnosis} .= "$cnames->[0]: @$readMap$break";
                $status->{errors}++;
                $complete = 0;
            }
	}
# test contig cover
	if ($cmin && $cmin != 1) {
            $status->{diagnosis} .= "! unusual lower bound $cmin of mapping";
            $status->{diagnosis} .= " range for contig $cnames->[0]$break";
            $status->{warnings}++;
        }
# test current read count against input tally
        if ($nreads != $counts->[0]) {
            $status->{diagnosis} .= "! Read count error on contig $cnames->[0]: $nreads ";
            $status->{diagnosis} .= "against $counts->[0] (Mixed padding perhaps?)$break";
            $status->{errors}++;
            $complete = 0;
        }
        else {
            $complete = $nreads if $complete;
            $counts->[1] = $cmax-$cmin+1; # the length of the contig
        }

        if ($counts->[1]) {
# determine full name of this contig from cover, length and begin and end read ids
            $cover  = $counts->[2]/$counts->[1];
# build the number as sqrt(r**2+c**2)*2*cover; produces an <=I12 number
# which is sensitive to a change of only one in either r or c for all
# practical values of cover (1-20); max contig length about 1.2-5 10**8
            my $uniquenumber = sqrt($cover*$cover + 1) * $counts->[2] * 1.75;
            my $uniquestring = sprintf("%012d",$uniquenumber);
            $cover = &truncate($cover,2); # truncate to 2 decimals
# cleanup the readnames
            $progress .= "minread $minread    maxread $maxread $break";
            $minread = &readAlias($minread);
            $maxread = &readAlias($maxread);
            $cnames->[1] = $minread.'-'.$uniquestring.'-'.$maxread;
	}
        else {
            $cnames->[1] = 'cannot be determined';
        }

        &timer('ContigBuilder dump part III',1) if $TIMER;

        $report .= "III : Full Arcturus contigname: $cnames->[1] (complete=$complete)$break";
    }


#############################################################################
# (IV) apply mapping to reads, test them and collect contig links
#############################################################################

    my $isConnected = 0;  
    my $isIdentical = 0;
    my $nameChange  = 0;
    my $oldContig   = 0;
    my $newContigHash = '000000:0:00000000';
    undef my @priorContigHash;

    my $isWeeded = 0;
    while ($complete && !$isWeeded) {

        &timer('ContigBuilder dump part IV',0) if $TIMER;

        my $progress = ''; # local report
        $isWeeded = 1; # switch to 0 later if not

# reset counters (left from any previous analysis)

        foreach my $cntg (keys (%$cntgmap)) {
            delete $cntgmap->{$cntg};
        }

# build the mappings for each ReadMapper; test connections to earlier contigs

        $tested = 0;
        $counts->[0] = 0;
        my $emptyReads = 0;
        foreach my $read (keys %$readmap) {
            print "Building map for read $read (nr $tested)$break" if ($CGI && !((++$tested)%50));
            my $readobject = $readmapper{$read};
            my $contocon = $readobject->{contocon};

# transfer the read-to-contig alignment to the ReadMapper instance REDUNDENT when calculations done in Mapper

# $readobject->alignToContig(\@{$readmap->{$read}}) if $PADDED;

# test the ReadMapper alignment specification and status for this read

# $readobject->align() if $PADDED; # already done with getAssembledFrom

# test previous alignments of this read in the database

            $readobject->mtest();

            $progress .= "Testing read $read (nr $tested)  con-to-con @$contocon$break";

# if it's a healthy read (no error status), build history info

            my $previous = $readobject->{dbrefs}->[3]; # the previous contig, if any
            $progress .= "previous contig info: $previous $break";

            if ($readobject->status(0) && $contocon->[4] < 0 && $self->{ignoreEmpty}) {
                $status->{diagnosis} .= "Empty read $read wil be ignored $break";
                $status->{warnings}++;
                delete  $readmap->{$read};
                delete $readmapper{$read};
                print "$fonts->{o} Empty read $read wil be ignored $fonts->{e} $break" if $CGI;
                $emptyReads++;
            }

            elsif ($readobject->status(0)) {
	        $status->{diagnosis} .= "! Error condition reported in ReadMapper $read$break";
                $status->{errors}++;
                $complete = 0;
            }

            else {
# defaults 0 for new readmap or a previous one which is deprecated (with contocon->[4] = 2 or 3)
                my $hash = $newContigHash;
                if ($previous && $contocon->[4] <= 1) {
# read was previously aligned to contig $previous (and not deprecated): get hash for linked contig
                    $hash = sprintf("%06d:%01d:%08d",$previous,$contocon->[4],$contocon->[5]);
                }

# auto vivify the linkdata array for the link to previous contig; also valid for this new contig

                my $linkdata = $cntgmap->{$hash};
                if (!$linkdata || @$linkdata != 6) {
                    my @linkdata = @$contocon;
                    $progress .= "initial alignment read $readobject->{dbrefs}->[0] to ";
                    $progress .= "contig $previous range: @linkdata$break";
                    $linkdata = \@linkdata; 
                    $cntgmap->{$hash} = $linkdata;
                    $cntgmap->{$hash}->[4] = 0;
                    $cntgmap->{$hash}->[5] = 0;
                }
                $progress .= "contig shift data: '@{$contocon}'$break";
                $linkdata->[0] = $contocon->[0] if ($contocon->[0] < $linkdata->[0]); # previous
                $linkdata->[1] = $contocon->[1] if ($contocon->[1] > $linkdata->[1]);
                $linkdata->[2] = $contocon->[2] if ($contocon->[2] < $linkdata->[2]); # this contig
                $linkdata->[3] = $contocon->[3] if ($contocon->[3] > $linkdata->[3]);
                $linkdata->[4]++; # number of reads in this previous/shift/alignment

# new reads and deprecated reads are treated the same as new alignments against this new contig 

                $cntgmap->{$hash}->[5]++ if ($contocon->[4] > 1);
# ??? $hash  = sprintf("%06d:%01d:%08d",$previous,$contocon->[4]-2,$shift);
# ??? $cntgmap->{$hash}->[5]--; # reads deleted from the previous contig (not used at the moment)
                $counts->[0]++; # count total number of reads in the current contig
            }
        }

# okay, here we have a complete list of all connecting contigs (and the new one as '00.... 00')

        my @contigLinkHash = sort keys %$cntgmap;
        $progress .= "contigLinkHash(es): @contigLinkHash $break";
        foreach my $hash (@contigLinkHash) {
            push @priorContigHash, $hash if ($hash ne $newContigHash);
        }

        if (@contigLinkHash == 1 && $contigLinkHash[0] eq $newContigHash) {
#** it's a completely new contig without connections (all mappings are new)
            $isIdentical = 0;
            $isConnected = 0;  
        }

        elsif (@contigLinkHash == 1 && $contigLinkHash[0] ne $newContigHash) {
#** one linked previous contig, but no new or deprecated mappings at all
#** the current contig may be identical to the previous one (but not necessarily!)
#** this section tests the contig names for possible inconsistencies
            my @linkdata = split ':',$contigLinkHash[0];
            $progress .= "linkdata to previous contig: @linkdata $break";
            $oldContig = $linkdata[0];
            $isConnected = 1;
            my $newReads = $cntgmap->{$contigLinkHash[0]}->[4];
# now test for reads appearing in the previous version but not in the new one
	    my $hashrefs = $CONTIGS->associate('nreads,contigname',$oldContig,'contig_id');
	    my $hashref = $hashrefs->[0];
            my $oldCheckSum = &checksum($hashref->{contigname});
	    my $newCheckSum = &checksum($cnames->[1]);
# if the contig hash names differ, test if perhaps the checksums and nr of reads match
	    if ($cnames->[1] ne $hashref->{contigname}) {
                if ($linkdata[1]) {
                    $isIdentical = 0; # inverted compared to previous, counts as different
                }
	        elsif ($oldCheckSum == $newCheckSum && $newReads == ($hashref->{nreads}-$emptyReads)) {
                    $isIdentical = 1; # cover, length and nr. of reads are identical 
                    $nameChange  = 1; # only the name not; mark for update
                }
                else {
                    $isIdentical = 0; # e.g. reads deleted compared with previous assembly
                }
            }
# the contig hash names match
            elsif ($linkdata[1]) {
# identical names, but different orientation: it's different, thus the previous name is somehow wrong
                $isIdentical = 0;
                $status->{warnings}++;
                $status->{diagnosis} .= "Inconsistent contigname detected in previous ";
                $status->{diagnosis} .= "generation : $cnames->[1]";
            }
            else {
# identical names and identical orientation: it's the same contig
                $isIdentical = 1;
            }
# for identical contigs, test number of reads
            if ($isIdentical && $newReads != $hashref->{nreads}) {
                $status->{warnings}++;
                $status->{diagnosis} .= "Reads mismatch for contig $cnames->[1] with ";
                $status->{diagnosis} .= "$newReads reads ($hashref->{nreads}); possibly ";
                $status->{diagnosis} .= "empty reads";
            }
        }

	elsif (@contigLinkHash == 2 && $contigLinkHash[0] eq $newContigHash) {
# there are new and/or deprecated mappings and the contig is linked to a previous one
            $isConnected = 1;
            my @nlinkdata = split ':',$contigLinkHash[0];
            my @olinkdata = split ':',$contigLinkHash[1];
            my $newContigData = $cntgmap->{$contigLinkHash[0]};
# it's the same contig if all new reads are deprecated and the names match, or 
# if the order & shift of [1] is 0 and the names match (e.g. continued after previous abort)
            if ($newContigData->[4] == $newContigData->[5] || $olinkdata[1] == 0 && $olinkdata[2] == 0) {
	        my $previous = $CONTIGS->associate('contigname',$olinkdata[0],'contig_id');
                $isIdentical = 1 if ($previous eq $cnames->[1]); # based on hash value
            }
            $oldContig = $olinkdata[0];
        }
# EXTRA case to be considered?
	else {
# either 0 or  more than one linking contig (contigLinkHash >= 2); definitively a new contig
            $isConnected = @priorContigHash;
            $isIdentical = 0;
        }

# if it's a new contig with connections, check the intervals on the previous contig(s)
# if (some) intervals overlap, the reads inside the intervals have to be deprecated
# and reallocated as first-appearing reads to this new contig; then redo this step IV

        if ($isConnected && !$isIdentical) {
print "Checking for overlapping intervals: isConnected=$isConnected isIdentical=$isIdentical $break";
            foreach my $link (@priorContigHash) {
                my $ors = $cntgmap->{$link}->[0];
                my $orf = $cntgmap->{$link}->[1];
print "link=$link  cntgmap  @{$cntgmap->{$link}} $break";
                my ($previous, $order, $shift) = split /\:/,$link;
print "previous=$previous  order=$order  shift=$shift $break";
# go through each alignment on $previous and test for overlap with the current alignment
                if (my $forward = $forward{$previous}) {
                    my @intervals = @$forward;
print "forward=$forward  intervals=@intervals $break";
                    while (@intervals) {
                        my @range;
                        $range[0] = shift @intervals;
                        $range[1] = shift @intervals;
                        @range = sort @range;
print "range @range orf=$orf  ors=$ors $break";
# now test the interval $oranges-$orangef against @range 
                        if ($range[0] <= $orf && $range[1] >= $ors) {
# there is overlap somewhere, test 4 cases
                            my $ws = $range[0];
                            my $wf = $range[1];
                            $ws = $ors if ($range[0] < $ors);
                            $wf = $orf if ($range[1] > $orf);
# deprecate the reads which fall inside the overlap window on the previous contig
                            my $deprecated = 0;
print "wrange: ws = $ws  wf = $wf $break";
                            foreach my $read (keys %$readmap) {
                                my $readobject = $readmapper{$read};
                                my $contocon = $readobject->{contocon};
print "read $read: contocon: @$contocon $break";
                                if (($contocon->[0] >= $ws && $contocon->[0] <= $wf)
		         	 || ($contocon->[1] >= $ws && $contocon->[1] <= $wf)) {
                                    $deprecated++ if $readobject->deprecate('because of overlap');
                                    $progress .= "read $read is deprecated because of overlap$break";
print "read $read is deprecated because of overlap$break";
                                }
                            }
                            $isWeeded = 0 if $deprecated;
                        }
                    }
                }
	    }

            if ($isWeeded) {
# add current interval(s) to the forward map from previous generation , but only at last iteration
                foreach my $link (@priorContigHash) {
                    my $ors = $cntgmap->{$link}->[0];
                    my $orf = $cntgmap->{$link}->[1];
                    my ($previous, $order, $shift) = split /\:/,$link;
                    &addForwardRange($previous, $ors, $orf);
                }
	    }
        }

# at this point, we have collected all the contigs referenced and possibly new reads

        $report .= "IV  : $isConnected connecting contig(s) found,  Identical=$isIdentical ";
        $report .= "weeded=$isWeeded nameChange=$nameChange$break";

        foreach my $hash (sort @priorContigHash) {
            my ($contig,$order,$shift) = split ':', $hash;
            my  $map = $cntgmap->{$hash};
	    $report .= sprintf ("%6d %1d %8d  %8d-%8d %8d-%8d  %6d %5d",$contig,$order,$shift,@$map);
            $report .= $break;
        }

        &timer('ContigBuilder dump part IV',1) if $TIMER;

        print $progress;
    }

#############################################################################
# (V) Add the contig to the CONTIGS table (we must have contig_id)
#############################################################################

print "V $break";

    my $accepted = 0;
    $accepted = 1 if (!$self->{minOfReads} || $counts->[0] >= $self->{minOfReads}); 

    $counts->[3] = @priorContigHash;
    my $newContigData = $cntgmap->{$newContigHash} || 0;
    if ($newContigData && @$newContigData) {
        $counts->[4] = $newContigData->[4] - $newContigData->[5];
        $report .= "newContigData=$newContigData  @$newContigData  cnts: @$counts $break";
    }
    else {
        $counts->[4] = 0;
        $report .= "No newContigData, i.e. no new readmaps, detected $break";
    }
 
    $CONTIGS->rollback(0); # clear any (previous) rollback(s) on this table 

    undef my $contig;
    if (!$accepted) {
# insufficient number of reads
        $status->{diagnosis} = "Contig $cnames->[1] with $counts->[0] reads is ignored$break";
    }
    elsif ($isIdentical) {
# use the previous contig ID
        $contig = $oldContig;
    }
    elsif ($complete) {
# add the new contig to CONTIGS and get its contig_id

        &timer('ContigBuilder dump part V',0) if $TIMER;

        $report .= "Adding new contig $cnames->[1] ($cnames->[0]) to CONTIGS table$break";

        undef my @columns;
        undef my @cvalues;
        push @columns, 'aliasname'; push @cvalues, $cnames->[0]; 
        push @columns, 'length';    push @cvalues, $counts->[1]; 
        push @columns, 'ncntgs';    push @cvalues, $counts->[3]; 
        push @columns, 'nreads';    push @cvalues, $counts->[0]; 
        push @columns, 'newreads';  push @cvalues, $counts->[4];
        push @columns, 'cover' ;    push @cvalues, $cover; 
        push @columns, 'origin';    push @cvalues, 'Arcturus CAF parser';
# SHOULDN'T WE ACQUIRE A LOCK HERE ????
# add new record using the compound name as contigname
        if (!$CONTIGS->newrow('contigname',$cnames->[1],\@columns,\@cvalues)) {
# if contig(name) already exists get contig number (NOTE: should never occur with non-unique contigname)
            if ($CONTIGS->{qerror} =~ /already\sexists/) {
                $contig =  $CONTIGS->associate('contig_id',$cnames->[1],'contigname');
                $status->{warnings}++;
                $status->{diagnosis} .= "contig $cnames->[1] is already present as number $contig$break";
                $CONTIGS->status(1); # clear the error status
            }
            else {
                $status->{errors}++;
                $status->{diagnosis} .= "Failed to add contig $cnames->[1]: $CONTIGS->{qerror}$break";
                $complete = 0;
            }
        }
        else {
# new contig added: get its contig_id number
	    $contig = $CONTIGS->lastInsertId; 
            $CONTIGS->signature($userid,'contig_id',$contig);
            $report .= "V   : Contig $cnames->[1] ($cnames->[0]) added as nr $contig ";
            $report .= "to CONTIGS ($counts->[0] reads)$break";
        }
# RELEASE THE LOCK HERE ????

        &timer('ContigBuilder dump part V',1) if $TIMER;

    }

#############################################################################
# (VI) dump all readmaps onto the database (and test if done successfully)
#############################################################################

print "VI $break";

    if ($complete && $accepted) {

        &timer('ContigBuilder dump part VI',0) if $TIMER;

        $report .= "VI  : Writing read maps to database $break";
# write the read mappings and edits to database tables for this contig and assembly
        my $dumped = 0;
# SHOULDN'T WE ACQUIRE A LOCK HERE on READS2CONTIG ????
        foreach my $readname (keys %readmapper) {
            my $readobject = $readmapper{$readname};
            print "Processing read $readname (nr $dumped)$break" if ($CGI && !((++$dumped)%50));
            if ($readobject) {
                $complete = 0 if (!$readobject->dump($contig,$assembly));
            }
            else {
                $complete = 0; # something weirdly wrong
            }
        }
# RELEASE THE LOCK HERE ????

# if complete, dumps are done okay; remove the ReadMappers at the very end

        $report .= "Failed to dump (some of the) read maps $break" if !$complete;

        &timer('ContigBuilder dump part VI',1) if $TIMER;
    }

#############################################################################
# (VII) here contig and map dumps are done (and successful if $complete)
#############################################################################
print "VII $break";
    &timer('ContigBuilder dump',1) if $TIMER;

    undef my @priorContigList;
    foreach my $hash (@priorContigHash) {
        my ($prior,$order,$shift) = split ':',$hash;
        push @priorContigList, $prior;
    }

    if ($complete && $accepted && !$isIdentical) {

        &timer('ContigBuilder dump part VII',0) if $TIMER;

# link the new contig to a scaffold and add assembly status 
        $CCTOSS->newrow('contig_id',$contig,'assembly',$assembly); # astatus N by default
# inherit the project from connecting contig(s), if any
        if (@priorContigHash) {
            $report .= "prior contigs=@priorContigList $break";
            my $project = $CCTOSS->associate('distinct project',\@priorContigList,'contig_id');
            if (ref($project) eq 'ARRAY') {
                $self->{warning} .= "! Multiple project references in connected contigs: @priorContigList$break";
            }
            elsif (!$project) {
                $self->{warning} .= "! No Scaffold references in connected contigs: @priorContigList$break";
            }
            else {
                $CCTOSS->update('project',$project,'contig_id',$contig);
            }
# amend the assembly status on connecting contigs
            foreach my $priorcontig (@priorContigList) {           
                $CCTOSS->update('astatus','S','contig_id',$priorcontig);
            }
        }

        $CCTOCC->rollback(0);
        foreach my $hash (@priorContigHash) {
            my ($priorContig,$order,$shift) = split ':',$hash;
            my $alignment = $cntgmap->{$hash};
            $report .= "priorContigHash: $hash,  alignment: @$alignment $break";
            if ($alignment->[4] >= 0) {
# this should be on a complete definition basis
                undef my @columns;
                undef my @cvalues;
                push @columns, 'newcontig'; push @cvalues, $contig;
                push @columns, 'oldcontig'; push @cvalues, $priorContig;
# the new range is always aligned
                push @columns, 'nranges'; push @cvalues, $alignment->[2];
                push @columns, 'nrangef'; push @cvalues, $alignment->[3];
# the old range is aligned or counter aligned
                if ($order == 0) {
                    push @columns, 'oranges'; push @cvalues, $alignment->[0];
                    push @columns, 'orangef'; push @cvalues, $alignment->[1];
                }
                else { # reverse alignment
                    push @columns, 'oranges'; push @cvalues, $alignment->[1];
                    push @columns, 'orangef'; push @cvalues, $alignment->[0];
                }
#CHANGE
                if (!$CCTOCC->newrow(\@columns, \@cvalues)) {
                    $status->{diagnosis} .= "! Failed to add entry to CONTIGS2CONTIG table$break";
                    $complete = 0;
                    last;
                } 
            }
# update the contig status for the previous contig
            $CCTOSS->update('astatus','S','contig_id',$priorContig);
        }

        &timer('ContigBuilder dump part VII',1) if $TIMER;

        if ($complete) {
# if there is a consensus sequence, dump it using this contig_id
#            $self->dumpDNA($contig,$counts->[1]) if $self->{WRITEDNA};
# here remove the ReadMappers and this contigbuilder to free memory
            my $dumped = 0;
            foreach my $readname (keys %readmapper) {
                my $readobject = $readmapper{$readname};
                print "Removing readmap $readname (nr $dumped)$break" if ($CGI && !((++$dumped)%50));
                $readobject->status(2); # dump warnings
                $readobject->delete();
            }
            undef %readmapper;
            my $result = &status($self,2);
            $report .= "Contig $cnames->[1] entered successfully into CONTIGS table ";
            $report .= "($counts->[4] new reads; $counts->[3] parent contigs)$break";
print $report;
            $CONTIGS->rollback(0); # clear rollback stack on CONTIGS table
            $CCTOCC->rollback(0); # clear rollback stack on CONTIGS2CONTIG table
            $ASSEMBLY->update('status','loading','assembly',$assembly);
            &delete($self);
            return 0;
        }
    }

# next block is activated if the current contig is identical to one entered earlier

    elsif ($complete && $accepted && $isIdentical) {
#$self->dumpDNA($contig,$counts->[1]); # for test purposes
# the new contig is identical to a previous one; remove the ReadMappers and this contigbuilder
        my $dumped = 0;
        foreach my $readname (keys %readmapper) {
            my $readobject = $readmapper{$readname};
            print "Removing readmap $readname (nr $dumped)$break" if ($CGI && !((++$dumped)%50));
            $readobject->status(2); # dump warnings
            $readobject->delete();
        }
        undef %readmapper;
# undo the addition to CONTIGS, if any
        $CONTIGS->rollback(1); 
        $status->{warnings}++;
        $status->{diagnosis} .= "Contig $cnames->[0] ($cnames->[1])$fonts->{'y'} not added";
        $status->{diagnosis} .= "$fonts->{e}: is identical to contig $oldContig$break";
# if the previous contig is part of generation 1, amend its assembly status (from N) to C (current)
        my $generation = $RRTOCC->associate('distinct generation',$oldContig,'contig_id');
        if (ref($generation) eq 'ARRAY') {
            $status->{warnings}++; # or error? 
            $status->{diagnosis} .= "Multiple generations @$generation for contig ";
            $status->{diagnosis} .= "$cnames->[1] ($contig), NO FURTHER TESTS DONE$break";
        }
        else {
# add the assembly info to the CONTIGS2SCAFFOLD table, if not done before 
            $CCTOSS->newrow('contig_id',$oldContig,'assembly',$assembly); # default N
            $CCTOSS->update('astatus','C','contig_id',$oldContig) if ($generation > 0);
# update the contig name (active after name redefinition)
            my $hashrefs = $CONTIGS->associate('contigname,aliasname',$oldContig,'contig_id');
            if ($nameChange && ($generation == 0 || $self->{nameChange})) {
                my $alias = $hashrefs->[0]->{aliasname};
                if ($cnames->[0] ne $alias) {
                    $status->{warnings}++;
                    $status->{diagnosis} .= "Mismatch of alias names: $cnames->[0] vs. $alias $break";
                    $nameChange = 0; # default no name change
                }
                elsif ($hashrefs->[0]->{contigname} ne $cnames->[1]) {
#                $nameChange = 1 if $self->{nameChange}; # overrides
#                if ($hashrefs->[0]->{contigname} ne $cnames->[1] && $nameChange) {
                    $CONTIGS->update('contigname',$cnames->[1],'contig_id',$oldContig);
                    $status->{diagnosis} .= "Old contigname $hashrefs->[0]->{contigname} ";
                    $status->{diagnosis} .= "is replaced by new $cnames->[1] $break";
                }
            }
        }
        my $result = &status($self,3);
        &delete($self);
        return 0;
    }


    if (!$complete) {
# the contig cannot be dumped because of errors in itself or any of its reads
        $status->{diagnosis} .= "! Contig $cnames->[0] NOT added because of errors:$break";
        $status->{diagnosis} .= $report;
        $status->{errors} += $missed;
        $status->{errors}++ if (!$status->{errors});
# cleanup any additions to the various tables        
        $CONTIGS->rollback(1); # undo, i.e. remove the last added record from CONTIGS
        $CCTOCC->delete('newcontig',$contig);
# remove any dumped readmaps
        $RRTOCC->delete('contig_id',$contig);
        $CCTOSS->delete('contig_id',$contig);
# and list the status of the individual readobjects
        foreach my $readname (keys %readmapper) {
            my $readobject = $readmapper{$readname};
            $readobject->status(2); # full error/warnings list 
        }
# possibly add the reads to PENDING (via class method isInDataBase, if not done earlier)
        if (!$tested) {
            foreach my $readname (keys (%$readmap)) {
                print "Pinging read $readname (nr $tested)$break" if (!((++$tested)%50));
                $ReadMapper->isInDataBase(0,1,$assembly);
            }
        }
        return status($self,1);
    }
}

#############################################################################

sub checksum {
    my $checksum = shift;

    my $fonts = &fonts;

#    $checksum =~ s/^[^\:]+\:(\d+)\:\S+$/$1/;
    $checksum =~ s/^\S+\W(\d+)\W\S+$/$1/;
print "$fonts->{o} BAD SPLIT $fonts->{e} on checksum $checksum $break" if ($checksum =~ /\D/);

    return $checksum
}

#############################################################################

sub truncate {
    my $float    = shift;
    my $decimals = shift;

    $decimals = 0 if ($decimals < 0);
    
    my $multi = 1.0;
    while ($decimals--) {
        $multi *= 10;
    }
    $multi = int($multi + 0.5);
    $float = int($float*$multi + 0.5) / $multi; 

    return $float;
}

#############################################################################

sub readAlias {
# replace the readname by read_id as long hexadecimal number 
    my $readname = shift;

    if (my $array = $READS->cacheRecall($readname,{indexName=>'readname'})) {
#print "readAlias: $readname => ";
        my $read_id = $array->[0]->{read_id};
        $readname = sprintf "%lx", $read_id;
#print " read_id $read_id  => alias $readname $break";
    }

    elsif (my $read_id = $READS->associate('read_id',$readname,'readname',{returnScalar=>1})) {
        $readname = sprintf "%lx", $read_id;
    }

    else {
# read_id undefined (should not occur!), recover by using an abbreviated readname
        my @section = split /\./,$readname;

        $readname  = $section[0];
        if (defined($section[1])) {
            while (length($section[1]) > 4) {
                chop $section[1];
            }
            $readname .= $section[1];
        }
    }

    return $readname;
}

#############################################################################

sub list {
# full list of status of this contig
    my $self = shift;

    my $counts  = $self->{counts};
    my $cnames  = $self->{cnames};
    my $readmap = $self->{readmap};

    my $fonts = &fonts;

    print "${break}$counts->[0] Reads for Contig $cnames->[0]$break";

    foreach my $read (sort keys %$readmap) {
        print STDOUT "$read   @{$readmap->{$read}}$break" if ($readmap->{$read});
        print STDOUT "$read   NO or INVALID data$break"  if (!$readmap->{$read});
    }

    if (@$cnames > 1) {
    # history links
    }

    return status($self,1);
}

#############################################################################

sub status {
# return eror count
    my $self = shift;
    my $list = shift;

    my $cnames = $self->{cnames};
    my $status = $self->{status};

    my $errors    = $status->{errors};
    $errors = $status->{inerrors} if (!$errors);
    my $warnings  = $status->{warnings};
    my $diagnosis = $status->{diagnosis};

    if (defined($list) && $list > 0) {
        my $fonts = &fonts;
        if ($errors || $warnings) {
            my $font = $fonts->{b}; $font = $fonts->{o} if $errors;
            print STDOUT "Status of ContigBuilder $cnames->[0]: ";
            print STDOUT "$font $errors errors $fonts->{e}, $warnings warnings$break";
            print STDOUT "$diagnosis$break";
        } else {
            print STDOUT "Status of ContigBuilder $cnames->[0]: $fonts->{g} pass $fonts->{e}$break";
        }
#        print STDOUT "$break";
    }

    return $errors;
}

#############################################################################

sub delete {
# delete the hashes of this contig (irreversible) and remove from %ContigBuilder
    my $self = shift;

    my $contig = $self->{cnames}->[0];
   
    foreach my $key (keys (%$self)) {
        my $hash = $self->{$key};
        undef %$hash if (ref($hash) eq "HASH");
        undef @$hash if (ref($hash) eq "ARRAY");
    }

    undef %$self;

    delete $ContigBuilder{$contig};

    print STDOUT "ContigBuilder object $contig destroyed$break$break";
}

###############################################################################

sub lookup {
# return the reference to a contigbuilder instance in the class table
    my $self   = shift;
    my $contig = shift;

# if no contig of that name defined, return reference to hash table
# if $contig is a name, return reference to named contig 
# if $contig is a number, return reference to that number in the table 

    my $result;

    if (!$contig) {
        $result = \%ContigBuilder;
    }
    elsif (my $object = $ContigBuilder{$contig}) {

        $result = $object;
    }
    elsif ($contig !~ /[a-z]/i && $contig =~ /\d+/) {

        foreach my $name (sort keys (%ContigBuilder)) {
            if (--$contig == 0) {
                $result = $ContigBuilder{$name};
                last;
            }
        }
    }
    return $result;
}


###############################################################################

sub flush {
# dump all remaining completed ContigBuilder objects
    my $self     = shift;
    my $minimum  = shift;
    my $assembly = shift; # optional
    my $forced   = shift; # optional

    my $pending = keys %ContigBuilder;
    if (!defined($minimum) || $pending >= $minimum) {
        foreach my $contig (keys %ContigBuilder) {
            $ContigBuilder{$contig}->dump($assembly,undef,$forced); # is after successful dump removed
#            $ContigBuilder{$contig}->dump($assembly,undef,$forced); # is after successful dump removed
        }
        foreach my $contig (keys %ContigBuilder) {
	    print STDOUT "Not Dumped: $contig$break" if $ContigBuilder{$contig};
        }
    }

# finally flush the remaining (i.e. unallocated) ReadMappers (and tables)

    $ReadMapper->flush;

    #$MyTimer->summary;

    return keys %ContigBuilder; # return number of leftover ContigBuilders
}

#############################################################################

sub cafFileParser {
    my $self     = shift;
    my $filename = shift; # full caf file name
    my $maxLines = shift; # maximum number of lines, 0 for all (optional)
    my $cnfilter = shift; # contig name filter (optional)
    my $cblocker = shift; # hash with contig names to be ignored (optional)
    my $rblocker = shift; # hash with read names to be ignored (optional)
    my $list     = shift || 0; # listing 

my $taglist = 3;
    print "enter CAF file parser $break";
my $errlist = 0;

    my $FTAGS = $self->tagList('FTAGS');
    my $STAGS = $self->tagList('STAGS');
    my $ITAGS = $self->tagList('ITAGS');# print STDOUT "itags=$ITAGS<br>";

    my $minOfReads = $self->{minOfReads}; 
print "minOfReads = $minOfReads $break";
    print STDOUT "file to be opened: $filename ..." if $list;
    open (CAF,"$filename") || return 2; # die "cannot open $filename";
    print STDOUT "... DONE $break" if $list;

    &timer('caf parser',0) if $TIMER;

    print STDOUT "Read a maximum of $maxLines lines $break" if ($list && $maxLines);
    print STDOUT "Contig (or alias) name filter $cnfilter $break" if ($list && $cnfilter);
    print STDOUT "Contigs with fewer than $minOfReads reads are NOT dumped $break" if ($list && $minOfReads > 1);

    my $line = 0;
    my $status = 0;

    my $exactmatch = 0;
    $exactmatch = 1 if ($cnfilter =~ s/^exact\s+//i);
#    my $exact = ($cnfilter =~ /(\S+)exact/$1/); # remove 'exact' appendix

    undef my $object;
    undef my $length;
#    my $suppress = 0;
    undef my $record;
    my $currentread;
    my $currentcontig;
    my $truncated = 0;

    my $plist = int(log($maxLines || 1)/log(10));
    $plist = $plist - 1 if ($plist > 1);
    $plist = int(exp($plist*log(10))+0.5);
    my $TESTMODE = $self->{TESTMODE};
    my $READSCAN = $self->{READSCAN};
    my $WRITEDNA = $self->{WRITEDNA} || 0;

# setup a buffer for rejected reads

    undef my %rblocker;
    $rblocker = \%rblocker if !$rblocker;

    my $type = 0;
    my $isPadded = 1; # set default padded caf file

    while (defined($record = <CAF>)) {
        $line++; 
        chomp $record;
        print STDOUT "Processing line $line$break" if ($list && ($line == 1 || !($line%$plist)));
        next if ($record !~ /\S/);
# print "$record $break";
        if ($maxLines && $line > $maxLines) {
            print STDOUT "Scanning terminated because of line limit $maxLines$break";
            $truncated = 1;
            $line--;
            last;
        }

# test for padded/unpadded keyword

        if ($record =~ /([un])padded/i) {
# test consistence of character
            my $unpadded = $1 || 0;
            if ($isPadded == 1) {
                $isPadded = ($unpadded ? 0 : 2); # on first entry
print "Padded set to $isPadded $break";
            }
            elsif ($isPadded && $unpadded || !$isPadded && !$unpadded) {
                print STDOUT "WARNING: inconsistent padding specification at line $line $break";
            }
            next;
        }

        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# new object detected, close the existing object
            if ($type == 2 || $type == 3 || $type == 4) {
                print "END Contig $object$break" if $list;
                $currentcontig->list() if ($list > 2);
            }
            elsif ($type == 1) {
#$self->{REPAIR}=0; # temporary
                $currentread->onCompletion($self->{TESTMODE},$self->{REPAIR});
                $currentread->list() if ($list > 2);
            }
            $object = $2; # name of new object
            $type = 0; # preset type unknown
        }        


        if (defined($object) && $object =~ /contig/i && $record =~ /assemble/i && abs($type) != 2 && !$READSCAN) {
# thisblock handles a special case where 'Is_contig' is defined after 'assembled' (? or abs(type) < 2 ?)
            $type = 2 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
            $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
            $type = 0 if  ($cnfilter && $exactmatch && $object ne $cnfilter); 
            if ($type) {
                print "NEW contig $object opened (triggered by line $line: $record)$break" if $list;
                $currentcontig = $self->new($object);
            }
            else {
                $type = -2;
                print "Contig $object SKIPPED$break" if ($list > 1);
            }
        }

        if ($record =~ /Is_contig/ && $type == 0 && !$READSCAN) {
# standard contig initiation
            $type = 2 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
            $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
            $type = 0 if ($exactmatch && $object ne $cnfilter); 
            if ($type > 0) {
                print "NEW contig $object opened (triggered by line $line: $record)$break" if $list;
                $currentcontig = $self->new($object);
	    }
            else {
                $type = -2;
                print "    contig = $object SKIPPED$break" if ($list > 1);
            }
        } 

        elsif ($record =~ /Is_read/ && $READSCAN) {
# test presence of required read in database
            print "testing read $object$break" if ($list > 1);
            my $dblookup = 1; $dblookup = 0 if $self->{preload};
            $ReadMapper->inDataBase($object,$dblookup,1,0,1000);
        }

        elsif ($record =~ /Is_read/) {
    # standard read initiation
            $type = 1;
            $type = 0 if ($rblocker && defined($rblocker->{$object})); # ignore reads already mapped
            if ($type) {
                print "NEW  read  $object opened (triggered by line $line: $record)$break" if ($list > 1);
                $currentread = $ReadMapper->new($object);
            }           
        }

        elsif ($record =~ /DNA/ && !$READSCAN && $WRITEDNA) {
# only act on DNA consensus sequence
            if ($record =~ /\bcontig\d+\b(.*)$/i) {
# register possible extra information
                my $extra = $1 || 0;
# contig initialisation
                $type = 3 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
                $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
                $type = 0 if ($exactmatch && $object ne $cnfilter); 
                if ($type) {
                    print "Contig $object opened for DNA (triggered by line $line: $record)$break" if $list;
                    $currentcontig = $self->new($object);
                    $length = $extra; # possibly length of contig here
	        }
                else {
                    print "    contig = $object SKIPPED$break" if ($list > 1);
                }
            }
            else {
                $type = -3; # will cause DNA for reads to be ignored
            }
        }

        elsif ($record =~ /BaseQuality/ && !$READSCAN && $WRITEDNA) {
# only act on consensus quality sequence
            if ($record =~ /\bcontig\d+\b(.*)$/i) {
                $type = 4 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
                $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
                $type = 0 if ($exactmatch && $object ne $cnfilter); 
                if ($type) {
                    print "Contig $object opened (triggered by line $line: $record)$break" if $list;
                    $currentcontig = $self->new($object);
	        }
                else {
                    print "Contig $object SKIPPED$break" if ($list > 1);
                }
            }
            else {
                $type = -3; # will cause Quality for reads to be ignored
            }
        }

        elsif ($type == 1) {
# processing a read, test for Alignments Quality specification and EDITs
	    if ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*replaced\s+(\w+)\s+by\s+(\w+)\s+at\s+(\d+)/) {
print "error in: $record |$1|$2|$3|$4|$5|$break" if ($1 != $2 && $errlist); # || $2 != $5); 
		$currentread->edit ($5,$3.$4);
	    }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
print "error in: $record$break |$1|$2|$3|$4|" if ($1 != $2 && $errlist); 
		$currentread->edit ($4,$3); # delete signalled by uc ATCG    
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
print "error in: $record$break |$1|$2|$3|$4|" if ($1 != $2 && $errlist); 
		$currentread->edit ($4,$3); # insert signalled by lc atcg    
            }
            elsif ($record =~ /Align\w+\s+((\d+)\s+(\d+)\s+(\d+)\s+(\d+))\s*$/) {
                my @positions = split /\s+/,$1;
                $currentread->addAlignToCaf(\@positions); # for both padded and unpadded files
            }
            elsif ($record =~ /clipping\sQUAL\s+(\d+)\s+(\d+)/i) {
                $currentread->quality ($1,$2,0);
            }
            elsif ($record =~ /clipping\sphrap\s+(\d+)\s+(\d+)/i) {
                $currentread->quality ($1,$2,1);
            }
            elsif ($record =~ /Ligation_no\s+(\w+)/i) {
                $currentread->setAttribute('ligation',$1,$TESTMODE);
            }   
            elsif ($record =~ /Insert_size\s+(\d+)\s+(\d+)/i) {
                $currentread->setAttribute('silow' ,$1,$TESTMODE);
                $currentread->setAttribute('sihigh',$2,$TESTMODE);
            }   
#            elsif ($record =~ /Sequenci\w+\s+\"(\w+)\"/i) {
#                $currentread->setAttribute('svector',$1,$TESTMODE);
#            }   
            elsif ($record =~ /Seq_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"(\w+)\"/i) {
                $currentread->setAttribute('svector',$4,$TESTMODE);
                $currentread->quality ($2,$3,2);
            }   
            elsif ($record =~ /Clone_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"(\w+)\"/i) {
                $currentread->setAttribute('cvector',$4,$TESTMODE);
                $currentread->quality ($2,$3,2);
            }   
            elsif ($record =~ /^Clone\s+(\w+)/) {
                $currentread->setAttribute('clone',$1,$TESTMODE);
            }   
            elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
                my $name = $1; my $trps = $2; my $trpf = $3; 
                my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
	        print STDOUT "READ tag: $name $trps $trpf $info $break" if ($taglist == ($taglist&1));
                $currentread->addTag($name,$trps,$trpf,$info);
            }
            elsif ($record =~ /Tag/ && $record !~ /$ITAGS/) {
                print STDOUT "READ tag not recognized: $record$break" if ($taglist || $list);
            }
            else {
                print STDOUT "not recognized: $record$break" if ($list > 1);
            }
        }

        elsif ($type == 2) {
# processing a contig, get constituent reads and mapping
            if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
# add the "assembled from" data: padded allows only one record per read, unpadded multiple records
# has to be done via a method on this module in order to access the internal counts
                $currentcontig->assembledFrom($1,$2);
            }
            elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
                my $name = $1; my $trps = $2; my $trpf = $3; 
                my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
# print STDOUT "CONTIG tag: $record $break $name $trps $trpf $info $break" if ($taglist == ($taglist&2));
                $currentcontig->addTag($name,$trps,$trpf,$info);
            }
            elsif ($record =~ /Tag/) {
                print STDOUT "CONTIG tag not recognized: $record$break" if ($taglist || $list);
            }
            else {
                print "$line ignored: $record$break" if $list;
            }
        }

        elsif ($type == -2) {
# processing a contig
            if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
                $rblocker->{$1}++; # add read in this contig to the read blocker list
#                print "read $1 marked as blocked $break" if (!((keys %$rblocker)%100));
            }
        }

        elsif ($type == 3) {
# add DNA consensus sequence
#print "DNA added: $record (length $length)$break";
#            $currentcontig->addDNA($record, $length);
#            $currentcontig->addDNA($record, 1);
        }

        elsif ($type == 4) {
# add consensus base quality 
#            $currentcontig->addDNA($record, 2);
        }

        elsif ($type > 0) {
	    print "$line ignored: $record (t=$type)$break" if ($record !~ /sequence/i);
        }
    }
    close (CAF);
    $ReadMapper->flush if $READSCAN; # flush PENDING table
    print STDOUT "$break$line Lines processed on file $filename $break" if $list;
    print STDOUT "Scanning the file was truncated $break" if ($list && $truncated);
    my $nr = keys %{$ReadMapper->lookup(0)}; 
    my $nc = keys %ContigBuilder;
    print STDOUT "$nc ContigBuilder(s), $nr ReadMapper(s) still active $break";

    &timer('caf parser',1) if $TIMER;

    return $truncated;
}

#############################################################################

sub promote {
# call this method after a CAF file has been processed completely
    my $self     = shift;
    my $assembly = shift;

    $assembly = $self->{ASSEMBLY} if !$assembly;
    return "promote ABORTED: undefined assembly in ContigBuilder::promote !$break" if !$assembly;

# retire reads occuring in generation 1 but not in 0

print "retire readmaps in generation 1 but not in 0 $break";
    $ReadMapper->retire($assembly);

# update the generation counter and cleanup the older generations

print "UPDATE and cleanup of generations $break";
    if (my $report = $self->ageByOne($assembly)) {
        return "promote on assembly $assembly FAILED: $report $break";
    }

# ageByOne successful: remove readmaps marked with 'M' generation>1 and this assembly

    $ReadMapper->reaper($assembly);

# HERE: update the data for the assembly status $self->assemblyUpdate($assembly,1);

# update counters and length for the current assembly at generation 1

    $self->updateAssembly($assembly, 1);

    return;
}

##################################################################################

sub ageByOne {
# increase all generation counters by one (after G0 is complete and G1 retired)
    my $self     = shift;
    my $assembly = shift || 0;

# only apply ageing if generation 0 exists

# this is a crucial step which MUST complete correctly; if not, any subsequent
# operation on the READS2CONTIG table will irretrievably corrupt the database.
# Therefore we first test the current status of the assembly and abort on error
# (block any action on READS2CONTIG).
# Subsequently we pre-set an error status on ASSEMBLY, and reset to 'completed'
# only if we are absolute sure that the process has terminated correctly.

# NOTE: the 'blocked' column on READS2CONTIG and operations upon it, could be
# replaced by a transaction protocol. However, speed is a consideration for
# actions on READS2CONTIG, and this way the overal process of dumping and ageing
# is faster.

    my $comment;

    my $where = "generation=0 AND assembly=$assembly";
    if ($assembly > 0 && $RRTOCC->probe('contig_id',undef,$where)) {

# OKAY, there is a 0 generation to be processed, now test the current assembly status

        my $astatus = $ASSEMBLY->associate('status',$assembly,'assembly');
        if ($astatus eq 'error' || $astatus eq 'complete') {
            return "Invalid assembly status: $astatus";
        }
# test if any blocked entries exist as leftover of previous operations (there shouldn't)
        elsif ($RRTOCC->probe('contig_id',undef,"assembly=$assembly and blocked='1'")) {
            return "Blocked entries detected in assembly $assembly";
        }

# OKAY, assembly status passed, preset the error flag 

        $ASSEMBLY->update('status','error','assembly',$assembly);
# we increase generation and set the blocked item
        my $query = "UPDATE <self> set generation=generation+1 WHERE assembly=$assembly"; # blocked taken out
#$query .= " limit 10000"; # test (partial) failure
        $RRTOCC->query($query,{traceQuery=>0,timeStamp=>1}); # time stamp & no trace
#        $RRTOCC->increment('generation','assembly',$assembly,1); # with allow query trace

# now test if any unblocked entries or generation 0 entries remain; if so, something has gone wrong

        $where = "assembly = $assembly and (generation = 0 or blocked = '0')";
        if ($RRTOCC->probe('contig_id',undef,$where)) {
            $comment = "Last generation update attempt FAILED (partially)";
            $ASSEMBLY->update('comment',$comment,'assembly',$assembly);
        }
	else {
# the ageing was successful: remove the blocking flag and reset assembly status
            $RRTOCC->update('blocked','0','assembly',$assembly); # remove the flag (replace by script afterwards)
#?           $CCTOCC->update('generation','generation+1');
            $ASSEMBLY->update('status','complete','assembly',$assembly);
            my $completed = "Last generation update successfully completed";
            $ASSEMBLY->update('comment',$completed,'assembly',$assembly);
        }
    }
    else {
        $comment = "ContigBuilder::ageByOne FAILED: there is no generation 0";
    }

    return $comment; # undef for success, else error status
}

#############################################################################

sub unbuild {
# remove generation 0 for given assembly from the database
    my $self     = shift;
    my $assembly = shift;

# only apply if generation 0 exists and assembly status != error

    my $comment;

    my $where = "generation=0 AND assembly=$assembly";
    if ($assembly > 0 && $RRTOCC->probe('contig_id',undef,$where)) {

# OKAY, there is a 0 generation to be processed, now test the current assembly status

        my $astatus = $ASSEMBLY->associate('status',$assembly,'assembly');
        if ($astatus eq 'error' || $astatus eq 'completed') {
            return "Invalid assembly status: $astatus";
        }
# test if any blocked entries exist as leftover of previous operations (there shouldn't)
        elsif ($RRTOCC->probe('contig_id',undef,"assembly=$assembly and blocked='1'")) {
            return "Blocked entries detected in assembly $assembly";
        }

# okay, now remove (this is not the fastest implementation!)

#        my $DBVERSION = $CONTIGS->dbVersion;

        my $where = "assembly = $assembly and generation = 0";
        my %qoptions = (returnScalar => 0, traceQuery => 0, orderBy => 'contig_id');
        my $contigs = $RRTOCC->associate('distinct contig_id','where',$where,\%qoptions);

# should be blocked

 return "Test abort";

        $RRTOCC->delete('where',$where);

        my $block = 500;
        while (@$contigs) {
            $block = @$contigs if ($block > @$contigs);
print "processing next block $block $break";
            undef my @block;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @block, (shift @$contigs);
            }
            $where = "contig_id in (".join(',',@block).")";
#print "query $where $break";
            $CCTOSS->delete('where',$where);   # to scaffold
            $TTTOCCS->delete('where',$where);  # tags
# missing here GENE2CONTIG & CLONES2CONTIG
            $CONTIGS->delete('where',$where);  # contigs
	    $where =~ s/contig_id/newcontig/;
            $CCTOCC->delete('where',$where);   # contig to contig
            $where =~ s/newcontig/contig_uid/;
            $SEQUENCE->delete('where',$where); # consensus
	}

# restore the status of the assembly for generation 1

        $self->updateAssembly($assembly,1);

    }
    else {
        $comment = "ContigBuilder::unbuild FAILED: there is no generation 0";
    }

    return $comment;
}

#############################################################################

sub updateAssembly {
# update counters and length for the current assembly
    my $self       = shift;
    my $assembly   = shift || 1;
    my $generation = shift || 0;
    my $list       = shift;

# test if the generation provided is legal

    my $accept = -1;

    if ($ASSEMBLY->associate('status',$assembly,'assembly') eq 'error') {
        print "Error status on assembly $assembly $break" if $list;
        return 0;
    }
    elsif ($RRTOCC->probe('contig_id',undef,"assembly=$assembly and blocked='1'")) {
        print "Blocked status on assembly $assembly $break" if $list;
        return 0;
    }
    elsif ($RRTOCC->probe('contig_id',undef,"generation=0 AND assembly=$assembly")) {
        $accept = 0;
    }
    elsif ($RRTOCC->probe('contig_id',undef,"generation=1 AND assembly=$assembly")) {
        $accept = 1;
    }

    print "update assembly $assembly cleared for generation $accept\n" if $list;

    return 0 if ($accept < 0 || $accept != $generation);

    my $DBVERSION = $CONTIGS->dbVersion;

# the next will work for version 4.1, using sub query

    if ($DBVERSION =~ /^4\.1\./) {
print "$DBVERSION getting length and L2000 ... " if $list;
        my $query = "select sum(length) as sum from CONTIGS where contig_id in ";
        $query .= "(select distinct contig_id from READS2CONTIG where ";
        $query   .= "assembly = $assembly and generation = 1)";
        my $length = $CONTIGS->query($query,{traceQuery=>0});
        $ASSEMBLY->update('length',$length->[0]->{sum},'assembly',$assembly);
print "total = $length & " if $list;

        $query =~ s/where/where length>=2000 and/; # only the irst one
        $length = $CONTIGS->query($query,{traceQuery=>0});
        $ASSEMBLY->update('l2000',$length->[0]->{sum},'assembly',$assembly);
print "l2000 = $length & " if $list;
    }

# for MySQL versions below 4.1 fall back on indirect method 

    else {
        print "VERSION $DBVERSION ${break}getting length and L2000 ... " if $list;
        my $where = "assembly = $assembly and generation = $generation";
        $where .= " and label>=10 and deprecated in ('N','M')";
        my %qoptions = (returnScalar => 0, traceQuery => 0, orderBy => 'contig_id');
        my $contigs = $RRTOCC->associate('distinct contig_id','where',$where,\%qoptions);
        my $query = "select sum(length) as sum from <self> where contig_id in (".join(',',@$contigs).")";
        my $length = $CONTIGS->query($query,{traceQuery=>0});
        $ASSEMBLY->update('length',$length->[0]->{sum},'assembly',$assembly);
print "total $length->[0]->{sum}   $break" if $list;
        $query =~ s/where/where length>=2000 and/; # only once
        $length = $CONTIGS->query($query,{traceQuery=>0});
print "l2000 query: $CONTIGS->{lastQuery} \n" if $list;
        $ASSEMBLY->update('l2000',$length->[0]->{sum},'assembly',$assembly);
print "l2000 = $length->[0]->{sum}  $break" if $list;
    }

# get the total counts for this assembly

    print "Update counters for assembly $assembly ... " if $list;
    my $where = "assembly = $assembly and label>=10 and deprecated in ('N','M')";
    print "all contigs in assembly $assembly ... $break" if $list;
    my $ncontig = $RRTOCC->count($where,'distinct contig_id');
    $ASSEMBLY->update('allcontigs',$ncontig,'assembly',$assembly);
    print "all reads in assembly $assembly ... $break" if $list;
    my $nreads  = $RRTOCC->count($where,'distinct read_id');
    $ASSEMBLY->update('reads',$nreads,'assembly',$assembly);

# contig count and read count for the assembly of generation

    $where .= " and generation = $generation";
    print "contigs in assembly $assembly and generation $generation$break" if $list;
    $ncontig = $RRTOCC->count($where,'distinct contig_id');
    $ASSEMBLY->update('contigs',$ncontig,'assembly',$assembly);
    print "assembled reads in assembly $assembly and generation $generation$break" if $list;
    $nreads  = $RRTOCC->count($where,'distinct read_id');
    $ASSEMBLY->update('assembled',$nreads,'assembly',$assembly);

# finally set the loading status

    $ASSEMBLY->update('status', 'loading','assembly',$assembly) if ($generation == 0);
    $ASSEMBLY->update('status','complete','assembly',$assembly) if ($generation == 1);

    return 1;
}

#############################################################################

sub setEnvironment {

# return the line break appropriate for the environment

    $ENV{REQUEST_METHOD} ? $CGI = 1 : $CGI = 0;

    $CGI ? $break = "<br>" : $break = "\n";
}


#############################################################################

sub fonts {

# return a hash with font specifications

    my %font = (b=>'blue', o=>'orange', g=>'lightgreen', 'y'=>'yellow', e=>'</FONT>');

    foreach my $colour (keys %font) {
        if ($ENV{REQUEST_METHOD}) {
            $font{$colour} = "<FONT COLOR=$font{$colour}>" if ($colour ne 'e');
       }
        else {
            $font{$colour} = " ";
        }
    }

    return \%font;
}

#############################################################################

sub timer {
# ad hoc local timer function
    my $name = shift;
    my $mark = shift;

#    use Devel::MyTimer;

#    $MyTimer = new MyTimer if !$MyTimer;

    $MyTimer->($name,$mark) if $MyTimer;
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        updated =>    "24 Sep 2003",
        date    =>    "05 Mar 2001",
    };
}

#############################################################################

1;
