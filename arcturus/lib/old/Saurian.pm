package Saurian;

# Assembler's interface to Arcturus database

use strict;

use Bootean;

use vars qw($VERSION @ISA); #our ($VERSION, @ISA);

@ISA = qw(Bootean);

use ReadsRecall;
use ContigBuilder;
use ContigRecall;

#############################################################################
my $DEBUG = 1;
#############################################################################

sub new {
# constructor invoking the constructor of the Bootean class
    my $caller   = shift;
    my $database = shift;
    my $options  = shift;

# import options specified in $options hash

    undef my %options;
    $options = \%options if (!$options || ref($options) ne 'HASH');
    my @tables = ('READS','CONTIGS');
    $options->{writeAccess} = \@tables if $options->{writeAccess};

# determine the class and invoke the class variable

    my $class = ref($caller) || $caller;
    my $self  = $class->SUPER::new($database,$options) || return 0;

# open ReadsReader and ContigReader modules

    $self->{READS}         = $self->{mother}->spawn('READS',$database); 
    $self->{ReadsRecall}   = ReadsRecall->init($self->{READS},'ACGTN ');
    $self->{ContigRecall}  = ContigRecall->init($self->{READS});
    $self->{ContigBuilder} = new ContigBuilder() if $options{writeAccess};

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 new (constructor)

=head2 Synopsis

=head2 Parameters:

=cut
#*******************************************************************************
#############################################################################

sub getRead {
# return hash or array of hashes with read items
    my $self = shift;
    my $name = shift;

    my $ReadsRecall = $self->{ReadsRecall} || return 0;

    undef my $read;
    if (ref($name) eq 'ARRAY') {
        $read = $ReadsRecall->spawnReads($name, @_); # returns array of hashes 
    }
    else {
        $read = $ReadsRecall->new($name); # returns (single) hash
    }

    return $read;
}
#--------------------------- documentation --------------------------
=pod

=head1 method getRead

=head2 Synopsis

Retrieve read(s) from the current database as hash image(s)

=head2 Parameters: 

=over 1

=item name: the read name

Returns a single hash with read data

=item name: reference to array of readnames

Returns a reference to an array of hashes for the retrieved reads

=back

=cut


#############################################################################

sub probeRead {
# return hash or array of hashes with read items
    my $self = shift;
    my $name = shift;

    return $self->{READS}->associate('read_id',$name,'readname');
}
#--------------------------- documentation --------------------------
=pod

=head1 method getRead

=head2 Synopsis

Retrieve readid for named read

=head2 Parameter: the read name

=cut
#############################################################################
#############################################################################

sub getUnassembledReads {
# short way using READS2ASSEMBLY; long way with a left join READS, R2CR2
    my $self = shift;
    my $full = shift || 0;

    my $READS = $self->{READS}; # the READS table handle in the current database 

    my $reads;

    if (!$full) {

# short option: use info in READS2ASSEMBLY.astatus (assuming it to be complete and consistent)

        my $R2A = $READS->spawn('READS2ASSEMBLY','<self>',0,0); # get table handle
        $READS->autoVivify($self->{database},0.5); # build links (existing tables only)
# find the readnames in READS by searching on astatus in READS2CONTIG
        $reads = $READS->associate('readname',"! '2'",'astatus',{returnScalar => 0});
    }

    else {

# the long way, bypassing READS2ASSEMBLY; first find all reads not in READS2CONTIG
        my $report = "Find all reads not in READS2CONTIG with left join: ";
        my $ljoin = "select distinct READS.readname from READS left join READS2CONTIG ";
        $ljoin  .= "on READS.read_id=READS2CONTIG.read_id ";
# $ljoin  .= "where READS.?? = ? ";
        $ljoin  .= "where READS2CONTIG.read_id IS NULL ";
        $ljoin  .= "order by readname";
# this query gets all reads in READS not referenced in READS2CONTIG
        my $hashes = $READS->query($ljoin,0,0);
        undef my @reads;
        $reads = \@reads;
        foreach my $hash (@$hashes) {
            push @reads,$hash->{readname};
        }
        $report .= scalar(@reads)." reads found\n";
# now we check on possible (deallocated) reads in READS2CONTIG which do NOT figure in generation 0 or 1
        $report .= "Check for reads deallocated from previous assembly ";
        if ($full == 1) {
# first alternative method: create a temporary table and do a left join
            $report .= "using a temporary table: ";
            my $extra = "create temporary table R2CTEMP select distinct read_id ";
            $extra  .=  "from READS2CONTIG where generation <= 1";
            if ($READS->query($extra,0,0)) {
                $READS->query("ALTER table R2CTEMP add primary key (read_id)");
                $ljoin  = "select distinct READS2CONTIG.read_id from READS2CONTIG left join R2CTEMP ";
                $ljoin .= "on READS2CONTIG.read_id = R2CTEMP.read_id ";
                $ljoin .= "where R2CTEMP.read_id is NULL";
                my $hashes = $READS->query($ljoin,0,0);
                if (ref($hashes) eq 'ARRAY') {
                    $report .= scalar(@$hashes)." reads found\n";
                    foreach my $hash (@$hashes) {
                        $hash = $hash->{read_id}; # replace each hash by its value
                    }
                    my $extra = $READS->associate('readname',$hashes,'read_id',{returnScalar => 0});
                    push @$reads, @$extra if @$extra;
                }
                elsif ($hashes) {
                    $report = "no deallocated reads found\n";
                }
                else {
                    $full = 2; # failed query, try to recover
                }
            }
            else {
                $full = 2; # creation of R2CTEMP probably failed, try to recover
            }
	}

        if ($full == 2) {
# second alternative method: scan READS2CONTIG with simple queries; first find al reads with generation > 1
            $report .= "with consecutive queries on READS2CONTIG and READS: ";
            my $R2C = $READS->spawn('READS2CONTIG','<self>',0,0); # get table handle
            $READS->autoVivify($self->{database},0.5); # build links (existing tables only)
            $hashes = $READS->associate('distinct readname','where',"generation > 1",{returnScalar => 0});
            if (ref($hashes) eq 'ARRAY' && @$hashes) {
                undef my %added; # the ones with generation > 1
                foreach my $name (@$hashes) {
                   $added{$name}++;
                }
# now find al reads with generation <=1 and get the difference
                $hashes = $READS->associate('distinct readname','where',"generation <= 1",{returnScalar => 0});
                foreach my $name (@$hashes) {
                    delete $added{$name};
                }
# what's left has to be added to @reads
                my $n = keys %added;
                $report .= "$n reads found\n";
                push @$reads, keys(%added) if $n;
            }
            elsif ($hashes) {
                $report .= "NONE found\n";
            }
            else {
                $report = "WARNING: error in query:\n $READS->{lastQuery} \n"; 
            }
	}
        $self->{report} = $report;
        undef $hashes;
    }

print $self->{report} if $DEBUG;
my $n = @$reads; print "reads $reads  $n  $reads->[0] $reads->[$n-1]\n" if $DEBUG;

    return $reads;
}

#--------------------------- documentation --------------------------
=pod

=head1 method getUnassembledReads

=head2 Synopsis

Find reads in current database which are not allocated to any contig

=head2 Parameters

mode (optional)

= 0 for quick search (fastest, but relies on integrity of READS2ASSEMBLY table

= 1 for complete search using temporary table

= 2 for complete search without using temporary table (in case =1 fails)


=head2 Returns: reference to array of readnames

=cut
#############################################################################

sub cafUnassembledReads {
# fetch all unassembled reads and write data to a CAF file
    my $self = shift;
    my $FILE = shift;
    my $full = shift;

    my $count = 0;

    my $readnames = $self->getUnassembledReads($full);
    if (ref($readnames) eq 'ARRAY' && @$readnames) {

        my $start = 0;
        my $block = 1000;
        while (@$readnames) {
            $block = @$readnames if ($block > @$readnames);
print "processing next block $block\n";
            undef my @test;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @test, (shift @$readnames);
            }
# print "reads to be built: @test \n";
            my $readinstances = $self->getRead(\@test,'hashrefs','readname');
            foreach my $instance (@$readinstances) {
                $count++ if $instance->writeToCAF($FILE);
            }
            if ($count != @$readinstances) {
# error warning?
            }
            undef $readinstances;           
        }
        undef $readnames;
    }
    return $count; # 0 to signal NO reads found, OR query failed
}

#############################################################################

sub getContig {
    my $self = shift;
    my $name = shift;

    my $ContigRecall = $self->{ContigRecall} || return 0;

    my $contig = $ContigRecall->new($name,@_);

    return $contig; # handle to ? 
}

#--------------------------- documentation --------------------------
=pod

=head1 method getContig

=head2 Synopsis

Return a reference to a ContigRecall object 

=head2 Parameters

=over 4

=item name

name of contig OR contig id  (both if no value is given) OR name of 
contig attribute (e.g. Tag) (and a value is defined)

=item value

value of attribute to identify a contig

=cut

#############################################################################
#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "17 Jan 2003",
        updated =>    "17 Jan 2003",
    };
}

#############################################################################

1;
