package ContigRecall;

#############################################################################
#
# assemble a contig from the ARCTURUS database
#
#############################################################################

use strict;

use ReadsRecall;

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

#############################################################################
# constructor init: serves only to create the database table handles
#############################################################################

sub init {
# initialisation
    my $prototype = shift;
    my $tblhandle = shift; # handle to any table in the organism database

    if (!$tblhandle || $tblhandle->{database} eq 'arturus') {
        die "You must specify a database other than 'arcturus' in ContigRecall\n";
    }

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

# get the table handles from the input database table handle (if any)

    $CONTIGS = $tblhandle->spawn('CONTIGS');
    $C2C = $tblhandle->spawn('CONTIGS2CONTIG');
    $R2C = $tblhandle->spawn('READS2CONTIG');
#    $READS = $tblhandle->spawn('READS');
    $C2S = $tblhandle->spawn('CONTIGS2SCAFFOLD');
    $DNA = $tblhandle->spawn('CONSENSUS');
#    $T2C = $tblhandle->spawn('TAGS2CONTIG');

#    $CONTIGS->autoVivify('<self>',1.5);

    $CONTIGS->setAlternates('contigname','aliasname');

    $ReadsRecall = new ReadsRecall; # get class handle

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

    $self->{contig}  = '';
    $self->{readids} = []; # for read names
    $self->{rhashes} = []; # for ReadsRecall hashes
    $self->{markers} = []; # re: speeding up consensus builder
    $self->{status}  = {}; # for error status report
    $self->{sensus}  = ''; # consensus sequence

    my $status = $self->{status};
    $status->{report} = 0;
    $status->{errors} = 0;

    if (defined($itsvalue)) {
        $self->getLabeledContig($contigitem, $itsvalue);
    }
    elsif ($contigitem =~ /[0-9]+/ && $contigitem !~ /[a-z]/i) {
        $self->getNumberedContig($contigitem);
    }
    else {
        $self->getNamedContig($contigitem);
    }    

    return $self;
}

#############################################################################

sub getNamedContig {
# initiate a new contig by name
    my $self = shift;
    my $name = shift;

    $self->{contig} = $name.' ';

    my $query = "contigname = '$name' or aliasname = '$name'";
    if (my $contig_id = $CONTIGS->associate('contig_id','where',$query)) {
        return $self->getContig($contig_id,@_);
#        return $self->getNumberedContig($contig_id,@_);
    }
    else {
        return 0;
    }
}

#############################################################################

sub getContig {
# build an image of the current contig (generation 1)
    my $self   = shift;
    my $contig = shift; # number or name
    my $scpos  = shift; # (optional) start of range on contig
    my $fcpos  = shift; # (optional)  end  of range on contig

    $self->{contig} .= $contig;

    my $status = $self->{status};

# autoVivify the links from READS2CONTIG table if not done before

    $R2C->autoVivify('<self>',1.5) if !keys(%{$R2C->{sublinks}});

# build read mappings required for this contig

    my $query = "contig_id = $contig and generation <= 1";
#    my $query = "contig_id = $contig and label < 20 and generation = 0";
    if (defined($scpos) && defined($fcpos) && $scpos <= $fcpos) {
        $scpos *= 2; $fcpos *= 2;
        $query .= "and (pcstart+pcfinal + abs(pcfinal-pcstart) >= $scpos) "; 
        $query .= "and (pcstart+pcfinal - abs(pcfinal-pcstart) <= $fcpos) "; 
print "query: where $query \n";
    }

# get hashes with mapping information to get the read_id involved


    my $maphashes; my %reads;
    if ($maphashes = $R2C->associate('hashrefs','where',$query)) {
        foreach my $hash (@$maphashes) {
            $reads{$hash->{read_id}} .= $hash.' '; # in case of multiple occurrances
        }        
    }
    else {
        $status->{report} = "No results found: $R2C->{qerror}\n";
        $status->{errors}++;
        return 0;
    }

    my @reads = keys %reads;

    my $hashes = $ReadsRecall->spawnReads(\@reads,'hashrefs');  # array of hashes
    my $series = $ReadsRecall->findInstanceOf;      # reference to hash of hashes

# store the mapping information in the read instances

    foreach my $hash (@$maphashes) {
        my $label = $hash->{label};
        my $recall = $series->{$hash->{read_id}}; # the instance of ReadsRecall read_id
# load the individual segments
        if ($label < 20 && $recall->segmentToContig($hash)) {
            print "WARNING: invalid mapping ranges for read $hash->{read_id}!\n";
        }
# load the (overall) read to contig alignment
        $recall->readToContig($hash) if ($label >= 10);
    }

# sort the ReadRecall objects according to increasing upper contig range

    @$hashes = sort { $a->{clower} <=> $b->{clower} } @$hashes;
# &lister($hashes);

# cleanup

    undef %reads;
    undef @reads;
    undef $maphashes;

    my $result = 0;
    if ($hashes) {
        $self->{rhashes} = $hashes;
        $result = @$hashes+0;
    }
    else {
        $status->{errors} = $ReadsRecall->{status}->{errors};
        $status->{result} = $ReadsRecall->{status}->{result};
    }
    return $result;
}

#############################################################################

sub lister {
# sort the hashes of the contig
    my $hashes = shift;

    print "input hashes $hashes \n";

    my $lastHash = @$hashes - 1;
    foreach my $i (0 .. $lastHash) {
        my $read = $hashes->[$i];
        my $range = '';
        print "$read $read->{readhash}->{read_id} $read->{clower} $read->{cupper} $range\n";
    }
    return;
}

#############################################################################

sub status {
    my $self = shift;
    my $list = shift;

    my $status = $self->{status};
    if ($list && $status->{errors}) {
        print "Error status on contig $self->{contig}: $self->{report}\n";
    }
    elsif ($list) {
        my $number = @{$self->{rhashes}};
        print "Contig $self->{contig}: $number reads configured\n"; 
    }
        
    return $status->{errors};
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

#    print "test window $wstart $wfinal:\n";

    for (my $i = 0; $i < @$rhashes; $i++) {

        next if ($mark && $markers->[$i]);

        my $read = $rhashes->[$i];
# print "process read $read $read->{readhash}->{read_id} ($read->{clower} $read->{cupper})\n";
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

sub writeToCaf {
# write this contig in caf format to $FILE
    my $self = shift;
    my $FILE = shift;

print "writeToCaf $self->{contig}\n";
# write the reads to contig mappings

    my $ReadsRecall = $self->{rhashes};
# write the individual read mappings ("align to caf")
    foreach my $ReadObject (@$ReadsRecall) {
        $ReadObject->writeMapToCaf($FILE,1);
    }
# write the overall maps for for the contig ("assembled from")
    print $FILE "Sequence : ..\nIs_contig\nPadded\n";
    foreach my $ReadObject (@$ReadsRecall) {
        $ReadObject->writeMapToCaf($FILE,0);
    }
    print $FILE "\n\n";
    

# write the consensus sequence / or all the reads ?

}

#############################################################################
#############################################################################

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.8 ,
        updated =>    "27 May 2003",
        date    =>    "08 Aug 2002",
    };
}

1;
