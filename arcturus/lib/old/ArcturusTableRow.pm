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

    $self->{table}   = $tblhandle;
    $self->{protect} = $tblhandle->getPrimaryKey;
    $self->{select}  = ''; # column name actually used for record selection

    $self->{contents}   = {}; # for the data of one table record
    $self->{attributes} = {}; # for possible attributes
    $self->{changes}    = {}; # for possible changes

# standard error reporting set-up

    $self->{status} = {};
    $self->clearErrorStatus; # initalise

print "TableRow completed<br>";
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

    my $status = $self->clearErrorStatus;

print "Loading record $item $value<br>";

    if (!defined($item) || !defined($value)) {
        $status->{diagnosis} = "loadRecord: incomplete parameter list";
        $status->{errors}++;
        return 0;
    }

    my $table = $self->{table};
    my $hash  = $table->associate('hashref',$value,$item,{traceQuery=>0});
   
# test error status on the data table reader

print "$item $hash->{$item}  $value<br>";
    if (defined($hash->{$item}) && $hash->{$item} eq $value) {
# the record exists and data are in $hash
        $self->{contents} = $hash; # or copy?
# register the current column name
        $self->{select} = $item;
# process possible attributes (only ArcturusTable objects
        if ($hash->{attributes} && ref($table) ne 'ArcturusTable') {
            $status->{diagnosis} = "attributes can't be unpacked because ";
            $status->{diagnosis} = " of wrong table type ",ref($table);
            $status->{warnings}++;
        }
        else {
            delete $hash->{attributes}; # remove from 'contents'
            my $attributes = $table->unpackAttributes($value,$item); # a reference to a hash
print "unpacked attributes $attributes <br>";
my @keys = keys %$attributes; print "keys @keys<br>";
            $self->{attributes} = $attributes;
        }
    }
    elsif ($table->qerrors()) {
        $status->{diagnosis} = "query error on table $table->{tablename}";
        $status->{qerrors} = $table->qstatus();
        $status->{errors}++;
        return 0; 
    }
    elsif (!keys (%$hash)) {
        $status->{diagnosis} = "$table->{tablename} entry $item = $value does not exist";
        $status->{errors}++;
        return 0; 
    }

    return 1;
}

#####################################################################

sub loadFirstRecord {
# load the first record in the table; returns 1 for success, else 0
    my $self   = shift;
    my $column = shift; # optional, default primary key

    my $status = $self->clearErrorStatus;

print "loadFirstRecord<br>";
    my $table = $self->{table};
    $column = $table->getPrimaryKey if !$column;

# test if a column is defined

    if (!$column) {
# there is no primary key; in this case a column name has to be specified
# (just loading any record with 'select *' as the first one serves no purpose)
        $status->{diagnosis} = "Cannot load first record: missing column name";
        $status->{errors}++;
        return 0;
    }

# get the first or last (numerically or alphabetically) value in the table

    my $desc = $self->{inverse} ? 'desc' : '';
    $self->{inverse} = 0; # reset to force  

    my $query = "select $column from <self> order by $column $desc limit 1";
    my $hashes = $table->query($query,0,0); # returns array reference
print "load first record hashes $hashes <br>\n";

    if (!defined($hashes->[0]->{$column})) {
        $status->{diagnosis} = "Table $table->{tablename} is empty";
        $status->{errors}++;
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

sub put {
# put an item to the internal hash; returns 1 for success, else 0 
    my $self  = shift;
    my $item  = shift;
    my $value = shift;
    my $flush = shift; 

# first try if the item is among the regular table columns

print "RM put: $item $value<br>";
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
        if ($table->qerrors()) {
            $status->{diagnosis} = "query error on table $table->{tablename}";
            $status->{qerrors} = $table->qstatus();
            $status->{errors}++;
            return 0; 
        }
    }
    return 1;
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

# not found, try the attributes

    $value = $self->{attributes}->{$item} unless defined($value);

    return $value;
}

#############################################################################

sub tableHandle {
# return the table handle
    my $self = shift;

    return $self->get('table');
}

#############################################################################

sub inventory {
# return a table with the current content of this object
    my $self = shift;
    my $part = shift;

    my $list;

    return $list;
}

#####################################################################

sub commit {
# write changes to the database; returns 1 for success, else 0
    my $self = shift;

# write all changes to parameters to the database table

    my $status = $self->clearErrorStatus;

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
            $status->{diagnosis}  = "Attempt to change column $key ";
            $status->{diagnosis} .= "from $prvalue to $changes->{$key}";
            $status->{errors}++;
            return 0;
        }
    }

    delete $changes->{$protect}; # to prevent confusion

    my $table = $self->{table};

# the existence of the columns has been tested in 'put'

    foreach my $key (keys %$changes) {

        next if ($changes->{$key} eq $content->{$key});

print "update $table->{tablename} $key, $changes->{$key}, $protect, $prvalue<br>";
#        $table->update($key, $changes->{$key}, $protect, $prvalue);

        if ($table->qerrors()) {
            my $qstatus = $table->qstatus;
            $status->{diagnosis} = "query error(s) on table $table->{tablename}";
            $status->{qerrors}  .= "$qstatus\n";
            $status->{errors}++;
            return 0; 
        }
    }

# reload the record from the database (to be sure it is current)

    return $self->loadRecord($protect, $prvalue); # returns 1 or 0
}

##########################################################################

sub newRow {
# add a new row with the current 'changes' buffer contents
    my $self = shift;

    my @column;
    my @values;

    my $changes = $self->{changes};

    foreach my $key (keys %$changes) {
        push @column, $key;
        push @values, $changes->{$key};
    }

    my $table = $self->{table};

    my $status = $self->clearErrorStatus;
print "new row<br>@column<br>@values<br>";

#    my $insert = $table->newrow(\@column,\@values); # returns true or 0
#    if (!$insert) {
        $status->{diagnosis} = $table->{qerror};
        $status->{errors}++;
#    }
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

sub status {
# return the error count
    my $self = shift;
    my $full = shift; # set true to treat warnings as error status

    my $status = $self->{status};

    my $output;

    if ($status->{errors} || ($full && $self->{warnings}++)) {
        $output .= "$status->{errors} ERRORs on $self:\n";
        $output .= "$status->{warnings} WARNINGSs on $self:\n" if $self->{warnings}; 
        $output .= "$self->{diagnosis}";
    }

    return $output; # returns undef for NO error status
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.1 ,
        updated =>    "13 Feb 2004",
        date    =>    "11 Feb 2004",
    };
}

#############################################################################

1;
