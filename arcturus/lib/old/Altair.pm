package Altair;

# GeneDB interface to Arcturus database

use strict;

use Bootean;

our ($VERSION, @ISA);

@ISA = qw(Bootean);

use ContigRecall;

#----------------------------------------------------------------------------
# ALTAIRIANS
#
# Alleged Reptilian inhabitants of the Altair stellar system in the 
# constellation Aquila, in collaboration with a smaller Nordic human
# element and a collaborative Grey and Terran military presence. 
# Headquarters of a collective known as the "Corporate", which
# maintains ties with the Ashtar and Draconian collectives (Draconian).
#
# 'Men in Black': The Alien Encyclopedia
#----------------------------------------------------------------------------

#############################################################################
my $DEBUG = 0;
#############################################################################

sub new {
# constructor invoking the constructor of the Bootean class
    my $caller   = shift;
    my $database = shift;
    my $options  = shift;

# import options specified in $options hash

    undef my %options;
    $options = \%options if (!$options || ref($options) ne 'HASH');

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = $class->SUPER::new($database,$options) || return 0;

print "Altair: $self \n" if $DEBUG;

    my $CONTIGS = $self->{mother}->spawn('CONTIGS',$database);
    $self->dropDead("Cannot access CONTIGS table in database $database") if !$CONTIGS;

print "Altair: $CONTIGS $options \n" if $DEBUG;

    $self->{ContigRecall} = ContigRecall->init($CONTIGS, 1, $options->{DNA});
print "recall $self->{ContigRecall}\n" if $DEBUG;
my $list = $self->{mother}->listInstances; print $list if ($DEBUG>1);

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 METHOD B< new > (constructor)

=head2 SYNOPSIS

    Opens a connection to a named arcturus organism database

=head2 OUTPUT

    Returns a database connection object of the -> Bootean class 

=head2 PARAMETERS

=over 2

=item database: 

        (required) name of Organism Database to be accessed

=item options : 

        (optional) hash with access options

=back


    Options will be passed on to the L< Bootean | Bootean.pm > interface


    If write access to the database is required, specify with keys:

    "writeAccess => 1"

    "username => '<username>'"

    "password => '<password>'"

    Write access requires a username and password

=cut
#############################################################################
# Finishers Assembly Interface
#############################################################################

sub getContigById {
# in: (unique arcturus) contig_id
    my $self   = shift;
    my $contig = shift;
    my $noseq  = shift || 0;

    $self->dropDead("Please define a contig identifier") if !$contig;

    my $ContigRecall = $self->{ContigRecall};

    $self->dropDead("Altair interface not correctly initialised") if !$ContigRecall;

    return $ContigRecall->getContigHashById($contig,$noseq,1); # long read
}
#--------------------------- documentation --------------------------
=pod

=head1

=head1 METHOD B< getContigById >

=head2 SYNOPSIS

    Get contig descriptors for contig identified by id number

=head2 PARAMETERS

=over 2

=item contig_id

    The (internal) arcturus contig identification number

=item no_sequence_flag

    Set flag to TRUE if no sequence is to be returned in the hash

=back

=head2 OUTPUT

 On success returns a data hash with contig descriptors

 On failure returns 0 or data hash with single I< status > key



 The data hash can contain any of the following:

=over 5

=item  contig_id

    The (input) contig identification number

=item  contigname

    Full (unique) arcturus contig name (e.g. 125c1-000041598472-bbcb)

=item  aliasname

    Original (usually Phrap) contig identifier (e.g. Contig610)

=item  projectname

    Project name or "UNKNOWN"

=item  assembly

    Assembly name or "UNKNOWN"

=item  generation

    The assembly generation count (1 for most recent)

=item  date

    Date of last update 

=item  sequence

    DNA consensus sequence OR a string "not requested" or "NOT FOUND" 

=item  sequencelength

    The number of bases in the string; present if DNA;

=item  status

    The only key guaranteed to be present

    Can have one of the following values:

=over 5

=item  Passed

=item  Incomplete

=item  Inconsistent

=item  Not found (ID)

=item  FAILED

=back

=back

=cut

#############################################################################

sub getContigByAlias {
# in: contig alias (projectname) (assemblyname) to resolve possible ambiguity
    my $self    = shift;
    my $alias   = shift;
    my $options = shift;

    $self->dropDead("Please provide a contig alias") if !$alias;

    my $ContigRecall = $self->{ContigRecall};

    $self->dropDead("Altair interface not correctly initialised") if !$ContigRecall;

    my $cids = $ContigRecall->findContigByAlias($alias, $options);

    return $cids; 
}

sub getContigByName {
# special case for getContigByAlias using only contig name or alias name
    my $self = shift;
    my $name = shift;
    my $opts = shift; # hash with control parameters

    my %opts; $opts = \%opts if !$opts;
    $opts->{mask} = '1000';

    return $self->getContigByAlias($name,$opts);
}

sub getContigByRead {
# special case for getContigByAlias using only readname
    my $self = shift;
    my $name = shift;
    my $opts = shift; # hash with control parameters

    my %opts; $opts = \%opts if !$opts;
    $opts->{mask} = '0100';

    return $self->getContigByAlias($name,$opts);
}

sub getContigByClone {
# special case for getContigByAlias using only clone name
    my $self = shift;
    my $name = shift;
    my $opts = shift; # hash with control parameters

    my %opts; $opts = \%opts if !$opts;
    $opts->{mask} = '0010';

    return $self->getContigByAlias($name,$opts);
}

sub getContigByTag {
# special case for getContigByAlias using only tag name
    my $self = shift;
    my $name = shift;
    my $opts = shift; # hash with control parameters

    my %opts; $opts = \%opts if !$opts;
    $opts->{mask} = '0001';

    return $self->getContigByAlias($name,$opts);
}
#--------------------------- documentation --------------------------
=pod

=head1

=head1 METHOD getContigByAlias

=head2 SYNOPSIS

Generic method to return a contig using its association with one of several

database items: contigname, readname, clone, tagname

=head2 OUTPUT

Depends on control options, either

=over 2

=item An array of contig_ids

    The array will be empty (zero length) if no contigs satisfy 
    the search conditions

=item A data hash

    The hash contains contig descriptors as documented with 
    method getContigById.

    See under getContigById for description of keyed hash values

    Always check the 'status' key

    In addition, one extra hash item may be returned: 'alternates'. If
    defined, the data hash returned is of the most recent contig
    fitting the search conditions. There were other contigs found;
    'alternates' contains a list of their contig_ids.

=back

=head2 PARAMETERS

=over 2

=item name

    (required) name of database item associated with contig

=item options 

    (optional) hash with control options; specify keys as:

=over 4

=item project => <name>

    (optional) name of the assembly project; default 0

=item assembly => <name>

    (optional) name of assembly; default 0

    if also a project is defined, both assembly and project are tested 

=item returnIds => 1

    return contig ids in an array; default 0, for return of a contig hash    

=item noSequence => 1

    return all contig descriptors except for the DNA sequence; default 0

=back

=back

=head2 ALTERNATIVE METHODS

 The following methods are special cases of getContigByAlias; they
 take the same input and have the same output.

=over 4

=item getContigByName

    Search on contigname or aliasname only

=item getContigByRead

    Search for a contig linked to the specified read

=item getContigByClone

    Search for contig(s) covered by the specified clone
    This may return a long list; use returnIds => 1

=item getContigByTag

    Search for a contig containing the specified tag

=back

=cut

#############################################################################

sub getMappedRange {
# in  old contig id, ranges
    my $self = shift;
    my $cntg = shift; # contig id or name
    my $poss = shift; # array reference with positions to be transformed

    my $ContigRecall = $self->{ContigRecall};

    if ($cntg =~ /\w/) {
        $cntg = $ContigRecall->findContigByName($cntg);
        $cntg = $cntg->[0] if (ref($cntg) eq 'ARRAY');
    }

    $cntg = $ContigRecall->traceForward($cntg, $poss);

    return $cntg;
}
#--------------------------- documentation --------------------------
=pod

=head1

=head1 METHOD getMappedRange

=head2 SYNOPSIS

Transpose a list of positions on a given contig to the corresponding

contig and positions in the latest assembly. 

=head2 OUTPUT

Returns the contig_id in the latest assembly

Returns the transposed positions in the input array

=cut

#############################################################################

sub getMappedContig {
# find the contig in the last assembly corresponding to input contig (id)
    my $self = shift;
    my $cntg = shift; # contig_id or name

    my $ContigRecall = $self->{ContigRecall};

    if ($cntg =~ /\w/) {
        $cntg = $ContigRecall->findContigByName($cntg);
        $cntg = $cntg->[0] if (ref($cntg) eq 'ARRAY');
    }

    return $ContigRecall->traceForward($cntg);
}
#--------------------------- documentation --------------------------
=pod

=head1

=head1 METHOD getMappedContig

=head2 SYNOPSIS

Find the contig in the last assembly corresponding to input contig

(as contig_id or contig name or alias name)

=head2 OUTPUT

Returns the contig_id in the latest assembly or undefined if not found

=cut

#############################################################################

sub test {
# return contig id (redundent?)
# in  old contig id, ranges
    my $self = shift;
    my $cntg = shift;

    my $ContigRecall = $self->{ContigRecall};

    my $list = $ContigRecall->traceLister($cntg);
    print $list;

}


#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.9 ,
        date    =>    "02 Jun 2003",
        updated =>    "13 Jun 2003",
    };
}

#############################################################################

1;

