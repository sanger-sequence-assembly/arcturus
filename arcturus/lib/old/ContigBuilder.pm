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

my %ContigBuilder;
my %forward; # ?

my $ReadMapper; # handle to ReadMapper module
my $Compress;   # handle to Compress   module

my $CONTIGS;    # database table handle to CONTIGS
my $CCSTOCC;    # database table handle to CONTIGS2CONTIG
my $CCTOSS;     # database table handle to CONTIGS2SCAFFOLD
my $READS;      # database table handle to READS 
my $RRTOCC;     # database table handle to READS2CONTIG 
my $GAP4TAGS;   # database table handle to GAP4TAGS
# my $READTAGS;   # database table handle to READTAGS table
my $TTTOCCS;    # database table handle to TAGS2CONTIG
my $ASSEMBLY;   # database table handle to ASSEMBLY
my $SEQUENCE;   # database table handle to CONSENSUS

my $break;

#############################################################################
# constructor init: initialise the global (class) variables
#############################################################################

sub init {
# initialise module by setting class variables
    my $prototype = shift;
    my $tblhandle = shift; # handle to any table in the database

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $break = &break;

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

    $CONTIGS    = $tblhandle->spawn('CONTIGS'         ,'<self>');
    $CCSTOCC    = $tblhandle->spawn('CONTIGS2CONTIG'  ,'<self>');
    $CCTOSS     = $tblhandle->spawn('CONTIGS2SCAFFOLD','<self>');
    $READS      = $tblhandle->spawn('READS'           ,'<self>');
    $RRTOCC     = $tblhandle->spawn('READS2CONTIG'    ,'<self>');
    $GAP4TAGS   = $tblhandle->spawn('GAP4TAGS'        ,'<self>');
    $TTTOCCS    = $tblhandle->spawn('TAGS2CONTIG'     ,'<self>');
    $ASSEMBLY   = $tblhandle->spawn('ASSEMBLY'        ,'<self>');
    $SEQUENCE   = $tblhandle->spawn('CONSENSUS'       ,'<self>');

# get the ReadMapper handle (class variable)

    $ReadMapper = ReadMapper->init($tblhandle);

    $ReadMapper->preload('1100');  # build table handle caches (READS and PENDING)

    $self->{minOfReads}  = 1; # accept contigs having at least this number of reads 
    $self->{ignoreEmpty} = 1; # default ignore empty reads; else treat as error status 
    $self->{TESTMODE}    = 0; # test mode for caf file parser
    $self->{REPAIR}      = 0; # test/repair mode for read attributes

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

    $self->{cnames}  = []; # array for name of this contig (and parents)
    $self->{readmap} = {}; # hash for read names and mapping data
    $self->{cntgmap} = {}; # hash for contig id's and mapping data
    $self->{DNA}     = ''; # consensus sequence 
    $self->{length}  =  0; # consensus sequence length (from caf)
    $self->{status}  = {}; # error status report
    $self->{counts}  = []; # counters
    $self->{tags}    = []; # array of tag hashes 

# store the name of this contig as first element in the instance array variable
 
    my $cnames   = $self->{cnames};
    $cnames->[0] = $contigname; # unique full name
    $cnames->[1] = $contigname; # (not unique) alias name
    my $counts   = $self->{counts};
    $counts->[0] = 0; # nr of reads 
    $counts->[1] = 0; # length of the contig 
    $counts->[2] = 0; # total mapped read length
    $counts->[3] = 0; # nr of contigs
    $counts->[4] = 0; # newly added read 
    my $status   = $self->{status};
    $status->{warnings} = 0;
    $status->{inerrors} = 0; # reading errors
    $status->{errors}   = 0; # dumping errors

# if new instance is spawned of an existing instance, inherit some variables

    if ($class eq ref($prototype)) {
        $self->{minOfReads}  = $prototype->{minOfReads}  || 1; 
        $self->{ignoreEmpty} = $prototype->{ignoreEmpty} || 1;     
        $self->{TESTMODE}    = $prototype->{TESTMODE}    || 0;
        $self->{REPAIR}      = $prototype->{REPAIR}      || 0;
print STDOUT "new ContigBuilder inherits from prototype $prototype  (class $class)$break";
print STDOUT "$self->{minOfReads},$self->{ignoreEmpty},$self->{TESTMODE},$self->{REPAIR} $break";
    }
    else {  
# use defaults
print STDOUT "new ContigBuilder (from scratch) $class $prototype $break";
        $self->{minOfReads}  = 1; # accept contigs having at least this number of reads 
        $self->{ignoreEmpty} = 1; # default ignore empty reads; else treat as error status 
        $self->{TESTMODE}    = 0; # test mode for caf file parser
        $self->{REPAIR}      = 0; # test/repair mode for read attributes
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

    undef %forward;

    my $query = "select distinct oldcontig,oranges,orangef from ";
    $query .= "CONTIGS2CONTIG,READS2CONTIG where CONTIGS2CONTIG.oldcontig ";
    $query .= "= READS2CONTIG.contig_id and READS2CONTIG.generation=1";

    my $hashes = $CCSTOCC->query($query,0,0);
    if (ref($hashes) eq 'ARRAY') {
        foreach my $hash (@$hashes) {
            my $contig = $hash->{oldcontig};
#            undef my @ranges;
#            $forward{$contig} = \@ranges if !$forward{$contig};
            $forward{$contig} = [] if (ref($forward{$contig}) ne 'ARRAY');
            my $ranges = $forward{$contig};
            push @$ranges, $hash->{oranges};
            push @$ranges, $hash->{orangef};
        }
    }
}

#############################################################################

sub setTestModes {
# (re)define class variables;
    my $self   = shift;
    my $test   = shift || 0; # test option for ContigBuilder
    my $repair = shift || 0; # repair mode for Reads

    $self->{TESTMODE} = $test;

    $self->{REPAIR}   = $repair;
}

#############################################################################

sub addRead {
# add a new read to the contig list
    my $self = shift;
    my $read = shift; # read name
    my $map  = shift; # mapping info as string of 4 integers

    my $readmap = $self->{readmap};
    my $counts  = $self->{counts};
    my $status  = $self->{status};

    $map =~ s/^\s+//; # remove leading blanks 
    my @fields = split /\s+|\:/,$map if ($map);
    my $entry = ++$counts->[0]; # count number of reads
    if (defined($read) && defined($map) && @fields == 4) {
        @{$readmap->{$read}} = @fields; 
    } 
    else {
        $readmap->{$read} = 0;
        $status->{inerrors}++;
        $status->{diagnosis} .= "! Invalid or missing data for read $entry:";
        $status->{diagnosis} .= " \"$read\" \"$map\"$break";
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
# enter the DNA consensus sequence
    my $self = shift;
    my $dna  = shift;
    my $lgt  = shift;

    $dna =~ s/^\s*|\s*$//; # chop leading and trailing blanks

    $self->{DNA} .= $dna;

    $self->{length} = $lgt if $lgt;
}

#############################################################################

sub dumpDNA {
# enter the DNA consensus sequence
    my $self = shift;
    my $c_id = shift;
    my $size = shift;

    return 0 if (!$self->{DNA} || !length($self->{DNA}));

# there are three sizes which should all be the same
# 1) the size of the DNA string
# 2) size specified in caf file (may be missing)
# 3) size from the readmaps ($size) 

    my $length = length($self->{DNA});
    $self->{length} = $length if !$self->{length}; # to have it defined

    if ($self->{length} != $length || $size != $length) {
        print "Warning: consensus sequence mismatch ($length $self->{length} $size)$break";
    }

# massage the data (uppercase, anything not ACTG replace by -)

    $self->{DNA} =~ tr/a-z/A-Z/;
    $self->{DNA} =~ s/[^ACGT]/-/g;

# compress the string

    my $scompress = 2; # Huffman

    my ($count, $sequence) = $Compress->sequenceEncoder($self->{DNA},$scompress);

# enter 

    my @columns = ('contig_id','sequence','scompress','length');
    my @cvalues = ($c_id      ,$sequence ,$scompress ,$length );
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

# get the assembly and user name (input values override defaults)

    $userid      = $self->{USERID}   if !$userid;
    $assembly    = $self->{ASSEMBLY} if !$assembly;

    my $fonts = &fonts; 

# we keep track of error conditions with the variable $complete

    my $cnames   = $self->{cnames};
    my $readmap  = $self->{readmap}; # hash of the maps read e.g. from caf file 
    my $cntgmap  = $self->{cntgmap};
    my $status   = $self->{status};
    my $counts   = $self->{counts};

    undef my $report;
    my $complete = 1;

    print "${break}Attempting to dump contig $cnames->[0] ....$break";

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

    undef my %readmapper; # hash for readmapper objects for reads in this contig
    undef my $nrOfReads;

    my $missed = 0;
    my $tested = 0;
    if ($complete) {
        foreach my $readname (keys (%$readmap)) {
            print "Testing read $readname (nr $tested)$break" if (!((++$tested)%50));
            my $readobject = $ReadMapper->lookup($readname);
            if (defined($readobject)) {
# add pointer to table
                $readmapper{$readname} = $readobject;
# now test if the read is in the database using ReadMapper
                if (my $dbrref = $readobject->isInDataBase(0,1,$assembly)) {
                    $report .= "Read $readname found in ARCTURUS database$break";
                }
                elsif (!$forced) {
                    $report .= "Read $readname not in ARCTURUS database$break";
                    $missed++;
                }
#                my ($dbrref, $dbpref) = $readobject->inDataBase($readname,1);
#                if (!$dbrref && $dbpref && !$forced) {
#                    $missed++;
#                    $report .= "Read $readname added to PENDING$break";
#                }
#                elsif (!$dbrref && !$dbpref && !$forced) {
#                    $missed++;
#                    $report .= "Read $readname could not be added to PENDING$break";
#                }
                else {
                    $status->{warnings}++;
                    $status->{diagnosis} .= "Read $readname not in ARCTURUS database: ";
                    $status->{diagnosis} .= "FORCED to ignore its absence $break";
                    delete $readmap->{$readname};
                    delete $readmapper{$readname};
                    $readobject->delete();
                    $counts->[0] -= 1;
                }
	    } 
            else {
# no ReadMapper, but still test if read in database; will add read to PENDING if missing
                $report .= "ReadMapper $readname missing $break";
                $ReadMapper->inDataBase($readname,0,1,$assembly);
                $missed++;
            }
        }
# test number of ReadMapper instances found or missed
        my $ntotal = keys %$readmap;
        $nrOfReads = keys %readmapper; # get number of ReadMappers found
        $complete = 0 if (!$nrOfReads || $missed);
        $complete = 0 if (($nrOfReads+$missed) != $ntotal);
        $complete = 0 if ($ntotal != $counts->[0]);
        $report .= "$nrOfReads ReadMappers defined, $missed missed or incomplete out ";
        $report .= "of $ntotal ($counts->[0]) for contig $cnames->[0]$break";
# complete 0 forces skip to exit
    }
    print "number of reads: $nrOfReads complete $complete $break";

#############################################################################
# (III) third test: are the mappings defined, complete and do they make sense
#############################################################################

my $LIST=0;

    $tested = 0;
    my $cover = 0;
    if ($complete) {
        my $nreads = 0;
        $counts->[2] = 0; # for total read length
        undef my $cmin; undef my $cmax;
        undef my $minread; undef my $maxread;
        undef my $minspan; undef my $maxspan;
        undef my @names; # of first and last reads
        foreach my $readname (keys (%$readmap)) {
# get the mapping of this read to the contig and test the range
#            print "Testing readmapping $readname (nr $tested)$break" if (!((++$tested)%50));
            if (@{$readmap->{$readname}} == 4) {
                my $pcstart = $readmap->{$readname}->[0];
                my $pcfinal = $readmap->{$readname}->[1];
                my $prstart = $readmap->{$readname}->[2];
                my $prfinal = $readmap->{$readname}->[3];
print "read $readname: $pcstart $pcfinal $prstart  $prfinal $break" if $LIST;
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
print "read $readname: $pcstart $pcfinal $cmin  $cmax $break" if $LIST;
                if ($pcstart == $cmin || $pcfinal == $cmin) {
# this read aligns with start of the contig
print "read: $readname, minread=$minread readspan=$readspan cmin=$cmin$break" if $LIST;
                    if (!defined($minspan) || $readspan < $minspan || $cmin != $lastmin) {
                        $minread = $readname;
                        $minspan = $readspan;
                    }
                    elsif ($readspan == $minspan) {
                        $names[1] = $minread;
                        @names = sort @names; # alphabetically sorted
                        $minread = $names[0]; # the first one
                    }
                }
                if ($pcfinal == $cmax || $pcstart == $cmax) {
# this read aligns with end of the contig
print "read: $readname, maxread=$maxread readspan=$readspan cmax=$cmax$break" if $LIST;
                    if (!defined($maxspan) || $readspan < $maxspan || $cmax != $lastmax) {
                        $maxread = $readname;
                        $maxspan = $readspan;
                    }
                    elsif ($readspan == $maxspan) {
                        $names[1] = $maxread;
                        @names = sort @names; # alphabetically sorted
                        $maxread = $names[1]; # the last one
                    }
                }
                $nreads++;
	    }
            else {
                $status->{diagnosis} .= "! Invalid mapping for read $readname in contig ";
                $status->{diagnosis} .= "cnames->[0]: @{$readmap->{$readname}}$break";
                $status->{errors}++;
                $complete = 0;
            }
	}
# test contig cover
	if ($cmin != 1) {
            $status->{diagnosis} .= "! unusual lower bound $cmin of mapping";
            $status->{diagnosis} .= " range for contig $cnames->[0]$break";
            $status->{warnings}++;
        }
# test current read count against input tally (addRead)
        if ($nreads != $counts->[0]) {
            $status->{diagnosis} .= "! Read count error on contig $cnames->[0]: ";
            $status->{diagnosis} .= "$nreads against $counts->[0]$break";
            $status->{errors}++;
            $complete = 0;
        }
        else {
            $complete = $nreads;
            $counts->[1] = $cmax-$cmin+1; # the length of the contig
        }
# determine full name of this contig
        $cover = $counts->[2]/$counts->[1]; # r/c
# build the number as sqrt(r**2+c**2)*2*cover; produces an <=I12 number
# which is sensitive to a change of only one in either r or c for all
# practical values of cover (1-20); max contig length about 1.2-5 10**8
        my $uniquenumber = sqrt($cover*$cover + 1) * $counts->[2] * 1.75;
        my $uniquestring = sprintf("%012d",$uniquenumber);
# cleanup the readnames
print "minread $minread    maxread $maxread $break" if $LIST;
        my @endreads;
	push @endreads, &readAlias($minread);
	push @endreads, &readAlias($maxread);
       ($minread, $maxread) = sort @endreads;
        $cnames->[1] = $minread.'-'.$uniquestring.'-'.$maxread;
    }

    print "Full Arcturus contigname: $cnames->[1] (complete=$complete)$break";

#############################################################################
# (IV) apply mapping to reads, test them and collect contig links
#############################################################################

$LIST = 1; print "IV $break";

    my $isConnected = 0;  
    my $isIdentical = 0;
    my $nameChange  = 0;
    my $oldContig  = '';
    my $newContigHash = '000000:0:00000000';
    undef my @priorContigHash;

    my $isWeeded = 0;
    while ($complete && !$isWeeded) {

        $isWeeded = 1; # switch to 0 later if not

# reset counters (left from any previous analysis)

        foreach my $cntg (keys (%$cntgmap)) {
            delete $cntgmap->{$cntg};
        }

# build the mappings for each ReadMapper; test connections to earlier contigs

        $tested = 0;
        $counts->[0] = 0;
        my $emptyReads = 0;
        foreach my $read (keys (%$readmap)) {
            print "Building map for read $read (nr $tested)$break" if (!((++$tested)%50));
            my $readobject = $readmapper{$read};
            my $contocon = $readobject->{contocon};

# transfer the read-to-contig alignment to the ReadMapper instance 

            $readobject->alignToContig(\@{$readmap->{$read}});
# test the ReadMapper alignment specification and status for this read
            $readobject->align();
# test previous alignments of this read in the database
            $readobject->mtest();

#$readobject->reporter(2) if $LIST; # test version
#$LIST = 0; $LIST = 1 if (!$tested || !((++$tested)%50));
#print "Testing read $read (nr $tested)  con-to-con @$contocon$break" if $LIST;

# if it's a healthy read (no error status), build history info

            my $previous = $readobject->{dbrefs}->[3]; # the previous contig, if any
#print "previous contig info: $previous $break" if $LIST;

            if ($readobject->status(0) && $contocon->[4] < 0 && $self->{ignoreEmpty}) {
                $report .= "Empty read $read wil be ignored $break";
                $status->{warnings}++;
                delete $readmap->{$read};
                delete $readmapper{$read};
                print "$fonts->{o} Empty read $read wil be ignored $fonts->{e} $break";
                $emptyReads++;
            }

            elsif ($readobject->status(0)) {
	        $report .= "! Error condition reported in ReadMapper $read$break";
                $status->{errors}++;
                $complete = 0;
            }

            else {
# defaults 0 for new readmap or a previous one which is deprecated
                my $shift = 0;
                my $hash = $newContigHash;
# new reads and deprecated reads are counted as new alignments at shift 0 
                if ($previous && $contocon->[4] <= 1) {
# read was previously aligned to contig $previous (and not deprecated)
                    $shift = $contocon->[5];
                    $hash  = sprintf("%06d:%01d:%08d",$previous,$contocon->[4],$shift);
                }

                if (!defined($cntgmap->{$hash})) {
                    my @linkdata = @$contocon;
#print "initial alignment read $readobject->{dbrefs}->[0] to contig $previous range: @linkdata$break" if $LIST;
                    $cntgmap->{$hash} = \@linkdata;
                    $cntgmap->{$hash}->[4] = 0;
                    $cntgmap->{$hash}->[5] = 0;
                }
                my $linkdata = $cntgmap->{$hash};
#print "contig shift data: '@{$contocon}' shift=$shift$break" if ($LIST);
                $linkdata->[0] = $contocon->[0] if ($contocon->[0] < $linkdata->[0]); # previous contig
                $linkdata->[1] = $contocon->[1] if ($contocon->[1] > $linkdata->[1]);
                $linkdata->[2] = $contocon->[2] if ($contocon->[2] < $linkdata->[2]); # this contig
                $linkdata->[3] = $contocon->[3] if ($contocon->[3] > $linkdata->[3]);
                $linkdata->[4]++; # number of reads in this previous/shift/alignment
                if ($contocon->[4] > 1) {
                    $linkdata->[5]++; # number of deprecated (realigned) earlier reads added as new
                    $hash  = sprintf("%06d:%01d:%08d",$previous,$contocon->[4]-2,$shift);
                    $cntgmap->{$hash}->[5]--; # reads deleted from the previous contig
	        }
                $counts->[0]++; # count total number of reads in the current contig
            }
        }

# okay, here we have a complete list of all connecting contigs (and the new one as '00.... 00')

$LIST = 1;

        my @contigLinkHash = sort keys %$cntgmap;
        foreach my $hash (@contigLinkHash) {
#print "linked contig $hash $break" if $LIST;
            push @priorContigHash, $hash if ($hash ne $newContigHash);
        }

        if (@contigLinkHash == 1 && $contigLinkHash[0] eq $newContigHash) {
#** it's a completely new contig (all mappings are new)
            $isIdentical = 0;
            $isConnected = 0;  
        }
        elsif (@contigLinkHash == 1 && $contigLinkHash[0] ne $newContigHash) {
#** one linked previous contig, but no new or deprecated mappings at all
#** the current contig may be identical to the previous one (but not necessarily!)
            my @olinkdata = split ':',$contigLinkHash[0];
#print "olinkdata @olinkdata $break" if $LIST;
            $oldContig = $olinkdata[0];
            $isConnected = 1;
            my $newReads = $cntgmap->{$contigLinkHash[0]}->[4];
# now test for reads appearing in the previous version but not in the new one
	    my $hashrefs = $CONTIGS->associate('nreads,contigname',$oldContig,'contig_id');
	    my $hashref = $hashrefs->[0];
print "hashrefs $hashrefs, hashref $hashref $hashref->{nreads} $hashref->{contigname}  cnames:$cnames->[1] $break" if $LIST;
	    if ($cnames->[1] ne $hashref->{contigname}) {
# the contig hash names differ, test if perhaps the checksums and nr of reads match
                my $oldCheckSum = &checksum($hashref->{contigname});
	        my $newCheckSum = &checksum($cnames->[1]);
	        if ($oldCheckSum == $newCheckSum && $newReads == ($hashref->{nreads}-$emptyReads)) {
                    $isIdentical = 1; # cover, length and nr. of reads are identical 
                    $nameChange  = 1; # only the name not; mark for update
                }
                else {
                    $isIdentical = 0; # e.g. reads deleted compared with previous assembly
                }
            }
            else {
# the contig hash name matches the previous one
                $isIdentical = 1;
                if ($newReads != $hashref->{nreads}) {
                    $status->{warnings}++;
                    $status->{diagnosis} .= "Reads mismatch for contig $cnames->[1] with ";
                    $status->{diagnosis} .= "$newReads reads ($hashref->{nreads}); possibly ";
                    $status->{diagnosis} .= "empty reads";
                }
            }
            $oldContig = $olinkdata[0];
        }
	elsif (@contigLinkHash == 2 && $contigLinkHash[0] eq $newContigHash) {
            $isConnected = 1;
# there are new and/or deprecated mappings 
            my @nlinkdata = split ':',$contigLinkHash[0];
            my @olinkdata = split ':',$contigLinkHash[1];
            my $newContigData = $cntgmap->{$contigLinkHash[0]};
# it's the same contig if all new reads are deprecated and the names match, or 
# if the order & shift of [1] is 0 and the names matche (e.g. continued after previous abort)
            if ($newContigData->[4] == $newContigData->[5] || $olinkdata[1] == 0 && $olinkdata[2] == 0) {
	        my $previous = $CONTIGS->associate('contigname',$olinkdata[0],'contig_id');
                $isIdentical = 1 if ($previous eq $cnames->[1]); # based on hash value
            }
            $oldContig = $olinkdata[0];
        }
	else {
# more than one linking contig (contigLinkHash >= 2); definitively a new contig
            $isConnected = @priorContigHash;
            $isIdentical = 0;
        }

# if it's a new contig with connections, check the intervals on the previous contig(s)
# if (some) intervals overlap, the reads inside the intervals have to be deprecated
# and reallocated as first-appearing reads to this new contig; then redo this step IV

        if ($isConnected && !$isIdentical) {

            foreach my $link (@priorContigHash) {
                my $ors = $cntgmap->{$link}->[0];
                my $orf = $cntgmap->{$link}->[1];
                my ($previous, $order, $shift) = split /\:/,$link;
# go through each alignment on $previous and test for overlap with the current alignment
                if (my $forward = $forward{$previous}) {
                    my @intervals = @$forward;
                    while (@intervals) {
                        my @range;
                        $range[0] = shift @intervals;
                        $range[1] = shift @intervals;
                        @range = sort @range;
# now test the interval $oranges-$orangef against @range 
                        if ($range[0] <= $orf && $range[1] >= $ors) {
# there is overlap somewhere, test 4 cases
                            my $ws = $range[0];
                            my $wf = $range[1];
                            $ws = $ors if ($range[0] < $ors);
                            $wf = $orf if ($range[1] > $orf);
# deprecate the reads which fall inside the window on the previous contig
                            my $deprecated = 0;
                            foreach my $read (keys %$readmap) {
                                my $readobject = $readmapper{$read};
                                my $contocon = $readobject->{contocon};
                                if (($contocon->[0] >= $ws && $contocon->[0] <= $wf)
		         	 || ($contocon->[1] >= $ws && $contocon->[1] <= $wf)) {
                                    $deprecated++ if $readobject->deprecate('because of overlap');
                                }
                            }
                            $isWeeded = 0 if $deprecated;
                        }
                    }
                }
	    }

            if ($isWeeded) {
# add current intervals, but only at last iteration
                foreach my $link (@priorContigHash) {
                    my $ors = $cntgmap->{$link}->[0];
                    my $orf = $cntgmap->{$link}->[1];
                    my ($previous, $order, $shift) = split /\:/,$link;
                    $forward{$previous} = [] if (ref($forward{$previous}) ne 'ARRAY');
                    my $forward = $forward{$previous};
                    push @$forward, $ors;
                    push @$forward, $orf;
                }
	    }
        }

# at this point, we have collected all the contigs referenced and possibly new reads

$LIST = 1;
print "$isConnected connecting contig(s) found,  Identical=$isIdentical weeded=$isWeeded $break" if $LIST;

        foreach my $hash (sort @contigLinkHash) {
            my ($contig,$order,$shift) = split ':', $hash;
            my  $map = $cntgmap->{$hash};
	    printf ("%6d %1d %8d  %8d-%8d %8d-%8d  %6d %5d",$contig,$order,$shift,@$map) if $LIST;
            print "$break";
        }
    }

$LIST = 0;

#############################################################################
# (V) Add the contig to the CONTIGS table (we must have contig_id)
#############################################################################

$LIST = 1;
$LIST = 1; print "V $break";

    my $accepted = 0;
    $accepted = 1 if (!$self->{minOfReads} || $counts->[0] >= $self->{minOfReads}); 

    $counts->[3] = @priorContigHash;
    my $newContigData = $cntgmap->{$newContigHash} || 0;
print "newContigData=$newContigData   cnts priorContigs: @$counts $break" if $LIST;
    if ($newContigData && @$newContigData) {
        $counts->[4] = $newContigData->[4] - $newContigData->[5];
print "newContigData=$newContigData  @$newContigData  cnts: @$counts $break" if $LIST;
    }
    else {
        $counts->[4] = 0;
    }
 
    undef my $contig;
    if ($complete && $accepted) {

print "Processing contig $cnames->[1] ($cnames->[0])$break" if $LIST;

        my (@columns, @cvalues);
        push @columns, 'aliasname'; push @cvalues, $cnames->[0]; 
        push @columns, 'length';    push @cvalues, $counts->[1]; 
        push @columns, 'ncntgs';    push @cvalues, $counts->[3]; 
        push @columns, 'nreads';    push @cvalues, $counts->[0]; 
        push @columns, 'newreads';  push @cvalues, $counts->[4]; 
        push @columns, 'cover' ;    push @cvalues, $cover; 
        push @columns, 'origin';    push @cvalues, 'Arcturus CAF parser';
# add new record using the compound name as contigname
        $CONTIGS->rollback(0); # clear any (previous) rollbacks 
        if (!$CONTIGS->newrow('contigname',$cnames->[1],\@columns,\@cvalues)) {
# if contig already exists get contig number
            if ($CONTIGS->{qerror} =~ /already\sexists/) {
                $contig =  $CONTIGS->associate('contig_id',$cnames->[1],'contigname');
                $status->{warnings}++;
                $status->{diagnosis} .= "contig $cnames->[1] is already present as number $contig$break";
                $CONTIGS->status(1); # clear the error status
print "SKIPPED: $status->{diagnosis} ";
            }
            else {
                $status->{errors}++;
                $status->{diagnosis} .= "Failed to add contig $cnames->[1]: $CONTIGS->{qerror}$break";
                $complete = 0;
print "FAILED: $status->{diagnosis} ";
            }
        }
        else {
# it's a new contig: get its number
            $contig = $CONTIGS->associate('contig_id',$cnames->[1],'contigname');
            $CONTIGS->signature($userid,'contig_id',$contig);
print "Contig $cnames->[1] ($cnames->[0]) added as nr $contig to CONTIGS ($counts->[0] reads)$break";
#  print "$fonts->{b} nreads $nreads $fonts->{e} $break";
        }
    }
    elsif ($complete) {
        print STDOUT "Contig $cnames->[1] with $counts->[0] reads is ignored$break";
    }

# print "$report "; 

# return 0;

#############################################################################
# (VI) dump all readmaps onto the database (and test if done successfully)
#############################################################################

$LIST = 1; print "VI $break";

    if ($complete && $accepted) {
# write the read mappings and edits to database tables for this contig and assembly
        my $dumped = 0;
        foreach my $readname (keys (%readmapper)) {
            my $readobject = $readmapper{$readname};
            print "Processing read $readname (nr $dumped)$break" if (!((++$dumped)%50));
            if ($readobject) {
                $complete = 0 if (!$readobject->dump($contig,$assembly));
            }
            else {
                $complete = 0; # something weirdly wrong
            }
        }
    }

#############################################################################
# (VII) here contig and map dumps are done (and successful if $complete)
#############################################################################
$LIST = 1; print "VII $break";

    undef my @priorContigList;
    foreach my $hash (@priorContigHash) {
        my ($prior,$order,$shift) = split ':',$hash;
        push @priorContigList, $prior;
    }

    if ($complete && $accepted && !$isIdentical) {
# link the new contig to a scaffold and add assembly status 
        $CCTOSS->newrow('contig_id',$contig,'assembly',$assembly); # astatus N by default
# inherit the project from connecting contig(s), if any
        if (@priorContigHash) {
print "prior contigs=@priorContigList $break" if $LIST;
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
            foreach my $priorcontig (@priorContigHash) {           
                $CCTOSS->update('astatus','S','contig_id',$priorcontig);
            }
        }

        $CCSTOCC->rollback(0);
        foreach my $hash (@priorContigHash) {
            my ($priorContig,$order,$shift) = split ':',$hash; 
            my $alignment = $cntgmap->{$hash};
            if ($alignment->[4] >= 0) {
#THERE should be a test for CtoC already loaded

                if (!$CCSTOCC->newrow('oldcontig',$priorContig,'newcontig',$contig)) {


                    $report .= "! Failed to add entry to CONTIGS2CONTIG table$break";
                    $complete = 0;
                    last;
                } 
                else {
            # the new range is always aligned
                    $CCSTOCC->update('nranges',$alignment->[2]); 
                    $CCSTOCC->update('nrangef',$alignment->[3]);
                    if ($order == 0) {
                        $CCSTOCC->update('oranges',$alignment->[0]); 
                        $CCSTOCC->update('orangef',$alignment->[1]); 
                    }
                    else { # reverse alignment
                        $CCSTOCC->update('oranges',$alignment->[1]); 
                        $CCSTOCC->update('orangef',$alignment->[0]);
                    }
                }
            }
            $CCTOSS->update('astatus','S','contig_id',$priorContig);
        }

        if ($complete) {
# if there is a consensus sequence, dump it using this contig_id
            $self->dumpDNA($contig,$counts->[1]) if ($self->{DNA});
# remove the ReadMappers and this contigbuilder to free memory
            foreach my $readname (keys (%readmapper)) {
                my $readobject = $readmapper{$readname};
                $readobject->status(2); # dump warnings
                $readobject->delete();
            }
            undef %readmapper;
            my $result = &status($self,2);
            print STDOUT "Contig $cnames->[1] entered successfully into CONTIGS table ";
            print STDOUT "($counts->[4] new reads; $counts->[3] parent contigs)$break";
            $CONTIGS->rollback(0); # clear rollback stack 
            $CCSTOCC->rollback(0); # clear rollback stack
            &delete($self);
            return 0;
        }
    }

# next block is activated if the current contig is identical to one entered earlier

    elsif ($complete && $accepted && $isIdentical) {
# remove the ReadMappers and this contigbuilder to free memory
        my $dumped = 0;
        foreach my $readname (keys (%readmapper)) {
            my $readobject = $readmapper{$readname};
            print "Removing read $readname (nr $dumped)$break" if (!((++$dumped)%50));
            $readobject->status(2); # dump warnings
            $readobject->delete();
        }
        undef %readmapper;
# undo the addition to CONTIGS, if any
        $CONTIGS->rollback(1);  
        $status->{warnings}++;
        $status->{diagnosis} .= "Contig $cnames->[0] $fonts->{y} not added$fonts->{e}: is identical to contig $oldContig$break";
# if the contig is part of generation 1 or higher, amend its assembly status (from N) to C (current)
        my $generation = $RRTOCC->associate('distinct generation',$oldContig,'contig_id');
        if (ref($generation) eq 'ARRAY') {
            $status->{diagnosis} .= "Multiple generations @$generation for contig ";
            $status->{diagnosis} .= "$cnames->[1] ($contig), NO FURTHER TESTS DONE$break";
        }
        else {
# add the assembly info to the CONTIGS2SCAFFOLD table, if not done before 
            $CCTOSS->newrow('contig_id',$oldContig,'assembly',$assembly); # default N
            $CCTOSS->update('astatus','C','contig_id',$oldContig) if ($generation > 0);
        }
# update the contig name (active after name redefinition)
        my $hashrefs = $CONTIGS->associate('contigname,aliasname',$oldContig,'contig_id');
        if (ref($generation) ne 'ARRAY' && $generation == 0 && $hashrefs->[0]->{aliasname} eq $cnames->[0]) {
           if ($hashrefs->[0]->{contigname} ne $cnames->[1] && $nameChange) {
               $status->{diagnosis} .= "Old contigname $hashrefs->[0]->{contigname} ";
               $status->{diagnosis} .= "is replaced by new $cnames->[1] $break";
               $CONTIGS->update('contigname',$cnames->[1],'contig_id',$oldContig);
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
        $CCSTOCC->delete('newcontig',$contig);
        $RRTOCC->delete('contig_id',$contig);
        $CCTOSS->delete('contig_id',$contig);
    # and list the status of the individual readobjects
        foreach my $readname (keys (%readmapper)) {
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

sub readAlias {
# remove first occurring period '.' and truncate at any further period
    my $readname = shift;

    my @section = split /\./,$readname;

    $readname  = $section[0];
    if (defined($section[1])) {
        while (length($section[1]) > 4) {
            chop $section[1];
        }
        $readname .= $section[1];
    }

# remove other symbols

#    $readname =~ s/\-//g;

    return $readname;
}


sub newreadAlias {
# replace the readname by read_id as long hexadecimal number 
    my $readname = shift;

    my $read_id = $READS->cacheRecall($readname);

    $readname = sprintf "%lx", $read_id;

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

    foreach my $read (sort keys (%$readmap)) {
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
        }
        foreach my $contig (keys %ContigBuilder) {
	    print STDOUT "Not Dumped: $contig$break" if $ContigBuilder{$contig};
        }
    }

# finally flush the remaining (i.e. unallocated) ReadMappers (and tables)

    $ReadMapper->flush;

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

    my $minOfReads = $self->{minOfReads}; print "minOfReads = $minOfReads $break";
    print STDOUT "file to be opened: $filename ..." if $list;
    open (CAF,"$filename") || return 2; # die "cannot open $filename";
    print STDOUT "... DONE $break" if $list;
    print STDOUT "Read a maximum of $maxLines lines $break" if ($list && $maxLines);
    print STDOUT "Contig (or alias) name filter $cnfilter $break" if ($list && $cnfilter);
    print STDOUT "Contigs with fewer than $minOfReads reads are tested ??? $break" if ($list && $minOfReads > 1);

    my $line = 0;
    my $status = 0;

    my $exactmatch = 0;
    $exactmatch = 1 if ($cnfilter =~ s/^exact\s+//i);

    undef my $object;
    undef my $length;
    my $type = 0;
    undef my $record;
    my $currentread;
    my $currentcontig;
    my $truncated = 0;

    my $plist = int(log($maxLines)/log(10));
    $plist = $plist - 1 if ($plist > 1);
    $plist = int(exp($plist*log(10))+0.5);
    my $TESTMODE = $self->{TESTMODE};

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
# $plist = 100 if ($line == 680000);

        if ($record =~ /^\s*(Sequence|DNA)\s*\:?\s*(\S+)/) {
# new object detected, close the existing object
            if ($type == 2 || $type == 3) {
                print "END Contig $object$break" if $list;
                $currentcontig->list() if ($list > 1);
            }
            elsif ($type == 1) {
#$self->{REPAIR}=0; # temporary
                $currentread->onCompletion($self->{TESTMODE},$self->{REPAIR});
                $currentread->list() if ($list > 2);
            }
            $object = $2; # name of new object
            $type = 0; # preset type unknown
        }        


        if (defined($object) && $object =~ /contig/i && $record =~ /assemble/i && $type != 2) {
    # thisblock handles a special case where 'Is_contig' is defined after 'assembled'
            $type = 2 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
            $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
            $type = 0 if ($exactmatch && $object ne $cnfilter); 
            if ($type) {
                print "NEW contig $object opened (triggered by line $line: $record)$break" if $list;
                $currentcontig = $self->new($object);
            }
            else {
                print "    contig = $object SKIPPED$break" if ($list > 1);
            }
        }

        if ($record =~ /Is_contig/ && $type == 0) {
    # standard contig initiation
            $type = 2 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
            $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
            $type = 0 if ($exactmatch && $object ne $cnfilter); 
            if ($type) {
                print "NEW contig $object opened (triggered by line $line: $record)$break" if $list;
                $currentcontig = $self->new($object);
	    }
            else {
                print "    contig = $object SKIPPED$break" if ($list > 1);
            }
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
        elsif ($record =~ /DNA/) {
# only act on DNA consensus sequence
            if ($record =~ /\bcontig\d+\b(.*)$/i) {
# contig initialisation
                $type = 3 if (!defined($cnfilter) || $cnfilter !~ /\S/ || $object =~ /$cnfilter/);
                $type = 0 if (!$cnfilter && $cblocker && defined($cblocker->{$object})); # skip processed contigs
                $type = 0 if ($exactmatch && $object ne $cnfilter); 
                if ($type) {
                    print "Contig $object opened for DNA (triggered by line $line: $record)$break" if $list;
                    $currentcontig = $self->new($object);
                    $length = $1; # print "length=$length $break" if $length;
	        }
                else {
                    print "    contig = $object SKIPPED$break" if ($list > 1);
                }
            }
            else {
                $type = 4; # will cause DNA for reads to be ignored
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
                $currentread->alignToCaf (\@positions);
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
                $currentcontig->addRead($1,$2);
            }
            elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
                my $name = $1; my $trps = $2; my $trpf = $3; 
                my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
#		print STDOUT "CONTIG tag: $record $break $name $trps $trpf $info $break" if ($taglist == ($taglist&2));
                $currentcontig->addTag($name,$trps,$trpf,$info);
            }
            elsif ($record =~ /Tag/) {
                print STDOUT "CONTIG tag not recognized: $record$break" if ($taglist || $list);
            }
            else {
                print "$line ignored: $record$break" if $list;
            }
        }
        elsif ($type == 3) {
# add DNA consensus sequence 
            $currentcontig->addDNA($record, $length);
        }
        elsif ($type != 4) {
	    print "$line ignored: $record (t=$type)$break" if ($record !~ /sequence/i);
        }
    }
    close (CAF);
    print STDOUT "$break$line Lines processed on file $filename $break" if $list;
    print STDOUT "Scanning the file was truncated $break" if ($list && $truncated);
    my $nr = keys %{$ReadMapper->lookup(0)}; my $nc = keys %ContigBuilder;
    print STDOUT "$nc ContigBuilder(s), $nr ReadMapper(s) still active $break";
    return $truncated;
}

#############################################################################

sub promote {
# call this method after a CAF file has been processed completely
    my $self     = shift;
    my $assembly = shift;

    $assembly    = $self->{ASSEMBLY} if !$assembly;

# update counters length and l2000 for the current assembly
      
    my $query = "select sum(distinct CONTIGS.length) from CONTIGS,READS2CONTIG where ";
    $query   .= "CONTIGS.contig_id=READS2CONTIG.contig_id and READS2CONTIG.generation=0";
    my $length = $CONTIGS->query($query,0,0);
    $ASSEMBLY->update('length',$length,'assembly',$assembly);

# l2000

    $query   .= " and CONTIGS.length>=2000";
    $length = $CONTIGS->query($query);
    $ASSEMBLY->update('l2000',$length,'assembly',$assembly);

# process reads in generation 1 but not in 0

    $ReadMapper->endOfLine();

# now update the generation counter and cleanup the older generations

print "UPDATE and cleanup of mapped generations $break\n";
    $ReadMapper->ageByOne($assembly);
}

#############################################################################

sub break {

# return the line break appropriate for the environment

    my $break = "\n";

    $break = "<br>" if $ENV{REQUEST_METHOD}; # cosmetics

    return $break;
}

#############################################################################

sub fonts {

# return a hash with font specifications

    my %font = (b=>'blue', o=>'orange', g=>'lightgreen', y=>'yellow', e=>'</FONT>');

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

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "08 Mar 2002",
        history =>    "05 Mar 2001",
    };
}

#############################################################################

1;
