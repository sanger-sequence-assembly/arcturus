package DbaseTable;

# interface to MySQL data tables

use strict;

my $VERSION = "1.1";

my $DEBUG = 1;

#############################################################################
# data common to all objects of the DbaseTable class
#############################################################################

my %instances;
my @alternates = ('identifier','description','name','type');
my $qTracer = 1; # default query tracing on (or via $self->{qTracer}

#############################################################################
# new method creates an instance of DbaseTable   
#############################################################################

sub new {

    my $prototype = shift;
    my $dbhandle  = shift; # the database handle
    my $tablename = shift;
    my $database  = shift; # the database of the table
    my $build     = shift; # define 0 for descriptors, 1 for hashrefs   
    my $order     = shift; # if build defined as 1, order by column 'order'

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{dbhandle}  = $dbhandle;
    $self->{tablename} = $tablename;
    $self->{database}  = $database;

    $self->{columns}     = []; # array for table column names
    $self->{coltype}     = {}; # hash with column types
    $self->{prime_key}   = ''; # place holder for the primary key
    $self->{unique}      = []; # place holders for a possible unique key
    $self->{hashrefs}    = []; # array with hashrefs for table rows
    $self->{hashref}     = ''; # hash reference of last accessed table row 
    $self->{errors}      = ''; # build/instantiate status
    $self->{qerror}      = ''; # query status
    $self->{warnings}    = ''; # 
    $self->{timestamp}   = ''; #

    $self->{qTracer}     = 1 ; # default query tracing on
    $self->{sublinks}    = {}; # hash with links to other tables

# initialize the table only if build is defined (preset error status for build)

    $self->{errors} = "Initialisation pending for table $database.$tablename";
    if (defined($build) && !build($self,$build,$order)) {    
        $self->{errors} = "Initialisation failed for table $database.$tablename";
    }

    bless ($self, $class);
    return $self;
}

#############################################################################
# initialise the table
#############################################################################

sub build {
# set switch "on" for full build including hash, else only table columns
    my $self   = shift;
    my $switch = shift;
# order by column "order" (optional)
    my $order  = shift;

    my $count = 0;
    $self->{errors} = ''; # clear error flag

# test the database handle and get full table name

    my ($dbh, $tablename) = whoAmI($self, 1);

# prepare for column names and types and hashrefs 

    undef my %columns;
    undef $self->{hashrefs};
    undef @{$self->{columns}};

# test if the table exists

    my $exists = 0;
    my $query = "SHOW TABLES";
    $query .= " from  $self->{database}" if ($self->{database});
    my $tst = $dbh->prepare($query);
    if ($tst->execute()) {
        while (my @description = $tst->fetchrow_array()) {
            $exists = 1 if ($description[0] eq $self->{tablename});
        }
        if (!$exists) {
            $self->{errors} = "! Table $tablename does not exist";
            return 0;
        }
    }

# get the column names in an array; mark the primary key, if there is one
# if no primary key found, use a column named after table instead, if any

    undef my $prime_col;
    my $sth = $dbh->prepare("SHOW COLUMNS from $tablename");
    if ($sth->execute()) {
        while (my @description = $sth->fetchrow_array()) {
            push @{$self->{columns}}, $description[0]; # keeps the order of entries
            $columns{$description[0]} = $description[1]; # hash for type information
            $self->{prime_key} = $description[0]     if ($description[3] eq 'PRI');
            push @{$self->{unique}}, $description[0] if ($description[3] eq 'PRI');
            push @{$self->{unique}}, $description[0] if ($description[3] eq 'UNI');
            $prime_col = $description[0] if ($tablename =~ /^\w+\.$description[0]$/i);
            $count++; 
        }
        $self->{coltype} = \%columns ;
    } else {
        $self->{errors} = "! Could not access table $tablename";
        return 0;
    }
    $sth->finish();

# if switch set build a hash of the whole table in memory
# order by the column defined, or else by the primary key, if any

    $switch = 0 if (!defined($switch));
    if ($switch && $order) {
        $count = buildhash(0, $self, $order);
    } elsif ($switch) {
# determine the default column to use for order
        $order = $prime_col if (defined($prime_col));
        $order = $self->{prime_key} if (!$order && $self->{prime_key});
# order will be undefined if no primary key or column named after table
        $count = buildhash(0, $self, $order);
    }

# finally, add the table to the 'instances' inventory of the DbaseTable class

#print "$tablename build with switch $switch<br>\n";
    $instances{$tablename} = $self;

# count is either the nr of columns (if !switch) or number of rows (if switch)

    return $count;
}

#############################################################################
# buildhash only to be used as private method (locked!)
#############################################################################

sub buildhash {
# build an image of the database table on disk as an array of hashes
    my $lock  = shift;
    my $self  = shift;
    my $order = shift;

# protect against unintended usage

    die "! Y're not supposed to use private method 'buildhash'\n" if ($lock);

# get every row from the database as an array of hash references

    my $orderby = ' ';
    $orderby = "order by $order" if ($order);

    my $count = 0;
    my $query = "select * from <SELF> $orderby";
    my $hashrefs = query($self,$query,0,0);
    if ($hashrefs && $hashrefs != 0) {
        $self->{hashrefs} = $hashrefs;
        $count = @{$self->{hashrefs}};
    }
    else {
        $self->{warnings} = "! Table $self->{tablename} is empty";
    }

# return the number of table lines

    return $count;
}

#############################################################################

sub spawn {
# spawn a new DbaseTable object with inheritance of current 
    my $self      = shift;
    my $tablename = shift;
    my $database  = shift;
    my $forced    = shift; # if true, force creation of a new instance

    my $dbhandle = $self->{dbhandle};
    $database = $self->{database} if ($database =~ /\bself\b/);

    my $handle = $self->findInstanceOf($database.'.'.$tablename);
    $handle = $self->new($dbhandle,$tablename,$database,@_) if (!$handle || $forced);    
    
    return $handle;
}

#############################################################################
# method whoAmI performs tests before the database is accessed
# returns the database handle and full tablename
#############################################################################

sub whoAmI {
# can be queried by sub classes
    my $self  = shift;
    my $force = shift;
    my $ping  = shift;

# test database handle, do a ping if specified

    my $dbh = $self->{dbhandle};
    if (!defined($ping) || $ping) {
        $dbh->ping() or die "database handle has expired";
    }

# get the database name (if $force require the database to be defined too)

    my $tbl = $self->{database};
    die "undefined database for table $self->{tablename}" if (!$tbl && $force);

# get the tablename (if database undefined, tablename should be in default)

    $tbl .= '.' if (defined($tbl));
    $tbl .= $self->{tablename};

# return the database handle and the full tablename

    return $dbh, $tbl;
}

#############################################################################

sub findInstanceOf {
# find the instance of the named table in the DbaseTable class %instances
    my $self          = shift;
    my $fullTableName = shift;

    if ($fullTableName) {
        $fullTableName =~ s/\<self\>/$self->{database}/i;
        return $instances{$fullTableName};
    }
    else {
        return \%instances;
    }  
}

#############################################################################

sub traceTable {
# trace the links of this table if the sublinks hash is defined
    my $self  = shift;
    my $href  = shift;

    my $tablename = whoAmI($self,0,0);

    undef my %output;
    $href = \%output if (!defined($href));

    foreach my $column (@{$self->{columns}}) {
        my $key = $tablename.'.'.$column;
        if ($self->{sublinks}->{$column}) {
        # there is a sublink
            my $linktable  = $self->{sublinks}->{$column}->[0];
            my $linkcolumn = $self->{sublinks}->{$column}->[1];
        # get the linked table reference
            my $tableref = $instances{$linktable};
            my $destination = $linktable.'.'.$linkcolumn;
            if (!defined($href->{$key}) || $href->{$key} ne $destination) {
                $href->{$key} = $destination; # prevent looping
# print "<br>TRACETABLE $self->{tablename} linktable=$linktable tableref=$tableref <br>";
                $tableref->traceTable($href);
            }
        }
        else {
    # there is no sublink; just add the current tablename and column
#            $href->{$key} = 0;
        }
    }
    return $href;
}

#############################################################################

sub status {
# probe and/or reset error status
    my $self  = shift;
    my $reset = shift;

    my $status = 0;

    if ($self->{errors} && $reset) {
        undef $self->{errors};
        $status = 1;
    }
    elsif ($self->{errors}) {
# replace possible <self> tags
        $self->{errors} =~ s/\<self\>/$self->{tablename}/g;
        $status = 1;
    }
    return $status;
}

#############################################################################

sub list {
    my $self = shift;
    my $mask = shift;
    my $mark = shift; # put this mark at each table line (allows editing outside) 

# set-up mask

    my $table;

    undef my %mask;
    if (defined($mask)) {
        my @mask = split //,$mask;
        foreach my $column (@{$self->{columns}}) {
            $mask{$column} = 0 if (!@mask);
            $mask{$column} = shift(@mask) if (@mask);
        }
    }

    my $tablename = $self->{tablename};

    undef my %lengths;
    foreach my $column (@{$self->{columns}}) {
        $lengths{$column} = $1 if ($self->{coltype}->{$column} =~ /\((\d+)\)/);
        $lengths{$column} = length($column) if !$lengths{$column};
        foreach my $hash (@{$self->{hashrefs}}) {
            my $item = $hash->{$column};
            if (defined($item) && length($item) > $lengths{$column}) {
 	        $lengths{$column} = length($item);
            }
        }
        $lengths{$column} = -$lengths{$column} if ($self->{coltype}->{$column} =~ /blob|char/);
    }

    if (keys %lengths == 0) {
        return undef;
    }

# assemble header

    undef my $header;
    foreach my $column (@{$self->{columns}}) {
        if (!defined($mask) || $mask{$column}) {
            my $length =  $lengths{$column};
            $header .= ' ' if ($header);
            $header .= sprintf ("%${length}s",$column);
        }
    }

    $table = "\nTable $tablename\n\n$header\n\n" if !$mark;

# print body (if it exists)


    foreach my $hash (@{$self->{hashrefs}}) {
        undef my $string;
        foreach my $column (@{$self->{columns}}) {
            if (!defined($mask) || $mask{$column}) {
                my $length =  $lengths{$column};
                $string .= ' ' if ($string); my $field = ' ';
                $field = $hash->{$column} if (defined($hash->{$column}));
# print "field $column  $field  length=$length\n";
                $string .= sprintf ("%${length}s",$field);
            }
        }
        $table .= "$mark " if $mark;
        $table .= "$string\n";
    }

# long list option for large tables where $hash is not made
#    if ($list && !$self->{hashrefs}) {
#    }

    return $table;
}

#############################################################################
# search functions
#############################################################################

sub associate {
    my $self  = shift;
    my $item  = shift;
    my $wval  = shift;
    my $wcol  = shift;
    my $multi = shift; # true i.e !=0 forces search for more than one return items
    my $order = shift;
    my $exact = shift; # use '=' and not 'like' in string comparisons (exact match)

# print "$self->{tablename} associate $item $wval $wcol <br>";
# return the value of column "item" in the row where 
# (1, wcol undefined) any column's value matches "wval" exactly
# (2, wcol defined) column "wcol"s value matches "wval" exactly
# return references to hashes 
# item names 'hashref' and 'hashrefs' are reserved: don't use 
#      them as column name in the database
# if you want possibly more than one row returned (hashes) set multi to true 
# multi>=0 allows activation of query tracing; multi<0 forbids
# ibas(multi) is used as limit if > 1

# column item must be defined in myself; wcol can be in a linked table

    undef my $hash;
    undef my $result;
    undef $self->{qerror};

# if one only exact match is required (no wildcards) test possible stored table hash

    $multi = 0 if (!defined($multi));
   ($hash, $result) = &locate ($self,$wval,$wcol) if (defined($wval) && $wval !~ /[\%\_]/ && !$multi || $exact);

# the next two branches relate to internally stored tables and only return 
# data of the first encountered record matching the query; use for unique items
 
    if (defined($hash) && $item eq 'hashref') {
# return hash reference to the (**first**) table record found by &locate; store for reference
        $self->{hashref} = $hash;
        $result = $hash;
    }
    elsif (defined($hash) && $item ne 'hashrefs') {
# return the value of the requested item in the **first** table record found by &locate
        $result = $hash->{$item};
    }

# the following branches relate to queries with wildcards or when no table is
# stored internally or where possibly more than one return value is expected ($multi != 0)

    elsif (defined($wval) && defined($wcol)) {

# compose the raw query which may be passed through the query tracer if the test column ($item)
# does not exist in myself (but could be in a linked table); suppress with $multi < 0 

        my ($dbh, $tablename) = whoAmI($self,0,0);

# determine if $item is composite or e.g. a function

        my $isComposite = 0;
        $isComposite = 1 if ($item =~ /\,|\(.+\)/);

# start the select string

        my $select = 'SELECT';
        $select .= ' DISTINCT' if ($item =~ s/^\s*distinct\s+//i); # catch e.g. 'distinct columnname'

# determine to use query tracing or not

        my $useQueryTracer = 0; # default assume column is in myself
        if (my $quoted = quoteColValue($self,$wcol,$wval)) {
            $wval = $quoted;
        }
        elsif ($multi >= 0) {
    # the test column $wcol does not exist in myself, is composite, or wval is of wrong type
            $useQueryTracer = $qTracer;
#            $useQueryTracer = $self->{qTracer};
        }
        elsif (($isComposite || $item ne 'count') && $wval !~ /\bwhere\b/i) {
    # the test column $wcol does not exist in myself but no query tracing
            $self->{qerror} = "Column $wcol does not exist in $self->{tablename}";
            $item = ' '; # skips the remainder
        }

# determine limit setting

        my $multi = abs($multi);
        my $limit = ''; $limit = "limit $multi" if ($multi > 1);

# determine possible ordering

        my $orderby = ''; $orderby = "order by $order" if $order;

        my $whereclause = $wcol;
        if ($wval =~ /\bwhere\b/i) {
    # in this case $wcol should contain the full specification
            $select .= ' DISTINCT' if ($wval =~ /distinct/i);
# print "<br>item:$item  wval:$wval  whereclause:$whereclause $useQueryTracer<br>\n" if ($tablename =~ /CONTIGS/);
        }
        else {
    # test and strip negation prefix
            my $not = 0; $not = 1 if ($wval =~ s/\s*(\!|not)\s*//i);
    # in this case $wcol should contain the column name and $wval a value
            if ($wval =~ /^\(.*?\,.+\)/) {
                $whereclause .= ' not' if $not;
                $whereclause .= ' in '; # with a list specification
            }
            elsif ($wval =~ /[\%\_]/ && !$exact) {
                $whereclause .= ' not' if $not;
                $whereclause .= ' like '; # one value with wild cards
            }
            else {
                $whereclause .= '!' if $not;
                $whereclause .= '='; # one value exact match
            }
            $whereclause .= $wval;
            $whereclause =~ s/=\s*null\s*$/is null/i; # adjust for NULL values
# print "item:$item  wval:$wval  whereclause:$whereclause   not=$not<br>\n" if ($tablename =~ /CONTIGS/);
        }
    # memorize the select where clause
        $self->{querywhereclause} = "$tablename.$whereclause";
        $self->{querytotalresult} = 0; # default no result returned
        
        my $query = 'UNDEF';
        my $queryStatus = 0;
        if (defined($self->{coltype}->{$item})) {
            $query = "$select $item from $tablename WHERE $whereclause $orderby $limit";
            $self->{lastQuery} = $query;
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            my $sty = $dbh->prepare($query); # return array of hashrefs
            my @result;
            if ($sty->execute()) {
                $queryStatus = 1; # signal valid query
                while (my $hash = $sty->fetchrow_hashref()) {
                    push @result, $hash->{$item};
                }
            }
	    $sty->finish();

            $self->{querytotalresult} = @result;
    # compose the output value: either a value or array reference
            if (@result == 1) {
                $result = $result[0];
            }
            elsif (@result > 1) {
                $result = \@result;
            }
        }
        elsif ($item =~ /\bcount\b/i) {
    # no query tracing provided in count, nor 'count(item)'
            $result = count($self,$whereclause);
            $queryStatus = 1 if (defined($result));
            $self->{querytotalresult} = $result || 0;
        }
        elsif ($item eq 'hashref') {
            $query = "$select * from $tablename WHERE $whereclause limit 1";
            $self->{lastQuery} = $query;
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            my $sty = $dbh->prepare ($query); # return hashref to first record found
            if ($sty->execute()) {
                $queryStatus = 1; # signal valid query
                $result = $sty->fetchrow_hashref();
                $self->{querytotalresult} = 1;
            }
	    $sty->finish();
        }
        elsif ($item eq 'hashrefs' || $isComposite) {
            undef my @hashrefs;
            $item = '*' if !$isComposite;
            $query = "$select $item from $tablename WHERE $whereclause $orderby $limit";
            $self->{lastQuery} = $query;
# print "composite! query: $query ;  tracer $useQueryTracer<br>" if ($isComposite);
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            my $sty = $dbh->prepare ($query); # return array of hashrefs
            if ($sty->execute()) {
                $queryStatus = 1; # signal valid query
                while (my $hash = $sty->fetchrow_hashref()) {
                    push @hashrefs, $hash;
                }
            }
	    $sty->finish();
# print "result $queryStatus: @hashrefs <br>" if $isComposite;
            $self->{querytotalresult} = @hashrefs + 0; 
            $result = \@hashrefs; # return reference to array of hashes
        }
        elsif ($item && $item =~ /\S/) {
            $self->{qerror} .= "Invalid column name '$item' specified. ";
        }

# $result is either defined, including the numerical value '0', as query answer
# or undefined which indicates either an invalid query or an empty query. Hence
# we re-assign '0' (FALSE) also to an undefined result, but this means that output
# '0' should be accompanied by a test for a valid query with $self->{qerror} or
# a test on the number of entries returned with $self->{querytotalresult}

        $self->{qerror} .= "Invalid query '$query' on table $tablename" if !$queryStatus;
        $result = 0 if !defined($result);

        if (!$self->{querytotalresult} && !$queryStatus) {
            print "$self->{lastQuery} <br>" if ($tablename =~ /CONTIGS|USERS/); # temp tests
        }
    }
    elsif ($item eq 'hashrefs') {
        $result = $self->{hashrefs}; # if any
    }
    elsif (defined($item)) {
    }

    $result;
}

#############################################################################

sub quoteColValue {
# determine the type of the column and quote the value
    my $self  = shift;
    my $cname = shift;
    my $value = shift;

# get database handle

    my ($dbh, $tablename) = whoAmI($self);

    undef my $output;
    if (defined($value) && (my $columntype = $self->{coltype}->{$cname})) {
        my $quote = 0;
        $quote = 1 if ($columntype =~ /char|blob|date|enum/i);
        if (ref($value) =~ /ARRAY/i) {
# print "quote array values $value<br>";
            my $count = 0;
            foreach my $choice (@$value) {
# print "choice $choice<br>";
                $output .= ',' if $count++;
                if ($quote) {
                    $choice =~ s/^([\'\"])(.*)\1$/$2/; # chop off any existing quotes
                    $choice .= $dbh->quote($choice) unless ($choice =~ /^null$/i);
                }
                $output .= $choice;
            }
            $output = '('.$output.')' if ($count > 1); # better than rely on ','
# print "output $output<br>";
        }
        elsif ($quote) {
            $value =~ s/^([\'\"])(.*)\1$/$2/; # chop off any existing quotes
            $output = $dbh->quote($value) unless ($value =~ /^null$/i);
        }
        else {
            $output = $value;
        }
    }

    $output; # output will be undefined on error, i.e. unknown column name
}

#############################################################################

sub locate {
    my $self = shift;
    my $wval = shift;
    my $item = shift;

# return hash reference to a row where:
# (1) the value of column  item equals "wval" (if $item defined) ; return hash reference and item value
# (2) the value of any row item equals "wval"  ($item undefined) ; return hash and column name

    undef my $result;
    undef my $rvalue;

    if (defined($wval) && defined($self->{hashrefs})) {           
# print "find item: $item  for key $wval \n";
        foreach my $hash (@{$self->{hashrefs}}) {
            if (defined($item) && defined($hash->{$item}) && $hash->{$item} eq $wval) {
                $result = $hash;
                $rvalue = $hash->{$item};
            } elsif (!defined($item)) {
                foreach my $column (@{$self->{columns}}) {
                    if (defined($hash->{$column}) && $hash->{$column} eq $wval) {
# print "column:$column value:$hash->{$column} matches, result= $hash->{$item}\n"; 
                        $result = $hash;
                        $rvalue = $column;
                        last; # accept the first match
                    }
                }
            }
        }
        
    } 
    $result, $rvalue;
}

#############################################################################

sub find {
# find table entries matching the item<>value pairs in $query
    my $self  = shift;
    my $query = shift; # the hash reference to input query value pairs
    my $sitem = shift; # the item to be returned; can be 'hash'
    my $exact = shift; # on for exact matching values

    undef my @output;
    my $hashrefs = $self->{hashrefs};
    @output = @$hashrefs if ($hashrefs && @$hashrefs);

    undef my $whereclause;
    foreach my $column (@{$self->{columns}}) {
        if (my $value = $query->{$column}) {
    # this column is in the search specification

    # test if item and value correspond
    # replace item by linked column if appropriate?
            if ($hashrefs && @$hashrefs) {
         # go through all hashes and test the catalogue item
                for (my $i=0 ; $i<@output ; $i++) {
                    if (my $hash = $output[$i]) {
                        if (!$exact) {
                            $output[$i] = 0 if ($hash->{$column} ne $value);
                        } elsif ($exact == 1) {
                            $output[$i] = 0 if (!($hash->{$column} =~ /$value/));
                        } else {
                            $output[$i] = 0 if (!($hash->{$column} =~ /$value/i));
                        }
                    }
                }

            } else {
        #accumulate query
                $whereclause .= ' and ' if ($whereclause);
                $whereclause .= "$column = '$value'" if ($exact);
                $whereclause .= "$column like '\%$value\%'" if (!$exact);
            }           
        }
    }

    if ($whereclause) {
        undef @output;
        my $query = "select $sitem from \<self\> where $whereclause";
        $hashrefs = query($self,$query);
        @output = @$hashrefs if (@$hashrefs);

    } else { # cleanup @output
        foreach (my $i=0 ; $i < @output ;) {
            if (my $hash = $output[$i]) {
                $output[$i] = $hash->{$sitem} if (defined($hash->{$sitem}));
                $i++;
            } else {
                splice (@output,$i,1);
            }
        }
    }

# returns an array with 'sitem' values found of hash values

    if (@output) {
        return \@output;
    } else {
        return 0;
    }
}

#############################################################################

sub nextrow {
# return hash reference to next row of table ($line undefined)
# return hash reference to row nr "line" of table ($line defined)
 
    my $self = shift;
    my $line = shift;

    my $nrow;

    $nrow = $self->{lastrow} if (defined($self->{lastrow}));
    $nrow = $line if (defined($line)); # overrides 
    $nrow = 0 if (!defined($nrow) || $nrow < 0); # protects

    my $hash = $self->{hashrefs}->[$nrow];
    $nrow++ if (!defined($line) || $line >= 0);
    $self->{lastrow} = $nrow; # preset next row

    return $hash;
}

#############################################################################

sub count {
# returns the number of rows in the table
    my $self  = shift;
    my $where = shift;

# where undefined: if a hash exists with table entries, return size of hash
# where = 0      : return full length of database table
# where = query  : return number of database table entries which satisfy the query

# obsolete    die "$self->{errors}" if ((!defined($stest) || $stest) && status($self));

    undef my $count;
    if (defined($self->{hashrefs}) && !defined($where) && @{$self->{hashrefs}}) {
        $count = @{$self->{hashrefs}};
# note: the curent hash could be different from the actual table; if you want
# to be sure to count on the actual database table, force a query by defining $where
    }
    else {
        my $whereclause = '';
        $whereclause = $where if ($where && $where =~ /like|\=|\<|\>/i);
        $whereclause = 'WHERE '.$whereclause if ($whereclause && $whereclause !~ /where/i);
        my ($dbh, $tablename) = whoAmI($self);
        my $query = "SELECT COUNT(*) FROM $tablename $whereclause";
        $self->{lastQuery} = $query;
        my $sth = $dbh->prepare ($query);
        if ($sth->execute()) {
            $count = $sth->fetchrow_array();
        }
        else {
            print "Execute failed on query: $query <br>\n";
        }
        $sth->finish();
    }
    return $count;
}

#############################################################################
# Simple counter function for table entries
#############################################################################

# Update the column item COLUMN: if its VALUE is already listed, search
# for a COUNT or COUNTED or COUNTER item and increment it by 1, if found
# If VALUE is not among the COLUMN entries, add a new row to the table 
# No action but error report if COLUMN not valid; No action if VALUE undefined

sub counter {

    my $self  = shift;
    my $cname = shift;
    my $value = shift;
    my $count = shift; # set to 0 if the counter is to be unchanged
    my $alter = shift; # alternative column name

# (1) test if column name cname exists i.e. is among the @columns
# (2) if so then test if $value exists (exact match)

    my $iden = 0;
    undef my $counter;
    foreach my $column (@{$self->{columns}}) {
        $counter = $column if (!$counter && $column =~ /count|reads/i); # take first one encountered
        $counter = $alter  if ($alter && $column eq $alter); # overrides, be sure $alter exists
        if (defined($cname) && $cname eq $column) {
            $iden = 2 if (defined($value));
            foreach my $hash (@{$self->{hashrefs}}) {
                $iden = 1 if (defined($value) && $value eq $hash->{$column});
            }
        }
    }

# iden = 0 : the column name does not exist; abort
# iden = 1 : both the column name and requested value do exist; increase counter
# iden = 2 : the column name does exist but requested value doesn't; add new row

    if ($iden) {

        undef my $whereclause;

        if ($iden == 2) {
    # create a new row (this creates the "whereclause" for the new row)
            &newrow ($self, $cname, $value) or $iden = 0;
	    $whereclause = $self->{whereclause};
        } 
        else {
    # the row already exists; get the "where clause" to target it
            $value = &quoteColValue($self,$cname,$value);
            $whereclause = "$cname = $value";
            $whereclause =~ s/\=\s+null/IS NULL/i;
        }

    # update the row counter

        if ($iden && $counter && $whereclause) {
#            $whereclause =~ s/(\%|\_)/\\$1/g; # quote MySQL wildcards; we do an exact match
            if (!defined($count)) {
                $count = 1;
            }
            elsif ($count < 0) {
                $count = 0 if (associate($self,$counter,$cname,$value) < -$count); # protect
print "$self->{tablename} counter: attempt to decrease counter $counter by $count to below 0<br>"; 
            }
            if ($count != 0) {
                my $command = "UPDATE <self> SET $counter=$counter+$count WHERE $whereclause";
                &query($self,$command,1,0) or $iden = 0;
        # write the undo string into the self hash; could be called to undo this change
                if (!$iden) {
                    $self->{errors} = "Failed to update $counter in table <self>";
                }
                else {
                    $command =~ s/\+1\sW/-1 W/; # decrement counter
                    push @{$self->{undoclause}}, $command;
                }
            }
            &buildhash(0,$self); # reload the counter table
        } 
        elsif ($counter) {
            $self->{errors} = "Failed to create a new row in table <self>";
            $iden = 0;
        }
        else { # no counter
            $self->{warnings} = "No counter identified in table <self>";
            $iden = 0;
        }
    }
    elsif (defined($value)) {

        if (defined($cname)) {
            $self->{errors} = "Column \'$cname\' not found in table <self>";
        }
        else {
            $self->{errors} = "Undefined column name presented for <self>";
        }
    }
    return $iden;
}

#############################################################################

sub OLDNEWROW {
# create a new row by putting one value in named column  
    my $self  = shift;
    my $cname = shift; # column name (required)
    my $value = shift; # its value (required)
    my $Cname = shift; # second column name (optional)
    my $Value = shift; # its value (optional)

    my ($dbh, $tablename) = whoAmI($self);

# identify column and its type; test it against the value

    my $columntype = $self->{coltype};
    if (!isSameType($columntype->{$cname},$value)) {
        $self->{errors}  = "! Failed to insert new row into table $tablename:";
        $self->{errors} .= "newrow: invalid value $value for column $cname";
        return 0;
    }

# check for unique value columns if the value does not exist (pre-empt error status)

    undef my $columntest;
    $columntest = 1 if ($self->{prime_key} && $cname eq $self->{prime_key});
    foreach my $unique (@{$self->{unique}}) {
        $columntest = 1 if ($cname eq $unique);
    }
    if ($columntest) {
        my $current = associate($self,$cname,$value,$cname,-1);
        if ($current) { # the column value already exists (column name should not be '0')
            update($self,$cname,$value,$cname,$current) if ($value ne $current);
            $self->{errors}  = "! Failed to insert new row into table $tablename:";
            $self->{errors} .= "newrow: column $cname value $value already exists";
            return 0;
        }
    }
    my $nextrow = count($self,0) + 1; # number of the next row, force query on table

# print "$tablename newrow: nextrow=$nextrow<br>" if ($tablename =~ /PEND/);

    my $status = 1;
    undef my $cstring; 
    undef my $vstring;
    undef my $wstring;
    if (defined($cname) && defined($value) && defined($columntype->{$cname})) {
        $cstring = $cname;
        $vstring = quoteColValue($self,$cname,$value);
        $wstring = $cname.'='.$vstring;
# test for second column definition
        if (defined($Cname) && defined($Value) && defined($columntype->{$Cname})) {
            $cstring .= ','.$Cname;
            $Value = quoteColValue($self,$Cname,$Value);
            $vstring .= ','.$Value;
            $wstring .= ') and ('.$Cname.'='.$Value;
        }
        elsif (defined($Cname)) {
        # either Value not defined or invalid Cname
            $cstring .= ','.$Cname if $Cname;
            $vstring .= ','.$Value if $Value;
            $status = 0;
        }

        if ($status) {               
        # input seems okay, add new record 
            my $query = "INSERT INTO $tablename ($cstring) VALUES ($vstring)";
# print "$tablename newrow: $query<br>" if ($tablename =~ /CHEM|PEND/);
            $status = &query($self,$query,1,0);       
        # on successful completion: store the WHERE string for further updates or rollback
            if ($status && count($self,0) == $nextrow) {
                $self->{whereclause} = "($wstring)";
                my $undoclause = "DELETE FROM $tablename WHERE $self->{whereclause}";
                push @{$self->{undoclause}}, $undoclause;
                $status = $nextrow;
            }
            else {
                undef $self->{whereclause};
                $status = 0; # to be sure
            }
        }
    }
    else {
        $status = 0;
    }

    if (!$status) {
        $self->{errors}  = "! Failed to insert new row into table $tablename:";
        $self->{errors} .= "  Invalid or undefined column name(s) $cstring or value(s) $vstring\n";
    }

    return $status; # 0 for failure, > 0 for success with status = nr of rows
}

#############################################################################

sub newrow {
# create a new row by putting one value in named column  
    my $self  = shift;
    my $cname = shift; # column name or array reference (obligatory)
    my $value = shift; # its  value  or array reference (obligatory)
    my $Cname = shift; # column name or array reference (optional)
    my $Value = shift; # its  value  or array reference (optional)

#    my ($dbh, $tablename) = whoAmI($self);

    my $multiLine = $self->{multiLine};

# test input data; build arrays with values to be inserted

    my $inputStatus = 1;
    my @cinserts; # columns
    my @vinserts; # values
    my $uniqueTest = 0;

my $list = 0;
if ($list) {
print "<br>enter NEWROW: cname $cname value $value";
print "   Cname $Cname Value $Value" if $Cname;
print "<br>";
}

    if (!defined($cname) || !defined($value)) {
        $inputStatus = 0;
    }
    elsif (ref($cname) eq 'ARRAY' && ref($value) eq 'ARRAY') {
        @cinserts = @$cname;
        @vinserts = @$value;
        $inputStatus = 0 if (@cinserts != @vinserts);
    }
    elsif (ref($cname) eq 'ARRAY' || ref($value) eq 'ARRAY') {
        $inputStatus = 0;
    }
    else {
# test input value against database if column value has to be unique
        foreach my $unique (@{$self->{unique}}) {
            $uniqueTest = 1 if ($cname eq $unique);
        }
        if ($uniqueTest && associate($self,$cname,$value,$cname,-1)) {
            $self->{errors} .= "! newrow: column $cname value $value already exists\n";
            $inputStatus = 0;
        }
        push @cinserts, $cname;
        push @vinserts, $value;
        if (ref($Cname) eq 'ARRAY' && ref($Value) eq 'ARRAY') {
            push @cinserts, @$Cname;
            push @vinserts, @$Value;
            $inputStatus = 0 if (@cinserts != @vinserts);
        }
        elsif (ref($Cname) eq 'ARRAY' || ref($Value) eq 'ARRAY') {
            $inputStatus = 0;
        }
        elsif (defined($Cname) && defined($Value)) {
            push @cinserts, $Cname;
            push @vinserts, $Value;
        }
        elsif (defined($Cname) || defined($Value)) {
            $inputStatus = 0;
        }
    }

if ($list) {
print "NEWROW: status $inputStatus<br>";
print "cinserts @cinserts<br>";
print "vinserts @vinserts<br>";
}

# check the column values for compatibility and quote where appropriate

    if ($inputStatus) {
# identify columns and their type; test against the value
        my $columntype = $self->{coltype};
        for (my $i = 0 ; $i < @cinserts ; $i++) {
	    my $column = $cinserts[$i];
            my $cvalue = $vinserts[$i];
            if (!$columntype->{$column}) {
                $self->{errors} .= "newrow: column $column does not exist\n";
                $inputStatus = 0;
            }
            elsif (!isSameType($columntype->{$column},$cvalue)) {
                $self->{errors} .= "newrow: invalid value $cvalue for column $column \n";
                $inputStatus = 0;
            }
            else {
                $vinserts[$i] = quoteColValue($self,$column,$cvalue);
            }
        }
    }

if ($list) {
print "NEWROW: status $inputStatus<br>";
print "$self->{errors} <br>" if !$inputStatus;
}
# build the query string

    if ($inputStatus) {

        undef my ($cstring, $vstring, $wstring);
	for (my $i=0 ; $i < @cinserts ; $i++) {
	    $cstring .= ',' if $cstring;
            $cstring .= $cinserts[$i];
	    $vstring .= ',' if $vstring;
            $vstring .= $vinserts[$i];
            if (!$uniqueTest || $cinserts[$i] eq $cname) {
                $wstring .= ') and (' if $wstring;
                $wstring .= $cinserts[$i].'='.$vinserts[$i];
            }
        }

        if (!$multiLine || $multiLine <= 1) {

            my $nextrow = count($self,0) + 1; # number of the next row, force query on table
            my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
print "NEWROW: nextrow=$nextrow query: $query \n wstring $wstring \n" if $list;
            my $status = &query($self,$query,1,0); # to be       
        # on successful completion: store the WHERE string for further updates or rollback
            if ($status && count($self,0) == $nextrow) {
                $self->{whereclause} = "($wstring)";
                my $undoclause = "DELETE FROM <self> WHERE $self->{whereclause}";
                push @{$self->{undoclause}}, $undoclause;
                $inputStatus = $nextrow;
            }
            else {
                undef $self->{whereclause};
                $inputStatus = 0; # to be sure
            }
        }
        else {  
    # multi-line mode
            if (!$self->{stack}->{$cstring}) {
                my @vstack;
                $self->{stack}->{$cstring} = \@vstack;
            }
            push @{$self->{stack}->{$cstring}}, $vstring;
            if (@{$self->{stack}->{$cstring}} >= $multiLine) {
                my $nextrow = count($self,0) + $multiLine; # or leave out?
                $vstring = join '),(',@{$self->{stack}->{$cstring}};
                my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
print "NEWROW: nextrow=$nextrow query: $query \n";
                my $status = &query($self,$query,1,0);      
                if ($status && count($self,0) == $nextrow) {
                    $inputStatus = $nextrow;
                }
                else {
                    $inputStatus = 0;
                }
                undef $self->{stack}->{$cstring};
            }
        }
    }

    if (!$inputStatus) {
#        $self->{errors}  = "! Failed to insert new row into table $tablename \n";
    }

print "NEWROW return status: $inputStatus<br>" if $list;
    return $inputStatus; # 0 for failure, > 0 for success with status = nr of row added
}

#############################################################################

sub setMultiLineInsert {
    my $self = shift;
    my $line = shift;

    $line = 1 if (!$line || $line < 1);

    $self->flush() if $self->{multiLine}; # dump any pending new lines
    $self->{multiLine} = $line;
}

#############################################################################

sub flush {
# flush stack data, either all or a named stack
    my $self   = shift;
    my $string = shift;

    my $status = 0;
    my $stack = $self->{stack};
    foreach my $cstring (keys %$stack) {
        if (!$string || $cstring eq $string) {
            my $vstring = join '),(',@{$stack->{$cstring}};
            my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
print "FLUSH query: $query \n";
            $status = &query($self,$query,1,0);      
            undef $self->{stack}->{$cstring} if $status;
        } 
    }
    return $status;
}

#############################################################################

sub update {
# update a row identified by where clause or by putting one value in named column  
    my $self  = shift;
    my $cname = shift; # column to be updated
    my $value = shift; # with this value
    my $wkey  = shift; # either 'where' or a column name
    my $wval  = shift; # with a whereclause or a value
    my $limit = shift;
    my $exact = shift; # exact match of where clause subject

# test database and the input

    my ($dbh, $tablename) = whoAmI($self);

# build the WHERE clause: only allow wkey and wval simultaneously undefined

    my $doStamp = 1;
    my $whereclause;
    if (defined($wkey) && defined($wval) && defined($self->{coltype}->{$wkey})) {
# use input parameters
   # here test $wval for ! or 'not'
        $wval = &quoteColValue($self,$wkey,$wval);
        $whereclause = "$wkey";
# $whereclause =~ s/\=\s+null\s*$/IS NULL/i; 
        if ($wval =~ /^\(.*?\,.+\)/) {
            $whereclause .= ' in '; # with a list specification
        }
        elsif ($wval =~ /[\%\_]/ && !$exact) {
            $whereclause .= ' like '; # one value with wild cards
        }
        else {
            $whereclause .= ' = '; # one value exact match
        }
        $whereclause .= $wval;
        $whereclause =~ s/=\s*null\s*$/is null/i; # adjust for NULL values
# print "update:$cname $value  whereclause:$whereclause<br>\n";
    }
    elsif (defined($wkey) && defined($wval) && $wkey =~ /\bwhere\b/i) {
        $whereclause = $wval; # must be fully specified including quoting
    }
    elsif (!defined($wkey) && !defined($wval) && defined($self->{whereclause})) {
    # use previously stored string: this is an update after an insert
        $whereclause = $self->{whereclause};
        $doStamp = 0;
    } 
    else {
        $self->{errors} .= "! Failed to update $tablename: missing or invalid WHERE";
        $self->{errors} .= " clause: cname=$cname value=$value wkey=$wkey wval=$wval";
        return 0;
    }

# okay, now do the update
            
    my $status = 0; # default failure
#    $value = 'NULL' if (!defined($value) || $value != /\w/);
    if (defined($cname) && defined($value) && defined($self->{coltype}->{$cname})) {
        $value = &quoteColValue($self,$cname,$value);
    # note: for a complete rollback one should query the current value of cname and add undoclause e.g. 
    # (my $oldvalue) = $dbh->selectrow_array("SELECT $cname FROM $tablename WHERE $whereclause");
    # $undoclause = "UPDATE $tablename SET $cname = $oldvalue WHERE $whereclause";
        my $query = "UPDATE $tablename SET $cname = $value WHERE $whereclause";
        $query .= " limit $limit" if ($limit && $limit > 0); # if any
        $status = &query($self,$query,$doStamp);
    }

    if (!$status) {
        $self->{errors}  = "! Failed to update  table $tablename: $self->{qerror}:";
        $self->{errors} .= " $self->{qerror}" if  $self->{qerror};
        $self->{errors} .= " Invalid or undefined column name $cname or value $value" if !$self->{qerror};
    }

    return $status;   
}

#############################################################################

sub increment {
# increment an integer value by 1 or [n] in row identified by a value in named column 
    my $self   = shift;
    my $column = shift;
    my $cnamed = shift;
    my $cvalue = shift;
    my $change = shift; # default +1; must be numerical

    my $status = 0; # default failure

    $change = 1 if !$change;

# test database and the input

    my ($dbh, $tablename) = whoAmI($self);

    if (defined($column) && defined($self->{coltype}->{$column})) {
# the target column exists
        if (defined($cnamed) && defined($self->{coltype}->{$cnamed}) && defined($cvalue)) {
    # the named column and value exist
            if ($self->{coltype}->{$column} =~ /int/i && $change !~ /\D/) {
        # target column and the increment are of type numerical
                $cvalue = &quoteColValue($self,$cnamed,$cvalue);
                my $query = "UPDATE $tablename SET $column = $column+$change ";
                $query .= "WHERE $cnamed = $cvalue";
                $status = &query($self,$query,0);
#print "query=$query  status=$status<br>";
            }
        }
        else {
#print "invalid column $cnamed in $tablename<br>";
        }
    }
    else {
#print "invalid target column $column in $tablename<br>";
    }
    return $status;
}

#############################################################################

sub delete {
# delete a row identified by a value in named column  
    my $self  = shift;
    my $cname = shift; # either 'where' or a column name
    my $value = shift; # a where clause or its value
    my $limit = shift;

    my $status = 0; # default failure

# test database and the input

    my ($dbh, $tablename) = whoAmI($self,0,0); # no ping here

    my $columntype = $self->{coltype}; 

# insist on a non blank value

    if (defined($value) && $value =~ /\w/) {
        if (defined($cname) && defined($columntype->{$cname})) {
            $value = &quoteColValue($self,$cname,$value);
    # delete the qualified row
            my $query = "DELETE FROM $tablename WHERE $cname = $value";
            $query .= " limit $limit" if ($limit && $limit > 0);
            $status = &query($self,$query,1,0);
        }
        elsif ($cname =~ /where/i) {
            my $query = "DELETE FROM $tablename WHERE $value";
            $query .= " limit $limit" if ($limit && $limit > 0);
            $status = &query($self,$query,1,0);           
        }
        else {
            print "! Invalid column name $cname\n";
        }
    } else {
        print "! Missing value for column $cname in delete on $tablename\n";
    }
    return $status;
}

#############################################################################

sub rollback {
    my $self = shift;
    my $mode = shift;

# undo the previous change(s) to the catalogue, if any; (either remove the record or decrease counter)

    my $status = 0;
    if ($mode && defined($self->{undoclause})) {
    # a rollback list exists; undo previous changes
        my ($dbh,$tablename) = whoAmI($self);

        foreach my $undocommand (@{$self->{undoclause}}) {
# print "undo: $undocommand\n";
            query($self,$undocommand,1,0) || $status++;
#            my $sth = $dbh->prepare ($undocommand);
#            $sth->execute() || $status++;
#	     $sth->finish();
        }
    }

# &timestamp(0,$self) if ($status);

# remove any undo or where clause

    delete $self->{whereclause};
    delete $self->{undoclause};

    return $status;
}

#############################################################################

sub do {
# do with return of number of lines affected
    my $self = shift;
    my $todo = shift;

    my ($dbh, $tablename) = whoAmI($self);

    $todo =~ s/\<self\>/$tablename/i; # if placeholder <SELF> given

    return $dbh->do($todo); 
}

#############################################################################

sub query {
# general query processing
    my $self  = shift;
    my $query = shift;
    my $stamp = shift; # undefined or true for timestamp on (updates);
    my $trace = shift; # undefined or true for query trace;

    $trace = $qTracer if !defined($trace); # use default value
#    $trace = $self->{qTracer} if !defined($trace); # use default value

    my ($dbh, $tablename) = whoAmI($self);

# substitute placeholder <self> or add full tablename to query string

    $query =~ s/\<self\>/$tablename/i; # if placeholder <SELF> given
    if ($query =~ /^\s*(select|delete)/i) {
        $query =~ s/(where)/from $tablename $1/i  if ($query !~ /from/i);
        $query .= " from $tablename"              if ($query !~ /from/i);
    }

# handle NULL values

    $query =~ s/\!\=\s+null\s/is not NULL /ig; # replace any '!= null' 
    $query =~ s/\=\s+null\s/is NULL /ig;       # replace any  '= null' 

# apply the query tracer to test columns referenced (select only)
  
    $trace = 1 if (!defined($trace)); # default is for tracing
    $trace = 0 if (!keys(%{$self->{sublinks}})); # no links available
    $self->{lastQuery} = "query '$query'  traced:$trace";
    $query = &traceQuery($self,$query) if ($query =~ /select/i && $trace);

# execute the query

    undef my @hashrefs;
    undef $self->{qerror};
    my $sth = $dbh->prepare($query); 
#print "query on $tablename: $query<br>" if ($tablename =~ /STA|PRI|STR|CHE|VECT|LIG|ASS/);
#print "query on $tablename: $query<br>" if ($tablename =~ /STA|PRI|STR|CHE|VECT|LIG|ASS/);
#print "query on $tablename: $query<br>" if ($tablename =~ /READS$/ && $query !~ /SET/i && $query =~ /4/);
    my $status = $sth->execute();
    $status = 0 if !defined($status);
# beware: $status:0 (false) indicates an error; 0E0 indicates no data returned
    if ($status > 0) {
# there is at least one returned row
        while (my $hash = $sth->fetchrow_hashref()) {
            push @hashrefs, $hash;

        }
    } 
    elsif ($status < 0) {
        $status = 0; # false
    }
    $sth->finish();

# set error flag if appropriate

    $self->{qerror} = "Error status returned on query: $query" if !$status;

# modify timestamp if query changed the table (update, delete, insert, ..)

    if ($status > 0 && $query =~ /^\s*(insert|update|delete|replace)/i) {
        &timestamp(0,$self,lc($1)) if (!defined($stamp) || $stamp);
# rebuild the table in memory if a hash list exists
        buildhash(0,$self) if (defined($self->{hashrefs}) && @{$self->{hashrefs}});
    }

# output status is either  UNDEFINED or 0 (FALSE) for a failed query
#                      or  0E0 for an empty return table (zero but TRUE)
#                      or  the reference to an array of row hashes (at least 1)

    if (@hashrefs) {
        return \@hashrefs; # the query returns at least one line
    }
    else {
        return $status; # the query is empty but true (0E0) or failed (undef)
    }
}

#############################################################################

sub traceQuery {
# expand query to include full table names & trace query across linked columns
    my $self  = shift;
    my $query = shift;

    my $tracedQuery = $query;

# consider queries of type SELECT what FROM table(s) WHERE 

my $list = 0;
$list = 2 if ($self->{tablename} =~ /CONTIGS/);
    if ($query =~ /^\s*select(\s+distinct)?\s+(.*)\sfrom\s(.*)\swhere\s(.*)$/i) {
print "query \"$query\" to be traced <br>\n" if ($list>1);
        my $targets = $2;
        my @targets = split ',',$targets;
        my $tables  = $3;
        my @tables  = split ',',$tables;
        my $clauses = $4; $clauses =~ s/\s*limit.*//i;
        my @clauses = split /\sand\s|\sor\s/i,$clauses;

print "traceQuery targets: @{targets}<br>\n" if ($list>1);
print "traceQuery tables : @{tables} <br>\n" if ($list>1);
print "traceQuery whereclause: '@{clauses}'<br>\n" if ($list>1);
# (1) if any $target does not contain a table specification, add <self>
        undef my %AND;
        undef my %tables;
        undef my @wheres;
        foreach my $clause (@clauses) {
            $clause =~ s/[\(\)]/ /g; # remove parentheses
print "check clause: $clause<br>\n" if ($list>1);
            my $PATTERN = "\<\=|\>\=|\>|\=|\!\=|\>|\<|\\bis\\b|\\blike\\b|\\bin\\b|\\bbetween\\b";
            my ($colname,$colvalue) = split /$PATTERN/i,$clause;
            my $relation = $clause; $relation =~ s/$colname|$colvalue//g;
            if ($colvalue =~ /[\%\&]+/) {
                $relation =~ s/\=/ like/; # change to character string mode
                $relation =~ s/\!/ not/;
            }
print "decomposed clause: c='$colname' v='$colvalue'  r='$relation'<br>\n" if ($list > 1);
            $colname  =~ s/\s//g; # remove all blanks
            $colvalue =~ s/^\s+|\s+$//g; # remove leading and trailing blanks
            $colvalue =~ s/([\'\"])(.+)\1/$2/; # remove any quotations to avoid double quoting
print "ENTER traceColumn from $self->{tablename}: $colname value $colvalue r=$relation<br>\n" if ($list>1);
            my ($status, $and) = traceColumn($self,$colname,$colvalue,$relation);
print "AFTER traceQuery column $colname value $colvalue status=$status<br>\n" if ($list>1);
            if ($status) {
print "traceQuery exit: status=$status, and: $and<br>\n" if ($list>1);
#                undef my $newclause;
#                undef my $newtables; 
                foreach my $table (keys %$and) {
print "table $table   where clause section:  $and->{$table}<br>\n" if ($list>1);
                    if ($and->{$table} && $and->{$table} ne '1') {
                        $tables{$table}++;
#                        $newtables .= ', ' if ($newtables);
#                        $newtables .= $table;
                    }
                }
                my $fullname = whoAmI($self,0,0);
                push @wheres, $and->{$fullname}; # add full subquery to table
print "$fullname (sub)whereclause = $and->{$fullname}<br>\n" if ($list>1);
            }
            else {
                print "column $colname could not be traced<br>\n" if ($list);
                print STDOUT "$self->{qerror}\n" if $self->{qerror};
            }
        }
# now collect all tables and rebuild the clauses from each sub-clause
        undef my $newtables;
        foreach my $table (keys %tables) {
            $newtables .= ', ' if ($newtables);
            $newtables .= $table;
        }
# and merge the where clauses
#        my $newclause = $wheres[0]; # temporary (should be complete parser, also for select items)
        my $newclause = join ' AND ',@wheres;
print "OLD query: <h3>$query</h3><br>\n" if ($list);
        $clauses = quotemeta($clauses);
        $tracedQuery =~ s/$clauses/$newclause/ if $newclause;
        $tracedQuery =~ s/$tables/$newtables/  if $newtables;
print "NEW query: <h3> $tracedQuery</h3><br><br>\n" if ($list);


# further development from here on

        foreach my $target (@targets) {
print "test target $target<br>\n" if ($list>1);
            if ($target eq '*') {
                $tracedQuery =~ s/\*/$self->{tablename}.*/;
            }
            elsif ($target !~ /\./ && defined($self->{coltype}->{$target})) {
        # the table is not qualified and the column exists in this instance
                my $newtarget = $self->{tablename}.'.'.$target;
                $tracedQuery =~ s/$target/$newtarget/;
            }
            else {
        # a tablename is specified; check if it is in @tables
                my ($table,$column) = split '.',$target;
            }
	}

    # get columns and values listed in whereclause

#        my @comparison = ('=','!=','is','is not','like','not like','in','<','<=','=>','>');

print "traced query: $tracedQuery<br>\n" if ($list>1);
    }

    $self->{lastQuery} .= "<BR>\n".$tracedQuery; # add traced query to log

    return $tracedQuery;
}

#############################################################################

sub traceColumn {
    my $self    = shift;
    my $colname = shift;
    my $cvalue  = shift;
    my $relate  = shift;
    my $and     = shift;
#    my $noLimit = shift;

    my $fulltname = whoAmI($self,0,0); # get full table name

    undef my %AND; 
    $and  = \%AND if (!defined($and)); # the hash for AND clauses

    my $status = 0;
# to avoid looping: test the $and hash entry for this table
    return $status, $and if ($and->{$fulltname});
    $and->{$fulltname} = 1; # blocks any subsequent reference

# test if the column name is qualified by a tablename

    if ($colname =~ /\./) {
        my @names = split /\./,$colname;
        my $names = @names; # length (2 or 3)
        $colname = $names[$names-1] if ($names[$names-2] eq $self->{tablename});
    }
my $list = 0;
print "find column $colname in $self->{tablename}<br>\n" if ($list);

    if (my $coltype = $self->{coltype}->{$colname}) {
# a column of name $colname is found; now test its type and try if a value matches
print "column $colname found and type to be tested ($coltype) against $cvalue<br>\n" if ($list);
        my $count = 0;
        my $tvalue = $cvalue; # test value for isSameType test
        if ($relate =~ /in/i) {
            my @values = split ',',$cvalue;
	    $tvalue = \@values;
        }
#        my $limit = 'limit 1';
#        $limit = '' if ($noLimit);
        if (isSameType($coltype,$tvalue)) {
            $status = 1; # signal column found (but value may not be present)
            $cvalue = quoteColValue($self,$colname,$tvalue); # also quotes an array of values
            $count = associate($self,'count','where',"$colname $relate $cvalue",-1);
            $and->{$fulltname} = $self->{querywhereclause}; # register the sub query
#            $and->{$fulltname} =~ s/$limit// if $limit;
            return 0,$and if (!$count && $self->{qerror}); # error status aborts trace
print "after column test: count=$count status=$status<br>\n" if $list;
        }
# if no match was found OR no count in the target column, try alternate column names
        if (!$count) {
print "No column or match found: status=$status.  Try alternates @{alternates}<br>\n" if ($list);
            foreach my $column (@alternates) {
		my $coltype = $self->{coltype}->{$column};
                if ($column ne $colname && $coltype && &isSameType($coltype,$cvalue)) {
print "column $column tested<br>\n" if ($list);
                    if (associate($self,'count',$cvalue,$column,-1) > 0) {
print "count > 0  on $column <br>\n"if ($list);
                        $and->{$fulltname} = $self->{querywhereclause}; # overrides the sub query
                        $status = 1; # signal matching column with counts found
                        last; # accept the first one encountered
                    }
                }
	    }
        }
print "status on column $colname: $status  counts:$self->{querytotalresult}<br>\n" if ($list);
    }

# if the column/value combination does not exist, check linked tables

$list = 0;
    if (!$status) {
# try sublinks on each column of myself
        if (my $columns = $self->{columns}) {
            undef my $nonzeroquery;
            undef my $initialquery;
            undef my @cleartables;
            foreach my $column (keys (%{$self->{sublinks}})) {
print "NEXT COLUMN $self->{tablename} column $column<br>\n" if ($list);
                my $sublink = $self->{sublinks}->{$column};
                my $linktable  = $sublink->[0];
                my $linkcolumn = $sublink->[1];
            # find the subtable reference
                undef my $output;
                my $ltableref  = $instances{$linktable};
                if ($ltableref) {
print "$self->{tablename} column $column has link to  $linktable $linkcolumn<br>\n" if ($list);
print "linktableref=$ltableref<br>\n" if $list;
                   ($output, $and) = $ltableref->traceColumn($colname,$cvalue,$relate,$and);
                }
                else {
                    print "DbaseTable $linktable connect FAILURE: $self->{warnings}<br>\n";
                }
            # add where clause to AND list
                if ($output) {
                    my $cleanedname = $column;
                    $cleanedname =~ s/\_+$//; # remove trailing underscores
print "Found indeed: colname=$colname column=$column  cleaned:$cleanedname<br>\n" if ($list);
print "current value of and: $fulltname  $and->{$fulltname}<br>\n" if ($list);
                # we keep two queries: one with all contributions from sublinks
                # and one with only contributions with counts
                    if ($and->{$fulltname} eq '1') {
                        undef $and->{$fulltname}; # remove the gate keeper
                        $self->{querytotalresult} = 0; # reset counts
                    }
                    my $addition = "$fulltname.$cleanedname = $linktable.$linkcolumn";
                    $addition   .= " AND $and->{$linktable}"; # from lower level
                    my $nonzeroaddition = $addition; # re: nonzerorquery
                # wrap the add clause in parentheses if it is found to be composite
                    if ($and->{$fulltname}) {
                        $and->{$fulltname} = "($and->{$fulltname})" if ($and->{$fulltname} !~ /\sOR\s/i);# initial
                        $addition = " OR ($addition)"; # subsequent
                    }
                # assemble all contributions
                    $initialquery = $addition if !$initialquery; # query on first-encountered sub link
                    $and->{$fulltname} .= $addition;
                    $status++;
                # transfer item counts from link table to <self>
                    if ($ltableref->{querytotalresult} > 0) {
                        $self->{querytotalresult} += $ltableref->{querytotalresult};
                        if ($nonzeroquery) {
                            $nonzeroquery = "($nonzeroquery)" if ($nonzeroquery !~ /\sOR\s/i); # initial
                            $nonzeroaddition = " OR ($nonzeroaddition)"; # subsequent
                        }
                        $nonzeroquery .= $nonzeroaddition;
                    }
                    else {
                        push @cleartables,$linktable; # list of tables to be ignored
                    }
                }
            }
        # replace query by nonzeroquery, if it exists, and clear empty link nodes  
# undef $nonzeroquery; # test purposes
            if ($nonzeroquery) {
                $and->{$fulltname} = $nonzeroquery;
                foreach my $linktable (@cleartables) {
                    $and->{$linktable} = 1; # but retain the gatekeeper
                }
            }
        # all queries are empty: return the one on the first branch only, and clear other empty links
            elsif ($initialquery) {
#print "initial query used: $initialquery<br>";
                $and->{$fulltname} = $initialquery;
                foreach my $linktable (@cleartables) {
                    $and->{$linktable} = 1 if ($initialquery !~ /$linktable/); # but retain the gatekeeper
                }
            }
	    $and->{$fulltname} = "($and->{$fulltname})" if ($and->{$fulltname} =~ /\sOR\s/i);
        }
        else {
            die "DbaseTable instance $self->{tablename} not properly built";
        }
print "Exit trace column<br>\n" if ($list);
    }
print "RETURN $fulltname status=$status  and=$and->{$fulltname}<br>\n" if ($list);
    return $status, $and;
}

#############################################################################

sub isSameType {
# test a value type against a column type (private function)
    my $ctype = shift;
    my $value = shift;

    return 0 if (!defined($ctype) || !defined($value));

    my $same = 1;

# if value is presented as an array of possibilities, use recursion to check all items

    if (ref($value) eq 'ARRAY') {
        foreach my $trial (@$value) {
            $same = 0 if (!isSameType($ctype,$trial));
	}
    }
    else {

        my $vtype = 1; # default integer numerical;
        $vtype = 0 if ($value =~ /\S/ && $value =~ /[^\d\.\s]/); # contains non-numerical
        $vtype = 2 if ($vtype && $value =~ /\d+\.\d*/); # floating specification

# numerical specifications must be matched; everything else is considered string

        $same = 0 if ($ctype =~ /int/i   && $vtype != 1);
        $same = 0 if ($ctype =~ /float/i && $vtype == 0); # both integer and float
# do a detailed analysis of character strings
        if ($same && !$vtype) {
            $value =~ s/\%|\?//g; # remove wildcards
            $same = 0 if ($ctype =~ /char\((\d+)\)/i && length($value) > $1); # too long
            $same = 0 if ($ctype =~ /enum/i && $ctype !~ /$value/); # no match 
        }
    }

    return $same;
}   

#############################################################################

sub setTracer {
# (re)define default query tracing
    my $self  = shift;
    my $trace = shift;

    $trace = 0 if !$trace;
    $qTracer = $trace;
#    $self->{qTracer} = $trace;
}

#############################################################################

sub unlink {
# remove sublinks from this or all DbaseTables
    my $self = shift;

    if (shift) {
#print "unlink all tables<br>";
        foreach my $table (keys %instances){
            my $tableref = $instances{$table};
            undef $tableref->{sublinks};
#print "unlinked: $tableref->{tablename}<br>"; 
        }
    }
    else {
        undef $self->{sublinks};
    }
}

#############################################################################

sub timestamp {
# (private method) register and return  the current date and time 
    my $lock = shift;
    my $self = shift;
    my $kind = shift;

# external use only as: &timestamp(), returns reformatted local time

    if ($lock && $self) {
        die "! Y're not supposed to use method 'timestamp' this way\n";
    }

    my @time = (localtime);
    $time[4]++; # to get month
    $time[5] += 1900; # & year

    my $stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $time[5],
		$time[4], $time[3], $time[2], $time[1], $time[0]);

    if ($self) {
# add the time stamp to the table hash
        $stamp .= '&'.$kind if ($kind);
        $self->{timestamp} = $stamp;
    }

    return $stamp;
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "30 Nov 2000",
        updated =>    "08 Apr 2002",
    };
}

1;
