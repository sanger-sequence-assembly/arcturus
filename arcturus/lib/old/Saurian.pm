package Saurian;

# Assembler interface to Arcturus database

use strict;

use Bootean;

#use vars qw($VERSION @ISA); 
our ($VERSION, @ISA);

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
    if (my $wa = $options->{writeAccess}) {
        $options->{writeAccess} = \@tables if ($wa !~ /[a-z]/i);
    }

# determine the class and invoke the class variable

    my $class = ref($caller) || $caller;
    my $self  = $class->SUPER::new($database,$options) || return 0;

# open ReadsReader and ContigReader modules

    $self->{READS}         = $self->{mother}->spawn('READS',$database); 
    $self->{ReadsRecall}   = ReadsRecall->init($self->{READS},'ACGTN ');
    $self->{ContigRecall}  = ContigRecall->init($self->{READS});
    if ($options->{writeAccess}) {
        $self->{ContigBuilder} = ContigBuilder->init($self->{READS},1);
    }

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 new (constructor)

=head2 Synopsis

Opens a connection to a named arcturus organism database

Returns a database connection object of the Bootean clas 

=head2 Parameters:

=over 2

=item database: (required) name of Organism Database to be accessed

=item options : (optional) hash with access options

Options will be passed on to the => Bootean interface; in addition a
request for write access to the database has to be specified with key;

"writeAccess => 1"

=back

=cut
#############################################################################

sub getRead {
# return hash or array of hashes with read items
    my $self = shift;
    my $name = shift;

    my $ReadsRecall = $self->{ReadsRecall} || return 0;

    undef my $read;
    if (ref($name) eq 'ARRAY') {
        $read = $ReadsRecall->spawnReads($name, @_); # returns array of objects
    }
    else {
        $read = $ReadsRecall->new($name); # returns (single) ReadsRecall object
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

Returns a single object of the ReadsRecall class for a named read

Read items can be accessed in $object->{readdata}->{}

=item name: reference to array of readnames

Returns an array of ReadsRecall objects

=back

=cut

#############################################################################

sub probeRead {
# return read_id for named read
    my $self = shift;
    my $name = shift;

    return $self->{READS}->associate('read_id',$name,'readname');
}
#--------------------------- documentation --------------------------
=pod

=head1 method probeRead

=head2 Synopsis

Retrieve readid for named read

=head2 Parameter: the read name

=cut
#############################################################################
#############################################################################

sub getUnassembledReads {
# short way using READS2ASSEMBLY; long way with a left join READS, R2CR2
    my $self = shift;
    my $hash = shift || 0; # default "short" & no date selection

# decode input "hash"

    my $date = 0;
    my $full = $hash;
    if (ref($hash) eq 'HASH') {
        $full = $hash->{full} || 0;
        $date = $hash->{date} || 0;
    }

    my $READS = $self->{READS}; # the READS table handle in the current database 

    my $reads;

    if (!$full) {

# short option: use info in READS2ASSEMBLY.astatus (assuming it to be complete and consistent)

        my $R2A = $READS->spawn('READS2ASSEMBLY','<self>',0,0); # get table handle
        $READS->autoVivify($self->{database},0.5); # build links (existing tables only)
# find the readnames in READS by searching on astatus in READS2CONTIG
        if (!$date) {
            $reads = $READS->associate('readname',"! '2'",'astatus',{returnScalar => 0});
        }
        else {
# TO BE TESTED !!
            my $where = "date <= '$date' and astatus != 2";
            $reads = $READS->associate('readname','where',$where,{returnScalar => 0});
        }
        if (!$reads) {
            $self->{report} = "! INVALID query in Saurian->getUnassembledReads: $READS->{lastQuery}\n";
        }
    }

    else {

# the long way, bypassing READS2ASSEMBLY; first find all reads not in READS2CONTIG

        my $report = "Find all reads not in READS2CONTIG with left join: ";
        my $ljoin = "select distinct READS.readname from READS left join READS2CONTIG ";
        $ljoin  .= "on READS.read_id=READS2CONTIG.read_id ";
        $ljoin  .= "where READS2CONTIG.read_id IS NULL ";
# TO BE TESTED !!!
        $ljoin  .= "and date <= '$date' " if $date;
        $ljoin  .= "order by readname"; 
#print "DATE test unassembled reads: $ljoin\n" if $date;
# this query gets all reads in READS not referenced in READS2CONTIG
        undef my @reads;
        $reads = \@reads;
        my $hashes = $READS->query($ljoin,0,0);
        if (ref($hashes) eq 'ARRAY') {
            foreach my $hash (@$hashes) {
                push @reads,$hash->{readname};
            }
        }
        elsif (!$hashes) {
            $report .= "! INVALID query in Saurian->getUnassembledReads: $ljoin\n";
        }
        $report .= scalar(@reads)." reads found\n";

# now we check on possible (deallocated) reads in READS2CONTIG which do NOT figure in generation 0 or 1

        $report .= "Checking for reads deallocated from previous assembly ";
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
                    $report .= "no deallocated reads found\n$hashes\n$READS->{lastQuery}\n";
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
my $n = @$reads; print "reads $reads $n from $reads->[0] to $reads->[$n-1]\n" if $DEBUG;

    return $reads;
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

sub cafUnassembledReads {
# fetch all unassembled reads and write data to a CAF file
    my $self = shift;
    my $FILE = shift;
    my $hash = shift;

    my $count = 0;
    undef my @missed;

print "Finding unassembled reads ($hash)\n" if $DEBUG;
    my $readnames = $self->getUnassembledReads($hash);
print "readnames $readnames \n" if $DEBUG;
    if (ref($readnames) eq 'ARRAY' && @$readnames) {
# NOTE: bulk processing does not require separate cacheing (see spawnReads)
        my $start = 0;
        my $block = 1000;
        while (@$readnames) {
            $block = @$readnames if ($block > @$readnames);
print "processing block $start $block\n" if $DEBUG;
            undef my @test;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @test, (shift @$readnames);
            }
            $start += $block;
print "reads to be built: @test \n" if ($DEBUG > 1);
            my $readinstances = $self->getRead(\@test,'hashrefs','readname');
            foreach my $instance (@$readinstances) {
                if ($instance->writeReadToCaf($FILE)) {
                    $count++;
                }
                else {
                    push @missed,$instance->{readhash}->{readname};
                }
            }
            undef $readinstances;           
        }
        undef $readnames;
    }

print "$count reads output \n" if $DEBUG;
print "reads missed: @missed \n" if ($DEBUG && @missed);

    return $count; # 0 to signal NO reads found, OR query failed
}

#--------------------------- documentation --------------------------
=pod

=head1 method cafUnassembledReads

=head2 Synopsis

Find reads in current database which are not allocated to any contig and
write them out on a caf-formatted output file

=head2 Parameters

=over 2

=item file (required) 

File handle of output device; can be \*STDOUT

=item hash (optional)

=over 2

=item hash key 'full'

= 0 for quick search (fastest, but relies on integrity of READS2ASSEMBLY table)

= 1 for complete search using temporary table; if this fails falls back on:

= 2 for complete search without using temporary table

=item hash key 'date'

Select only reads before and including the given date

=head2 Output

Is written onto the file handle (about 3-5 Kbyte per read)

=cut
#############################################################################

sub getContig {
# return a ContigRecall object(s) for named contig(s)
    my $self = shift;
    my $name = shift;

$DEBUG = 1;

    my $ContigRecall = $self->{ContigRecall} || return 0;

    my $contigrecall;
    if (ref($name) eq 'ARRAY') {
# return an array of ContigRecall objects
        undef my @contigrecall;
        $contigrecall = \@contigrecall;
print "building contig " if $DEBUG;
        foreach my $contig (@$name) {
            my $getContig = $self->getContig($contig);
            push @contigrecall, $getContig  if $getContig;
my $nr = @contigrecall; print "$nr .. " if ($DEBUG && ($nr == 1 || !($nr%50)));
        }
print "\n" if $DEBUG;
    }
    else {
        $contigrecall = $ContigRecall->new($name,@_);
    }

    return $contigrecall; 
}

#--------------------------- documentation --------------------------
=pod

=head1 method getContig

=head2 Synopsis

Return a reference to a ContigRecall object 

=head2 Parameters

=over 2

=item name

name of contig OR contig ID (both if no value is given) OR name of 
contig attribute (e.g. Tag) (and then a value must be defined)

=item value

value of attribute to identify a contig

=cut
#############################################################################

sub cafContig {
# write mappings of named contig(s) and its reads onto a filehandle in caf format
    my $self = shift;
    my $FILE = shift; # reference to file handle
    my $name = shift || return 0; # name or list of names (compulsory)
print "cafContig $name \n";

    my $ccaf = 0;

    if (ref($name) ne 'ARRAY') { 
print "get contig $name \n";
        my $contig = $self->getContig($name);
        $ccaf++ if $contig->writeToCaf($FILE);
    }

    else { 
        my $start = 0;
        my $block = 1000;
        while (@$name) {
            $block = @$name if ($block > @$name);
print "processing block $start $block\n" if $DEBUG;
            undef my @test;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @test, (shift @$name);
            }
            $start += $block;
print "contigs to be built: @test \n" if ($DEBUG > 1);
            my $contiginstances = $self->getContig(\@test);
#undef @$contiginstances;
            foreach my $instance (@$contiginstances) {
                if ($instance->writeToCaf($FILE)) {
                    $ccaf++;
                }
                else {
# test for error?
#                    push @missed,$instance->{readhash}->{readname};
                }
            }
            undef $contiginstances;           
        }
        undef $name;
    }

    return $ccaf;
}

#############################################################################

sub cafAssembly {
# write all contigs (and mappings) in generation 1 to file in CAF format
    my $self = shift;
    my $FILE = shift; # reference to file handle

print "cafAssembly entered \n";

# do the query on CONTIGS instead of READS2CONTIGS for speed!

    my $READS   = $self->{READS};
    my $CONTIGS = $READS->spawn('CONTIGS');
    my $RTAGS   = $READS->spawn('READTAGS');
    my $R2C     = $READS->spawn('READS2CONTIGS');
# contig tags
    $CONTIGS->autoVivify($self->{database},0.5);

    my %opts = (returnScalar => 0);
    my $cids = $CONTIGS->associate('distinct contig_id',1,'generation',\%opts);
print "last query: $CONTIGS->{lastQuery}\n";
print "output R2C search: $cids @$cids \n";

# cache all data in READS, READTAGS, READS2CONTIG and contig TAGS on initialization

    my $cacheing = 1;
    if ($cacheing) {
print "READS cache being built \n";
my $tstart = time;
        my $query = "select * from <self>";
        $READS->cacheBuild($query,'read_id',{list => 1});
my $tfinal = time;
my $elapsed = $tfinal - $tstart;
print "load  time $tstart $tfinal, elapsed $elapsed seconds\n\n";
print "READTAGS cache being built \n";
$tstart = $tfinal;
        $RTAGS->cacheBuild($query,'read_id',{list => 1});
$tfinal = time;
$elapsed = $tfinal - $tstart;
print "load  time $tstart $tfinal, elapsed $elapsed seconds\n\n";

# R2C maps
# CONTIG tags
# Consensus
    }

    $self->cafContig($FILE,$cids);    
}

#############################################################################

sub update {
# update counters for assembly status
    my $self       = shift;
    my $assembly   = shift;
    my $generation = shift;

    print "enter update: $self->{ContigBuilder} \n";
    my $ContigBuilder = $self->{ContigBuilder} || return 0;

    $self->allowTableAccess('ASSEMBLY',1);

    return $ContigBuilder->updateAssembly($assembly, $generation,@_);
}

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
        updated =>    "12 Sep 2003",
    };
}

#############################################################################

1;
