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

sub cafRead {
# write named read into caf file (unpadded)
    my $self = shift;
    my $FILE = shift;
    my $name = shift; # read name or array of readnames

# to be extended using on the fly caf output for many reads

    my $read = $self->getRead($name); # returns a ReadsRecall object

    my @reads;
    my $reads = \@reads;
    (ref($read) eq 'ARRAY') ? $reads = $read: $reads->[0] = $read;

    my $count = 0;
    foreach my $instance (@$reads) {
        $count++ if ($instance->writeReadToCaf($FILE));
    }

    return $count; # compare externally with length of input nr of name(s)
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
=pod

=head1 method probeRead

=head2 Synopsis

Retrieve read ID for named read

=head2 Parameter: the read name

=cut
#############################################################################
#############################################################################

sub cafUnassembledReads {
# fetch all unassembled reads and write data to a CAF file
    my $self = shift;
    my $FILE = shift;
    my $opts = shift;

    my $ReadsRecall = $self->{ReadsRecall};

    my %hash; $opts = \%hash if !$opts; $opts->{onTheFly} = 1;

    return $ReadsRecall->cafUnassembledReads($FILE, $opts);
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

=over 3

=item hash key 'full'

= 0 for quick search (fastest, but relies on integrity of READS2ASSEMBLY table)

= 1 for complete search using temporary table; if this fails falls back on:

= 2 for complete search without using temporary table

=item hash key 'date'

Select only reads before and including the given date

=item hash key 'onTheFly'

Uses less memory if set to 1

=head2 Output

Is written onto the file handle (about 3-5 Kbyte per read)

=cut
#############################################################################

sub buildContig {
# return a ContigRecall object(s) for named contig(s)
    my $self = shift;
    my $name = shift;

$DEBUG = 1;

    my $ContigRecall = $self->{ContigRecall} || return 0;

    return $ContigRecall->buildContig($name,@_);
}

#--------------------------- documentation --------------------------
=pod

=head1 method buildContig

=head2 Synopsis

Build a ContigRecall object and its ReadsRecall objects

=head2 Parameters

=over 2

=item name

contig identifier: name of contig or contig ID or value of an
attribute (e.g. a tag name)

=item options

hash image with options:

=head2 Output

Return the reference the ContigRecall object

=cut
#############################################################################

sub cafDumpContig {
# write mappings of named contig(s) and its reads onto a filehandle in caf format
    my $self = shift;
    my $FILE = shift; # reference to file handle
    my $name = shift || return 0; # name or list of names (compulsory)
    my $padd = shift || 0;

print "cafDumpContig $name padded $padd\n";

    my $ccaf = 0;

    if (ref($name) ne 'ARRAY') {
print "get contig $name \n";
        my $contig = $self->buildContig($name);
        $ccaf++ if $contig->dumpThisToCaf($FILE,$padd);
    }

    else { 
$DEBUG=1;
        my $start = 0;
        my $block = 10;
        while (@$name) {
            $block = @$name if ($block > @$name);
print "Saurian::processing block $start $block\n" if $DEBUG;
            undef my @test;
            for (my $i = 0 ; $i < $block ; $i++) {
                push @test, (shift @$name);
            }
            $start += $block;
print "contigs to be built: @test \n" if ($DEBUG > 1);
            my $contiginstances = $self->buildContig(\@test);
print "contig instances: $contiginstances @$contiginstances\n" if ($DEBUG > 1);
            foreach my $instance (@$contiginstances) {

                if ($instance->dumpThisToCaf($FILE,$padd)) {
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
sub cafTestContig {
# test generate contig
    my $self = shift;
    my $FILE = shift; # reference to file handle
    my $nmbr = shift;
    my $cache = shift;

    my $ContigRecall = $self->{ContigRecall} || return 0;

    my $READS   = $self->{READS};
    my $CONTIGS = $READS->spawn('CONTIGS');
    my $RTAGS   = $READS->spawn('READTAGS');
    my $R2C     = $READS->spawn('READS2CONTIG');

# build cached data

    $ContigRecall->prepareCaches($nmbr) if $cache;

    my $reads = $R2C->cacheRecall($nmbr,{indexName=>'contigs'});

    $reads = $R2C->usePreparedQuery('readsQuery',$nmbr) if !$reads;

#    if (my $reads = $R2C->cacheRecall($nmbr,{indexName=>'contigs'})) {

# or prepared query?
    if ($reads) {

        foreach my $hash (@$reads) {
            $hash = $hash->{read_id};
        }

        $READS->prepareCaches($reads) if $cache;

        $ContigRecall->writeToCafPadded($FILE,$nmbr);
    }
    else {
        print "No data found! (No such contig $nmbr in generation 1, perhaps ?)\n";
    }
}

sub cafAssembly {
# write all contigs (and mappings) in generation 1 to file in CAF format
    my $self = shift;
    my $FILE = shift; # reference to file handle

print "cafAssembly entered \n";

# do the query on CONTIGS instead of READS2CONTIGS for speed!

    my $READS   = $self->{READS};
    my $CONTIGS = $READS->spawn('CONTIGS');
    my $RTAGS   = $READS->spawn('READTAGS');
    my $R2C     = $READS->spawn('READS2CONTIG');
# contig tags
    $CONTIGS->autoVivify($self->{database},0.5);

    my %opts = (returnScalar => 0, orderBy => 'contig_id');
#    my $cids = $CONTIGS->associate('distinct contig_id',1,'generation',\%opts);
    my $where = "generation=1 and label>=10";
    my $cids = $R2C->associate('distinct contig_id','where',$where,\%opts);
print "last query: $CONTIGS->{lastQuery}\n";
print "last query: $R2C->{lastQuery}\n";
print "output R2C search: $cids @$cids \n";

# cache all data in READS, READTAGS, READS2CONTIG and contig TAGS on initialization

    my $cacheing = 0;
    if ($cacheing) {
print "READS cache being built \n";
my $tstart = time;
        my $query = "select * from <self>";
#        $READS->cacheBuild($query,'read_id',{list => 1});
my $tfinal = time;
my $elapsed = $tfinal - $tstart;
print "load  time $tstart $tfinal, elapsed $elapsed seconds\n\n";
print "READTAGS cache being built \n";
$tstart = $tfinal;
#        $RTAGS->cacheBuild($query,'read_id',{list => 1});
$tfinal = time;
$elapsed = $tfinal - $tstart;
print "load  time $tstart $tfinal, elapsed $elapsed seconds\n\n";

# R2C maps
# CONTIG tags
# Consensus
    }

    $self->cafDumpContig($FILE,$cids,0);
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

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "17 Jan 2003",
        updated =>    "20 Oct 2003",
    };
}

#############################################################################

1;
