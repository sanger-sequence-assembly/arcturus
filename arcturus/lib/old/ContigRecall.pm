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

my $CONTIGS;  # database handle to CONTIGS table
my $R2C;      # database handle to READS2CONTIG table
my $C2C;      # database handle to CONTIGS2CONTIG table
my $READS;    # database handle to READS table
# my $C2S;      # database handle to CONTIGS2SCAFFOLD table


#############################################################################
# constructor item new; serves only to create a handle to a stored read
# subsequently ->getRead will load a (new) read
#############################################################################

sub new {
# create instance for new contig
    my $prototype  = shift;
    my $dbasetable = shift; # handle to any table in the current database
    my $contigname = shift; # the Contig name

    my $class = ref($prototype) || $prototype;
    my $self  = {};

# get the table handles from the input database table handle (if any)

    if ($dbasetable) {
        $CONTIGS = $dbasetable->spawn('CONTIGS'         ,'<self>',0,0);
        $C2C     = $dbasetable->spawn('CONTIGS2CONTIG  ','<self>',0,0);
        $R2C     = $dbasetable->spawn('READS2CONTIG'    ,'<self>',0,0);
        $READS   = $dbasetable->spawn('READS'           ,'<self>',0,0);
#        $C2S     = $dbasetable->spawn('CONTIGS2SCAFFOLD','<self>',0,0);
    }

# allocate internal counters

    $self->{readids} = [];
    $self->{contig}  = $contigname;
    $self->{status}  = {}; # error status report
    $self->{counts}  = []; # counters

    my $status = $self->{status};
    $status->{warnings} = 0;
    $status->{errors}   = 0;


    bless ($self, $class);
    return $self;
}

#############################################################################

sub newContigName {
# initiate a new contig by name
    my $self = shift;
    my $name = shift;

    my $query = "contigname = '$name' or aliasname = '$name'";
    if (my $contig_id = $CONTIGS->associate('contig_id','where',$query)) {
        return $self->newContigId($contig_id,@_);
    }
    else {
        return 0;
    }

}

#############################################################################

sub newContigId {
    my $self     = shift;
    my $contigID = shift;
    my $scpos    = shift;
    my $fcpos    = shift;

# build reads table required for this contig

    my $query = "contig_id = $contigID and label >= 10 ";
    if (defined($scpos) && defined($fcpos) && $scpos <= $fcpos) {
        $scpos *= 2; $fcpos *= 2;
        $query .= "and (pcstart+pcfinal + abs(pcfinal-pcstart) >= $scpos) "; 
        $query .= "and (pcstart+pcfinal - abs(pcfinal-pcstart) <= $fcpos) "; 
    } 
    if (my $readids = $R2C->associate('read_id','where',$query)) {
        if ($readids && ref($readids) ne 'ARRAY') {
            undef my @readids;
            $readids[0] = $readids;
            $readids = \@readids;
        }
        elsif (!$readids) {
            return 0;
        }
        $self->{readids} = $readids;
        return @$readids+0;
    }
    else {
        return 0;
    }
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

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.8 ,
        date    =>    "08 Aug 2002",
    };
}

1;




