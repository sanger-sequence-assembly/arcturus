package Bootes;

# interface to Arcturus database

use strict;

use GateKeeper;
use ReadsReader;
use ReadsRecall;
use ContigBuilder;
use ContigRecall;

#############################################################################
# class variables
#############################################################################

my $GateKeeper;
my $ReadsRecall;
my $ReadsReader;
my $ContigRecall;

#############################################################################

sub new {
# constructor
    my $prototype = shift;
    my $dbasename = shift;
    my $options   = shift; # hash image with options (open reading, writing, with authorization)

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

# get options

    my %options = (writeAccess => 0, username => 0, password => 0, readsOnly => 0, DNA => '');
    &importOptions (\%options,$options); # override with input options, if any

# initialize gate keeper and get ArcturusTable handle

    $GateKeeper = new GateKeeper('mysql',$options) if !$GateKeeper;

    $self->{mother} = $GateKeeper->dbHandle($dbasename,{returnTableHandle => 1, defaultRedirect => 2});

# make $dbasename default

    $GateKeeper->focus({dieOnError => 1}); 
    $self->{database} = $dbasename;

# open ReadsReader and ContigReader modules

    $self->{READS} = $self->{mother}->spawn('READS',$dbasename); 
    $ReadsRecall  = ReadsRecall->init($self->{READS});
    $ContigRecall = ContigRecall->init($self->{READS}) if !$options{readsOnly};

# prepare for write access

    if ($options{writeAccess}) {
# test authorisation ($options username and password, or session)
        delete $options{writeAccess};
        $options{makeSession}  = 2;
        $options{dieOnError}   = 1;
        $options{closeSession} = 0;
        if ($GateKeeper->authorize(100,\%options)) {
            $self->{session} = $GateKeeper->{SESSION};
# open modules which write to database
            $ReadsReader = new ReadsReader($self->{READS}, $options{DNA});
#          $ContigBuilder
        }
        else {
	    print "authorization FAILED: $GateKeeper->{report} \n";
        }
        print "session $self->{session} \n";
    }

    return $self;
}

#*******************************************************************************

sub importOptions {
# private function 
    my $options = shift;
    my $hash    = shift;

    my $status = 0;
    if (ref($options) eq 'HASH' && ref($hash) eq 'HASH') {
        foreach my $option (keys %$hash) {
            $options->{$option} = $hash->{$option};
        }
        $status = 1;
    }

    $status;
}

#############################################################################

sub whereIs {
# find the server and port of the database
    my $self     = shift;
    my $database = shift;

    my $mother = $self->{mother};

    if (my $residence = $mother->associate('residence',$database)) {
        print "Database $database is on server $residence\n";
    }
    else {
        print "Unkown database $database\n";
    }
}

#############################################################################

sub getRead {
# return hash or array of hashes with read items
    my $self = shift;
    my $name = shift;

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

sub putRead {
# enter hash with read items into database
    my $self = shift;
    my $hash = shift;
    my $opts = shift;

    die "No write access granted\n" if !$ReadsReader;

    my %options = (sencode => 1, qencode => 3, readback => 1);
    &importOptions(\%options, $opts);

    my $inserted = 0;

    $ReadsReader->erase;
    $ReadsReader->enter($hash);

# test the contents

    $ReadsReader->format;
    $ReadsReader->ligation;
    $ReadsReader->strands;
    $ReadsReader->chemistry;

# check possible error status ...

    my ($summary, $errors) = $ReadsReader->status(2,0);

    if ($errors) {
        $errors = "Contents error(s) for putRead: $summary\n";
    }

# encode and dump the data

    elsif ($errors = $ReadsReader->encode($options{sencode}, $options{qencode})) {
        $errors = "Encode error status in putRead: $errors\n";
    }

    elsif (!($inserted = $ReadsReader->insert)) {
# get error information
       ($summary, $errors) =  $ReadsReader->status(2,0);
        $errors = "Failed to insert read in putRead: $summary\n";
    }

    elsif ($options{readback} && ($errors = $ReadsReader->readback)) {
        $errors = "Readback error status in putRead: $errors\n";
    }

    $ReadsReader->rollBack($errors); # undo any changes to dictionary tables if errors

    return $inserted; # e.g. number of read items inserted
}

#--------------------------- documentation --------------------------
=pod

=head1 method putRead

=head2 Synopsis

Enter a read into the current arcturus organism database

use as:  ->putRead($hash, {sencode=>1, ...}

=head2 Parameters: 

=over 1

=item hash

hash table with read data keyed on standard Sanger items (e.g. RN, SQ, etc)

=item options (optional)

hash image with options presented as data key on the option name:

sencode : (default 1) Sequence compression code [0 - 2]

qencode : (default 3) Quality data compression code [0 - 3]

readback : (default 1) After writing to database table, verify by readback 

=back

=head2 Returns: reference to array of readnames

=cut
#############################################################################

sub putInTrace {
# confirm that the read is entered into the trace archive by setting 'tstatus'
    my $self = shift;
    my $name = shift; # read name, compulsory

    my $READS = $self->{READS};
    my $success = $READS->update('astatus','A','readname',$name);

    return $success;   
}

#--------------------------- documentation --------------------------
=pod

=head1 method putInTrace

=head2 Synopsis

Signal that a read has been entered into the trace archive

=head2 Parameters: 

=over 1

=item name:  the read name

=back

=head2 Returns: reference to array of readnames

=cut
#############################################################################

sub getNotInTrace {
# return a list of reads which are labeled as not yet entered into the trace archive
    my $self = shift;

    my $READS = $self->{READS};

    my %options = (orderBy => 'readname', returnScalar => 0);
    my $reads = $READS->associate('readname','N','tstatus',\%options);

    return $reads;
}

#--------------------------- documentation --------------------------
=pod

=head1 method getNotInTrace

=head2 Synopsis

Find reads in current database which are labeled as not yet entered into the trace archive 

=head2 Parameters: none

=head2 Returns: reference to array of readnames

=cut
#############################################################################

sub getContig {
    my $self = shift;
    my $name = shift;

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

sub testAccess {
    my $self = shift;

    my $session = $self->{session};
    my $author = $GateKeeper->authorize(100,{session => $session});
    print "authorization: $author \n";
}

#############################################################################

sub ping {
# test if the database is alive
    my $self = shift;

    my $alive = 1;

    $alive = 0 if (!$self->{database} || !$GateKeeper->ping);

    return $alive;
}

#############################################################################

sub DESTROY {
# force disconnect and close session, if not done previously
    my $self = shift;

    $self->disconnect if $self->{database};
}

#############################################################################

sub disconnect {
    my $self = shift;

    my $session = $self->{session};

    $GateKeeper->closeSession($session) if $session;

    $GateKeeper->disconnect;

    delete $self->{database};
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "07 Sep 2002",
        updated =>    "11 Sep 2002",
    };
}

#############################################################################

1;
