package Bootes;

# ASP/loader interface to Arcturus database

use strict;

use Bootean;

use vars qw($VERSION @ISA); #our ($VERSION, @ISA);

@ISA = qw(Bootean);

use ReadsReader;

#############################################################################
my $DEBUG = 0;
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
# return read_id or array of read_ids for input readname(s)
    my $self = shift;
    my $name = shift;

    my $READS = $self->{READS} || return 0;

    my %options = (traceQuery => 0, returnScalar => 0);

    return $READS->associate('read_id',$name,'readname',\%options);
}
#--------------------------- documentation --------------------------
=pod

=head1 method probeRead

=head2 Synopsis

Retrieve read_id for named read

=head2 Parameter: the read name

=cut
#############################################################################

sub getReadNames {
# return array of readnames in database (possibly satisfying some criterium)
    my $self  = shift;
    my $where = shift;

    my $READS = $self->{READS} || return 0;

    my %options = (traceQuery => 0, returnScalar => 0);

    if ($where && $where =~ /[a-zA-Z]/) {
# the where condition contains a name (hence a column name somewhere)
        $READS->autoVivify($self->{database},3);
        $options{traceQuery} = 1;
    }
    else {
        $where = '1';
    }

    return $READS->associate('readname','where',$where);
}
#--------------------------- documentation --------------------------
=pod

=head1 method getReadNames

=head2 Synopsis

Retrieve the readnames in the current database; a selection condition can be
specified as a SQL "where" clause. 

=head2 Parameter (optional): the SQL "where" clause

=cut
#############################################################################

sub putRead {
# enter hash with read items into database
    my $self = shift;
    my $hash = shift;
    my $opts = shift;

    my $ReadsReader = $self->{ReadsReader};

    $self->dropDead("No write access granted") if !$ReadsReader;

    my $TEST = 1;
    my %options = (sencode => 99, qencode => 99, readback => 1, dataSource => 1);
    $self->importOptions(\%options, $opts);

    my $inserted = 0;

    if ($self->allowTableAccess('READS',1)) {

      if ($TEST) {
        $inserted = $ReadsReader->insertRead($hash, $opts);
      }
      else {

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

readback   : (default 1) After writing to database table, verify by readback 

dataSource : 1 = experiment (asped) file (default); 2 = Oracle; 3 = Foreign

=back

=head2 Returns: number of read items loaded

=cut
#############################################################################

sub putPendingReads {
# enter read names into the PENDING table
    my $self  = shift;
    my $names = shift || return 0; # name or array reference

    $self->{PENDS} = $self->{READS}->spawn('PENDING');

    $self->{PENDS}->setMultiLineInsert(200);

    my $success = 0;

    if ($self->allowTableAccess('PENDING',1)) {

        undef my @names; $names[0] = $names;
        $names = \@names if (ref($names) ne 'ARRAY');

        foreach my $name (@$names) {

            $success++ if $self->{PENDS}->newrow('readname',$name);
        }
    }

    $self->{PENDS}->flush();

    if ($success) {
 
        $self->{mother}->update('reads_pending',$success,'dbasename',$self->{database});

    }

    return $success;
}

#--------------------------- documentation --------------------------
=pod

=head1 method pendingReads

=head2 Synopsis

Enter a read into the PENDING table of the current arcturus organism database

use as:  ->pendingReads(\@names)

=head2 Parameter "names"

       (single) read name OR reference to array with read names

       The array method is much more efficient than single entries

=head2 Returns: number of read names entered

=cut

#############################################################################

sub cafImportForeignReads {
# import foreign reads from a caf file
    my $self = shift;
    my $file = shift;
    my $opts = shift;

    my $ReadsReader = $self->{ReadsReader};

    $self->dropDead("No write access granted") if !$ReadsReader;

    if ($self->allowTableAccess('READS',1)) {
# ensure that the data source is defined as foreign by default
        my %opts; $opts = \%opts if !$opts;
        $opts->{dataSource} = 3  if !$opts->{dataSource};

        if (!$ReadsReader->cafFileReader($file,$opts)) {
            my ($status, $errors) = $ReadsReader->status(2);
            $self->{GateKeeper}->report("No data loaded");
            $self->{GateKeeper}->report("$status") if $errors;
            return;
        }
# update ORGANISMS table etc.
        my $userid = $self->{USER} || 'arcturus';
        $ReadsReader->housekeeper($userid);
    }

}

#############################################################################

sub setTraceStatus {
# confirm that the read is entered into the trace archive by setting 'tstatus'
    my $self   = shift;
    my $name   = shift; # read name, compulsory
    my $status = shift || 'T'; 

    my $success = 0;

# will fail if status not one of 'N', 'I' or 'T'

    if ($self->allowTableAccess('READS',1)) {

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

=item name   : the read name

=item status : either 'N', 'I', or 'T'; default 'T'

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

sub repairReads {

    my $self = shift;

    $self->allowTableAccess('READS',1);

    my $ReadsReader = $self->{ReadsReader} || return 0;

    return $ReadsReader->repairReads(@_);
}

#--------------------------- documentation --------------------------
=pod

=head1 method repairReads

=head2 Synopsis:

Runs through the READS table and tests DNA against Quality Data for length
missmatch. Repairs Quality data for consensus sequences by shifting leading
spurious zero (added by an error in earlier version of rloader script)

=head2 Parameters:

=over 3

=item commit (0 or 1)

=item start read_id (default 1)
 
=item final read_id (default all)

=back

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
        updated =>    "02 Dec 2003",
    };
}

#############################################################################

1;
