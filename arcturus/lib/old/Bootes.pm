package Bootes;

# ASP interface to Arcturus database

use strict;

use Bootean;

use vars qw($VERSION @ISA); #our ($VERSION, @ISA);

@ISA = qw(Bootean);

use ReadsReader;

#############################################################################
my $DEBUG = 1;
#############################################################################
sub new {
# constructor invoking the constructor of Bootean class
    my $caller   = shift;
    my $database = shift;
    my $options  = shift;

# import options specified in $options hash

    undef my %options;
    $options = \%options if (!$options || ref($options) ne 'HASH');
    $options->{writeAccess}   = 'READS' if $options->{writeAccess};
    $options->{oracle_schema} = '' if !$options->{oracle_schema};
    $options->{DNA}           = '' if !$options{DNA};

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = $class->SUPER::new($database,$options) || return 0;

print "Bootes: $self \n" if $DEBUG;

    $self->{READS} = $self->{mother}->spawn('READS',$database); 

    $self->{ReadsReader} = new ReadsReader($self->{READS}, $options->{DNA}, $options->{oracle_schema});

print "ReadsReader module $self->{ReadsReader} \n" if $DEBUG;

    return $self;
}
#--------------------------- documentation --------------------------
=pod

=head1 new (constructor)

=head2 Synopsis

ASP interface to Arcturus database; this interface allows
any query on the database, but restricts writing access to the
READS table (and its dictionary tables)

=head2 Parameters:

=over 2

=item database

The name of the Arcturus database to be used

=item options

Options communicated as a hash with the option names as keys:

=over 5

=item HostAndPort:

format "host:port"; if not specified a default host and port will be
used, if any is available.

=item writeAccess:

Specify as true if write access is needed. Write access requires a 
username and password to be specified as well.

=item username (or, as alternative, 'identify')

Your Arcturus username

=item password

Password for the given username

=item oracle_scheme

Possibly required when loading new reads to locate SCF files; in its 
absence chemistry info will be labeled as undefined and a read will
not be loaded

=item DNA

6 character encoding string for reads DNA sequence; default 'ATCG- '

=back

=back

=cut
#############################################################################

sub probeRead {
# return hash or array of hashes with read items
    my $self = shift;
    my $name = shift;

    my $READS = $self->{READS} | return 0;

    return $READS->associate('read_id',$name,'readname');
}
#--------------------------- documentation --------------------------
=pod

=head1 method probeRead

=head2 Synopsis

Retrieve read_id for named read

=head2 Parameter: the read name

=cut
#############################################################################

sub putRead {
# enter hash with read items into database
    my $self = shift;
    my $hash = shift;
    my $opts = shift;

    my $ReadsReader = $self->{ReadsReader};

    $self->dropDead("No write access granted") if !$ReadsReader;

    my %options = (sencode => 1, qencode => 3, readback => 1, dataSource => 1);
    $self->importOptions(\%options, $opts);

    my $inserted = 0;

    if ($self->allowTableAccess('READS')) {


        $ReadsReader->erase;
        $ReadsReader->enter($hash, $options{dataSource});

# test the contents

        $ReadsReader->format;
        $ReadsReader->ligation;
        $ReadsReader->strands;
        $ReadsReader->chemistry;

# check possible error status ...

        my ($summary, $errors) = $ReadsReader->status(2,0);

print "summary $summary \nerrors $errors \n" if $DEBUG;

        if ($errors) {
            $errors = "Contents error(s) for putRead: $summary\n";
        }

# encode and dump the data

        elsif ($errors = $ReadsReader->encode($options{sencode}, $options{qencode})) {
            $errors = "Encode error status in putRead: $errors\n";
        }

        elsif (!($inserted = $ReadsReader->insert(1))) {
# get error information
           ($summary, $errors) =  $ReadsReader->status(2,0);
            $errors = "Failed to insert read; $summary, $errors\n";
        }

        elsif ($options{readback} && ($errors = $ReadsReader->readback)) {
            $errors = "Readback error status in putRead: $errors\n";
        }

print "putRead errors: $errors \n" if $DEBUG;
# note rollback in multi mode inserts is not applicable
        $ReadsReader->rollBack($errors,'SESSIONS'); # undo any changes to dictionary tables if errors

    }

    return $inserted; # e.g. number of read items inserted
}

#--------------------------- documentation --------------------------
=pod

=head1 method putRead

=head2 Synopsis

Enter a read into the current arcturus organism database

use as:  ->putRead($hash, $optionshash)

=head2 Parameters: 

=over 1

=item hash

hash table with read data keyed on standard Sanger items (e.g. RN, SQ, etc)

=item options (optional)

hash image with options presented as data keyed on the option name:

sencode    : (default 1) Sequence compression code [0 - 2]

qencode    : (default 3) Quality data compression code [0 - 3]

readback   : (default 1) After writing to database table, verify by readback 

dataSource : 0 = undefined; 1 = experiment file (default); 2 = Oracle;

=back

=head2 Returns: reference to array of readnames

=cut
#############################################################################

sub setTraceStatus {
# confirm that the read is entered into the trace archive by setting 'tstatus'
    my $self   = shift;
    my $name   = shift; # read name, compulsory
    my $status = shift || 'T'; 

    my $success = 0;

# will fail if status not one of 'N', 'I' or 'T'

    if ($self->allowTableAccess('READS')) {

        $success = $self->{READS}->update('tstatus',$status,'readname',$name);
    }

    return $success;   
}

#--------------------------- documentation --------------------------
=pod

=head1 method setTraceStatus

=head2 Synopsis

Set tstatus flag in READS table to signal that a read has been entered into the 
trace archive

=head2 Parameters: 

=over 1

=item name:  the read name

=back

=head2 Returns true if successful

=cut
#############################################################################

sub getNotInTrace {
# return a list of reads which are labeled as not yet entered into the trace archive
    my $self = shift;

    my $READS = $self->{READS} || return 0;

    my %options = (orderBy => 'readname', returnScalar => 0);
    my $reads = $READS->associate('readname','N','tstatus',\%options);

    return $reads; # always array reference
}

#--------------------------- documentation --------------------------
=pod

=head1 method getNotInTrace

=head2 Synopsis

Find reads in current database which are labeled as not yet entered into the 
trace archive 

=head2 Parameters: none

=head2 Returns: reference to array of readnames

=cut
#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "17 Jan 2003",
        updated =>    "20 Jan 2003",
    };
}

#############################################################################

1;


