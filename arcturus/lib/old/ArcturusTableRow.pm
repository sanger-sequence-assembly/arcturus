package ArcturusTableRow;

############################################################
# accessing/processing one record in a database table
############################################################

use strict;

############################################################
# constructor 
############################################################

sub new {
# communicate the arcturus table handle to a new instance
    my $prototype = shift;
    my $tblhandle = shift || die "Missing table handle"; 

    my $class = ref($prototype) || $prototype;

    my $self = {};
    bless ($self, $class);

# define basic elements of the data hash

    $self->{table}     = $tblhandle;
    $self->{tablename} = $tblhandle->{tablename};
    $self->{protect}   = $tblhandle->getPrimaryKey;
    $self->{select}    = ''; # column name actually used for record selection

    $self->{contents}   = {}; # for the data of one table record
    $self->{attributes} = {}; # for possible attributes
    $self->{changes}    = {}; # for possible changes

# standard error reporting set-up

    $self->{status} = {};
    $self->clearErrorStatus; # initalise

    return $self;
}

#####################################################################
# methods to load/change data of this instance
#####################################################################

sub loadRecord {
# load data from an individual record into a hash; returns 1 for success, else 0
    my $self  = shift;
    my $item  = shift;
    my $value = shift;

    $self->clearErrorStatus;

my $TEST = 0;
print "Loading record $item $value<br>" if $TEST;

    if (!defined($item) || !defined($value)) {
        $self->putErrorStatus(1,"loadRecord: incomplete parameter list");
        return 0;
    }

    my $table = $self->{table};
    my $hash  = $table->associate('hashref',$value,$item,{traceQuery=>0});
   
# test error status on the data table reader

print "$item $hash->{$item}  $value<br>" if ($hash && $TEST);
    if (ref($hash) eq 'HASH' && defined($hash->{$item}) && $hash->{$item} eq $value) {
# the record exists and data are in $hash
        $self->{contents} = $hash; # or copy?
# register the current column name
        $self->{select} = $item;
# process possible attributes (only ArcturusTable objects
        if ($hash->{attributes} && ref($table) ne 'ArcturusTable') {
            my $text = "attributes can't be unpacked because of wrong table type ".ref($table);
            $self->putErrorStatus(1,$text);
        }
        elsif ($hash->{attributes}) {
            delete $hash->{attributes}; # remove from 'contents'
            my $attributes = $table->unpackAttributes($value,$item); # a reference to a hash
print "unpacked attributes $attributes <br>" if $TEST;
my @keys = keys %$attributes; print "keys @keys<br>" if $TEST;
            $self->{attributes} = $attributes;
        }
    }
    elsif ($self->putQueryStatus) {
print "END loadRecord (qerrors) <br>" if $TEST;
        return 0;
    }
    elsif (!$hash || !keys (%$hash)) {
        $self->putErrorStatus(1,"$self->{tablename} entry $item = $value does not exist");
print "END loadRecord <br>" if $TEST;
        return 0; 
    }

    return 1;
}

#####################################################################

sub loadFirstRecord {
# load the first record in the table; returns 1 for success, else 0
    my $self   = shift;
    my $column = shift; # optional, default primary key

    $self->clearErrorStatus;

print "loadFirstRecord<br>";
    my $table = $self->{table};
    $column = $table->getPrimaryKey if !$column;

# test if a column is defined

    if (!$column) {
# there is no primary key; in this case a column name has to be specified
# (just loading any record with 'select *' as the first one serves no purpose)
        $self->putErrorStatus(1,"Cannot load first record: missing column name");
        return 0;
    }

# get the first or last (numerically or alphabetically) value in the table

    my $desc = $self->{inverse} ? 'desc' : '';
    $self->{inverse} = 0; # reset to force  

    my $query = "select $column from <self> order by $column $desc limit 1";
    my $hashes = $table->query($query,0,0); # returns array reference
print "load first record hashes $hashes <br>\n";

    if (!defined($hashes->[0]->{$column})) {
        $self->putErrorStatus(1,"Table $self->{tablename} is empty");
        $self->putQueryStatus;
        return 0;
    }
        
    return $self->loadRecord($column,$hashes->[0]->{$column});
}

#####################################################################

sub loadLastRecord {
# load the last record in the table; returns 1 for success, else 0
    my $self   = shift;
    my $column = shift; # optional, default primary key

    $self->{inverse} = 1;

    return $self->loadFirstRecord($column);
}

#####################################################################

sub count {
# count the number of rows in the master table
    my $self  = shift;

    my $table = $self->{table};

    return $table->count(shift);
}

#####################################################################

sub put {
# put an item to the internal 'changes' hash; returns 1 for success, else 0 
    my $self  = shift;
    my $item  = shift;
    my $value = shift;
    my $flush = shift; 

# first try if the item is among the regular table columns

#print "RM put: $item $value<br>";
    my $table = $self->{table};

    my $protect = $self->{protect} || $self->{select};

    if ($table->doesColumnExist($item)) {
# add to the changes hash (with optional commit)
        $self->{changes}->{$item} = $value;
        return $self->commit if $flush;
    }

    else {
# add the item to the attributes (and commit)
        my $status = $self->{status};
        my $prvalue = $self->{contents}->{$protect};
        $table->packAttribute($prvalue,$protect,'attributes',$item,$value);
        return 0 if $self->putQueryStatus; # previous operation failed
    }
    return 1;
}

#############################################################################

sub setDefaultColumn {
# specify a default column
    my $self = shift;

    $self->{defaultColumn} = shift;
}

#############################################################################
# export of current, new or changed data
#############################################################################

sub get {
# get a named record item; returns a value or undef
    my $self = shift;
    my $item = shift || return;

# first, search in the contents hash 

    my $value = $self->{contents}->{$item};

# if not found, try the attributes

    $value = $self->{attributes}->{$item} unless defined($value);

# finally, try the self hash 

    $value = $self->{$item} unless defined($value);

    return $value;
}

#############################################################################

sub tableHandle {
# return the table handle
    my $self = shift;

    return $self->{table};
}

#############################################################################

sub data {
# return the reference to the data hash
    my $self = shift;

    return $self->{contents};
}

#############################################################################

sub getDefaultColumn {
# select the default item from the table, if wanted with a "where" clause
    my $self  = shift;
    my $where = shift || 1;

    my $column = $self->{defaultColumn} || die "No default column name specified";

    my $table = $self->{table};

# always return an array reference

    return $table->associate($column,'where',$where,{returnScalar=>0});
}

#############################################################################

sub inventory {
# return a table with the current content of this object
    my $self = shift;
    my $part = shift;

    my $list;
# to be completed ...
    return $list;
}

#####################################################################

sub commit {
# write changes to the database; returns 1 for success, else 0
    my $self = shift;

# write all changes to parameters to the database table

    $self->clearErrorStatus;

    my $content = $self->{contents};
    my $changes = $self->{changes};

    my $protect = $self->{protect} || $self->{select};
    my $prvalue = $content->{$protect};

# test if one of the changes is on the 'protected' column,
# which is usually the primary key, but in its absence is
# the column on which the record was selected
# you can't change the protected key; use newRow instead

print "RM enter commit<br>";
    foreach my $key (keys %$changes) {
        
        if ($key eq $protect && $changes->{$key} ne $prvalue) {
            my $text = "Attempt to change column $key from $prvalue to $changes->{$key}";
            $self->putErrorStatus(1,$text);
            return 0;
        }
    }

    delete $changes->{$protect}; # to prevent confusion

    my $table = $self->{table};

# the existence of the columns has been tested in 'put'

    foreach my $key (keys %$changes) {

        next if ($changes->{$key} eq $content->{$key});

print "update $self->{tablename} $key, $changes->{$key}, $protect, $prvalue<br>";
        $table->update($key, $changes->{$key}, $protect, $prvalue);

        return 0 if $self->putQueryStatus;
    }

# reload the record from the database (to be sure it is current)

    return $self->loadRecord($protect, $prvalue); # returns 1 or 0
}

##########################################################################

sub newRow {
# add a new row with the current 'changes' buffer contents
    my $self = shift;

    $self->clearErrorStatus;

    my @column;
    my @values;

    my $changes = $self->{changes};

    foreach my $key (keys %$changes) {
        push @column, $key;
        push @values, $changes->{$key};
    }

    if (!@column) {
        $self->putErrorStatus(0,"There is no data to insert");
        return 0;
    }

    my $table = $self->{table};

    my $insert = $table->newrow(\@column,\@values);

    $self->putQueryStatus unless $insert;

    return $insert;
}

#############################################################################
# error reporting
#############################################################################

sub clearErrorStatus {
# clear error status
    my $self = shift;

    my $status = $self->{status};
    $status->{errors}    = 0;
    $status->{warnings}  = 0;
    $status->{diagnosis} = '';
    $status->{qerrors}   = '';

    return $status;
}

#####################################################################

sub putErrorStatus {
# enter error information
    my $self = shift;
    my $type = shift; # 0 for warning, else error
    my $text = shift; # add to diagnosis

    my $status = $self->{status};

    my $kind = $type ? 'warnings' : 'errors';
    $status->{$kind}++;

    return unless $text;

    $status->{diagnosis} .= "\n" if $status->{diagnosis};
    $status->{diagnosis} .= $text;
}

#####################################################################

sub putQueryStatus {
# enter (possible) query error information (return 0 if NO error)
    my $self = shift;

    my $table = $self->{table};

# if there is a query error, add it to the status hash and return true

    if ($table->qerrors()) {
# put a standard error message
        $self->putErrorStatus(1,"query error on table $self->{tablename}");
# and add the query error to qerrors 
        my $status = $self->{status};
        $status->{qerrors} .= "\n" if $status->{qerrors};
        $status->{qerrors} .= $table->qstatus;
        return 1; # there is an error
    }

    return 0; # there is no error
}

#####################################################################

sub status {
# return the error count
    my $self = shift;
    my $full = shift; # set true to treat warnings as error status

    my $status = $self->{status};

    my $output;
    if ($status->{errors} || ($full && $status->{warnings})) {
        $output .= "$status->{errors} ERRORs on ".ref($self).":\n";
        $output .= "$status->{warnings} WARNINGs on ".ref($self).":\n" if $status->{warnings}; 
        $output .= "$status->{diagnosis}\n";
    }

    $output .= "$status->{qerrors}\n" if $status->{qerrors};

    return $output; # returns undef for NO error status
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.8 ,
        updated =>    "19 Feb 2004",
        date    =>    "11 Feb 2004",
    };
}

#############################################################################

1;
