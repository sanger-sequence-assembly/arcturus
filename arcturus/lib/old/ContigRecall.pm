package ContigRecall;

#############################################################################
#
# assemble a contig from the ARCTURUS database
#
#############################################################################

use strict;

use ReadsRecall;

use Compress;

#############################################################################
# Global variables
#############################################################################

my $CONTIGS;  # database table handle to CONTIGS table
my $R2C;      # database table handle to READS2CONTIG table
my $C2C;      # database table handle to CONTIGS2CONTIG table
# my $READS;   # database table handle to READS table
my $C2S;      # database table handle to CONTIGS2SCAFFOLD table
my $DNA;      # database table handle to CONSENSUS table
#my $TAGS;     # database table handle to TAGS

my $ReadsRecall; # handle to ReadsRecall module

my %instances; # what purpose?

my $DEBUG = 0;
my $TEST  = 0;
my $break = '<br>';

#############################################################################
# constructor init: serves only to create the database table handles
# 
# 
#############################################################################

sub init {
# initialisation
    my $prototype = shift;
    my $tblhandle = shift; # handle to any table in the organism database
    my $initmode  = shift; 
    my $dna       = shift;

    if (!$tblhandle) {
        print "Missing database table handle in ContigRecall init\n";
        return 0;
    }
    elsif ($tblhandle->{database} eq 'arturus') {
        print "You must specify a database other than 'arcturus' in ContigRecall\ initn";
        return 0;
    }

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

# now initialise the table handles: default init is for building contig(s) and
# read maps, e.g. for display or caf output; non default for output as hash

$DEBUG = 0;
    if (!$initmode ) {
	print "standard initialisation $tblhandle\n" if $DEBUG;

# get the table handles from the input database table handle (if any)

        $CONTIGS = $tblhandle->spawn('CONTIGS');
        $C2C = $tblhandle->spawn('CONTIGS2CONTIG');
        $R2C = $tblhandle->spawn('READS2CONTIG');
# $READS = $tblhandle->spawn('READS');
        $C2S = $tblhandle->spawn('CONTIGS2SCAFFOLD');
#        $DNA = $tblhandle->spawn('CONSENSUS');
#    $T2C = $tblhandle->spawn('TAGS2CONTIG');

#    $CONTIGS->autoVivify('<self>',1.5);
	print "DONE \n" if $DEBUG;
        $CONTIGS->setAlternates('contigname','aliasname');

	print "before ReadsRecall .. " if $DEBUG;
        $ReadsRecall = new ReadsRecall; # get class handle (initialize outside this module)
        print "after ReadsRecall .. " if $DEBUG;
    }

    else {
print "NON-standard initialisation \n" if $DEBUG;
        $C2C = $tblhandle->spawn('CONTIGS2CONTIG');
# initialisation for output of contig hash table

	$CONTIGS =$tblhandle->spawn('CONTIGS');
        $self->{R2C}    = $CONTIGS->spawn('READS2CONTIG');
        $self->{READS}  = $CONTIGS->spawn('READS');
        $self->{CLONES} = $CONTIGS->spawn('CLONES');
        $CONTIGS->autoVivify('<self>',2.5);
        $CONTIGS->setAlternates('contigname','aliasname');
        $self->{CONTIGS} = $CONTIGS;

        $self->{CLONES}->autoVivify('<self>',1.5);

        $self->{ASSEMBLY} = $CONTIGS->spawn('ASSEMBLY');
        $self->{ASSEMBLY}->autoVivify('<self>',2.5,0); # rebuild links of tables involved

        $self->{PROJECTS} = $CONTIGS->spawn('PROJECTS');
        $self->{PROJECTS}->autoVivify('<self>',2.5,0); # rebuild links of tables involved

        $self->{C2S} = $CONTIGS->spawn('CONTIGS2SCAFFOLD');
        $self->{C2S}->autoVivify('<self>',1.5);

        $self->{SEQUENCE} = $CONTIGS->spawn('CONSENSUS');
#my $snapshot = $CONTIGS->snapshot; print $snapshot;

#        my $DNA = $options->{DNA}; # may be empty
        my $Compress = new Compress($dna);
        $self->{Compress} = $Compress;
print "DONE $self \n" if $DEBUG;
    }

    return $self;
}

#############################################################################
# constructor new
#############################################################################

sub new {
# create instance for new contig
    my $prototype  = shift;
    my $contigitem = shift; # the Contig name or item
    my $itsvalue   = shift;

    if (!$contigitem) {
        die "You must specify a name, number or item & value identifying the contig in ContigRecall\n";
    }

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

# allocate internal counters

    $self->{contig}  =  0; # contig id
    $self->{ctgname} = ''; # contigname
    $self->{readids} = []; # for read names
    $self->{rhashes} = []; # for ReadsRecall hashes
    $self->{markers} = []; # re: speeding up consensus builder
    $self->{status}  = {}; # for error status report
    $self->{sensus}  = ''; # consensus sequence
#    $self->{forward} = {};
#    $self->{reverse} = {};

    my $status = $self->{status};
    $status->{report} = '';
    $status->{errors} = 0;

    if (defined($itsvalue)) {
        
        my $cids = $self->findContigByAlias($itsvalue,{attribute => $contigitem});
# output always an array
        if (!$cids || (ref($cids) eq 'ARRAY' && !@$cids)) {
            $status->{report} = "No such contig linked with $itsvalue";
            $status->{errors} = 1;
        }
        else {
# build the first
            my $number = @$cids;
            $status->{report} = "$number contigs linked with $itsvalue";
            $self->buildContig($cids->[0]);
        }        
    }

    elsif ($contigitem =~ /[0-9]+/ && $contigitem !~ /[a-z]/i) {
# case: contig_id specified
        $self->buildContig($contigitem);
    }

    elsif (my $cids = $self->findContigByName($contigitem)) {
# case: contig or alias name specified
        if (ref($cids) ne 'ARRAY') {
            $self->buildContig($cids);
            $self->{ctgname} = $contigitem;
        }
        else {
# take the first one
            my $number = @$cids;
            $status->{report} = "$number contigs named $itsvalue";
            $self->buildContig($cids->[0]);
        }        
    } 
    else {
        $status->{report} = "No such contig linked with $itsvalue";
        $status->{errors} = 1;
    }   

    return $self;
}

#############################################################################
# buildContig: standard build of single ContigRecall and its ReadsRecall objects
#############################################################################

sub buildContig {
# build a ContigRecall object for given contig_id
    my $self   = shift;
    my $contig = shift; # contig_id
    my $opts   = shift;

    my %options = ( sort => 1,       # sort maps according to increasing lower range
                    generation => 1, # select contigs and maps for generation 1
                    scpos => -1,     # start position interval (if positive) 
                    fcpos => -1,     # end   position interval (if positive)
                   );
    $CONTIGS->importOptions(\%options,$opts);

    $self->{contig} .= $contig; # store contig id

    my $status = $self->{status};

# autoVivify the links from READS2CONTIG table if not done before

    $R2C->autoVivify('<self>',1.5) if !keys(%{$R2C->{sublinks}});

# build read mapping query required for this contig

    my $query = "contig_id = $contig ";
    my $generation = $options{generation};
    $query .= "and generation = $generation " if ($generation >= 0);
    $query .= "and deprecated in ('N','M') ";

    my $scpos = $options{scpos};
    my $fcpos = $options{fcpos};
    if ($scpos > 0 && $fcpos > 0 && $scpos <= $fcpos) {
        $scpos *= 2; $fcpos *= 2;
        $query .= "and (pcstart+pcfinal + abs(pcfinal-pcstart) >= $scpos) "; 
        $query .= "and (pcstart+pcfinal - abs(pcfinal-pcstart) <= $fcpos) "; 
print "query: where $query \n";
    }
print "query: where $query \n";

# get hashes with mapping information to get the read_id involved

    my %reads;
    my $maphashes = $R2C->cacheRecall($contig); # if built beforehand
    $maphashes = $R2C->associate('hashrefs','where',$query,{traceQuery => 0}) if !$maphashes;
    if ($maphashes && @$maphashes) {
        foreach my $hash (@$maphashes) {
            $reads{$hash->{read_id}} .= $hash.' '; # in case of multiple occurrances
        }        
    }
    else {
        $status->{report} = "No results found: query = $R2C->{lastQuery} ($R2C->{qerror})";
        $status->{errors}++;
        return 0;
    }

    my @readids = keys %reads; # the readids in this contig

    my $hashes = $ReadsRecall->spawnReads(\@readids,'hashrefs');  # build the read hashes
    my $series = $ReadsRecall->findInstanceOf; # returns reference to hash of read hashes

# store the mapping information in the read instances

    foreach my $hash (@$maphashes) {
        next if ($generation >= 0 && $hash->{generation} ne $generation);
        next if ($hash->{deprecated} eq 'X' || $hash->{deprecated} eq 'Y');
        my $recall = $series->{$hash->{read_id}}; # the instance of ReadsRecall read_id
# load the individual segment in the read
        if ($hash->{label} < 20 && $recall->segmentToContig($hash)) {
            print "WARNING: invalid mapping ranges for read $hash->{read_id}!\n";
        }
# load the (overall) read to contig alignment
        $recall->readToContig($hash) if ($hash->{label} >= 10);
    }

# what about READTAGS, CONSENSUS, and Contig TAGS ??

# sort the ReadRecall objects according to increasing lower contig range

    @$hashes = sort { $a->{clower} <=> $b->{clower} } @$hashes  if $options{sort};

# cleanup

    undef %reads;
    undef @readids;
    undef $maphashes;

    my $result = 0;
    if ($hashes) {
        $self->{rhashes} = $hashes;
        $result = @$hashes+0;
    }
    else {
        $status->{errors} = $ReadsRecall->{status}->{errors};
        $status->{report} = $ReadsRecall->{status}->{result} || 'unspecified';
    }

# add contig to the list of instances

    $instances{$contig} = $self;

    return $result;
}

#############################################################################

sub status {
    my $self = shift;
    my $list = shift;

    my $status = $self->{status};
    if ($list && $status->{errors}) {
        print "Error status $status->{errors} on contig $self->{contig}: '$status->{report}'\n";
    }
    elsif ($list) {
        my $number = @{$self->{rhashes}};
        print "Contig $self->{contig}: $number reads configured\n"; 
    }
        
    return $status->{errors};
}

#############################################################################
#############################################################################
# Tracing from contig to contig
#############################################################################
#############################################################################

sub traceForward {
# link input contig and positions to contig/positions in latest assembly
    my $self   = shift;
    my $contig = shift;
    my $posits = shift; # array ref with positions to be transformed

# build the trace table for this contig

    my $tracer = $self->traceBuilder($contig);

    my $sign = 1.0;
    my $shft = 0.0;

# search through the forward trace until no next link is found

    while (my $next = $tracer->{forward}->{$contig}) {
#print "traceForward next: @$next \n";
        $contig = $next->[0]; # the next contig
# accumulate the transformation between the previous and new contig
        if ($next->[1] > 0) {
            $shft += $next->[2];
        }
        else {
            $sign = -$sign;
            $shft = $next->[2] - $shft;
        }
#print "new contig $contig\n";
    }

    if ($posits && ref($posits) eq 'ARRAY') {
        foreach my $pos (@$posits) {
            $pos = $sign*$pos + $shft;
        }
    }

    return $contig;
}

#############################################################################

sub traceBuilder {
# recursively build forward and reverse link tables for given input contig id
    my $self   = shift;
    my $contig = shift;
    my $output = shift;

my $DEBUG = 0;

    if (!$output || ref($output) ne 'HASH') {
        undef my %output;
        $output = \%output;
        $output->{reverse} = {};
        $output->{forward} = {};
    }

print "ContigRecall tracing $contig \n" if $DEBUG;

    my $reverse = $output->{reverse}; print "reverse $reverse \n" if $DEBUG;
    my $forward = $output->{forward}; print "forward $forward \n" if $DEBUG;

    my $where    = "oldcontig = $contig or newcontig = $contig";
    my $hashrefs = $C2C->associate('hashrefs','where',$where,{traceQuery  => 0});

    my $report = '';
    foreach my $hash (@$hashrefs) {

        my $ors  = $hash->{oranges};
        my $orf  = $hash->{orangef};
        my $nrs  = $hash->{nranges};
        my $nrf  = $hash->{nrangef};
        my $octg = $hash->{oldcontig};
        my $nctg = $hash->{newcontig};
print "hash: $octg $ors $orf  $nctg $nrs $nrf \n" if $DEBUG;
        next if ($ors == $orf); # ignore "bottle neck"
        my $sign = ($nrf - $nrs)/($orf - $ors);
print "sign $sign \n" if $DEBUG;
        if (abs($sign) != 1.0) {
            $report .= "! invalid contig-to-contig map ($octg $ors $orf $nctg $nrs $nrf)\n";
            next;
        }
        elsif ($octg == $contig && !$forward->{$contig}) {
# add to the forward path
            $forward->{$contig}->[0] = $nctg;
            $forward->{$contig}->[1] = $sign;
            $forward->{$contig}->[2] = $nrs - $sign * $ors;
print "forward tracing $nctg " if $DEBUG; my @keys = keys %$forward; print "forward keys: @keys \n" if $DEBUG;
            $self->traceBuilder($nctg,$output) if !$forward->{$nctg};
print "return forward tracing $nctg \n" if $DEBUG;
        }
        elsif ($nctg == $contig && !$reverse->{$contig}) {
# add to the reverse path
            $reverse->{$contig}->[0] = $octg;
            $reverse->{$contig}->[1] = $sign;
            $reverse->{$contig}->[2] = $ors - $sign * $nrs;
print "reverse tracing $octg " if $DEBUG; my @keys = keys %$reverse; print "reverse keys: @keys \n" if $DEBUG;
            $self->traceBuilder($octg,$output) if !$reverse->{$octg};
print "return reverse tracing $octg \n" if $DEBUG;
        }
    }
print "ContigRecall tracing $contig exit \n \n" if $DEBUG;

    return $output;
}

#############################################################################

sub traceLister {
# list a trace made with method traceBuilder
    my $self = shift;
    my $hash = shift; # input trace hash, or contig id 

#    print "hash $hash \n" if (ref($hash) ne 'HASH');
    $hash = $self->traceBuilder($hash) if (ref($hash) ne 'HASH');

    my $forward = $hash->{forward};
    my $reverse = $hash->{reverse};

    my $listing = "Forward chain:\n\n";
    foreach my $key (sort keys %$forward) {
        my $next = $forward->{$key};
        $listing .= sprintf ("%6s %6s     %2d %7d \n",$key,@$next);
    }
    $listing .= "\nReverse chain:\n\n";
    foreach my $key (sort keys %$reverse) {
        my $next = $reverse->{$key};
        $listing .= sprintf ("%6s %6s     %2d %7d \n",$key,@$next);
    }
    return $listing;
}

#############################################################################

sub trace {
    my $self = shift;
    my $spos = shift; # start position in contig
    my $fpos = shift; # end position in contig

# determine first and last position to be retrieved

    undef my %contigstart;
    undef my %contigfinal;
    undef my %contiglevel;
    undef my %contigshift;

    my $contig = $self->{'contig'}; # the starting point

    $contigstart{$contig} = $spos if (defined($spos));
    $contigstart{$contig} = 1 if (!$contigstart{$contig});
    $contigfinal{$contig} = $fpos if (defined($fpos));
    $contigfinal{$contig} = $CONTIGS->associate('length',$contig,'contigname')
                            if (!$contigstart{$contig});
    $contiglevel{$contig} = $CONTIGS->associate('parity',$contig,'contigname');
    
# do a traceback until contigs with parity>0

    my $query;
    my $number = 1;
    while ($number > 0) {
    # collect contigs with status 0
        undef my @testcontigs;    
        foreach $contig (keys (%contiglevel)) {
            push @testcontigs, $contig if (!$contiglevel{$contig});
        }
        $number = 0;
        foreach $contig (@testcontigs) {
        # collect data about this contig
            my $cstart = $contigstart{$contig};
            my $cfinal = $contigfinal{$contig};
            my $shift  = $contigshift{$contig};
        # collect all the reads connected to this contig
            my $thesereads = $R2C->associate ('hashrefs',$contig,'contig_id');
        # here thesereads is a pointer to an array of hashes; collect data
            foreach my $readhashes (@$thesereads) {
            }
        # collect all connecting preceding contigs
            my $oldcontigs = $C2C->associate ('hashrefs',$contig,'newcontig');
        # here oldcontigs is a pointer to an array of hashes; collect data
            foreach my $contighash (@$oldcontigs) {
            # get the mapping data
                my $oc = $contighash->{'oldcontig'};
                my $os = $contighash->{'oranges'};
                my $of = $contighash->{'orangef'};
                my $ns = $contighash->{'nranges'};
                my $onshift = $ns - $os; # shift from old to new contig 
            # test if the range on new contig falls inside the window
                my $nf = $ns + ($of - $os);
                if ($ns >= $cstart && $ns <= $cfinal || $nf >= $cstart && $nf <= $cfinal) {
                # yes, this contig is in the target range
                    
                # get the active window and shift
                    $contigstart{$oc} = $cstart - $onshift; # start point in the old contig
                    $contigfinal{$oc} = $cfinal - $onshift; # end   point in the old contig
                    $contigshift{$oc} = $shift  + $onshift; # shift with respect to assembly
                    $contiglevel{$oc} = $CONTIGS->associate('parity',$oc,'contigname');
                    $number++;
                } # else ignore
            }
        }
    }

# the tables now contain the contigs at parity > which contribute to the assembly
# each contig has its own active region os-of and the shift with respect to the assemby
# now collect the corresponding reads

    foreach $contig (keys (%contiglevel)) {
    # get active window (on this contig) and shift
        my $os = $contigstart{$contig};
        my $of = $contigfinal{$contig}; 
        my $sh = $contigshift{$contig};
    # collect the reads inside the active window
        $query  = "select readname,read_id,pcstart,pcfinal,prstart,prfinal ";
        $query .= "from READS,CONTIGS,READS2CONTIG ";
        $query .= "where CONTIGS.contigname = $contig ";
        $query .= "and READS.read_id = READS2CONTIG.read_id ";
        $query .= "and CONTIGS.contig_id = READS2CONTIG.contig_id ";
        $query .= "and READS2CONTIG.deprecated = 'N'"; 
        my $readhashes = $R2C->query($query);
    }
                    
}

#############################################################################
#############################################################################
# Consensus sequence and contig windows
#############################################################################
#############################################################################

sub window {
# extract a contig window
    my $self   = shift;
    my $wstart = shift;
    my $wfinal = shift;
    my $mark   = shift;
    my $list   = shift;

    my $rhashes = $self->{rhashes} || return;

    my $markers = $self->{markers};

# collect the sequence and quality data in the specified window

    undef my @SQ;

    print "\ntest window $wstart $wfinal:\n" if $list;

    for (my $i = 0; $i < @$rhashes; $i++) {

        next if ($mark && $markers->[$i]);

        my $read = $rhashes->[$i];
        print "process read $read->{readhash}->{read_id} ($read->{clower} $read->{cupper})\n" if ($list > 1);
        if (my $SQ = $read->inContigWindow($wstart, $wfinal)) {
            push @SQ, $SQ; # array of arrays of references to sequence & quality and read data
            $markers->[$i] = 1 if ($mark && $read->{cupper} <= $wfinal);
            if ($list) {
                my $output = $SQ->[0];            
                my $sequence = join '',@$output;
#                my $quality = $SQ->[1];
                printf (" %8d:", $read->{readhash}->{read_id});
                print "$sequence \n";
#                print "@$quality \n";
            }
        }
# disable this read once it has been found fully downwards of the window 
        elsif ($read->{cupper} < $wstart) {
# print "last  read below $read $read->{readhash}->{read_id} ($read->{clower} $read->{cupper}) marked to ignore \n";
            $markers->[$i] = 1 if $mark;
        }
        elsif ($read->{clower} > $wfinal) {
# the read is found upwards of the contig window; all subsequent ones will be too
# print "first read above $read $read->{readhash}->{read_id} ($read->{clower} $read->{cupper})\n";
            last;
        }
    }

# get the consensus sequence

    return &vote (\@SQ); # 0 if no data in window
}

#############################################################################

sub vote {
# Bayesian voting on consensus 
    my $SQ = shift || return 0;

    undef my $string;

#    undef my @SQ;
    my $length = 0;
    foreach my $sq (@$SQ) {
        $length = $sq->[2] if ($sq->[2] > $length);
# print "vote input $sq : @$sq \n";
    }
# return;
    my $i = 0;
    while ($i < $length) {
        my @sequence;
        my @squality;
        foreach my $sq (@$SQ) {
            push @sequence, $sq->[0]->[$i];
            push @squality, $sq->[1]->[$i];
        }
# preliminary voting on highest quality
        my $vote = 0;
# print "S:@sequence Q:@squality \n" if ($i == 0 || $i == $length-1); 
        foreach my $j (1 .. $#squality) {
            $vote = $j if ($squality[$j] > $squality[$vote]);
        }
#	print "vote $i: $vote $sequence[$vote] $squality[$vote] \n";
        $string .= $sequence[$vote];
        $i++;
    }

    return $string;
}

#############################################################################

sub consensus {
# build the consensus sequence
    my $self  = shift;
    my $block = shift || 500; # default
    my $list  = shift || 0;

    my $rhashes = $self->{rhashes} || return;

    undef @{$self->{markers}};

    $self->{sensus} = '';

    my $initm = 1;
    my $start = 0;
    undef my $length;
    while ($block) {
        my $final = $start + $block;
        $start++;
print "block $start-$final: " if $list;
        if (my $substring = $self->window($start, $final, 1)) {
            $self->{sensus} .= $substring;
            my $slength = length($substring);
            $length += $slength;
print "\n$substring \n" if $list;
            $block = 0 if ($slength < $block);
        }
        else {
            $block = 0;
print "end\n" if $list;
        }
        $start = $final;
    }
    return $length;
}

#############################################################################

sub reset {
# reset the markers
    my $self = shift;

    undef @{$self->{markers}};
}

#############################################################################
#############################################################################
#
# Methods returning contig descriptors in a hash table:
#
#   getContigHashById
#   getContigHashByAttribute
#
# Methods returning a contig ID:
#
#   findContigByName
#   findContigByAlias
#   findContigByQuery
#
#############################################################################
#############################################################################

sub getContigHashById {
# in: (unique) arcturus contig_id
    my $self     = shift;
    my $contigid = shift || 0;
    my $ioptions = shift;


    if (ref($contigid) eq 'ARRAY') {
# replace each input contig id by the corresponding contig hash
        my @contig;
        foreach my $contig (@$contigid) {
            $contig = $self->getContigHashById($contig,$ioptions);
        }
        return $contigid;
    }

# find data for contig nr $contigid 
 
    my $CONTIGS = $self->{CONTIGS};

    my %soptions = (concise => 0, noSequence => 0);
    $CONTIGS->importOptions(\%soptions, $ioptions);
    
# prepare output hash

    my %contig;
    my $contig = \%contig;

    my $hashref = $CONTIGS->associate('hashref',$contigid,'contig_id',{traceQuery=>0});
    if ($hashref->{contig_id}) {
        foreach my $key (sort keys %$hashref) {
            $contig->{$key} = $hashref->{$key} if $hashref->{$key};
        }
        $contig->{status} = 'Passed';
    }
    else {
print "No such contig ($contigid):\n $CONTIGS->{lastQuery}\n" if $DEBUG;  
        $contig->{status} = "Not found ($contigid)";
        return $contig;
    }

    my $R2C = $self->{R2C};
    $contig->{generation} = $R2C->associate('distinct generation',$contigid,'contig_id');

    return $contig if $soptions{concise}; # short version returns contig data and generation only

    my $PROJECTS = $self->{PROJECTS};
    $hashref  = $PROJECTS->associate('hashref',$contigid,'contig_id');
# add to output hash
    if ($hashref && ref($hashref) eq 'HASH' && $hashref->{project}) {
        $contig->{projectname} = $hashref->{projectname};
        $contig->{projecttype} = $hashref->{projecttype};
        $contig->{assembly}    = $hashref->{assembly};
        $contig->{pupdated}    = $hashref->{updated};
    }
    else {
        $contig->{projectname} = 'UNKNOWN';
        $contig->{assembly}    = 'UNKNOWN';
        $contig->{status} = "Incomplete";
        my $qstatus = $PROJECTS->qstatus;
print "no data for project:\n $qstatus \n" if $DEBUG;
    }

    my $ASSEMBLY = $self->{ASSEMBLY};
    $hashref  = $ASSEMBLY->associate('hashref',$contigid,'contig_id');
    if ($hashref && ref($hashref) eq 'HASH' && $hashref->{assembly}) {
        my $assembly = $hashref->{assemblyname};
        $contig->{assembly} = $assembly if $assembly;
        $contig->{aupdated} = $hashref->{updated};
        if ($hashref->{organism}) {
            my $ORGANISM = $ASSEMBLY->spawn('ORGANISMS','arcturus');
            $hashref = $ORGANISM->associate('hashref',$hashref->{organism},'number');
            $contig->{database} = $hashref->{dbasename};
            my $organism = $hashref->{genus};
            $organism .= ' '.$hashref->{species} if $hashref->{species};
            $organism .= ' '.$hashref->{serovar} if $hashref->{serovar};
            $organism .= ' '.$hashref->{strain}  if $hashref->{strain};
            $organism .= ' '.$hashref->{isolate} if $hashref->{isolate};
            $contig->{organism} = $organism;
        }
    }

# get associated clones

    my $CLONES = $self->{CLONES};
    my %coptions = (returnScalar => 0, orderBy => 'clonename');
    my $hashes = $CLONES->associate('distinct clonename',$contigid,'contig_id',\%coptions);
# print "hashes $hashes @$hashes $CLONES->{lastQuery}<br>";
    if ($hashes && ref($hashes) eq 'ARRAY') {
        $contig->{clones} = join ',',@$hashes;
    }
    else {
        $contig->{clones} = 'NOT FOUND';
    }

# gate associated tags

    if (my $TAGS = $self->{TAGS}) {
        my %toptions = (returnScalar => 0, orderBy => 'tagname');
        $hashes = $TAGS->associate('distinct tagname',$contigid,'contig_id',\%toptions);
# print "hashes $hashes @$hashes $TAGS->{lastQuery}<br>";
        if ($hashes && ref($hashes) eq 'ARRAY') {
            $contig->{tags} = join ',',@$hashes;
        }
        else {
            $contig->{tags} = 'NOT FOUND';
        }
    }
    
    if (!$soptions{noSequence}) {
        my $SEQUENCE = $self->{SEQUENCE};
        my $hashref = $SEQUENCE->associate('hashref',$contigid,'contig_id',{traceQuery=>0});
        if ($hashref && $hashref->{contig_id}) {
            my $Compress = $self->{Compress};
            my $dc = $hashref->{scompress} || 0;
            if ($dc && defined($Compress)) {
               (my $sl, $self->{sequence}) = $Compress->sequenceDecoder($hashref->{sequence},$dc,0);
	        $contig->{sequencelength} = $hashref->{length};
	        $contig->{status} = "Inconsistent" if ($hashref->{length} != $sl);
            }
        }
        else {
            $contig->{sequence} = 'NOT FOUND';
            $contig->{status} = "Incomplete";
 my $qstatus = $SEQUENCE->qstatus;
 print "no data for sequence:\n $qstatus \n" if $DEBUG;
        }
    }
    else {
        $contig->{sequence} = 'not requested';
    }

    return $contig;    
}

#############################################################################

sub getContigHashByAttribute {
# return a hash with contig data for contig with the specified attribute
# in: contig alias (projectname) (assemblyname) to resolve possible ambiguity
    my $self      = shift;
    my $attribute = shift || 0; # (scalar value of ) name, readname, tag, clone
    my $ioptions  = shift;      # (hash, optional) e.g. projectname, assemblyname

# search is controlled by a 'mask' of 4 characters, set by either specifying
# it explicitly in options, or implicitly with the 'attribute' option (which
# must be one of 'name', 'read','clone', 'tag', 'all' or 'any'
        
    my %soptions = (project    => 0, assembly   => 0, mask => '1100',
                    noSequence => 0, postSelect => 1, returnIds => 0,
                    limit      => 0, attribute  => 0, concise => 0);
    my $soptions = \%soptions; 

    my $CONTIGS = $self->{CONTIGS};

    $CONTIGS->importOptions($soptions, $ioptions); # i(nput)options override default s(earch)options

    $soptions->{mask} = '1000' if ($soptions->{mask} !~ /\S/); # defaults to contig name

    if (my $attribute = $soptions->{attribute}) {

        my %items = (name => '1000', read => '0100', all => '1111',
                     contigname => '1000', readname => '0100',
                     clone => '0010', tag => '0001', any => '1111');

        return 0 if !defined($items{$attribute}); # invalid attribute specified

        $soptions->{mask} = $items{$attribute}; # overrides any input mask setting
    }

# split the masking string (to get the choices to be active)

# mask 0 : search on (unique) contigname or (non-unique) aliasname
# mask 1 : search on readname linked to the contig
# mask 2 : search on clone name linked to the contig 
# mask 3 : search on tag (sts, gap4, happy) linked to the contig 

#$soptions->{mask} = '1111'; # test

    print "Warning: insufficient mask length: $soptions->{mask}"  if (length($soptions->{mask}) < 4);

    my @mask = split //,$soptions->{mask};

$TEST = 1; print "mask $soptions->{mask}:  @mask <br>\n" if $TEST;

# SEARCH

    undef my @cids; # array for results

    my %qoptions = (traceQuery => 1, useCache => 0, returnScalar => 0,
                    limit => $soptions{limit}); # query options

# first try CONTIGS contigname or aliasname

    if ($mask[0] or $mask[1] or $mask[2]) {

        undef my $where;
# $where = "contigname = '$attribute' or aliasname = '$attribute'" if $mask[0];
        $where = "contigname = '$attribute'" if $mask[0]; # is expanded to include aliasname
        $where .= " or " if ($where && $mask[1]);
        $where .= "readname  = '$attribute'" if $mask[1];
        $where .= " or " if ($where && $mask[2]);
        $where .= "clonename = '$attribute'" if $mask[2];
# $where .= " or " if ($where && $mask[3]);
# $where .= "tagname   = '$attribute'" if $mask[3];
# $qoptions{debug} = 1 if ($mask[2] || $mask[3]);
print "ContigRecall : $where <br>\n" if $TEST;
        my $output  = $CONTIGS->associate('distinct contig_id','where',$where,\%qoptions);
        push @cids, @$output if (ref($output) eq 'ARRAY' && @$output);
print "ContigRecall : $CONTIGS->{lastQuery} <br>\n" if $TEST;
    }
print "ContigRecall : @cids<br>\n\n" if $TEST;

# then try TAGS (STSTAGS, GAP4TAGS, HAPPYTAGS) via tagname

    if ($mask[3]) {
        my $hashes = $CONTIGS->associate('contig_id','where',"tagname = '$attribute'",\%qoptions);
        push @cids, @$hashes if (ref($hashes) eq 'ARRAY' && @$hashes);
    }

# if several contigs found, filter on projectname or assemblyname, if defined

push @cids,100, 200 if ($TEST > 1); # test purposes
    if (@cids > 1 && ($soptions->{project} or $soptions->{assembly})) {
print "find project $soptions->{project} or assembly $soptions->{assembly} \n" if $TEST;
        my $where = "contig_id in (".join(',',@cids).") and ";
        $where .= "assemblyname = '$soptions->{assembly}'" if $soptions->{assembly};
        $where .= " and " if ($where && $soptions->{project});
        $where .= "projectname = '$soptions->{project}'" if $soptions->{project};
#$qoptions{debug} = 1;
        my $hashes = $self->{C2S}->associate('contig_id','where',$where,\%qoptions);
        @cids = @$hashes; # could be empty
print "ContigRecall : @cids\n\n" if $TEST;
    }

# if still more than one possibility: sort according to generation

    if (@cids > 1) {
        my $where = "contig_id in (".join(',',@cids).")";
        $self->{R2C} = $CONTIGS->spawn('READS2CONTIG') if !$self->{R2C};
        $qoptions{traceQuery} = 0; $qoptions{orderBy} = 'generation';
        my $hashes = $self->{R2C}->associate('distinct contig_id','where',$where,\%qoptions);
        @cids = @$hashes if @$hashes;
    }

# OUTPUT

# return the array with contig ids (could be zero length), if returnIds set

print "RESULT IDS ContigRecall : @cids\n\n" if $TEST;

    return \@cids if $soptions->{returnIds};

# or, if nothing found matching the search parameters, return hash with only status key

    return {status => 'Not found'} if !@cids;

# or return a hash with the data for the contig found, if only one contig found

    return $self->getContigHashById($cids[0],$soptions) if (@cids == 1);

# or return a hash with the data for the most recent contig and add an 'alternates' key 
# to list the contig IDs of other contigs found

    my $cid = shift @cids;
    my $contig = $self->getContigHashById($cid,$soptions);
    $contig->{alternates} = join ',',@cids  if @cids;
   
    return $contig;
}

#############################################################################

sub findContigByAlias {
# in: contig alias; out: array of contig IDs
    my $self    = shift;
    my $alias   = shift; # name
    my $options = shift; # input options

    my %options; $options = \%options if (ref($options) ne 'HASH');

    $options->{returnIds} = 1;

    return $self->getContigHashByAttribute($alias, $options);
}

#############################################################################

sub findContigByName {
# find a contig by name, return its contig ID
    my $self = shift;
    my $name = shift;

    my %options = (traceQuery => 0, returnScalar => 0);
    my $query = "contigname = '$name' or aliasname = '$name'";
    my $cids = $CONTIGS->associate('contig_id','where',$query,\%options);

# returns 0 for failure, a scalar contig_id if one found,
# or a reference to an array with contig ids (e.g. if name contains wildcard)

    if (!$cids || !@$cids) {
        $cids = 0;
    }
    elsif (@$cids == 1) {
        $cids = $cids->[0];
    }

    return $cids;
}

#############################################################################

sub findContigByQuery {
# find a contig by name, return its contig ID
    my $self  = shift;
    my $where = shift;

    my %options = (traceQuery => 1, returnScalar => 0);
    my $cids = $CONTIGS->associate('contig_id','where',$where,\%options);

    return $cids;
}

#############################################################################

sub listContigHash {
    my $self = shift;
    my $hash = shift;
    my $html = shift;

    my $list = "<table>";
#    $list .= "<tr><th>key</th><th align=left>value</th></tr>";

    foreach my $item (sort keys %$hash) {
        my $value = $hash->{$item};
        $value = "&nbsp" if !defined($value);
        $value =~ s/(.{60})/$1 <br>/g if (length($value) > 60);
        $list .= "<tr><th align=left>$item</th><td>$value</td></tr>";
    }
    $list .= "</table>\n";
}

#############################################################################
#############################################################################
# dumpToCaf: write ContigRecall and ReadsRecall data in caf format to file.
#            This method takes the Recall objects built earlier with 'new'
#            (i.e. 'buildContig') and dumps the data; use this method only 
#            for a few contigs as building the modules in memory may slow 
#            the process substantially
#############################################################################
#############################################################################

sub dumpToCaf {
# write the contig (its read mappings and its reads) in caf format to $FILE
    my $self = shift;
    my $FILE = shift;

# write the reads to contig mappings

    my $ReadsRecall = $self->{rhashes}; 

# write the individual read mappings ("align to caf")

    foreach my $ReadObject (@$ReadsRecall) {
        $ReadObject->writeMapToCaf($FILE,1);
    }

# write the overall maps for for the contig ("assembled from")

    my $outputname = sprintf("contig%08d",$self->{contig});
    print $FILE "\nSequence : $outputname\nIs_contig\nPadded\n";

    foreach my $ReadObject (@$ReadsRecall) {
        $ReadObject->writeMapToCaf($FILE,0);
    }
    print $FILE "\n\n";
    

# write the consensus sequence / or all the reads ?

}

#############################################################################
# writeToCaf: does the same a dumpToCaf, but on-the-fly,  without building 
#             all ReadsRecall objects to avoid grabbing a large chunk of 
#             memory, doing the calculations for each read in turn 
#############################################################################

sub writeToCaf {
# write this contig on the fly in caf format to $FILE
    my $self   = shift;
    my $FILE   = shift;
    my $contig = shift; # contig ID or list of contig IDs

    if (ref($contig) eq 'ARRAY') {
        my $count = 0;
        foreach my $contig (@$contig) {
            $count++ if $self->writeToCaf($contig);
        }
        return $count;
    }

# get the reads belonging to this contig
 
    my $reads = $R2C->cacheRecall($contig,{indexName=>'names'});
    print "recalled $reads \n";
    if (ref($reads) eq 'ARRAY') {
        my $n = @$reads;  
        print "$n :  @$reads \n"; $n--;
        print "read 0 $reads->[0]->{read_id}  read $n $reads->[$n]->{read_id} \n";
    }

    $self->{assembled} = '';
    foreach my $read (@$reads) {
# get the read_id
        my $read_id = $read->{read_id};
# load the read into memory, replacing the existing hash
        $ReadsRecall->newReadHash($read_id);
# get the map hashes
        my $maphashes = $R2C->cacheRecall($read_id,{indexName=>'mappings'}); # cached previously on read_id
print "No cacahed maphashes: useprepared query\n" if !$maphashes;
        $maphashes = $R2C->usePreparedQuery('mapQuery', $read_id) if !$maphashes;

        $maphashes = $R2C->associate('hashrefs',$read_id,'read_id') if !$maphashes;

# put mappings into place

        foreach my $hash (@$maphashes) {
#print "map hash $hash: $hash->{generation} $hash->{deprecated} $hash->{read_id} $hash->{contig_id} \n";
            next if ($hash->{generation} != 1);
            next if ($hash->{deprecated} eq 'X' || $hash->{deprecated} eq 'Y');
# load the individual segment in the read
            if ($hash->{label} < 20 && $ReadsRecall->segmentToContig($hash)) {
                print "WARNING: invalid mapping ranges for read $hash->{read_id}!\n";
            }
# load the (overall) read to contig alignment
            $ReadsRecall->readToContig($hash) if ($hash->{label} >= 10);
        }

# write out the read and SCF alignments on the fly

        $ReadsRecall->writeMapToCaf($FILE,1);
# write the contig mapping into the assembled string
        $self->{assembled} .= $ReadsRecall->writeMapToCaf(0,0);      
    }

# finally write out the Contig part

    my $outputname = sprintf("contig%08d",$contig);
    print $FILE "\nSequence : $outputname\nIs_contig\nPadded\n";

    print $FILE "$self->{assembled}\n\n";
    
# 
}

#############################################################################

sub writeAssemby {
# write the latest assembly to a caf file
    my $self = shift;
    my $FILE = shift;

# preliminary notes
# get all contigs and their nr of reads from CONTIGS where generation=1
# if the dump is to be done in blocks: distribute the contigs such that the
#    number of reads per block is about the same. Then for each block
#       cache readmaps and readdata; cache tags and consensus
#       run through all contigs dumping them on the fly
# if not in blocks, the whole database could be cached, or you might want to
#    pickup the data as needed
}

#############################################################################

sub prepareQueries {

    my $query = "select * from <self> where read_id=? and";
    $query .= " deprecated in ('N','M') and generation = 1";
    $R2C->prepareQuery($query,'readMapQuery');

    $query =~ s/read/contig/;
    $R2C->prepareQuery($query,'contigMapQuery');
}

#############################################################################
#############################################################################

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.8 ,
        updated =>    "30 Sep 2003",
        date    =>    "08 Aug 2002",
    };
}

1;
