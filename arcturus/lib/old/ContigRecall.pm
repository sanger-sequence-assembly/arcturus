package ContigRecall;

#############################################################################
#
# assemble a contig from the ARCTURUS database
#
#############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

#############################################################################
# Global variables
#############################################################################

my $readrecall; # handle to ReadsRecall module:=> TableReader::ReadsRecall.pm
my $dbCONTIGS;  # database handle to CONTIGS table
my $dbCEVENTS;  # database handle to CEVENTS table
my $dbRRtoCC;   # database handle to READS2CONTIG table

#############################################################################
# constructor init: initialise the global (class) variables
#############################################################################

sub init {
    my $prototype = shift;

    my $dbcontig  = shift;
    my $dbcevent  = shift;
    my $dbrtoc    = shift;
    my $mapper    = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $dbCONTIGS  = $dbcontig;
    $dbCEVENTS  = $dbcevent;
    $dbRRtoCC   = $dbrtoc;
    $readrecall = $mapper;

    bless ($self, $class);

    return $self;
}


#############################################################################
# constructor item new; serves only to create a handle to a stored read
# subsequently ->getRead will load a (new) read
#############################################################################

sub new {
# create instance for new contig
    my $prototype  = shift;
    my $contigname = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{'contig'}  = $contigname;
    $self->{'status'}  = {}; # error status report
    $self->{'counts'}  = []; # counters

    my $status = $self->{'status'};
    $status->{'warnings'} = 0;
    $status->{'errors'} = 0;   # dumping errors


    bless ($self, $class);
    return $self;
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
    $contigfinal{$contig} = $dbCONTIGS->associate('length',$contig,'contigname')
                            if (!$contigstart{$contig});
    $contiglevel{$contig} = $dbCONTIGS->associate('parity',$contig,'contigname');
    
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
            my $thesereads = $dbRRtoCC->associate ('hashrefs',$contig,'contig_id');
        # here thesereads is a pointer to an array of hashes; collect data
            foreach my $readhashes (@$thesereads) {
            }
        # collect all connecting preceding contigs
            my $oldcontigs = $dbCEVENTS->associate ('hashrefs',$contig,'newcontig');
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
                    $contiglevel{$oc} = $dbCONTIGS->associate('parity',$oc,'contigname');
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
        my $readhashes = $dbRRtoCC->query($query);
    }
                    
}

#############################################################################
#############################################################################

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>  "ejz, group 81",
        version =>             0.8 ,
        date    =>    "15 Jan 2001",
    };
}

1;




