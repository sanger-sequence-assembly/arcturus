package ReadsRecall;

#############################################################################
#
# retrieve a READ from the ARCTURUS database
#
#############################################################################

use strict;

use Compress;

#use Devel::MyTimer;

#############################################################################
# Global variables
#############################################################################

my $Compress; # reference to encoding/decoding module
my $MODEL;    # reference to READMODEL database table
my $READS;    # table handle to the READS table
my $RTAGS;    # table handle to the READTAGS table

my %instance; # hash for all ReadsRecall instances 

my %reverse;  # hash for reverse substitutions of DNA

my %library;  # hash for dictionary lookup data

#my $MyTimer;

my $loadQuality; # default do not load quality data

my $USENEWREADLAYOUT;

#############################################################################
# constructor item init; serves only to create a handle the stored READS
# database and the Compress module
#############################################################################

sub init {
# initialize the readobjects constructor
    my $prototype = shift;
    my $tblhandle = shift || &dropDead; # handle of Arcturus database table 

    my $class = ref($prototype) || $prototype;
    my $self  = {};

# test if input table handle is of the READS table

    $READS = $tblhandle->spawn('READS');
    $RTAGS = $tblhandle->spawn('READTAGS');

# set up prepared queries on these table handles

    &prepareQueries;

    $Compress = Compress->new(@_); # build decoding table

    %reverse = ( A => 'T', T => 'A', C => 'G', G => 'C', '-' => '-',
                 a => 't', t => 'a', c => 'g', g => 'c',
                 U => 'A', u => 'a');

#    $MyTimer = new MyTimer;

    bless ($self, $class);
    return $self;
}

#############################################################################

sub dropDead {

    my $text = shift;

    die "$text" if $text; 

    die "module 'ReadsRecall' must be initialized with a READS table handle";
}

#############################################################################
# constructor item new; serves only to create a handle to a stored read
# subsequently ->getRead will load a (new) read
#############################################################################

sub new {
# create a new Read object
    my $prototype = shift;
    my $readitem  = shift;
    my $itsvalue  = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

    $self->{readhash} = {}; # hash table for read data
    $self->{sequence} = []; # array of DNA sequence
    $self->{quality}  = []; # array of quality data
    $self->{range}    = []; # base range of sufficient quality data
    $self->{toContig} = {}; # read-contig mapping
    $self->{contig}   = ''; # reference

    $self->{index}    = []; # array of data index
    $self->{status}   = {}; # error status reporting
    $self->{links}    = {}; # links to items in other data tables

# okay, now select how to find the data and build the read object

    if (!$readitem) {
        return $self; # use e.g. to get access to class methods
    }

    elsif (ref($readitem) eq 'HASH') {
# build the read instance directly from the input hash
# print "1 new read for hash $readitem \n";
        &loadReadData(0,$self,$readitem);        
        $readitem = $self->{readhash}->{read_id} || $self->{readhash}->{readname} || 0;
    }

    elsif (defined($itsvalue)) {
# select read using readitem and itsvalue
        $self->getLabeledRead($readitem, $itsvalue);
        $readitem = $self->{readhash}->{read_id};
    } 

    elsif (defined($readitem)) {
# select read as number or as name
        return $instance{$readitem} if $instance{$readitem}; # already stored
#print "get read $readitem \n";
        if ($readitem =~ /[0-9]+/  && !($readitem =~ /[a-z]/i)) {
            $self->getNumberedRead($readitem);
        }
        else {
            $self->getNamedRead($readitem);
        }
    }

    $readitem = $self->{readhash}->{read_id};
    $instance{$readitem} = $self if $readitem; # keyed on read ID
    $readitem = $self->{readhash}->{readname};
    $instance{$readitem} = $self if $readitem; # keyed on readname
#print "read $readitem added to inventory \n";

    return $self;
}

#############################################################################

sub spawnReads {
# spawn a number of read objects for the given read-IDs
    my $self    = shift;
    my $readids = shift; # reference to array of read_ids or names
    my $items   = shift || 'hashrefs'; # (optional) selected readitems
    my $keyword = shift || 'read_id';

    return 0 if ($keyword ne 'read_id' && $keyword ne 'readname');

    my $status = $self->{status};
    $status->{errors} =  0;
    $status->{report} = '';

    if ($items ne 'hashrefs') {
# there must be a minimum set of read items
        $items .= ',scompress' if ($items =~ /sequence/ && $items !~ /scompress/);
        $items .= ',qcompress' if ($items =~ /quality/  && $items !~ /qcompress/);
        $items .= ',slength'   if ($items !~ /compress/ && $items !~ /slength/);
        $items .= ',read_id'   if ($items !~ /read_id/);
        $items .= ',readname'  if ($items !~ /readname/);
        $items .= ',chemistry' if ($items !~ /chemistry/);
        $items .= ',strand'    if ($items !~ /strand/);
    }

# the next block builds a single ReadsRecall object (if $readids is either a number 
# or a name) using the 'new' method, or builds a series of ReadsRecall objects (if
# $readids is a reference to an array of readnames or readids

# blocked processing of a large number of reads is almost as good as cacheing; for
# smaller numbers or repeated calls to the new method, cacheing will increase speed 

    undef my @reads;
    if (ref($readids) ne 'ARRAY') {
        push @reads,$self->new($readids);
    }
    else {
# first pick up any cached read hashes (cacheing to be done before calling this method) 
        undef my %notfound;
        foreach my $read (@$readids) {
#print "ReadsRecall->spawnReads: finding read $read in cache .. ";
            $read =~ s/^\'|\'$//g if ($keyword eq 'readname'); # remove quoting
            if (my $hash = $READS->cacheRecall($read)) {
                push @reads, $self->new($hash);
#print "found \n";
            }
            else {
                $notfound{$read}++;
#print "NOT found \n";
            }
        }
# pick up any remaining entries from the database
        my @leftover = keys %notfound; 
#print "remaining @leftover reads \n\n";         
        if (@leftover) {
#print "recovering remaining reads \n\n";         
            if (my $hashrefs = $READS->associate($items,\@leftover,$keyword,{returnScalar => 0})) {
                foreach my $hash (@$hashrefs) {
                    push @reads,$self->new($hash);
                    delete $notfound{$hash->{$keyword}}; # remove from list
                    undef $hash;
                }
                undef @$hashrefs;
            }
        }
# test number of read instances not spawned
        if (my $leftover = keys(%notfound)) {
            $status->{errors}++;
            $status->{report} = "$leftover reads NOT spawned!";
            return 0;
        }
    }

    return \@reads;
}

#############################################################################

sub findInstanceOf {
# find the instance of the ReadsRecall class %instances
    my $self = shift;
    my $name = shift;

    if ($name) {
        return $instance{$name} || 0;
    }
    else {
        return \%instance;
    }
}

#############################################################################

sub prepareQueries {
# set-up prepared queries on the READS and TAGS tables 

    $READS->prepareQuery("select * from <self> where readname=?",'nameQuery');
    $READS->prepareQuery("select * from <self> where  read_id=?",'nmbrQuery');

#    $RTAGS->prepareQuery("select * from <self> where read_id=?",'tagsQuery');

    return if !$USENEWREADLAYOUT; 

    my $DNAitems = 'DNA.scompress,DNA.sequence,DNA.qcompres,DNA.quality';
    my $query = "select READS.*,$DNAitems from READS left join DNA using (read_id) ";
    $query .= "where READS.read_id=?"; # to get all items except read_id in DNA
    $READS->prepareQuery($query,'nmbrQuery');

    $query =~ s/read_id=/readname=/;
    $READS->prepareQuery($query,'nameQuery');
}

#############################################################################

sub prepareCaches {

    my $self = shift;
    my $rids = shift; # read ID or array of read IDs
    
    my $readlist = " = $rids" || 0;
    $readlist = " in (" . join(',',@$rids) . ")" if (ref($rids) eq 'ARRAY');

    my $query = "select * from <self> ";
    $query .= "where read_id $readlist" if $readlist;

    $READS->cacheBuild($query,{indexKey=>'read_id', list=>0});
}

#############################################################################

sub getNamedRead {
# ingest a new read, return reference to hash table of Read items
    my $self     = shift;
    my $readname = shift; # the name of the read

    my $status = $self->clear;

    &dropDead("ReadsRecall needs to be initialized with the ->init method") if !$READS;

    my $readhash;

# first try if there is cached data on the READS table interface 

    $readhash = $READS->cacheRecall($readname,{indexname=>'readname'}) if !shift;

    $readhash = $READS->usePreparedQuery('nameQuery',$readname,1) if !$readhash;

#    $readhash = $READS->associate('hashref',$readname,'readname') if !$readhash;

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
        my $number = $readhash->{read_id};
        $self->loadReadTags($number);
    }
    else {
        $status->{report} .= "! Read $readname NOT found in ARCTURUS READS\n";
        $status->{errors} += 2;
    }

    return $self->status;
}

#############################################################################

sub getNumberedRead {
# reads a numbered Read file 
    my $self    = shift;
    my $number  = shift;
    my $nocache = shift;

    my $status = $self->clear;

    &dropDead("ReadsRecall needs to be initialized with the ->init method") if !$READS;

    my $readhash;

#$MyTimer->timer('get numbered read',0);

# first try if there is cached data on the READS table interface (indexed on read_id)

    $readhash = $READS->cacheRecall($number,{indexName=>'read_id',returnHash=>1}) if !$nocache;

# if not, query database using a prepared query (if it exists, else returns undef)

    $readhash = $READS->usePreparedQuery('nmbrQuery',$number,1) if !$readhash;

#    $readhash = $READS->associate('hashref',$number,'read_id')  if !$readhash;

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
        $self->loadReadTags($number);
    }
    else {
        $status->{report} .= "! Read nr. $number does not exist";
        $status->{errors}++;
    }
#$MyTimer->timer('get numbered read',1);

    return $self->status;
}

#############################################################################

sub getLabeledRead {
# reads a Read file for a given value of a given column 
    my $self     = shift;
    my $readitem = shift;
    my $itsvalue = shift;

    my $status = $self->clear;

    &dropDead("ReadsRecall needs to be initialized with the ->init method") if !$READS;

# retrieve the (first encountered) read name for the specified condition 

    my $readhash;
    if ($USENEWREADLAYOUT) {
# first get the read_id, then pull dat out with a query on a join
        my $number = $READS->associate('read_id',$itsvalue,$readitem);
        $readhash  = $READS->usePreparedQuery('nmbrQuery',$number,1);
    }
    else {
        $readhash = $READS->associate('hashref',$itsvalue,$readitem);
    }

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
        my $number = $readhash->{read_id};
        $self->loadReadTags($number);
    } 
    else {
        $status->{report} .= "! No read found for $readitem = $itsvalue";
        $status->{errors}++;
    }

    return $self->status;
}

#############################################################################

sub getUnassembledReads {
# short way using READS2ASSEMBLY; long way with a left join READS, R2CR2
    my $self = shift;
    my $opts = shift || 0; # default "short" & no date selection

    &dropDead("ReadsRecall needs to be initialized with the ->init method") if !$READS;

# decode input options

    my %options = (date => 0, full => 0, item => 'read_id');
    $READS->importOptions(\%options, $opts);
    my $readitem = $options{item};
    
    if ($readitem ne 'read_id' && $readitem ne 'readname') {
        &dropDead("Invalid read item $readitem for ReadsRecall::getUnassembledReads");
    } 

#$MyTimer->timer('getUnassembledReads',0);

    my $R2C = $READS->spawn('READS2CONTIG');
    my $CONTIGS = $READS->spawn('CONTIGS');

    my @output;
    my $output = \@output;

    if (!$options{full}) {

# short option: use info in READS2ASSEMBLY.astatus (assuming it to be complete and consistent)

        my $R2A = $READS->spawn('READS2ASSEMBLY','<self>',0,0); # get table handle
        $READS->autoVivify(0,0.5); # build links (existing tables only)
# find the readnames in READS by searching on astatus in READS2ASSEMBLY
        if (!$options{date}) {
            $output = $READS->associate($readitem,"! '2'",'astatus',{returnScalar => 0});
        }
        else {
# TO BE TESTED !!
            my $where = "date <= '$options{date}' and astatus != 2";
            $output = $READS->associate($readitem,'where',$where,{returnScalar => 0});
        }
        if (!$output) {
            $self->{report} = "! INVALID query in ReadsRecall::getUnassembledReads:\n $READS->{lastQuery}\n";
        }
    }

    else {

# the long way, bypassing READS2ASSEMBLY; first find all reads not in READS2CONTIG with a left join

        my $report = "Find all reads not in READS2CONTIG with left join: ";
        my $ljoin = "select distinct READS.$readitem from READS left join READS2CONTIG ";
        $ljoin  .= "on READS.read_id=READS2CONTIG.read_id ";
        $ljoin  .= "where READS2CONTIG.read_id IS NULL ";
        $ljoin  .= "and READS.date <= '$options{date}' " if $options{date}; # TO BE TESTED !!!
        $ljoin  .= "order by $readitem"; 
print "Find unassembled reads with left join\n";

        undef my @output;
        $output = \@output;
#$MyTimer->timer('Finding reads with left join',0);
        my $hashes = $READS->query($ljoin,0,0);
#$MyTimer->timer('Finding reads with left join',1);
        if (ref($hashes) eq 'ARRAY') {
            foreach my $hash (@$hashes) {
                push @output,$hash->{$readitem};
            }
            undef @$hashes;
        }
        elsif (!$hashes) {
            $report .= "! INVALID query in Saurian->getUnassembledReads: $ljoin\n";
        }
        $report .= scalar(@output)." reads found\n";

# now we check on (deallocated)reads in READS2CONTIG; those do NOT figure in generation<=1, only in >1
# this is done by finding ALL (distinct) reads with generation > 1, and subtract from those the reads
# found in generation <= 1. The ones left in generation > 1 have been deallocated from a previous 
# assembly and are therefore unassembled reads, to be added to @output

        $report .= "Checking for reads deallocated from previous assembly ";

        if ($options{full} == 1) {
# first alternative method: create a temporary table and do a left join
            $report .= "using a temporary table: ";
            my $extra = "create temporary table R2CTEMP select distinct read_id ";
            $extra  .=  "from READS2CONTIG where generation <= 1 and label >= 10";
            if ($READS->query($extra,0,0)) {
                $READS->query("ALTER table R2CTEMP add primary key (read_id)");
                $ljoin  = "select distinct READS2CONTIG.read_id from READS2CONTIG left join R2CTEMP ";
                $ljoin .= "on READS2CONTIG.read_id = R2CTEMP.read_id ";
                $ljoin .= "where R2CTEMP.read_id is NULL";
#                $ljoin .= " and READS2CONTIG.label >= 10"; # ?? TO BE TESTED
                my $hashes = $READS->query($ljoin,0,0);
                if (ref($hashes) eq 'ARRAY') {
                    $report .= scalar(@$hashes)." reads found\n";
                    foreach my $hash (@$hashes) {
                        $hash = $hash->{read_id}; # replace each hash by its value
                    }
                    my $extra = $READS->associate($readitem,$hashes,'read_id',{returnScalar => 0});
                    push @$output, @$extra if @$extra;
                }
                elsif ($hashes) {
                    $report .= "no deallocated reads found\n$hashes\n$READS->{lastQuery}\n";
                }
                else {
                    $options{full} = 2; # failed query, try to recover
                }
            }
            else {
                $options{full} = 2; # creation of R2CTEMP probably failed, try to recover
            }
	}

        if ($options{full} == 2) {
print "Checking for reads deallocated from previous assembly with full=2\n";
# second alternative method: scan READS2CONTIG with simple queries; first find al reads with generation > 1
            $report .= "with consecutive queries on READS2CONTIG and READS: ";
            my $where = "generation > 1 and label >= 10";
#$MyTimer->timer('Finding other reads with method 2 step 1',0);
            if ($readitem eq 'readname') {
#                $READS->autoVivify($self->{database},0.5); # build links (existing tables only)
                $READS->autoVivify(0,0.5); # build links (existing tables only)
                $hashes = $READS->associate("distinct $readitem",'where',$where,{returnScalar => 0});
#print "found $hashes with '$READS->{lastQuery}' '$READS->{qerror}'\n";
                $report = "WARNING: error in query:\n $READS->{lastQuery} $READS->{qerror}\n" if !$hashes; 
	    }
            else {
                $hashes = $R2C->associate("distinct $readitem",'where',$where,{returnScalar => 0});
#print "found $hashes with '$R2C->{lastQuery}' '$R2C->{qerror}'\n";
                $report = "WARNING: error in query:\n $R2C->{lastQuery} $R2C->{qerror}\n" if !$hashes; 
            }
#$MyTimer->timer('Finding other reads with method 2 step 1',1);
            if (ref($hashes) eq 'ARRAY' && @$hashes) {
# the ones with generation > 1
                undef my %added;
                foreach my $item (@$hashes) {
                    $added{$item}++;
#                    $added{$hash->{$readitem}}++;
                }
# now find al reads with generation <=1 and get the difference
                $where = "generation <= 1 and label >= 10";
#$MyTimer->timer('Finding other reads with method 2 step 2',0);
                if ($readitem eq 'readname') {
                    $hashes = $READS->associate('distinct $readitem','where',$where,{returnScalar => 0});
                    $report = "WARNING: error in query:\n $READS->{lastQuery} $READS->{qerror}\n" if !$hashes; 
                }
                else {
                    $hashes = $R2C->associate('distinct $readitem','where',$where,{returnScalar => 0});
                    $report = "WARNING: error in query:\n $R2C->{lastQuery} $R2C->{qerror}\n" if !$hashes; 
                }
#$MyTimer->timer('Finding other reads with method 2 step 2',1);
                foreach my $item (@$hashes) {
                    delete $added{$item};
#                    delete $added{$hash->{$readitem}};
                }
# what's left has to be added to @output
                my $n = keys %added;
                $report .= "$n deallocated reads found\n";
                push @$output, keys(%added);
            }
            elsif ($hashes) {
                $report .= "NONE found\n";
            }
	}
        $self->{report} = $report;
        undef $hashes;
    }

# finally add possible reads in single-read contigs

print "Finding reads in single-read contigs\n";
    $R2C->autoVivify(0,0.5);
#$MyTimer->timer('Finding reads in single-read contigs',0);

    my $where = "nreads = 1 and generation <= 1 and label >= 10";
    my $readids = $R2C->associate('distinct read_id','where',$where,{returnScalar => 0});
    if ($readitem eq 'readname' && @$readids) {
	print "translating into readnames \n";
        $readids = $READS->associate('readname',$readids,'read_id',{returnScalar => 0});
    }
    push @$output, @$readids if @$readids;
#$MyTimer->timer('Finding reads in single-read contigs',1);
    

my $DEBUG = 0;
print $self->{report} if $DEBUG;
#my $n = @$output; print "reads $output $n from $output->[0] to $output->[$n-1]\n" if $DEBUG;
#$MyTimer->timer('getUnassembledReads',1);

    return $output;
}

#--------------------------- documentation --------------------------
=pod

=head1 method getUnassembledReads

=head2 Synopsis

Find reads in current database which are not allocated to any contig

=head2 Parameter (optional)

hash

=over 2

=item hash key 'full'

= 0 for quick search (fastest, but relies on integrity of READS2ASSEMBLY table)

= 1 for complete search using temporary table; if this fails falls back on:

= 2 for complete search without using temporary table (slowest)

=item hash key 'date'

Select only reads before and including the given date

=head2 Returns: reference to array of readnames

=cut
#############################################################################

# use this method if you do not want to create a new ReadsRecall object

sub newReadHash {
# replace the current read hash by a new one
    my $self = shift;
    my $hash = shift || return 0;

# input a hash of read items or a read name or ID 

    return if (ref($hash) ne 'HASH');

    my $status = $self->clear;

    &loadReadData(0,$self,$hash,@_);

    return $self->status;
}
  
#############################################################################

sub loadReadTags {
    my $self   = shift;
    my $number = shift;
    my $list   = shift;

# use cached data!
print "load TAGS for read_id $number\n" if $list;
}

#############################################################################

sub clear {
# reset internal buffers and counters
    my $self = shift;
    my $mode = shift;

    my $status = $self->{status};

    undef @{$self->{sequence}};
    undef @{$self->{quality}};
    undef @{$self->{index}};
    undef @{$self->{range}};
    undef $self->{sstring};
    undef $self->{qstring};

# reset the space for mappings

    undef %{$self->{readhash}};
    undef %{$self->{toContig}};

# reset error logging

    $status->{errors}   = 0;
    $status->{warnings} = 0;
    $status->{report}  = '';

    return $status;
}

#############################################################################
# private protected method
#############################################################################

sub loadReadData {
# reads a Read file
    my $lock = shift;
    my $self = shift;
    my $hash = shift;

    &dropDead('Illegal usage of loadReadData method') if $lock;

    my $status = $self->{status};
    my $range  = $self->{range};
    $range->[0] = 1; # default

# if the read exists, build the (local) buffers with the sequence data

    my $scount = 0; my $sstring = 0;
    my $qcount = 0; my $qstring = 0;
    my $length = 0;

#$MyTimer->timer('loadReadData hash',0);

    if (defined($hash) && ref($hash) eq 'HASH') {

        $self->{readhash} = $hash; # ??? this should be a copy with splitting off the READS.keyname etc ?? test !!
        undef @{$self->{quality}};

# decode the sequence data (after  loading the compressed data are deleted)

        if (defined($hash->{scompress}) && defined($Compress)) {

             if (defined($hash->{sequence})) {
                my $dc = $hash->{scompress};
               ($scount, $sstring) = $Compress->sequenceDecoder($hash->{sequence},$dc,0);
                if (!$sstring || $sstring !~ /\S/) {
                    $status->{report} .= "! Missing or empty sequence ($dc)\n";
                    $status->{errors}++;
                }
                else {
                    $sstring =~ s/\s+//g; # remove blanks
                    $qcount = $scount; # preset for absent quality data
                }
 	        $hash->{sequence} = ''; # clear, but leave the key (re: sub list)
            }
            else {
                $status->{report} .= "! Missing DNA sequence\n";
                $status->{errors}++;   
            }
        }
        elsif (defined($hash->{scompress})) {
            $status->{report} .= "! Cannot access the Compress module\n";
            $status->{errors}++;
        }

# decode the quality data (allow for its absence)

        if (defined($hash->{qcompress}) && defined($Compress)) {

            if (defined($hash->{quality})) {
                my $dq = $hash->{qcompress};
               ($qcount, $qstring) = $Compress->qualityDecoder($hash->{quality},$dq);
                if (!$qstring || $qstring !~ /\S/) {
                    $status->{report} .= "! Missing or empty quality data ($dq)\n";
                    $status->{errors}++;
                }
                elsif ($loadQuality) {
                    @{$self->{quality}} = $Compress->getQualityData(); # copy the original array
                }
                $hash->{quality} = ''; # clear, but leave the key (re: sub list);
            }
        }
    } 
    else {
        $status->{report} .= "! MISSING readname in ReadsRecall\n";
        $status->{errors}++;
    }
 
# cleanup the sequences and store in buffers @sequence and @quality

    if (!$status->{errors}) {

        $self->{sstring} = $sstring;
        $self->{qstring} = $qstring;

# test length against database value

        $length = $hash->{slength} if (defined($hash->{slength}));
        $length = $scount if ($scount == $qcount && $length == 0); # temporary recovery
# default mask
        $range->[1] = $length || $scount;
# test 
        if ($scount != $qcount || $scount != $length || $length == 0) {
            $status->{report} .= "! Sequence length mismatch: DNA=$scount, Q=$qcount ($hash->{slength})\n";
# this is a patch for length errors in consensus sequence
            if ($qcount == ($scount+1) && $self->{qstring} =~ /^\s*0\s+/ && $qstring !~ /[^\s01]/) {
# it probably is a spurious leading 0 in the quality data
                shift @{$self->{quality}}; # if @{$self->{quality}};
                $self->{qstring} =~ s/^\s*0\s+//;
                $status->{report} .= "Recovered: spurious leading 0 removed from quality data\n";
                $status->{warnings}++;
            }
            else {
                $status->{errors}++;
            }   
        }
    }

# apply masking (counted from 1, not 0!)

    $range->[0] = $hash->{lqleft}  + 1  if defined($hash->{lqleft});
    $range->[1] = $hash->{lqright} - 1  if defined($hash->{lqright});
    $range->[0] = 1 if (!$range->[0] || $range->[0] < 0); # protection just in case
    $range->[1] = $length if (!$range->[1] || $range->[1] > $length); # ibid

#    print "window: $range->[0]  $range->[1]\n";

    if (defined($hash->{cvleft})  && $hash->{cvleft}  >= $range->[0]) {
        $range->[0] = $hash->{cvleft}  + 1;
    }
    if (defined($hash->{cvright}) && $hash->{cvright} <= $range->[1]) {
        $range->[1] = $hash->{cvright} - 1;
    }

#    print "window: $range->[0]  $range->[1]\n";

    if (defined($hash->{svleft})  && $hash->{svleft}  >= $range->[0]) {
        $range->[0] = $hash->{svleft}  + 1;
    }
    if (defined($hash->{svright}) && $hash->{svright} <= $range->[1]) {
        $range->[1] = $hash->{svright} - 1;
    }

# either copy the input hash or pass the pointer to readhash key

#$MyTimer->timer('loadReadData hash',1);

    $range->[0]--;
    $range->[1]--;
}

#############################################################################

#############################################################################
# assembly related methods (e.g. read-to-contig mapping)
#############################################################################

sub segmentToContig {
# input of reads to contig mapping
    my $self     = shift;
    my $segment  = shift; # hash with mapping data of individual read section

    my $rtoc = $self->{toContig};

    my $prstart = $segment->{prstart};
    my $prfinal = $segment->{prfinal};
    my $rlength = $prfinal - $prstart + 1;
    my $mapkey = sprintf("%04d",$prstart).sprintf("%04d",$prfinal);
    undef @{$rtoc->{$mapkey}}; 
    $rtoc = $rtoc->{$mapkey}; # is now a reference to an array
    my $pcstart = $segment->{pcstart};
    my $pcfinal = $segment->{pcfinal};
# contig window range should be positive for consensus; flip windows if required  
    my $k = 0; $k = 1 if ($pcfinal < $pcstart);
# in case of inversion (k=1) ensure contig window is aligned by swapping indices
    $rtoc->[$k]   = $prstart; $rtoc->[1-$k] = $prfinal;
    $rtoc->[2+$k] = $pcstart; $rtoc->[3-$k] = $pcfinal;
    my $clength = $rtoc->[3] - $rtoc->[2] + 1;

    $self->{contig} = $segment->{contig_id};

    return $clength - $rlength; # should be 0
}

#############################################################################

sub readToContig {
# input of overall read to contig mapping
    my $self     = shift;
    my $mapping  = shift; # hash with mapping data

    my $rtoc = $self->{toContig};

    undef @{$rtoc->{0}};
    my $omap = $rtoc->{0};
    
    push @$omap, $mapping->{pcstart};
    push @$omap, $mapping->{pcfinal};
    push @$omap, $mapping->{prstart};
    push @$omap, $mapping->{prfinal};

    if ($mapping->{pcstart} <= $mapping->{pcfinal}) {
        $self->{clower} = $mapping->{pcstart};
        $self->{cupper} = $mapping->{pcfinal};
    }
    else {
        $self->{cupper} = $mapping->{pcstart};
        $self->{clower} = $mapping->{pcfinal};
    }
}

#############################################################################

sub putSegmentsToContig {
# combines segmentToContig and readToContig in one call for whole mapping
    my $self       = shift;
    my $maphashes  = shift; # array with mapping segment hashes
    my $generation = shift;

    $generation = 1 unless defined($generation);

    my $RTOC = $self->{toContig};
    undef %$RTOC; # clear the memory

    my $status = 0;

    my $contig = 0;
    my $alignment = 0;
    foreach my $segment (@$maphashes) {

        next if ($segment->{generation} != $generation);
        next if ($segment->{deprecated} !~ /N|M|Y/);

# test contig value; error adds 1000000 to status

        $contig = $segment->{contig_id} if !$contig;
        $status += 1000000 if ($segment->{contig_id} != $contig);
        
# get segment on read

        my $prstart = $segment->{prstart};
        my $prfinal = $segment->{prfinal};
        my $rlength = $prfinal - $prstart + 1;

# determine orientation

        my $pcstart = $segment->{pcstart};
        my $pcfinal = $segment->{pcfinal};
# contig window range should be positive for consensus; flip windows if required  
        my $k = 1; $k = 2 if ($pcfinal < $pcstart);
# test against previous orientations (all should be the same)
        if ($rlength > 1) {
            $alignment = $k if !$alignment;
            $status++ if ($alignment != $k);
# print "? $pcstart, $pcfinal, $prstart, $prfinal  $alignment $k \n" if ($alignment != $k);
        }
         
# assemble data in array

        undef my @rtoc;
        my $rtoc = \@rtoc;
# in case of inversion (k=2) ensure contig window is aligned by swapping indices
        $rtoc->[$k-1] = $prstart; $rtoc->[2-$k] = $prfinal;
        $rtoc->[$k+1] = $pcstart; $rtoc->[4-$k] = $pcfinal;
        my $clength = $rtoc->[3] - $rtoc->[2] + 1;

# store the array ref in the RTOC hash

        my $label = $segment->{label};
        my $mapkey = sprintf("%04d",$prstart).sprintf("%04d",$prfinal);

        if ($label < 20) {
# store the individual mapping(s)
            $RTOC->{$mapkey} = $rtoc;
# test length info (signal possible mapping errors)
            $status += 1000 if ($clength != $rlength);
print "? $pcstart, $pcfinal, $prstart, $prfinal,  @$rtoc \n" if ($clength != $rlength);
        }

        if ($label >= 10) {
# special case for overall map (with different ordering)
            undef @{$RTOC->{0}}; 
            @{$RTOC->{0}} = ($pcstart, $pcfinal, $prstart, $prfinal);
            $self->{clower} = $rtoc->[2];
            $self->{cupper} = $rtoc->[3];
        }
    }

    $self->{contig} = $contig;
    
    return $status;
}

#############################################################################
# NOT YET USED, to be tested
sub shiftMap {
# linear shift on reads to contig mapping
    my $self   = shift;
    my $shift  = shift;
    my $contig = shift; # (optional) new contig reference

    print "shiftMap called \n";
    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        $map->[2] += $shift; 
        $map->[3] += $shift;
    } 

    $self->contigRange;

    $self->{contig} = $contig if $contig;
}

#############################################################################
# not yet USED, to be tested
sub invertMap {
# nowhere used ??? what is this for ???
# invert the "toContig" mapping given length of contig
    my $self   = shift;
    my $length = shift || return; # length of contig
    my $contig = shift; # (optional) new contig reference

    print "invertMap called \n";
# invert the contig mapping window

    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        $map->[2] = $length - $map->[2] + 1; 
        $map->[3] = $length - $map->[3] + 1;
# ensure contig window is aligned by swapping boundaries 
        if ($map->[2] > $map->[3]) {
            my $store = $map->[0]; 
            $map->[0] = $map->[1]; 
            $map->[1] = $store;
            $store = $map->[2]; 
            $map->[2] = $map->[3]; 
            $map->[3] = $store;
        }
    }

# replace sequence by complement (?)

    my $sstring = $self->{sstring};
    my $nstring = '';
    while (my $allele = chop $sstring) {
       $allele = $reverse{$allele} || '-';
       $nstring .= $allele;
    }
    $self->{sstring} = $nstring;
    undef @{$self->{sequence}};

    $self->contigRange;

    $self->{contig} = $contig if $contig;    
}

#############################################################################

sub contigRange {
# get the coverage of this read on the contig
    my $self = shift;

    $self->{clower} = 0;
    $self->{cupper} = 0;
    $self->{ranges} = 0;

#my $read =  $self->{readhash}->{read_id};
#print "\ncontigRange for read $read \n" if ($read == 75068);

    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        next if !$key; # skip overall range
        my $map = $rtoc->{$key};
        $self->{clower} = $map->[2] if (!$self->{clower} || $map->[2] < $self->{clower}); 
        $self->{cupper} = $map->[3] if (!$self->{cupper} || $map->[3] > $self->{cupper});
#print "read $read: $key  map @$map | $self->{clower} $self->{cupper} \n" if ($read == 70417);
        $self->{ranges}++;
    }     
}

#############################################################################

sub inContigWindow {
# sample part of reads in specified contig window
    my $self   = shift;
    my $wstart = shift; # start on contig
    my $wfinal = shift; # end on contig (start<end ?)

#    $self->contigRange;

    undef my @output; undef my @quality;
    for (my $i = $wstart; $i <= $wfinal; $i++) {
	$output[$i-$wstart] = '-';
	$quality[$i-$wstart] = 0;
    }

    my $rtoc = $self->{toContig};

# get at the DNA in sequence array; if not, build it from $sstring

    my $sequence = $self->{sequence};
    if (!@$sequence) {
        my @sequence = split //,$self->{sstring}; # slow!
        $sequence = \@sequence;
    }

# get at the quality data in array; if not, build it from qstring

    my $quality  = $self->{quality};
    if (!@$quality) {
        my @quality = split /\s+/, $self->{qstring};
        $quality = \@quality;
    }
    
    my $count = 0;
    my $length = 0;
    my $reverse = 0;
    foreach my $key (keys %$rtoc) {
        next if !$key;
        my $map = $rtoc->{$key};
        my $cstart = $wstart; $cstart = $map->[2] if ($cstart < $map->[2]); 
        my $cfinal = $wfinal; $cfinal = $map->[3] if ($cfinal > $map->[3]);
        if ($cstart <= $cfinal && $map->[0] <= $map->[1]) { # aligned
            my $j = $map->[0] - $map->[2] - 1; 
            for (my $i = $cstart; $i <= $cfinal; $i++) {
                $output[$i - $wstart] = $sequence->[$j + $i];
                $quality[$i - $wstart] = $quality->[$j + $i] if $quality;
                $length = $i - $wstart + 1  if (($i - $wstart + 1) > $length);
            }
            $count += $cfinal - $cstart + 1;
        }
        elsif ($cstart <= $cfinal) { # counter aligned
            my $j = $map->[0] + $map->[2] - 1;
            for (my $i = $cstart; $i <= $cfinal; $i++) {
                my $allele = $sequence->[$j - $i];
                $output[$i - $wstart] = $reverse{$allele} || '-';
                $quality[$i - $wstart] = $quality->[$j - $i] if $quality;
                $length = $i - $wstart + 1  if (($i - $wstart + 1) > $length);
            }
            $count += $cfinal - $cstart + 1;
        }
    }

    if ($length) {
        push @output,' ';
        push @output,'R' if $reverse;
        undef my @SQ;
        $SQ[0] = \@output;
        $SQ[1] = \@quality if $quality;
        $SQ[2] = $length;
        $SQ[3] = $self->{readhash}->{chemistry};
        $SQ[4] = $self->{readhash}->{strand};
        $SQ[5] = $count;
        return \@SQ;
    }
    else {
        return 0; # no data in window
    }
}

#############################################################################
#############################################################################

sub indexing {
# build index on active DNA sequence
    my $self = shift;

    my %enumerate = ('A','0','C','1','G','2','T','3','U','3',
                     'a','0','c','1','g','2','t','3','u','3');

    my $sstring  = $self->{sstring};
    my @sequence = split /\s+|/,$sstring if $sstring; # slow!
    my $sequence = \@sequence;

    my $range    = $self->{range};
    my $index    = $self->{index};

    for (my $i=0 ; $i<=$range->[1] ; $i++) {
        $index->[$i] = 0;
        if ($i >= $range->[0]+3 && $i <= $range->[1]-3) {
            my $accept = 1;
            for (my $j=0 ; $j<7 ; $j++) {
                if (defined($enumerate{$sequence->[$i+$j-3]}) && $accept) {
                    $index->[$i] *= 4 if ($index->[$i]);
                    $index->[$i] += $enumerate{$sequence->[$i+$j-3]};
                } else {
                    $index->[$i] = -1;
                    $accept = 0;
                }
            }
        }
    }
#    print "index: @{$index}\n";
}

#############################################################################
# public methods for access and testing
#############################################################################

sub edit {
# replace individual bases by a specified new value in lower case
    my $self = shift;
    my $edit = shift; # the edit recipe as string

    my $sstring  = $self->{sstring};
    my @sequence = split /\s+|/,$sstring if $sstring; # slow!
    my $sequence = \@sequence;

# edits encoded as string nnnCcnnnCc., to replace existing base nnn S by s
# successful replacement only if base nr. nnn is indeed S

    undef my $miss;
    while ($edit =~ s/^(\d+)([ACTGU-])([actgu])//) {
        if (defined($sequence->[$1]) && $sequence->[$1] eq $2) {
            $sequence->[$1] = $3;
        } else {
            $miss .= $1.$2.$3;
        }
    }
    $miss .= $edit if ($edit);
    return $miss;
}

#############################################################################

sub align {
# align segment of read to consensus contig
    my $self = shift;
    my $alignment = shift;

print "ReadsRecall->align to be implemented \n";
}

#############################################################################

sub status {
# query the status of the table contents; define list for diagnosis
    my $self = shift; 
    my $list = shift;

    my $hash = $self->{readhash};
    my $status = $self->{status};

    if (defined($list) && $list>0) {
    # list > 0 for summary of errors, > 1 for warnings as well
        my $n = keys %{$hash};
        $hash->{readname} = "UNDEFINED" if (!$hash->{readname});
        print STDOUT "Read $hash->{readname}: $n items found; ";
        print STDOUT "$status->{errors} errors, $status->{warnings} warnings\n";
        $list-- if (!$status->{errors}); # switch off if only listing of errors
        print STDOUT "$status->{report}" if ($list && defined($status->{report}));
    }

    $status->{errors};
}

#############################################################################

sub list {
# list current data (straight list if html=0, HTML format if html=1)
    my $self = shift;
    my $html = shift;

    undef my $report;

    $self->translate(1); # substitute the dictionary items

    my $hash   = $self->{readhash};
    my $status = $self->{status};
    my $links  = $self->{links};

    undef my $readname;
    $readname =  $hash->{readname} if (defined( $hash->{readname}));
    $readname =  $hash->{ID} if (!$readname && defined( $hash->{ID}));
    $readname = "UNDEFINED" if (!$readname);
    $report .= "<CENTER><h3>" if ($html);
    $report .= "\nContents of read $readname:\n\n";
    $report .= "</h3></center>" if ($html);
    $report .= "<CENTER><TABLE BORDER=1 CELPADDING=2 VALIGN=TOP WIDTH=98%>" if ($html);
    $report .= "<TR><TH>key</TH><TH ALIGN=LEFT>value</TH></TR>" if ($html);

    my $n = 0;
    foreach my $key (sort keys (%{$hash})) {
        undef my $string;
        my $wrap = 'WRAP';
        if (defined($hash->{$key})) {
# for keys sequence and quality we have to pick up the decompressed strings in $self->{} 
            if ($key eq 'sequence' || $key eq 'SQ') {
                $string = $self->{sstring};
                $string =~ s/(.{60})/$1\n/g;
            }
            if ($key eq 'quality'  || $key eq 'AV') {
                $string = $self->{qstring};
# prepare the string for printout: each number on I3 field
                $string =~ s/\b(\d)\b/0$1/g;
                $string =~ s/^\s+//; # remove leading blanks
                $string =~ s/(.{90})/$1\n/g;
            }
# some formatting for HTML output
            if ($string && $html) {
                $string = "<code>$string</code>";
                $string = "<small>$string</small>" if ($key eq 'quality'  || $key eq 'AV');
                $string =~ s/\n/\<\/code>\<BR\>\<code\>/g;
                $wrap = 'NOWRAP';
	    }
            $string = $hash->{$key} if (!$string);
            $string = "&nbsp" if ($string !~ /\S/);
# test for linked information
            if ($links->{$key}) {
                my ($dbtable,$dbalias,$dbtarget) = split ('/',$links->{$key});
                my $alias = $dbtable->associate($dbalias,$key,$dbtarget);
                $key .= " ($alias)" if ($alias); 
            }
            $n++;
        }
        else {
            $string = "&nbsp";
	}
        $report .= "$key = $string\n" if (!$html);
        $report .= "<TR><TD ALIGN=CENTER>$key</TD><TD $wrap>$string</TD></TR>" if ($html);
    }
    $report .= "</TABLE><P>" if ($html);

    if (!$html || $status->{errors} || $status->{report} =~ /spurious/) {
        $report .= "\n$n items found; $status->{errors} errors";
        $report .= ", $status->{warnings} warnings\n";
        $report .= "<P>" if ($html);
        $report .= "$status->{report}\n" if (defined($status->{report}));
    }

    $report .= "</CENTER>" if ($html);
    
    return $report;
}

#############################################################################

sub writeReadToCaf {
# write this read in caf format (unpadded) to $FILE
    my $self    = shift;
    my $FILE    = shift;
    my $blocked = shift;

    $self->translate(0); # substitute dictionary items

    my $hash   = $self->{readhash};
    my $status = $self->{status};
    my $links  = $self->{links};

# first write the Sequence, then DNA, then BaseQuality

    print $FILE "\n\n";
    print $FILE "Sequence : $hash->{readname}\n";
    print $FILE "Is_read\nUnpadded\nSCF_File $hash->{readname}SCF\n";
    print $FILE "Template $hash->{template}\n";
    print $FILE "Insert_size $hash->{insertsize}\n";
    print $FILE "Ligation_no $hash->{ligation}\n";
    print $FILE "Primer $hash->{primer}\n";
    print $FILE "Strand $hash->{strand}\n";
    print $FILE "Dye $hash->{chemistry}\n";
    print $FILE "Clone $hash->{clone}\n";
    print $FILE "ProcessStatus PASS\nAsped $hash->{date}\n";
    print $FILE "Base_caller $hash->{basecaller}\n";
# add the alignment info
    $self->writeMapToCaf($FILE,1) if shift;

    my $sstring = $self->{sstring};
# replace by loop using substr
    $sstring =~ s/(.{60})/$1\n/g;
    print $FILE "\nDNA : $hash->{readname}\n$sstring\n";

# the quality data

    my $qstring = $self->{qstring};
    if ($blocked) {
# prepare the string for printout as a block: each number on I3 field
        $qstring =~ s/\b(\d)\b/0$1/g;
        $qstring =~ s/^\s+//; # remove leading blanks
        $qstring =~ s/(.{90})/$1\n/g;
    }
    print $FILE "\nBaseQuality : $hash->{readname}\n$qstring\n";

# process read tags ?


    return $status->{errors};
}

#############################################################################

sub writeMapToCaf {
# write the reads to contig mapping to file as 'assembled from' lines
    my $self = shift;
    my $FILE = shift;
    my $read = shift;

    my $hash = $self->{readhash};
    my $rtoc = $self->{toContig};

    if ($read && $rtoc && $rtoc->{0}) {
# add one Align_to_SCF record per read 
        my $rs  = $rtoc->{0}->[2];
        my $rf  = $rtoc->{0}->[3];
        print $FILE "Align_to_SCF $rs $rf $rs $rf\n";
        return;
    }
    elsif (!$read) {
# list the individual mappings of this read for the contig
        my $lines = '';
        foreach my $map (sort keys %$rtoc) {
            next if !$map;
            my $cs = $rtoc->{$map}->[2]; my $cf = $rtoc->{$map}->[3];
            my $rs = $rtoc->{$map}->[0]; my $rf = $rtoc->{$map}->[1];
            $lines .= "Assembled_from $hash->{readname} $cs $cf $rs $rf\n" if $map;
        }
        print $FILE $lines if $FILE;
        return $lines;
    }
}

#############################################################################

sub writeToCafPadded {
# write both the read and the read-to-contig mapping in caf format to $FILE
    my $self = shift;
    my $FILE = shift;
    my $long = shift; # 0 for segments for this read; 1 for "assembled from"

    $self->translate(0);

    my $hash = $self->{readhash};
    my $rtoc = $self->{toContig};
    my $omap = $rtoc->{0};

# NOTE: the ordering and position for individual read elements is different 
# from the one used for the overal mapping! see methods segmentToContig & 
# readToContig 

# get the mapped read length (the scf map) from overall mapping

    undef my @scfmap;
    if ($omap && @$omap == 4) {
        @scfmap = @$omap; # copy to local array
        my $scflength = abs($scfmap[1] - $scfmap[0]);
        $scfmap[3] = $scfmap[2] + $scflength;
    }
    else {
        print STDOUT "Missing reads-to-contig overall map in $hash->{readname}\n";
exit 0;
        return 0; # error status: missing or invalid overall map
    }

    if (!$long) {
        my $line = "Assembled_from $hash->{readname} @scfmap\n";
        print $FILE $line if $FILE;
        return $line;
    }

# to get the to-SCF mapping we have to backtransform the contig window

    my $sign = 1;
    if ($scfmap[1] < $scfmap[0]) {
        $sign = -1; # counter aligned
    }
    my $shift = $scfmap[2] - $sign * $scfmap[0];

# the transformation from contig to scfread is: ri = sign*ci + shift 

    my @segments = sort keys %$rtoc;
    
# first write the Sequence, then DNA, then BaseQuality

    print $FILE "\n\n";
    print $FILE "Sequence : $hash->{readname}\n";
    print $FILE "Is_read\nPadded\nSCF_File $hash->{readname}SCF\n";
    print $FILE "Template $hash->{template}\n";
    print $FILE "Insert_size $hash->{insertsize}\n";
    print $FILE "Ligation_no $hash->{ligation}\n";
    print $FILE "Primer $hash->{primer}\n";
    print $FILE "Strand $hash->{strand}\n";
    print $FILE "Dye $hash->{chemistry}\n";
    print $FILE "Clone $hash->{clone}\n";
    print $FILE "Base_caller $hash->{basecaller}\n";

# here list the Align_to_SCF alignments and build the padded sequence at the same time

    my $padded = '';
    my $quality = '';
    my $previous = 0;
    my $length = $hash->{slength};
    my $lastsegment = $segments[$#segments];

    my $qualitydata = $self->{quality};
    if (!@$qualitydata) {
        my @quality = split /\s+/, $self->{qstring};
        $qualitydata = \@quality;
    }

    foreach my $segment (@segments) {
        next if !$segment; # skip the overall map
        my $map = $rtoc->{$segment};
# get the interval with the read interval ordered
        my $j = 0; $j = 1 if ($sign < 0);
        my $scstart = $sign * $map->[2+$j] + $shift;
        my $scfinal = $sign * $map->[3-$j] + $shift;
        my $rdstart = $map->[$j];
        my $rdfinal = $map->[1-$j];
# adjust the start and end intervals (overriding the back-transformed data)
        if (!$previous) {
#print "first segment $segment    $rdstart  $scstart\n";
            $rdstart = 1;
            $scstart = 1;
        }
        if ($segment eq $lastsegment) {
            my $remainder = $length - $rdfinal;
#print "last  segment $segment  $rdfinal  $scfinal  $length $remainder\n";
            $rdfinal += $remainder;
            $scfinal += $remainder;
        }

        my $pad = $scstart - $previous - 1; 
#print "previous $previous  scstart $scstart  pad $pad \n";
        $previous = $scfinal;
        print $FILE "Align_to_SCF $scstart $scfinal $rdstart $rdfinal\n";
        if ($pad > 0) {
            while ($pad--) {
                $padded .= '-';
                $quality .= '  0';
            }
        }
        elsif ($pad < 0) {
            print "Error in mapping! @$map \n";
        }
        my $length = $rdfinal - $rdstart + 1;
        $padded .= substr ($self->{sstring}, $rdstart-1, $length);
        for my $i ($rdstart .. $rdfinal) {
            $quality .= sprintf "%3d", $qualitydata->[$i-1];
        }
    }

    if (!$previous) {
	print "ABORTED: no segments for read $hash->{readname} $hash->{read_id} \n"; 
        print "segments: '@segments' \n";
        exit 0;
    }

    print $FILE "Seq_vec SVEC ";
    if ($hash->{svleft}) {
        print $FILE "1 $hash->{svleft} ";
    }
    elsif ($hash->{svright}) {
        print $FILE "$hash->{svright} $hash->{slength} ";
    }
    print $FILE "\"$hash->{svector}\"\n";
    my $lqleft = $hash->{lqleft} + 1;
    my $lqright = $hash->{lqright} - 1; 
    print $FILE "Clipping QUAL $lqleft $lqright\n"; 
    print $FILE "Clone $hash->{clone}\n";
    print $FILE "Sequencing_vector \"$hash->{svector}\"\n";

# Tags?

# finally, write out the sequence and quality data in padded form

    $padded =~ s/(.{60})/$1\n/g; # split in lines of 60
    print $FILE "\n\nDNA : $hash->{readname}\n$padded\n";
    print $FILE "\n\nBaseQuality : $hash->{readname}\n$quality\n";
}

#############################################################################

sub cafUnassembledReads {
# fetch all unassembled reads and write data to a CAF file
    my $self = shift;
    my $FILE = shift;
    my $opts = shift;

    my %options = (onTheFly => 0,item => 'read_id');
    $READS->importOptions(\%options, $opts);

    my $readitem = $options{item};

    my $count = 0;
    undef my @missed;

    my $reads = $self->getUnassembledReads($opts);

    if (ref($reads) eq 'ARRAY' && @$reads) {
# NOTE: bulk processing does not require separate cacheing (see spawnReads)
        my $start = 0;
        my $block = 10000;
        while (@$reads) {
            $block = @$reads if ($block > @$reads);
            undef my @test;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @test, (shift @$reads);
            }
            $start += $block;

            if ($options{onTheFly}) {
print "testing onTheFly method\n";
                my $hashes = $READS->associate('hashrefs',\@test,$readitem,{returnScalar=>0});
# returns array of hashes
                foreach my $hash (@$hashes) {
# load the read hash
                    if (my $status = $self->newReadHash($hash)) {
                        push @missed,$hash->{readname};
                    }
                    elsif (!$self->writeReadToCaf($FILE)) {
                        $count++;
                    }
                    else {
                        push @missed,$hash->{readname};
                    } 
                }
                undef $hashes;
            }
# build read instances
#            elsif (my $readinstances = $self->getRead(\@test,'hashrefs')) {
            elsif (my $readinstances = $self->spawnReads(\@test,'hashrefs')) {

                foreach my $instance (@$readinstances) {
                    if (!$instance->writeReadToCaf($FILE)) {
                        $count++;
                    }
                    else {
                        push @missed,$instance->{readhash}->{readname};
                    }
                }
                undef $readinstances;
            }          

        }
    }

# what to do with error message?
my $missed=@missed; # print "$count reads written to output device; missed $missed \n" if $DEBUG;

    return $count; # 0 to signal NO reads found, OR query failed
}

#############################################################################

sub touch {
# unused at the moment ??
# get the reference to the data hash; possibly apply key translation 
    my $self = shift;

    $MODEL = $READS->spawn('READMODEL','arcturus') if !$MODEL;

    my $hash = $self->{readhash};

    if ($MODEL) {
        foreach my $key (keys %$hash) {
            my $newkey = $MODEL->associate('item',$key,'column_name');
            if (defined($newkey)) {
                $hash->{$newkey} = $hash->{$key};
                delete $hash->{$key};
            }
        }
    }

    return $hash;
}

#############################################################################

sub translate {
# link a table item to a value in another table
    my $self = shift;
    my $long = shift; # long version or 0 for short version (for caf output)
  
    my $library = \%library;
    if (!keys %$library) {
# on first call set up the translation library from the data in the dictionary
#print "Initialising library <br>\n";
        $READS->autoVivify('<self>',1,0); # one level deep
# process chemistry
        my %options = (returnScalar => 0, useCache => 0);
        my $CHEMISTRY = $READS->spawn('CHEMISTRY');
        $CHEMISTRY->autoVivify('<self>',1,0); # to get at CHEMTYPES
        my $hashes = $CHEMISTRY->associate('chemistry','where',"description like '%primer%'",\%options);
        $library->{chemistry} = {};
        foreach my $chemistry (@$hashes) {
            $library->{chemistry}->{$chemistry} = "Dye_primer";
        }        
        $hashes = $CHEMISTRY->associate('chemistry','where',"description like '%terminator%'",\%options);
        foreach my $chemistry (@$hashes) {
            $library->{chemistry}->{$chemistry} = "Dye_terminator";
        }
        $hashes = $CHEMISTRY->associate('chemistry','where',"description like '%Licor%'",\%options);
        foreach my $chemistry (@$hashes) {
            $library->{chemistry}->{$chemistry} = "Licor_chemistry";
        }
# extend with full chemistry info
        $hashes = $CHEMISTRY->{hashrefs};
        foreach my $hash (@$hashes) {
            my $chemistry = $hash->{chemistry};
            $hash->{chemtype} = "?" if !$hash->{chemtype}; # to have it defined
            $library->{chemistry}->{$chemistry} = "Unknown" if !$library->{chemistry}->{$chemistry};
            $library->{chemistry}->{$chemistry} .= " :  \"$hash->{identifier}\"  ($hash->{chemtype})" if $long;
        }
# strands   
        $library->{strand} = {};   
        my $STRANDS = $READS->spawn('STRANDS');
        $hashes = $STRANDS->{hashrefs};
        foreach my $hash (@$hashes) {
            my $strand = $hash->{strand};
            my $description = $hash->{description};
#print "strand $strand $description <br>";
            $library->{strand}->{$strand} = "Unknown";
            $library->{strand}->{$strand} = "Forward" if ($description =~ /forward/i);
            $library->{strand}->{$strand} = "Reverse" if ($description =~ /reverse/i);
            $library->{strand}->{$strand} .= " ($strand)" if $long;
	}
# primer type
        $library->{primer} = {};
        my $PRIMERS = $READS->spawn('PRIMERTYPES');
        $hashes = $PRIMERS->{hashrefs};
        foreach my $hash (@$hashes) {
            my $primer = $hash->{primer};
            my $description = $hash->{description};
#print "primer $primer $description <br>\n";
            $library->{primer}->{$primer} = "Unknown_primer";
            $library->{primer}->{$primer} = "Universal_primer" if ($description =~ /forward|reverse/i);
            $library->{primer}->{$primer} = "Custom \"Oligo\"" if ($description =~ /custom/i);
            $library->{primer}->{$primer} .= " (nr $primer)" if $long;
        }
# clone
        $library->{clone} = {};
        my $CLONES = $READS->spawn('CLONES');
        $hashes = $CLONES->{hashrefs};
        foreach my $hash (@$hashes) {
            my $clone = $hash->{clone};
#print "clone $clone $hash->{clonename} <br>\n";
            $library->{clone}->{$clone} = $hash->{clonename};
            $library->{clone}->{$clone} .= " (nr $clone)" if $long;
        }
# basecaller
        $library->{basecaller} = {};
        my $CALLER = $READS->spawn('BASECALLER');
        $hashes = $CALLER->{hashrefs};
        foreach my $hash (@$hashes) {
            my $caller = $hash->{basecaller};
            $library->{basecaller}->{$caller} = $hash->{name};
        }
# ligation
        $library->{ligation} = {};
        $library->{ligation}->{0} = "NONE";
        $library->{insertsize} = {};
        my $LIGATIONS = $READS->spawn('LIGATIONS');
        $hashes = $LIGATIONS->{hashrefs};
        foreach my $hash (@$hashes) {
            my $ligation = $hash->{ligation};
            $library->{ligation}->{$ligation} = $hash->{identifier};
            $library->{ligation}->{$ligation} .= " (nr $ligation)" if $long;
# create a new library entry for insert size
            my $insertsize = "unknown";
            if (defined($hash->{silow}) && defined($hash->{sihigh})) {
                $insertsize = "$hash->{silow} $hash->{sihigh}";
	    }
            $library->{insertsize}->{$ligation} = $insertsize;
        }
# sequencevector
        $library->{svector} = {};
        $library->{svector}->{0} = "NONE";
        my $SVECTORS = $READS->spawn('SEQUENCEVECTORS');
        $hashes = $SVECTORS->{hashrefs};
        foreach my $hash (@$hashes) {
            my $svector = $hash->{svector};
            $library->{svector}->{$svector} = $hash->{name};
            $library->{svector}->{$svector} .= " (nr $svector)" if $long;
        }
# cloningvector
        $library->{cvector} = {};
        $library->{cvector}->{0} = "NONE";
         my $CVECTORS = $READS->spawn('CLONINGVECTORS');
        $hashes = $CVECTORS->{hashrefs};
        foreach my $hash (@$hashes) {
            my $cvector = $hash->{cvector};
            $library->{cvector}->{$cvector} = $hash->{name};
            $library->{cvector}->{$cvector} .= " (nr $cvector)" if $long;
        }
#print $READS->listInstances();
    }

    my $readhash = $self->{readhash};
    return if defined($readhash->{insertsize}); # already done earlier
    $readhash->{insertsize} = $readhash->{ligation} || 'unknown';

    foreach my $column (sort keys %$readhash) {
        my $code = $readhash->{$column};
        next if !defined($code); 
        if (my $dictionary = $library->{$column}) {
            if (defined($dictionary->{$code})) {
                $readhash->{$column} = $dictionary->{$code};
            }
            elsif ($column eq 'chemistry' || $column eq 'insertsize') {
                $readhash->{$column} = 'unknown';
            }
	    else {
                print "No translation for read item $column: $code<br>\n";
            }
        }
    }
}

#############################################################################

sub minimize {
# reduce the amount of space occupied by this read (irreversible)
    my $self = shift;

# remove all data except from the sequence & quality arrays

    foreach my $key (keys (%$self)) {
        if ($key ne 'sequence' && $key ne 'quality' && $key ne 'index') {
            if (ref($key) =~ /HASH/) {
                foreach my $qey (keys (%$key)) {
                    delete $key->{$qey};
                }
            } elsif (ref($key) =~ /ARRAY/) {
		undef @{$self->{$key}};
            }
            delete $self->{$key};
        }
    }

}

#############################################################################

sub delete {
# remove references to this object to clear memory
    my $self = shift;

# remove all references to the object

    my $read = $self->{readhash}->{read_id};
    delete $instance{$read};
    $read = $self->{readhash}->{readname};
    delete $instance{$read};

#    undef $self->{sstring};
#    undef $self->{qstring};
#    undef $self->{sequence};
#    undef $self->{quality};
#    undef $self->{rtoc};

    undef $self;
}

#############################################################################
#############################################################################

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>  "ejz, group 81",
        version =>             0.8 ,
        updated =>    "17 Oct 2003",
        date    =>    "15 Jan 2001",
    };
}

1;
