package DbaseTable;

# interface to MySQL data tables

use strict;

my $DEBUG = 0;

#############################################################################
# common to all instances of the DbaseTable class
#############################################################################

my %instances;
my $DBVERSION;

#############################################################################
# new method creates an instance of DbaseTable   
#############################################################################

sub new {
# constructor
    my $prototype  = shift;
    my $dbhandle   = shift; # the database handle
    my $tablename  = shift;
    my $database   = shift; # the database of the table
    my $build      = shift; # define 0 for descriptors only, 1 for hashrefs; undef for no build   
    my $order      = shift; # if build defined as 1, order by column 'order'
    my $dieOnError = shift || 0; # die if build fails

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    bless ($self, $class);

# table identification

    $self->{dbhandle}  = $dbhandle;
    $self->{tablename} = $tablename;
    $self->{database}  = $database;

# table instance attributes

    $self->{columns}   = []; # array for table column names
    $self->{coltype}   = {}; # hash with column types
    $self->{coldata}   = {}; # hash with complete column description
    $self->{prime_key} = ''; # place holder for the primary key
    $self->{unique}    = []; # place holders for a possible unique key
    $self->{autoinc}   = ''; # for a possible autoincremental column
    $self->{hashrefs}  = []; # array with hashrefs for table rows
    $self->{hashref}   = ''; # hash reference of last accessed table row 
    $self->{'build'}   =  0; # build hash status; true if table is loaded
    $self->{'index'}   = {}; # hash for a possible index on cached data
    $self->{'count'}   =  0; # length of table in database
    $self->{errors}    = ''; # build/instantiate error status
    $self->{warnings}  = ''; # build warning

# query attributes

    $self->{lastQuery} = ''; # the most recent query attempted 
    $self->{qerror}    = ''; # possible query eror status
    $self->{qTracer}   =  1; # default query tracing 'on'
    $self->{sublinks}  = {}; # hash with links to other tables
    $self->{timestamp} = ''; # timestamp if database contents changed
    $self->{alternate} = []; # array for alternate column names (re: tracing)

# multi line and counter insert mode

    $self->{stack}     = {}; # hash for multiple line insert stack
    $self->{multiLine} =  1; # default one line at time
    $self->{counts}    = {}; # hash for counter stack
    $self->{polyCount} = 64; # default update (possible) table counter 

# initialize the table only if build is defined (preset error status for build)

    $self->{errors} = "Initialisation pending for table $database.$tablename";
    &build($self,$build,$order,$dieOnError) if defined($build); # overrides errors 

# get the database version

    $DBVERSION = $self->query('select version()',0,0) if !$DBVERSION;

    return $self;
}

#############################################################################

sub spawn {
# spawn a new DbaseTable object with inheritance of current
# used on an ArcturusTable, the result is a new ArcturusTable instance 
    my $self      = shift;
    my $tablename = shift; # obligatory
    my $database  = shift; # defaults to $self->{database} if missing or specified as 'self' 
    my $forced    = shift; # if true, force creation of a new instance
    my $build     = shift;

    $database = $self->{database} if (!$database || $database =~ /\bself\b/);

    my $dbhandle = $self->{dbhandle};

    my $handle = $self->getInstanceOf($database.'.'.$tablename) || '';

    $handle = 0 if (ref($handle) eq 'DbaseTable' && ref($handle) ne ref($self)); # $self in sub class

# do a build if so specified and not done before (unless forced, which creates a new instance)

    $handle->build(1) if ($handle && !$forced && $build && !@{$handle->{hashrefs}});

# create, or force creation of, a new instance 

    $handle = $self->new($dbhandle,$tablename,$database,$build,@_) if (!$handle || $forced);

    return $handle;
}

#############################################################################
# initialise the table
#############################################################################

sub build {
# set switch "on" for full build including hash, else only table columns
    my $self   = shift;
    my $switch = shift;
    my $order  = shift;
    my $dieOE  = shift; # die if build fails

    my $count = 0;
    $self->{errors} = ''; # clear error flag

# test the database handle and get full table name

    my ($dbh, $tablename) = whoAmI($self, 1);

# prepare for column names and types and hashrefs 

    undef my %columns;
    undef my %coldata;
    undef @{$self->{hashrefs}};
    undef @{$self->{columns}};

# print "content-type: text/plain\n\n";

# test if the table exists

    my $exists = 0;
    my $query = "SHOW TABLES";
    $query .= " from  $self->{database}" if ($self->{database});
    my $sth = $dbh->prepare($query);
    my $status = $sth->execute();
    if ($status && $status > 0) {
#print "status $status $query<br>" if ($self->{tablename} !~ /ORG/);
        while (my @description = $sth->fetchrow_array()) {
            $exists = 1 if ($description[0] eq $self->{tablename});
        }
        if (!$exists) {
            $self->{errors} = "! Table $tablename does not exist";
            die "$self->{errors}" if $dieOE;
            return 0;
        }
    }
    else {
        $self->{errors} = "! Database $self->{database} is empty or does not exist";
        die "$self->{errors}" if $dieOE;
        return 0;
    }

# get index information

    my $hashes = $self->query("show index from $tablename");
    if ($hashes > 0) {
        foreach my $hash (@$hashes) {
            if (!$hash->{Non_unique} && $hash->{Key_name} !~ /INDEX/) {
                push @{$self->{unique}},$hash->{Column_name};
            }
        }
    }
# get the column names in an array; mark the primary key, if there is one
# if no primary key found, use a column named after table instead, if any
    undef my $prime_col;
    $sth = $dbh->prepare("SHOW COLUMNS from $tablename");
    if ($sth->execute()) {
        while (my @description = $sth->fetchrow_array()) {
            push @{$self->{columns}}, $description[0];   # keeps the order of entries
            $columns{$description[0]} = $description[1]; # hash for type information
            $coldata{$description[0]} = \@description;   # full description
            $self->{prime_key} = $description[0]     if ($description[3] eq 'PRI');
            $prime_col = $description[0] if ($tablename =~ /^\w+\.$description[0]$/i);
            $self->{autoinc} = $description[0] if ($description[5] && $description[5] =~ /auto/i);
            $count++; 
        }
        $self->{coltype} = \%columns;
        $self->{coldata} = \%coldata;
    }
    else {
        $self->{errors} = "! Could not access table $tablename";
        die "$self->{errors}" if $dieOE;
        return 0;
    }
    $sth->finish();

# if switch set build a hash of the whole table in memory
# order by the column defined, or else by the primary key, if any

    $self->{'build'} = 0;
    $switch = 0 if (!defined($switch));
    if ($switch && $order) {
        $count = buildhash(0, $self, $order);
    }
    elsif ($switch) {
# determine the default column to use for order
        $order = $prime_col if (defined($prime_col));
        $order = $self->{prime_key} if (!$order && $self->{prime_key});
# order will be undefined if no primary key or column named after table
        $count = buildhash(0, $self, $order);
    }
    else {
        $self->count(0); # stores length of table in $self->{'count'}
    }

# finally, add the table to the 'instances' inventory of the DbaseTable class

    $tablename = $self->makeFullTableName($tablename);
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
print "BUILDHASH method invoked (build=$self->{'build'}) on table $self->{tablename}\n" if ($self->{tablename} eq 'READS2CONTIG');

# get every row from the database as an array of hash references

    my $orderby = ' ';
    $orderby = "order by $order" if ($order);

    my $count = 0;
    my $query = "select * from <SELF> $orderby";
    my $hashrefs = query($self,$query,0,0);
    if (ref ($hashrefs) eq 'ARRAY' && @$hashrefs) {
        $self->{hashrefs} = $hashrefs;
        $count = @{$self->{hashrefs}};
        $self->{'count'} = $count;
        $self->{'build'} =  1;
        $self->{'index'} = {}; # remove index for partial cache
    }
    elsif ($hashrefs) {
        $self->{warnings} = "! Table $self->{tablename} is empty";
    }

# return the number of table lines

    return $count;
}

#############################################################################
# selective build: array of hashes for subset of the data 
#############################################################################

sub cacheBuild {
# partial build of internal hash
    my $self   = shift;
    my $query  = shift; # select query 
    my $option = shift;

    my %options = (queryTrace => 0, indexKey => 0, extend => 0,
                   sortBy     => 0, noIndex  => 0, list   => 0);
    $self->importOptions(\%options, $option);
    $options{indexKey} = $self->{prime_key} if !$options{indexKey}; # if any !

    my $report = "cache building query $query \n";

    my $storedhashrefs = $self->{hashrefs};
    my $hashrefs = $self->query($query,0,$options{queryTrace});
    if ($hashrefs && ref($hashrefs) eq 'ARRAY') {
        undef @$storedhashrefs if !$options{extend};
        push  @$storedhashrefs, @$hashrefs;   

if ($self->{tablename} eq 'READS2CONTIG') {
#     my $n = @$storedhashrefs; print "$report: $n hashes stored \n";
#     print "cacheBuild storedhashrefs: @$storedhashrefs \n";
#    foreach my $hash (@$storedhashrefs) {
#        print "$hash  $hash->{read_id} $hash->{deprecated} $hash->{label} \n";
#    } 
}

    }
    else {
        $report .= "! No data found \n";
    }
    
# build an index if a key is specified

    my $coltype = $self->{coltype};
    if (my $indexKey = $options{indexKey}) {
# first test if the key is unique
        my $isUnique = 0;
        foreach my $unique (@{$self->{unique}}) {
            $isUnique = 1 if ($indexKey eq $unique);
        }
        $report .= "indexKey = $indexKey   isUnique=$isUnique \n";

        $self->{'index'} = {};
        my $index = $self->{'index'};

        if (!$coltype->{$indexKey}) {
            $report .= "Unknown column: $indexKey\n";
        }
        elsif ($isUnique) {
# in case of a unique key, we can build a hash table
            my $nh = @$storedhashrefs;
            $report .= "$nh entries found \n";
            foreach my $i (1 .. $nh) {
                my $key = $storedhashrefs->[$i-1]->{$indexKey};
                $index->{$key} = $storedhashrefs->[$i - 1];
            }
        }
        else {
# in case of a non-unique key, we build a two dimensional table
            my $sort = $options{sortBy};
	    $sort = $indexKey if !$sort;
            $sort = "$indexKey,$sort" if ($sort !~ /\b$indexKey\b/);
# build a sort string from the input specification
            my @sort = split /\s*\,\s*/, $sort;
            foreach my $sort (@sort) {
                my $cmp = 'cmp';
                if (!$coltype->{$sort}) {
                    $report .= "Unknown column $sort \n";
                }
                elsif ($coltype->{$sort} =~ /int|float/i) {
		    $cmp = '<=>';
                }
                $sort = '$a->{'.$sort.'} '.$cmp.' $b->{'.$sort.'}';
            }
            my $sortstring = join ' or ',@sort; $sortstring .= ';';
            my $sorter = '@$storedhashrefs = sort {'.$sortstring.'} @$storedhashrefs';
            $report .= "sorting by: $sorter \n";
            eval $sorter;
# now set up the index by going through the hashes now ordered with index key
            my $nh = @$storedhashrefs;
            $report .= "$nh entries found \n";
            foreach my $i (1 .. $nh) {
                my $key = $storedhashrefs->[$i-1]->{$indexKey};
                my $nmr = 0; $nmr = 1 if $index->{$key};
                $index->{$key}->[$nmr] = $i - 1;
                $index->{$key}->[1] = $i - 1 if !$nmr;
            }
        }
#        $self->{'build'} = $query; # or sortKey? ! this will destroy the index on any update/delete
    }
    else {
        $report .= "No index key or sorting key defined \n";
    } 
    
#print "index status: $report \n" if ($self->{tablename} eq 'READS2CONTIG');
#$options{list} = 1 if ($self->{tablename} eq 'READS2CONTIG');
# list the index 

    if ($options{list}) {
        print STDOUT $report;
        my $index = $self->{'index'};
        foreach my $key (sort keys %$index) {
            my $result = $self->cacheRecall($key);
            next if (!$result || $options{list} <= 1);
            foreach my $hash (@$result) {
                print STDOUT "$hash: ";
                foreach my $key (sort keys %$hash) {
                    print STDOUT "$key $hash->{$key}  ";
		}
                print STDOUT "\n";
            } 
        }
    }
}

#############################################################################

sub cacheRecall {
# returns a ref to array with 1 or more hashes or 0
    my $self = shift;
    my $ikey = shift; # the index key

    my $hashrefs = $self->{hashrefs};
    my $index    = $self->{'index'};

my $LIST = 0; # $LIST = 1 if ($self->{tablename} eq 'READS2CONTIG');

    my $result = 0; # default no data
    if (my $hash = $index->{$ikey}) {
print STDOUT "recall: $ikey $index->{$ikey} \n" if $LIST;
        my @result;
print STDOUT "recall: $ikey  hash $hash  " if $LIST;
        if (ref($hash) eq 'ARRAY') {
            my $is = $hash->[0];
            my $if = $hash->[1];
print STDOUT "s:$is  f:$if " if $LIST;
            foreach my $i ($is .. $if) {
                push @result, $hashrefs->[$i];
            }
        }
        else {
            push @result, $hash;
        }
print STDOUT "\n" if $LIST;
        $result = \@result if @result;
    }
    else {
print STDOUT "recall: $ikey NOT FOUND \n" if $LIST;
    }

    return $result; 
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
    if (!$dbh) {
        die "undefined database handle";
    }
    elsif (!defined($ping) || $ping) {
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

sub getColumnInfo {
# return description of specified column 
    my $self   = shift;
    my $column = shift || return '';
    my $order  = shift || 0; # order enum values

    my $description = $self->{coldata}->{$column} || return '';

    my $info = $column;
# remove size info from integer fields
    $description->[1] =~ s/\(\d+\)//   if ($description->[1] =~ /int/i);
# handle enumerated items
    if ($description->[1] =~ /enum\(([^\)]+)/i && $order) {
        my @choices = split /\,/,$1;
        @choices = sort @choices;
        my $choices = join ',',@choices;
        $description->[1] = "enum($choices)";
    }
    $info .= ' '.$description->[1];
# check on default
    $description->[4] = '' if !defined($description->[4]);
    if ($description->[4] =~ /\S/ && $description->[4] !~ /NULL|0000-00-00|00:00:00/i) {
# there is a default defined
        if ($description->[4] =~ /\D/ || $description->[1] =~ /char|enum/) {
            $info .= " default '$description->[4]'";
        }
        else {
            $info .= " default $description->[4]";
        }
    }
    elsif ($description->[2] =~ /yes/i) {
        $info .= ' NULL';
    }
    else {
        $info .= ' NOT NULL' 
    }

    $info .= ' '.$description->[5] if ($description->[5] =~ /auto/);

    $info .= ' primary key' if ($description->[3] =~ /pri/i);

    return $info;
}

#############################################################################

sub getInstanceOf {
# find the instance of the named table in the DbaseTable class %instances
    my $self = shift;
    my $name = shift;

# if no input name given, return reference to the instances hash

    return \%instances if !$name;

# else, return the table instance keyed on its full name (on the current node)

    $name = $self->makeFullTableName($name);
    return $instances{$name};
}

#############################################################################

sub makeFullTableName {
# build the full tablename using server and database info
    my $self = shift;
    my $name = shift;

# full tablename "DB-handlestring.database.tablename"

    my $database = $self->{database};
    my $dbhandle = $self->{dbhandle};
print "makeFullTableName: no table handle" if !$self->{dbhandle};
    $dbhandle =~ s/.*\((\w+)\).*/$1/; # strip out clutter
    my $prefix = $dbhandle.'.'.$database;

# test format of input name and add appropriately 

    my $fullTableName = $name;
    $name =~ s/\<?self\>?/$self->{tablename}/i; # fill placeholder 'self'
    if ($fullTableName !~ /\./) {
# database nor server specified
        $fullTableName = $prefix.'.'.$name;
    }
# test substitution of place holder '<self>'
    elsif ($fullTableName !~ s/\<self\>/$prefix/i) {
# database is specified in input name; add handlestring (assumed to be never specified in input name)
        $fullTableName = $dbhandle.'.'.$name;
    }

#print "makeFullTableName: input: $name  handle: '$dbhandle' full name: $fullTableName<br>\n";

    return $fullTableName;
}

#############################################################################

sub listInstances {
# produce a list of all current instances of DbaseTable
    my $self  = shift;
    my $break = shift || "\n";
    
    my $list = "Current table instances:$break$break";
    foreach my $instance (sort keys (%instances)) {
#        $list .= "$instance  $instances{$instance} $break";
        $list .= sprintf "%-40s  %32s $break", $instance, $instances{$instance}; 
    }

    my $hashes = $self->query("show tables");
    $list .= "${break}Tables in the current database:$break$break";

    foreach my $hash (@$hashes) {
        my @keys = keys %$hash;
        $list .= "$hash->{$keys[0]}  $break";
    }

    $list;
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
            my $tablehandle = $self->getInstanceOf($linktable);
            my $destination = $linktable.'.'.$linkcolumn;
            if (!defined($href->{$key}) || $href->{$key} ne $destination) {
                $href->{$key} = $destination; # prevent looping
# print "<br>TRACETABLE $self->{tablename} linktable=$linktable tableref=$tablehandle <br>\n";
                $tablehandle->traceTable($href);
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
    my $multi = shift || 0; # true i.e !=0 forces search for more than one return items, <0 no trace
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

# (obsolete?? column item must be defined in myself; wcol can be in a linked table)

    my %option = (traceQuery   => 1, # default query expansion activated
                  compareExact => 0, # default use 'like' in string comparisons, else '='
                  useCache     => 1, # default test table image hash, if it exists
                  returnScalar => 1, # default return scalar if query returns single column value
                  orderBy      => 0, # override with column name if ordering required
                  limit        => 0, # default no maximum specification
                  debug        => 0);
    $option{useCache} = 0 if ($item =~ /\,|\(.+\)/); # override default for composite $item
    $option{useCache} = 0 if (keys %{$self->{'index'}}); # don't allow with partial cache (temporary)
    $self->importOptions(\%option, $multi);

# the next lot redefines options using $multi, $order, $exact input in old applications

    if (!$multi || (ref($multi) ne 'HASH')) {
        $option{traceQuery}   = 0 if ($multi < 0);
        $option{compareExact} = 1 if $exact;
        $option{useCache}     = 0 if ($multi != 0 || (defined($wval) && $wval =~ /[\%\_]/));
        $option{useCache}     = 1 if $exact; # overrides above; used for values containing '%' or '_'
        $option{orderBy} = $order if $order;
        $option{limit} = abs($multi) if (abs($multi) > 1); 
    }
    else {
        $option{useCache} = 1 if ($option{compareExact} > 1); # for values containing '%' or '_'
    }

    undef my $hash;
    undef my $result;
    $self->qclean;

# if one only exact match is required (no wildcards) test possible stored table hash

   ($hash, $result) = &locate($self,$wval,$wcol) if $option{useCache};

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
# other dev: no hash but wval defined and wcol not ??

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
        elsif ($option{traceQuery}) {
# the test column $wcol does not exist in myself, is composite, or wval is of wrong type
            $useQueryTracer = $self->{qTracer};
            $useQueryTracer = 0 if (!keys(%{$self->{sublinks}})); # no links available
        }
        elsif (($isComposite || $item ne 'count') && $wval !~ /\bwhere\b/i) {
# the test column $wcol does not exist in myself
            $self->{qerror} = "Column $wcol does not exist in <self>";
            $item = ' '; # skips the remainder
        }

# determine limit setting

        my $limit = ''; $limit = "limit $option{limit}" if $option{limit};

# determine possible ordering

        my $orderby = ''; $orderby = "order by $option{orderBy}" if $option{orderBy};

        my $whereclause = $wcol;
        if ($wval =~ /\bwhere\b/i) {
    # in this case $wcol should contain the full specification
            $select .= ' DISTINCT' if ($wval =~ /distinct/i);
print "item:$item  wval:$wval  whereclause:$whereclause $useQueryTracer $self->{qTracer}\n" if $option{debug};
        }
        else {
    # test and strip negation prefix
            my $not = 0; $not = 1 if ($wval =~ s/\s*(\!|not)\s*//i);
    # in this case $wcol should contain the column name and $wval a value
            if ($wval =~ /^\(.*?\,.+\)/) {
                $whereclause .= ' not' if $not;
                $whereclause .= ' in '; # with a list specification
            }
            elsif ($wval =~ /[\%\_]/ && !$option{compareExact}) {
                $whereclause .= ' not' if $not;
                $whereclause .= ' like '; # one value with wild cards
            }
            else {
                $whereclause .= '!' if $not;
                $whereclause .= '='; # one value exact match
            }
            $whereclause .= $wval;
            $whereclause =~ s/=\s*null\s*$/is null/i; # adjust for NULL values
print "item:$item  wval:$wval  whereclause:$whereclause   not=$not<br>\n" if $option{debug};
        }
    # memorize the select where clause
        $self->{querywhereclause} = "$tablename.$whereclause";
        $self->{querytotalresult} = 0; # default no result returned
        
        my $query = 'UNDEF';
        my $queryStatus = 0;
        if (defined($self->{coltype}->{$item})) {
            $query = "$select $item from $tablename WHERE $whereclause $orderby $limit";
            $query =~ s/where\s+order/order/i; # in case whereclause empty 
print "$self->{tablename}: input query = '$query'\n" if  $option{debug};
            $self->{lastQuery} = $query;
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            undef my @result; 
# if (my $array = $dbh->traceQuery(selectcol_arrayref ($query)) {
#     $result = $array;
            my $sth = $dbh->prepare($query); # return array of hashrefs
            if ($sth->execute()) {
                $result = \@result if !$option{returnScalar}; # valid query but may be empty
                $queryStatus = 1; # signal valid query
                while (my $hash = $sth->fetchrow_hashref()) {
                    push @result, $hash->{$item};
                    $result = \@result;
                }
            }

            $self->{querytotalresult} = @result + 0;
# compose the output value: either a value or array reference
            if (@result == 1 && $option{returnScalar}) {
                $result = $result->[0];
            }
        }

        elsif ($item =~ /\bcount\b/i) {
# no query tracing provided in count, nor 'count(item)'
            $result = &count($self,$whereclause);
            $queryStatus = 1 if (defined($result));
            $self->{querytotalresult} = $result || 0;
        }

        elsif ($item eq 'hashref') {
            $query = "$select * from $tablename WHERE $whereclause limit 1";
            $self->{lastQuery} = $query;
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            my $sth = $dbh->prepare ($query); # return hashref to first record found
            if ($sth->execute()) {
                $queryStatus = 1; # signal valid query
                $result = $sth->fetchrow_hashref();
                $self->{querytotalresult} = 1;
            }
        }

        elsif ($item eq 'hashrefs' || $isComposite) {
            undef my @hashrefs;
            undef my $hashrefs;
            $item = '*' if !$isComposite;
            $query = "$select $item from $tablename WHERE $whereclause $orderby $limit";
            $self->{lastQuery} = $query;
            $query = &traceQuery($self,$query) if ($useQueryTracer);
            my $sth = $dbh->prepare ($query); 
            if ($sth->execute()) {
                $queryStatus = 1; # signal valid query
                $hashrefs = $sth->fetchall_arrayref({}); # return array of hashrefs
                $hashrefs = \@hashrefs if !$hashrefs; # to ensure it's a ref to an empty array
# while (my $hash = $sth->fetchrow_hashref()) {
#     push @hashrefs, $hash;
# }
            }
            $self->{querytotalresult} = @$hashrefs + 0; 
            $result = $hashrefs;
        }
        elsif ($item && $item =~ /\S/) {
            $self->{qerror} = "Invalid column name '$item' in table $tablename\n";
        }

# $result is either defined, including the numerical value '0', as query answer
# or undefined which indicates either an invalid query or an empty query. Hence (not correct ?)
# we re-assign '0' (FALSE) also to an undefined result, but this means that output
# '0' should be accompanied by a test for a valid query with $self->{qerror} or
# a test on the number of entries returned with $self->{querytotalresult}

        $self->{qerror} .= "Failed query on table $tablename:\n'$query'" if !$queryStatus;
        $result = 0 if !defined($result);
    }

    elsif (defined($wval) || defined($wcol)) {
# one of them is undefined
        $result = 0; # false, because invalid use of associate
    }

    elsif ($item && $item eq 'hashrefs') {
        $result = $self->{hashrefs}; # if any, array reference
    }

    elsif (defined($item) && (!@{$self->{hashrefs}} || $multi)) {
# print "$self->{tablename} associate item=$item  wval=$wval wcol=$wcol multi=$multi \n"; # TO BE TESTED
# $result = $self->associate($item,'where',1,1,$item); # returns an ordered array or undefined
        $option{orderBy} = $item;
        $result = $self->associate($item,'where',1,\%option); # returns an ordered array or undefined
    }

    elsif (defined($item)) {
# print "item $item\n";
        undef my @values;
        foreach my $hash (@{$self->{hashrefs}}) {
            push @values, $hash->{$item};
        }
        @values = sort @values;
        $result = \@values if @values;
    }

    $result;
}

#*******************************************************************************

sub importOptions {
# overwrite input options hash with values presented in hvalues
    my $self    = shift;
    my $options = shift; # hash with preset options
    my $hvalues = shift; # hash with values overriding the preset options

    my $status = 0;
    if (ref($options) eq 'HASH' && ref($hvalues) eq 'HASH') {
        foreach my $option (keys %$hvalues) {
            $options->{$option} = $hvalues->{$option};
        }
        $status = 1;
    }

    $status;
}

#############################################################################

sub quoteColValue {
# determine the type of the column and quote the value
    my $self  = shift;
    my $cname = shift || 0;
    my $value = shift;

# get database handle

    my ($dbh, $tablename) = whoAmI($self,0,0); # no ping

    undef my $output;
    if (defined($value) && (my $columntype = $self->{coltype}->{$cname})) {
        my $quote = 0;
        $quote = 1 if ($columntype =~ /char|blob|date|enum/i);
        if (ref($value) =~ /ARRAY/i) {
            my $count = 0;
            foreach my $choice (@$value) {
                $output .= ',' if $count++;
                if ($quote) {
                    $choice =~ s/^([\'\"])(.*)\1$/$2/; # chop off any existing quotes
                    $choice = $dbh->quote($choice) unless ($choice =~ /^null$/i);
                }
                $output .= $choice;
            }
            $output = '('.$output.')' if ($count > 1); # better than rely on ','
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
# locate a column $item of value $wval in the internal hash table
    my $self = shift;
    my $wval = shift;
    my $item = shift;
# update an associated column with a new value in the internal hash ??
    my $column = shift;
    my $nvalue = shift; 

# return hash reference to a row where:
# (1) the value of column  item equals "wval" (if $item defined) ; return hash reference and item value
# (2) the value of any row item equals "wval"  ($item undefined) ; return hash and column name

    undef my $result;
    undef my $rvalue;

    if (defined($wval) && defined($self->{hashrefs})) {           
# what to do if partially cached data ? ($self->{'index'} exists)
  
        foreach my $hash (@{$self->{hashrefs}}) {

            if (defined($item) && defined($hash->{$item}) && $hash->{$item} eq $wval) {
                $result = $hash;
                $rvalue = $hash->{$item};
# what does this do and why?
                if (defined($column) && defined($nvalue)) {
print "$self->{tablename}: new value $nvalue for column $column \n";
                    $hash->{$column} = $nvalue;
                }
            } 
            elsif (!defined($item)) {
                foreach my $column (@{$self->{columns}}) {
                    if (defined($hash->{$column}) && $hash->{$column} eq $wval) {
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

sub probe {
# test if a specified item exists for a given value and/or constraint
    my $self       = shift;
    my $item       = shift;
    my $value      = shift;
    my $constraint = shift;

    my $where = '';
    $where .= "$item = $value" if defined($value);
    $where .= " and " if ($where && $constraint);
    $where .= $constraint if $constraint;
    $where = "$item is not null" if !$where;

# return the first one found

    return $self->associate($item,'where',$where,{limit=>1});
}

#############################################################################

sub find {
# find table entries matching the item<>value pairs in $query
    my $self  = shift;
    my $query = shift; # the hash reference to input query value pairs
    my $sitem = shift; # the item to be returned; can be 'hash'
    my $exact = shift; # set true for exact matching values

    undef my @output;
    my $hashrefs = $self->{hashrefs};
    @output = @$hashrefs if ($hashrefs && @$hashrefs);

    undef my $whereclause;
    foreach my $column (@{$self->{columns}}) {
# is this column is in the search specification?
        if (my $value = $query->{$column}) {
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
# accumulate query
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

print "sub $self->{tablename}->nextrow (to be deprcated) \n";

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
    my $item  = shift || "*"; # default all rows
    my $trace = shift || 0; 

# where = undefined: if a hash exists with table entries, return size of hash
# where = defined 0: return full length of database table

# return number of database table entries which satisfy the query

# if the count is on the whole table, store as 'count' in the $self hash

    undef my $count;
    if (defined($self->{hashrefs}) && @{$self->{hashrefs}} && !defined($where)) {
        $count = @{$self->{hashrefs}};
# store in $self hash
        $self->{'count'} = $count;
# note: the curent hash could be different from the actual table; if you want
# to be sure to count on the actual database table, force a query on the database
# by defining $where, e.g. &count(1)
    }
    else {
        my $whereclause = '';
        $whereclause = $where if ($where && $where =~ /like|\=|\<|\>/i);
        $whereclause = 'WHERE '.$whereclause if ($whereclause && $whereclause !~ /where/i);
        my ($dbh, $tablename) = whoAmI($self);
        my $query = "SELECT COUNT($item) FROM $tablename $whereclause";
#print "count: $query <br>";
        $query = &traceQuery($self,$query) if $trace;
        undef $self->{qerror};
        $self->{lastQuery} = $query;
        my $sth = $dbh->prepare ($query);
        if ($sth->execute()) {
            $count = $sth->fetchrow_array();
        }
        else {
            $self->{qerror} = 1;
        }
        $sth->finish();
# store in $self hash, if count on whole table
        $self->{'count'} = $count if !$where;
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

# define a count, if it's not done on input
                
    $count = 1 if !defined($count);

# (1) test if column name cname exists i.e. is among the @columns
# (2) if so then test if $value exists (exact match)

    my $iden = 0;
    my $error = '';
    undef my $counter;
    foreach my $column (@{$self->{columns}}) {
        $counter = $column if (!$counter && $column =~ /count|reads/i); # take first one encountered
        $counter = $alter  if ($alter && $column eq $alter); # overrides, be sure $alter exists
        if (defined($cname) && $cname eq $column && defined($value)) {
            $iden = 2;
            my $hashrefs = $self->{hashrefs}; # should be a HASH ref
            if ($hashrefs && @$hashrefs) {
                foreach my $hash (@$hashrefs) {
                    $iden = 1 if ($value eq $hash->{$column});
                }
            }
# this branch is used when the table is not loaded as a hash into memory
            elsif ($self->associate($cname,$value,$column)) {
                $iden = 1;
            }
        }
    }

# iden = 0 : the column name does not exist; abort
# iden = 1 : both the column name and requested value do exist; increase counter
# iden = 2 : the column name does exist but requested value doesn't; add new row

    if ($iden) {

# get the insert mode

        my $polyCount = $self->{polyCount} || 1;
        $polyCount = 1 if !$self->{'build'}; # no stored table
$polyCount = 1; # test

        undef my $whereclause;

        if ($iden == 2) {
# create a new row (with counter at 0; also this creates the "where clause" for the new row)
print "New Row for $self->{tablename} <br>" if ($polyCount > 1);
            &newrow ($self, $cname, $value) or $iden = 0;
	    $whereclause = $self->{whereclause};
            &buildhash(0,$self) if ($iden && $self->{'build'}); # reload the counter table
        } 
        else {
# the row already exists; get the "where clause" to target it
            my $quotedvalue = &quoteColValue($self,$cname,$value);
            $whereclause = "$cname = $quotedvalue";
            $whereclause =~ s/\=\s+null/IS NULL/i; # in case value "null" is specified
        }

# update the row counter

        if ($iden && $counter && $whereclause) {
# protect against counter underflow (and leave table unchanged)
            if ($count < 0) {
                $count = 0 if (associate($self,$counter,$cname,$value) < -$count);
                $self->{warnings} .= "attempt to decrease counter $counter by $count to below 0\n"; 
            }

            my $template = "UPDATE <self> SET counter WHERE $whereclause";
            if ($count != 0 && $polyCount <= 1) {
# single count insert mode (probably very inefficient)
                my $command = "UPDATE <self> SET $counter=$counter+$count WHERE $whereclause";
                $command =~ s/\+\s*\-/-/; # change possible '+-' to '-'
                &query($self,$command,1,0) or $iden = 0;
                if (!$iden) {
                    $error = "failed to modify column $counter";
                }
                else {
                    $command = "UPDATE <self> SET $counter=$counter-$count WHERE $whereclause";
                    $command =~ s/\-\s*\-/+/; # change possible '--' to '+'
                    push @{$self->{undoclause}}, $command;
                }
# update the stored hash image ($counter + $count for $cname = $value) 
                foreach my $hash (@{$self->{hashrefs}}) {
                    $hash->{$counter} += $count if ($hash->{$cname} eq $value);
                }
            }
# the next branch handles the polyCount mode
            elsif ($count != 0) {
#print "$self->{tablename}: use counter stack <br>";
                my $counts = $self->{counts};
# store count sum on combination of counter column and where clause as key
                $counts->{$counter.':'.$whereclause} += $count;
# update the stored hash image
# my $list = $self->list(); $list =~ s/\n/<br>/g; print $list;
                foreach my $hash (@{$self->{hashrefs}}) {
                    $hash->{$counter} += $count if ($hash->{$cname} eq $value);
                }
# get total changes until now
                my $total = 0;
                foreach my $clause (keys %$counts) {
                    next  if !$counts->{$clause};
                    $total += $counts->{$clause};
                }
# decide on flush
#print "   total count: $total<br>";
                if ($total >= $polyCount) {
                    $error = $self->cflush();
# keep the last insert as undo clause (but store only after a flush)
                    my $command = $template;
                    $command =~ s/\stemplate\s/ $counter=$counter-$count /;
                    $command =~ s/\-\s*\-/+/; # change possible '--' to '+'
                    push @{$self->{undoclause}}, $command if !$error;
                }
            }
        } 
        elsif ($counter) {
            $error = "failed to create a new row";
            $iden = 0;
        }
        else { # no counter
            $self->{warnings} .= "table <self> has no counter column";
            $iden = 0;
        }
    }

    elsif (defined($value)) {

        if (defined($cname)) {
            $error = "column \'$cname\' not found";
        }
        else {
            $error = "undefined column for value $value";
        }
    }

    $self->{qerror} = "Failed to update (counter) table <self>: $error" if $error;

    return $iden;
}

#############################################################################

sub cflush {
# process any pending counter inserts
    my $self = shift;

    my $counts = $self->{counts};

    my $status = '';
    foreach my $key (keys %$counts) {
        my $count = $counts->{$key} || next;
        my ($counter, $whereclause) = split /\:/,$key,2;
        my $command = "UPDATE <self> SET $counter=$counter+$count WHERE $whereclause";
#print "$command <br>" if ($self->{tablename} eq 'SESSIONS');
        $command =~ s/\+\s*\-/-/; # change possible '+-' to '-'
#print "$command <br>" if ($self->{tablename} eq 'SESSIONS');
print "$command <br>";
        if ($self->query($command,1,0,0)) {
            delete $counts->{$key};
        }
        else {
            $status .= "failed to modify column $counter\n";
        }
    }
    return $status;
}

#############################################################################

sub newrow {
# create a new row by putting one value in named column  
    my $self  = shift;
    my $cname = shift; # column name or array reference (obligatory)
    my $value = shift; # its  value  or array reference (obligatory)
    my $Cname = shift; # column name or array reference (optional)
    my $Value = shift; # its  value  or array reference (optional)

    my $multiLine = $self->{multiLine};

# test input data; build arrays with values to be inserted

    my $inputStatus = 1;
    my @cinserts; # columns
    my @vinserts; # values
    my $uniqueTest = 0;
    my $error = '';

    if (!defined($cname) || !defined($value)) {
        $inputStatus = 0;
        $error = "undefined column name $cname or value $value";
    }
    elsif (ref($cname) eq 'ARRAY' && ref($value) eq 'ARRAY') {
        @cinserts = @$cname;
        @vinserts = @$value;
        if (@cinserts != @vinserts) {
            my $nc = @cinserts; my $nv = @vinserts;
            $error = "unequal array sizes (cname $nc, value $nv)";
            $inputStatus = 0;
        }
    }
    elsif (ref($cname) eq 'ARRAY' || ref($value) eq 'ARRAY') {
        $inputStatus = 0; # one array missing
        $error = "missing input array";
    }
    else {
# test input value against database if column value has to be unique
        foreach my $unique (@{$self->{unique}}) {
            $uniqueTest = 1 if ($cname eq $unique);
        }
        if ($uniqueTest && associate($self,$cname,$value,$cname,-1)) {
            $error = "column $cname value $value already exists";
            $inputStatus = 0;
        }
        push @cinserts, $cname;
        push @vinserts, $value;
        if (ref($Cname) eq 'ARRAY' && ref($Value) eq 'ARRAY') {
            push @cinserts, @$Cname;
            push @vinserts, @$Value;
            if (@cinserts != @vinserts) {
                my $nc = @cinserts; my $nv = @vinserts;
                $error = "unequal array sizes (Cname $nc, Value $nv)";
                $inputStatus = 0;
            }
        }
        elsif (ref($Cname) eq 'ARRAY' || ref($Value) eq 'ARRAY') {
            $inputStatus = 0;
            $error = "missing input array";
        }
        elsif (defined($Cname) && defined($Value)) {
            push @cinserts, $Cname;
            push @vinserts, $Value;
        }
        elsif (defined($Cname) || defined($Value)) {
            $inputStatus = 0;
            $error = "missing column name or value";
        }
    }

# check the column values for compatibility and quote where appropriate

    if ($inputStatus) {
# identify columns and their type; test against the value
        my $columntype = $self->{coltype};
        for (my $i = 0 ; $i < @cinserts ; $i++) {
	    my $column = $cinserts[$i];
            my $cvalue = $vinserts[$i];
            if (!$columntype->{$column}) {
                $error = "column $column does not exist";
                $inputStatus = 0;
            }
            elsif (!isSameType($columntype->{$column},$cvalue,1)) {
                $error = "invalid value $cvalue for column $column";
                $inputStatus = 0;
            }
            else {
                $vinserts[$i] = quoteColValue($self,$column,$cvalue);
            }
        }
    }

# build the query string

    if ($inputStatus) {

        undef my $cstring;
        undef my $vstring;
        undef my $wstring;
	for (my $i=0 ; $i < @cinserts ; $i++) {
	    $cstring .= ',' if $cstring;
            $cstring .= $cinserts[$i];
	    $vstring .= ',' if $vstring;
            $vstring .= $vinserts[$i];
            if (!$uniqueTest || $cinserts[$i] eq $cname) {
                $wstring .= ') and (' if $wstring;
# float values are a special case for equality testing: use 'like'                  
                my $equality = ($vinserts[$i] =~ /^\d+\.\d+$/) ? ' like ' : '='; 
                $wstring .= $cinserts[$i].$equality.$vinserts[$i];
            }
        }

#my $list = 0;
#print "multiline = $multiLine <br>" if ($multiLine > 1);

        if (!$multiLine || $multiLine <= 1) {

            my $nextrow = $self->count(0) + 1; # number of the next row, force query on table
            my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
            my $status = $self->query($query,1,0);       
# on successful completion: store the WHERE string for further updates or rollback
            if ($status && $self->count(0) == $nextrow) {
                $self->{whereclause} = "($wstring)";
                my $undoclause = "DELETE FROM <self> WHERE $self->{whereclause}";
                push @{$self->{undoclause}}, $undoclause;
                $inputStatus = $nextrow;
            }
            else {
# the insert failed
                undef $self->{whereclause};
                $error = "unspecified error (query =  $query)";
                $inputStatus = 0;
            }
        }
        else {  
# multi-line mode
            if (!$self->{stack}->{$cstring}) {
                my @vstack;
                $self->{stack}->{$cstring} = \@vstack;
            }
            push @{$self->{stack}->{$cstring}}, $vstring;
            $inputStatus = @{$self->{stack}->{$cstring}};
            if ($inputStatus >= $multiLine) {
                my $nextrow = $self->count(0) + $multiLine;
                $vstring = join '),(',@{$self->{stack}->{$cstring}};
                my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
#print "NEWROW: nextrow=$nextrow\n" if $list;
                my $status = $self->query($query,1,0);      
                if ($status && $self->count(0) == $nextrow) {
                    $inputStatus = $nextrow;
                }
                else {
                    $error  = "nextrow counts don't match ($self->{'count'} vs $nextrow ";
                    $error .= "(multiline = $multiLine, query =  $query)";
                    $inputStatus = 0;
                }
                undef $self->{stack}->{$cstring};
            }
            else {
                $inputStatus += $self->{'count'};
            }
        }
    }

    if (!$inputStatus) {
        $self->{qerror}  = "Failed to insert new row into table ";
        $self->{qerror} .= "$self->{tablename}: '$error'";
    }

# return value: 0 for failure, > 0 for success with status = nr of row added

    return $inputStatus;
}

#############################################################################

sub lastInsertId {
# returns the last occurring value of an auto incremented column
    my $self = shift;

    return if !$self->{autoinc}; # undefined, cannot be determined

# test if there is any last insert in the current server session

    my $query = "select last_insert_id()";
    return if !$self->query($query,0,0); 

# I return the highest autoincremented value on THIS table, which is NOT
# necessarily the same as the last_insert_id(), which could be in another table

    my $item = $self->{autoinc};
    $query = "select $item from <self> order by $item desc limit 1";
    my $hashes = $self->query($query,0,0);
print "hashes $hashes \n";

    return $hashes->[0]->{$item};
}

#############################################################################

sub setMultiLineInsert {
# (re-)define insert block size
    my $self = shift;
    my $line = shift;

    $line = 1 if (!$line || $line < 1);

    $self->lflush() if $self->{multiLine}; # dump any pending inserts

    $self->{multiLine} = $line; # assign new line number
}

#############################################################################

sub lflush {
# flush stack data, either all or a named stack
    my $self   = shift;
    my $string = shift; # undef for all stacks

#print "FLUSH $self->{tablename}\n";
# process any pending new line inserts

    my $status = 0;
    my $stack = $self->{stack};
    foreach my $cstring (keys %$stack) {
#print "key=$cstring\n"; print "stack $stack->{$cstring} \n";
        if ((!$string || $cstring eq $string) && $stack->{$cstring}) {
            my $vstring = join '),(',@{$stack->{$cstring}};
            my $query = "INSERT INTO <self> ($cstring) VALUES ($vstring)";
#print "FLUSH query: $query \n";
            $status = &query($self,$query,1,0);      
            undef $self->{stack}->{$cstring} if $status;
        } 
    }

    return $status;
}

#############################################################################

sub insert {
# load a dataset presented as an array of hashes keyed on column names
    my $self     = shift;
    my $hashrefs = shift || return 0; # single hashref, or array of hashes

    my @hashrefs;
    $hashrefs[0] = $hashrefs;
    $hashrefs = \@hashrefs if (ref($hashrefs) ne 'ARRAY');

    my $status = 0;
    foreach my $hash (@$hashrefs){
        undef my @columns;
        undef my @cvalues;
        foreach my $column (keys %$hash) {
            push @columns,$column;
            push @cvalues,$hash->{$column};
        }
        $status++ if $self->newrow(\@columns,\@cvalues);
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

# build the WHERE clause: only allow wkey and wval simultaneously undefined

#    &qclean($self);

    my $doStamp = 1;
    my $whereclause;
    if (defined($wkey) && defined($wval) && defined($self->{coltype}->{$wkey})) {
# use input parameters; test $wval for ! or 'not'
        $wval = &quoteColValue($self,$wkey,$wval);
        $whereclause = "$wkey";
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
# use $wval in where clause; must be fully specified including quoting
        $whereclause = $wval;
    }
    elsif (!defined($wkey) && !defined($wval) && defined($self->{whereclause})) {
# use previously stored where clause: update after an insert
        $whereclause = $self->{whereclause};
        $doStamp = 0;
    } 
    else {
        my $error = "missing or invalid WHERE clause: cname=$cname value=$value wkey='$wkey' wval='$wval' ";
        $error .= "or earlier failure to insert newrow";
        $self->{qerror} = "! Failed to update table $self->{tablename}: $error"; print "$self->{qerror}<br>";
        return 0;
    }

# okay, now do the update
            
    my $status = 0; # default failure
#    $value = 'NULL' if (!defined($value) || $value !~ /\w/);
    if (defined($cname) && defined($value) && defined($self->{coltype}->{$cname})) {
        $value = &quoteColValue($self,$cname,$value);
# note: for a complete rollback one should query the current value of cname and add undoclause e.g. 
# (my $oldvalue) = $dbh->selectrow_array("SELECT $cname FROM <self> WHERE $whereclause");
# $undoclause = "UPDATE <self> SET $cname = $oldvalue WHERE $whereclause";
        my $query = "UPDATE <self> SET $cname = $value WHERE $whereclause";
        $query .= " limit $limit" if ($limit && $limit > 0); # if any
        $status = &query($self,$query,$doStamp);
        $self->{qerror} = "Failed to update table <self>" if !$status;
        buildhash(0,$self) if ($status && $self->{'build'}); # reload hash        
    }
    else {
        $self->{qerror} = "Failed to update table <self>: (probably) column $cname does not exist";
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
    my $change = shift || 1; # default +1, must be numerical

    my $status = 0; # preset failure
    undef $self->{qerror};

    if (defined($column) && defined($self->{coltype}->{$column})) {
# the target column exists
        if (defined($cnamed) && defined($self->{coltype}->{$cnamed}) && defined($cvalue)) {
# the named  column and value exist
            if ($self->{coltype}->{$column} =~ /int/i && $change !~ /\D/) {
# target column and the increment are of type numerical
                $cvalue = &quoteColValue($self,$cnamed,$cvalue);
                my $query = "UPDATE <self> SET $column = $column+$change ";
                $query .= "WHERE $cnamed = $cvalue";
                $status = &query($self,$query,0);
            }
        }
        else {
            $self->{qerror} = "invalid column $cnamed in <self>";
        }
    }
    else {
        $self->{qerror} = "invalid target column $column in <self>";
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

    my $status = 0;
    &qclean($self);
    my $error = '';

# insist on a non blank value

    if (defined($value) && $value =~ /\w/) {
        my $columntype = $self->{coltype}; 
        if (defined($cname) && defined($columntype->{$cname})) {
            $value = &quoteColValue($self,$cname,$value);
            my $query = "DELETE FROM <self> WHERE $cname = $value";
            $query .= " limit $limit" if ($limit && $limit > 0);
            $query =~ s/\=/in/ if $value =~ /\(/; # replace '=' by 'in'
            $status = &query($self,$query,1,0);
        }
        elsif ($cname =~ /where/i) {
            my $query = "DELETE FROM <self> WHERE $value";
            $query .= " limit $limit" if ($limit && $limit > 0);
            $status = &query($self,$query,1,0);           
        }
        else {
            $error = "invalid column $cname";
        }
    } 
    else {
        $error = "missing value for column $cname";
    }

    $self->{qerror} = "Failed to delete from table <self>: $error";

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
print "UNDO: $undocommand\n";
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

sub prepare {
# prepare a query and return sth handle
    my $self = shift;
    my $prep = shift;

    my ($dbh, $tablename) = whoAmI($self);

    $prep =~ s/\<self\>/$tablename/i; # if placeholder <SELF> given

    return $dbh->prepare($prep); 
}

#############################################################################

sub qclean {
    my $self = shift;

    undef $self->{qerror};
    undef $self->{lastQuery};
}

#############################################################################

sub query {
# general query processing
    my $self  = shift;
    my $query = shift;
    my $stamp = shift; # undefined or true for timestamp on (updates);
    my $trace = shift;
    my $bhash = shift || 0; # rebuild a hash table after an update

    $self->qclean;

    $trace = $self->{qTracer} if !defined($trace); # default
# override any trace specification if no links have been set up
    $trace = 0 if (!keys(%{$self->{sublinks}}));

    my ($dbh, $tablename) = whoAmI($self);

# substitute placeholder <self> or add full tablename to query string

    $query =~ s/\<self\>/$tablename/ig; # if placeholder <SELF> given
    if ($query =~ /^\s*(select|delete)/i) {
        $query =~ s/(where)/from $tablename $1/i  if ($query !~ /from/i);
        $query .= " from $tablename"              if ($query !~ /from/i);
    }

# handle NULL values

    $query =~ s/\!\=\s+null\s/is not NULL /ig; # replace any '!= null' 
    $query =~ s/\=\s+null\s/is NULL /ig;       # replace any  '= null' 

# apply the query tracer to test columns referenced (select only)

    $query = &traceQuery($self,$query) if ($query =~ /select/i && $trace);

# execute the query

    undef my @hashrefs;
    my $hashrefs = \@hashrefs;
    undef $self->{qerror};
    $self->{lastQuery} .= $query;
    my $sth = $dbh->prepare($query); 
    my $status = $sth->execute();
    $status = 0 if !defined($status);
# beware: $status:0 (false) indicates an error; 0E0 indicates no data returned
    if ($status > 0 && $query =~ /select|show/i) {
# there is at least one returned row
        $hashrefs = $sth->fetchall_arrayref({});
        $hashrefs = \@hashrefs if !$hashrefs;
# print "TEST $query status $status hashrefs $hashrefs VALUES: @$hashrefs <br>\n";
    }
    elsif (!$status) {
        $self->{qerror} = 1;
    } 
    elsif ($status < 0) {
        $status = 0; # just in case, false
        $self->{qerror} = 1;
    }

# modify timestamp if query changed the table (update, delete, insert, ..)

    if ($status > 0 && $query =~ /^\s*(insert|update|delete|replace)/i) {
        &timestamp(0,$self,lc($1)) if (!defined($stamp) || $stamp);
# rebuild the table in memory if a hash list exists
        buildhash(0,$self) if ($bhash && $self->{'build'});
    }

# output status is either  UNDEFINED or 0 (FALSE) for a failed query
#                      or  0E0 for an empty return table (zero but TRUE)
#                      or  the reference to an array of hashes (at least 1)

    if (@$hashrefs) { # add switch to force return of array ref
        return $hashrefs; # the query returns at least one line
    }
    else {
        return $status; # the query is empty but true (0E0) or failed (undef)
    }
}

#############################################################################

sub qstatus {
    my $self = shift;

    $self->{qerror} =~ s/\<self\>/$self->{tablename}/g if $self->{qerror};

    my $report = "Query on table $self->{tablename}:\n";
    $report .= "$self->{lastQuery}\nStatus = ";
    if (!$self->{qerror}) {
        $report .= "succeeded";
    }
    else {
        $report .= "FAILED";
        $report .= ': '.$self->{qerror} if ($self->{qerror} =~ /\D/);
    } 

    $report .= "\n";
    $report .= "errors: $self->{errors}\n"     if $self->{errors};
    $report .= "warnings: $self->{warnings}\n" if $self->{warnings};

    return $report;
}

#############################################################################

sub traceQuery {
# expand query to include full table names & trace query across linked columns
    my $self  = shift;
    my $query = shift;

# print "ENTER traceQuery with '$query' \n\n" if ($self->{tablename} =~ /CONTIGS/);

    my $tracedQuery = $query;

# consider queries of type SELECT what FROM table(s) WHERE 

my $list = $DEBUG;
#$list = 2 if ($self->{tablename} =~ /CONTIGS/);
    if ($query =~ /^\s*select(\s+distinct)?\s+(.*)\sfrom\s(.*)\swhere\s(.*)$/i) {
print "query \"$query\" to be traced <br>\n" if ($list);
        my $distnct = $1 || '';
        my $targets = $2;
        my @targets = split ',',$targets;
        my $tables  = $3;
        my @tables  = split ',',$tables;
        my $clauses = $4;
# determine 'order by' or 'limit' clause
        my $order = '';
        $order = $1 if($clauses =~ s/\s*\b((limit|order)\b.*)//i);

# tricky here: if input query contains an OR in the where clause, a 
# UNION construct should be used (assume AND always before OR)
# the UNION operator requires MySQL version 4.0 or higher

        if ($clauses =~ /\bor\b/i) {

            $DBVERSION = $DBVERSION->[0]->{'version()'} if (ref($DBVERSION) eq 'ARRAY');
# split where clause on 'or' and generate query for each individually
# (at the moment no processing of targets and tables, careful with complex queries)
            my @clauses = split /\sor\s/i,$clauses;
            $tracedQuery = '';
            foreach my $clause (@clauses) {
                $tracedQuery .= " UNION " if $tracedQuery;
                my $query = "select $distnct $targets from $tables where $clause";
                $tracedQuery .= $self->traceQuery($query);               
            }
print "tracedquery: $tracedQuery <br>";
            $tracedQuery =~ s/UNION.*?where/OR/g if ($DBVERSION =~ /^3\./); # stop gap
            $tracedQuery .= ' '.$order if $order;
print "tracedquery: $tracedQuery <br>";
        }

        else {
# the where clause may still contain an OR:  however, split on 'AND'
        my @clauses = split /\sand\s/i,$clauses;
#        my @clauses = split /\sand\s|\sor\s/i,$clauses;
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
                    $self->{qerror} .= "column $colname does not exist or could not be traced<br>\n";
                    print STDOUT "$self->{qerror}\n" if $list;
                    return $query;
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
#$list=0;
print "OLD query: <h3>$query</h3><br>\n" if ($list);
            $clauses = quotemeta($clauses);
            $tracedQuery =~ s/$clauses/$newclause/ if $newclause; # contains possibly order or limit
            $tracedQuery =~ s/$tables/$newtables/  if $newtables;
print "NEW query: <h3> $tracedQuery</h3><br><br>\n" if ($list);
$list=0;

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
    }

    $self->{lastQuery} = "* original * : $query\n\n* traced *   : $tracedQuery\n";

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
my $list = $DEBUG;
#$list = 2 if ($self->{tablename} =~ /PROJECTS|SCAFFOLD/);
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
        if (isSameType($coltype,$tvalue,0,1)) {
            $status = 1; # signal column found (but value may not be present)
            $cvalue = quoteColValue($self,$colname,$tvalue); # also quotes an array of values
print "before count colname=$colname cvalue $cvalue  || where: '$colname $relate $cvalue'<br>" if $list;
            $count = associate($self,'count','where',"$colname $relate $cvalue",-1);
            $and->{$fulltname} = $self->{querywhereclause}; # register the sub query
#          $and->{$fulltname} =~ s/$limit// if $limit;
            return 0,$and if (!$count && $self->{qerror}); # error status aborts trace
print "after column test: count=$count status=$status<br>\n" if $list;
        }
# if no match was found OR no count in the target column, try alternate column names
        if (!$count) {
            my $alternates = $self->{alternate};
print "No column or match found: status=$status.  Try alternates @$alternates<br>\n" if ($list);
            foreach my $column (@$alternates) {
#            foreach my $column (@alternates) {
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

#$list = 0;
#$list = 2 if ($self->{tablename} =~ /PROJECTS|SCAFFOLD/);
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
                my $ltableref  = $self->getInstanceOf($linktable);
                if ($ltableref) {
print "$self->{tablename} column $column has link to  $linktable $linkcolumn<br>\n" if ($list);
print "linktableref=$ltableref<br>\n" if $list;
                   ($output, $and) = $ltableref->traceColumn($colname,$cvalue,$relate,$and);
                }
                else {
                    $self->{warnings} .= "! no DbaseTable instance for table $linktable";
                    print "DbaseTable $linktable connect FAILURE: $self->{warnings}<br>\n";
#  print "last query $self->{lastQuery} <br>\n";
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
    my $input = shift; # set to 1 if testing for input (no wild cards allowed)
    my $nolgt = shift; # set to 1 for NO length testing of character values 

    return 0 if (!defined($ctype) || !defined($value));

    my $same = 1;

# if value is presented as an array of possibilities, use recursion to check all items

    if (ref($value) eq 'ARRAY') {
        foreach my $trial (@$value) {
            $same = 0 if (!isSameType($ctype,$trial,$input,$nolgt));
	}
    }
    else {
# determine the type of the input value
        my $vtype = 0; # default string type;

        if ($value =~ /^\s*[+-]?\d+\s*$/) {
            $vtype = 1 ;  # numerical integer
        }
        elsif ($value =~ /^\s*[+-]?\d+\.\d*\b(\S*)$/ || $value =~ /^\s*[+-]?\.\d+\b(\S*)$/) {
            my $exponent = $1;
            $vtype = 2 unless ($exponent && $exponent !~ /E[+-]?\d+/i); # floating specification
        }

# numerical specifications must be matched; everything else is considered string

        $same = 0 if ($ctype =~ /int/i   && $vtype != 1);
        $same = 0 if ($ctype =~ /float/i && $vtype == 0); # allow both integer and float

# do a detailed analysis of some character strings (also for numerical types!)

        if (!$nolgt && $same && $ctype =~ /char/) {
            $value =~ s/\%|\?//g if !$input; # remove wildcards
            $same = 0 if ($ctype =~ /char\((\d+)\)/i && length($value) > $1); # too long
        }

# note: the combination of an enumerate type value with wildcards and NOT for input, is NOT tested
#       In MySQL this is a legal query contruct, but perhaps not a good idea to use 

        if (!$nolgt && $same && $ctype =~ /enum/ && ($input || $value !~ /\%|\?/)) {
# note: this version uses pattern matches; alternative would be to split and test each item
            $ctype =~ s/enum\(\'|\'\,\'|\'\)/  /ig; # separate enumerate items by only blanks 
            $value =~ s/(\\|\||\(|\)|\[|\]|\{|\}|\^|\$|\*|\+|\?|\.)/\\$1/g; # backslash metacharacters
            $same = 0 if ($ctype !~ /\s$value\s/); # no match 
        }
    }
    return $same;
}   

#############################################################################

sub setTracer {
# (re)define default query tracing
    my $self  = shift;
    my $trace = shift || 0;

    $self->{qTracer} = $trace;
# print "redefined qTracer $trace  for $self->{tablename}\n";
}


#############################################################################

sub setAlternates {
# (re)define default alternative column names
    my $self = shift;

# has to be developed ....

    my @alternates = @_ if @_;

    $self->{alternate} = \@alternates;

#print "setAlternates for $self->{tablename}: @alternates \n<br>"; 
}

#############################################################################

sub unlink {
# remove sublinks from this or all DbaseTables
    my $self = shift;

    if (shift) {
# unlink all tables
        foreach my $table (keys %instances){
            my $tableref = $instances{$table};
            $tableref->unlink();
#            undef $tableref->{sublinks};
        }
    }
    else {
#print "unlinked: $self->{tablename}<br>";
        undef $self->{sublinks};
        $self->setTracer(0);
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

sub flush {
# flush the current table, or all tables on this node
    my $self = shift;
    my $mode = shift; # set true for all

    if ($mode) {
# get current node
        my $fullTableName = $self->makeFullTableName('<self>');
        my @thisNameSections = split '\.',$fullTableName;

        my $instances = $self->getInstanceOf(0);
#        return 0 if (!$instances);

        foreach my $instance (sort keys %$instances) {
            my ($node,$dbase,$tname) = split '\.',$instance;
            next if ($node ne $thisNameSections[0]);
            $instances->{$instance}->flush();
        }
    }
    else {
# flush all pending new lines and counter updates on this table
# print "flushing $self->{tablename} <br>";
        $self->lflush();
        $self->cflush();
    }
}

#############################################################################

sub setDebug {

    my $self  = shift;
    my $debug = shift || 0;

    $DEBUG = $debug;
}

#############################################################################

sub dbVersion {

# return current database version

    $DBVERSION = $DBVERSION->[0]->{'version()'} if (ref($DBVERSION) eq 'ARRAY');

    return $DBVERSION;
}

#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "30 Nov 2000",
        updated =>    "25 Feb 2003",
    };
}

#############################################################################

1;
