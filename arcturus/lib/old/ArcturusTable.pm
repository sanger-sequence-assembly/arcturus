package ArcturusTable;

# inherits from DbaseTable and adds methods specific
# for the ARCTURUS assembly-tracking database

use strict;

use DbaseTable;
use Compress;

use vars qw($VERSION @ISA);
#our ($VERSION, @ISA);

@ISA = qw(DbaseTable);

$VERSION = 0.9;

#############################################################################
# data common to all objects of the ArcturusTable class
#############################################################################

my $SEED;
my $EXPAND = '/nfs/repository/'; # expansion for '~' in file names
my $SPLIT  = '\:|\,'; # the default split string

my $BLOCK  = 0; # block set to suppress looping on INVENTORY

#############################################################################

sub new {
# constructor invoking the constructor of the DbaseTable class
    my $caller    = shift;

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = $class->SUPER::new(@_);

# check on the build (test columns); if not done, look in INVENTORY for guidance

    if (!defined($self->{columns}) || !@{$self->{columns}}) {
# try to open the INVENTORY table
        if (my $inventory = testArcturusInventory ($self,1)) {
            my $build = 0;
            $build = 1 if ($inventory->associate('onRead',$self->{tablename}));
            $self->build($build); #  bad table flagged with $self->{errors}
        }
    }

# blessing has been done in SUPER, just return the reference

    return $self;
}

#############################################################################

sub default {
# change the default database
    my $self     = shift;
    my $database = shift;

    $database = 'arcturus' if !$database;

    return $self->do("use $database");
}

#############################################################################

sub testArcturusInventory {
    my $self = shift;
    my $init = shift;

# test if an instance if the INVENTORY table exists; if not, build it

    my $inventory = $self->findInstanceOf('arcturus.INVENTORY');

    if (!$BLOCK && !$inventory && $init--) {
        $BLOCK = 1; # prevent looping
        my $dbh = $self->{dbhandle};
        $inventory = $self->new($dbh,'INVENTORY','arcturus',1);
        die "Could not get at INVENTORY table" if (!$inventory);
    }
    elsif ($inventory && !$inventory->{hashrefs}) {
        $inventory->build(1);
    }
    return $inventory;
}

#############################################################################

sub autoVivify {
# auto generate the connecting tables using INVENTORY and DATAMODEL
    my $self     = shift;
    my $database = shift; # for special case of a Common table at top
    my $depth    = shift;
    my $reset    = shift;

    $self->unlink(1) if $reset; # reset any existing linking information

    return 0  if keys(%{$self->{sublinks}}); # the links have already been set up

# test the level; stop if explicitly defined and <= 0
# print "<br>begin autoVivify: $self->{tablename} depth=$depth<br>";

    return 0  if (defined($depth) && $depth-- <= 0);

# specify to build links to existin table instances only with a non-integer $depth 

my $LIST = 0;
    my $existOnly = $depth || 0;
    $existOnly -= int($existOnly); # will be 0 for integer $depth
print "Non integer depth detected: $depth<br>" if ($existOnly && $LIST);
print "Integer depth detected: $depth<br>"    if (!$existOnly && $LIST);

    my ($dbh,$fullname) = $self->whoAmI(1); # insist on database spec

# test if an instance of the INVENTORY table exists; if not, build it

    my $inventory = testArcturusInventory ($self, 1);

# now get the list of other tables linking to this table

    my @tablenames;
    if ($fullname eq 'arcturus.INVENTORY') {
# I am the inventory table myself, build all tables listed in inventory
        my $hashrefs = $inventory->{hashrefs};
        foreach my $hash (@$hashrefs) {
            push @tablenames,$hash->{tablename};
        }
        $depth = 0;
    }
    else {
# test existence of datamodel
        if (!$self->findInstanceOf('arcturus.DATAMODEL')) {
            $self->new($dbh,'DATAMODEL','arcturus',0);
        }
# I am some other table; collect the referenced (dictionary) tables
# at the same time, enter the linking information in $self->{sublinks}
# (use column in this table as key for a hash array)
        my ($dbasename, $thistable) = split '\.',$fullname;
        $database = $dbasename if ($dbasename ne 'arcturus');
        if (my $datamodel = $self->findInstanceOf('arcturus.DATAMODEL')) {
    # DATAMODEL table is found among class %instances
            my $hashrefs = $datamodel->SUPER::associate('hashrefs',$thistable,'tablename');
            foreach my $hash (@$hashrefs) {
                my $thiscolumn = $hash->{tcolumn};
                my $linktable = $hash->{linktable};
            # test possible existence of the linktable
                my $doesExist = $self->findInstanceOf('arcturus.'.$linktable);
                $doesExist  = $self->findInstanceOf($database.'.'.$linktable) if !$doesExist;
print "table $linktable: exist status=$doesExist<br>" if $LIST;
            # add the table to the list of tables to be vivified
                if (!$existOnly || $doesExist) {
print "add to link list: $hash->{linktable} $thiscolumn<br>" if $LIST; 
                    push @tablenames,$hash->{linktable}.'&'.$thiscolumn;
            # test if this column already exists, if so add _ to allow multiple column references
                    while ( $self->{sublinks}->{$thiscolumn}->[0] ) {
                        $thiscolumn .= '_';
                    }
                # add link information to the sublinks hash 
print "add link reference to sublink hash under key: $thiscolumn<br>" if $LIST; 
                    $self->{sublinks}->{$thiscolumn}->[0] = $hash->{linktable};
                    $self->{sublinks}->{$thiscolumn}->[1] = $hash->{lcolumn};
print "sublinks $thiscolumn @{$self->{sublinks}->{$thiscolumn}} <br>\n" if $LIST;
                }
            }
        }
        else {
            die "Could not get at the DATAMODEL table\n";
        }    
    }

# okay, here we have a list of tables to be instanciated
# go through the list and build those table which do not yet exist

#$LIST=1;
    foreach my $tableentry (@tablenames) {
        my ($linktable,$thiscolumn) = split /\&/,$tableentry;
        $thiscolumn = 'none' if !$thiscolumn; # protection
print "linktable for $fullname: $linktable  column=$thiscolumn<br>" if $LIST;
        my $domain = $inventory->SUPER::associate('domain',$linktable);
print "  tabledomain=$domain<br>" if $LIST;
        if (defined($domain)) {
            undef my $dbasename;
            $dbasename = 'arcturus' if ($domain eq 'c');
            $dbasename = $database  if ($domain eq 'o');
            die "Undefined or invalid domain identifier\n" if (!$dbasename);
print "inventory link database $dbasename $linktable $domain<br>" if $LIST;
            my $newtable = $self->findInstanceOf($dbasename.'.'.$linktable);
            if (!$newtable) {
print "AUTOVIVIFY table $linktable<br>" if $LIST;
                $newtable = $self->new($dbh,$linktable,$dbasename);
                if ($newtable->{errors}) {
#$LIST=1 if ($linktable eq 'CLONEMAP');;
print "FAILED to create $linktable: ERROR status = $newtable->{errors}<br>" if $LIST; 
                    $self->{warnings} .= "! autoVivify FAILED: $newtable->{errors}\n";
                    delete $self->{sublinks}->{$thiscolumn}; # remove the links
                }
                else {
                    $newtable->autoVivify($dbasename,$depth);
                }
            }
        # in case the table exists, but the links not
            elsif (!keys(%{$newtable->{sublinks}}) && ref($newtable) =~ /Arcturus/) {
                $newtable->autoVivify($dbasename,$depth);
            }
        # the target table does already exist and has itself links defined
        # if all links have been reset at top entry, this node was visited
        # therefore, remove the sublink to the target table 
            else {
print "table $linktable appears to have been visited before<br>" if $LIST;
#                delete $self->{sublinks}->{$thiscolumn}; # ? really necessary?
            }
        # add the database name to the linking information
            my $sublinks = $self->{sublinks};
            foreach my $thiscolumn (keys %$sublinks) {
print "SUBLINKS installed for $thiscolumn<br>" if $LIST;
                if ($sublinks->{$thiscolumn}->[0] eq $linktable) {
                    $sublinks->{$thiscolumn}->[0] = $dbasename.'.'.$linktable;
                }
            }
	}
        else {
            print "Undefined domain or unknown link table $linktable<br>";
        }
    }
    return 1; # signal full pass through procedure
}

#############################################################################

sub counted {
# returns number of rows in table, or sum of counts if it's a counter table
    my $self = shift;
 
    my $count = $self->count(0); # returns the number of table entries

# if the table has data, check if there is a "counted" column; if so, tally 

    if ($count > 0 && $self->{coltype}->{counted}) {
 
        $count = 0;
        if ($self->{hashrefs}) {
            foreach my $hash (@{$self->{hashrefs}}) {
                $count += $hash->{counted};
            }
        }
        else {
            my $query = "SELECT SUM(counted) AS total FROM <SELF>";
            my $hash  = $self->SUPER::query($query);
            $count = $hash->[0]->{total};
#print "count= $count<br>";
        }
    }

    return $count;
}

#############################################################################

sub expandSequence {
# if there are columns "sequence" and "scompress" : expand
    my $self = shift;
    my $seed = shift; # if undefined, default 'ACGT- ' is used

# check first hashrefs and if not found check hashref 

    undef my @hashref;
    undef my $hashrefs;
    $hashrefs = $self->{hashrefs} if ($self->{hashrefs});
    if (!defined($hashrefs) && $self->{hashref}) {
        $hashref[0] = $self->{hashref};
        $hashrefs = \@hashref;
    }

# hashrefs, if defined, points to an array of hash references

# get the seed, either from parameter list or from global variable

    $seed = $SEED if (!$seed);

    if (defined($hashrefs) && @$hashrefs > 0) {

        my $columns = $self->{coltype};
    # determine type of compression, if any
        undef my $compress;
        $compress = "scompress" if (defined($columns->{scompress}));
    # here possible alternatives
        if (defined($compress) && defined($columns->{sequence})) {
        # setup de-compression algorithm
            my $encoder =  Compress->new($seed);
            foreach my $hash (@$hashrefs) {
                my $sequence = $hash->{sequence};
                if (defined($hash->{$compress}) && $hash->{$compress} == 1 && $sequence) {
                   (my $length,$sequence) = $encoder->sequenceDecoder($sequence);
		   $hash->{sequence} = $sequence;
                   $hash->{$compress} = 0;
                }
            }    
        }
    }
}

#############################################################################

sub compressSeed {

# redefine the default seed value

    $SEED = $_[1];

}

#############################################################################
# time stamping on tables and databases
#############################################################################

sub historyUpdate {
# update the history table by going through all open ArcturusTable s
    my $self = shift;
    my $user = shift;
    my $text = shift;
    my $list = shift;


    my $brtag = "\n";
    $brtag = "<br>" if ($list && $list > 1);

    my $instances = $self->findInstanceOf(0);
# print "historyUpdate: instances=$instances\n";
    return 0 if (!$instances);

    print "${brtag}Time stamping modified tables${brtag}" if $list;

    my $logEvents = 0;
    undef my $organisms;
    undef my %databases;
    foreach my $instance (keys %$instances) {
        my ($dbase, $tname) = split '\.',$instance;
        my $tablereference = $instances->{$instance};
# print "instance $instance ref: $tablereference$brtag\n";
        if ($tablereference =~ /ArcturusTable/) {
            $organisms = $tablereference if ($instance =~ /ORGANISMS/);
            if ($tablereference->historyLogger($user, $text, $list)) {
                $databases{$dbase}++;
                $logEvents++;
            }
        }
    }

    delete $databases{arcturus};
    foreach my $database (keys %databases) {
        if ($organisms) {
            print "${brtag}SIGNATURE on ORGANISMS for database $database${brtag}" if $list;
            $organisms->signature($user,'dbasename',$database);
        }
        elsif ($list) {
            print "${brtag}WARNING: table ORGANISMS not opened as ArcturusTable${brtag}";
        }
    }

    return $logEvents;
}

#############################################################################

sub historyLogger {
# update my record of the history table in ARCTURUS database
    my $self = shift;
    my $user = shift;
    my $text = shift;
    my $list = shift;

    my $brtag = "\n";
    $brtag = "<br>" if ($list && $list > 1);

    my ($dbh, $tablename) = $self->whoAmI(1);

    my $logged = 0;
    if ($tablename !~ /history|arcturus/i) {
        my $database = $self->{database};
        my $historyTableName = $database.'.HISTORY'.uc($database);
    # test if the history table reference exist; if not, open 
        my $history;
        if (!($history = $self->findInstanceOf($historyTableName))) {
            $history = $self->new($dbh,'HISTORY'.uc($database),$database,0);
            undef $history if $history->status();
        }
        if ($history) {
    # reset time stamp on history table (if any)
            undef $history->{timestamp};
            $text = 'unknown' if (!$text);
    # test time stamp on this table
            if (my $timestamp = $self->{timestamp}) {
                my ($time, $action) = split /\&/,$timestamp;
                $action = $text if (!$action);
                $tablename = $self->{tablename};
                if (!$history->associate('tablename',$tablename,'tablename')) {
                    print "Table $tablename is not listed in $historyTableName${brtag}\n";
                    print "$tablename will be added with undefined creation date${brtag}\n";
                    $history->newrow('tablename',$tablename);
                }
                elsif ($list) {
                    print "Time Stamp found on table $tablename${brtag}";
                }
                $history->update('lastouch',$time  ,'tablename',$tablename);
                $history->update('lastuser',$user  ,'tablename',$tablename);
                $history->update('action'  ,$action,'tablename',$tablename);
            }
	    $logged = 1 if $history->{timestamp};  # successful update
        }
        else {
            print "${brtag}WARNING: Unable to access table $historyTableName${brtag}";
        }
    }
    return $logged;
}

##############################################################################

sub signature {
# add a signature "userid & updated" to a table if those columns exist
    my $self   = shift;
    my $user   = shift;
    my $tcname = shift; # column name  to identify the row to update
    my $tvalue = shift; # column value to identify the row to update
    my $userid = shift; # alternative name for identifier column
    my $update = shift; # alternative name for datetime column 

    $userid = 'userid'  if !$userid; # default column name for userid
    $update = 'updated' if !$update; # default column name for datetime

#print "signature on $self->{tablename}: $user, $tcname, $tvalue, $userid, $update\n";
    if ($tcname && $tvalue && defined($self->{coltype}->{$tcname})) {
# update the 'userid' if the column exists
        if (defined($user) && $user && defined($self->{coltype}->{$userid})) {
            $self->update($userid,$user,$tcname,$tvalue);
#print "user: $userid update\n";
        }
# update the 'updated' if the column exists
        if (defined($self->{coltype}->{$update})){
            my $datetime = $self->timestamp();
            $self->update($update,$datetime,$tcname,$tvalue);
#print "update: $update\n";
        }
    }
}

############################################################################
# These methods pack a hash into a single character string and store in
# a BLOB field of the database table; default field name is 'attributes'
#############################################################################

sub unpackAttributes {
    my $self   = shift;
    my $tvalue = shift; # value for associate search
    my $target = shift; # column name for ibid
    my $field  = shift; # name of target field; default 'attributes' 

    undef my %attributes;
    undef my $attributes;

    $field = 'attributes' if (!$field);
# ensure that the field exists and is of type BLOB; if not, ignore
    if (defined($self->{coltype}->{$field}) && $self->{coltype}->{$field} =~ /blob/i) {
# get the field value
        if ($attributes = $self->SUPER::associate($field,$tvalue,$target)) {
    # supposedly the field value is a hash image; values my contain a '~' (files)
            $attributes =~ s?\~?$EXPAND?g; # replace possible '~' by full file name
            %attributes = split /$SPLIT/ , $attributes  if ($attributes);
        }
    }
    return $attributes,\%attributes;
}

#############################################################################

sub packAttribute {
# add a key-value pair to the hash image packed into a blob field 
    my $self   = shift;
    my $tvalue = shift; # target value for associate search
    my $target = shift; # column name for ibid
    my $field  = shift; # name of target field; default attributes
    my $newkey = shift; # the key to be added/replaced/deleted
    my $kvalue = shift; # the key value; delete the key if absent

    my $result = 0;

    $field = 'attributes' if (!$field);
# ensure that the field exists and is of type BLOB; if not, ignore
    if (defined($self->{coltype}->{$field}) && $self->{coltype}->{$field} =~ /blob/i) {
# get the current data
        my ($existing, $hash) = unpackAttributes($self,$tvalue,$target,$field);
# replace/add or delete the keyed value to the hash
        if (defined($kvalue)) {
            $hash->{$newkey} = $kvalue;
        }
        else {
            delete $hash->{$kvalue};
        }
# pack the hash into a string using the first two separators in $SPLIT
        undef my $attributes;
        my $split = $SPLIT; 
        $split =~ s/\\//g; # remove possible backslashes
        my @separators = split /\|/, $split;
        $separators[0] = ':' if (!@separators);
        $separators[1] = $separators[0] if (@separators == 1);
        foreach my $key (sort keys %$hash) {
            $attributes .= $key."$separators[0]";
            $attributes .= $hash->{$key}."$separators[1]"; 
        }
        chop $attributes; # remove trailing separator symbol
# add to database table
        if (!$existing || ($attributes && ($attributes ne $existing))) {
            $self->update($field,$attributes,$target,$tvalue);
            $result++;
        }         
    }
    return $result; # update made or not
}


#############################################################################

sub packParameters {
# enter new split/join symbols for pack methods, or a new ~ substitution
    my $self   = shift;
    my $split  = shift;
    my $expand = shift;

    $SPLIT  = $split  if $split;  # any number of split symbols
    $EXPAND = $expand if $expand;
}

#############################################################################
# authorization
#############################################################################

sub authorize {
# authorisation method; works only on ARCTURUS table USERS
    my $self   = shift;
    my $userid = shift; 
    my $passwd = shift; # plain text password
    my $access = shift; # priviledge sought

# this is a function exclusively for the USERS table: the encrypted password
# 'passwd' of user 'userid' is tested; access contains a code mask

    my $status = 0;

    my ($dbh,$fullname) = $self->whoAmI(1); # insist on database 

    if ($fullname eq 'arcturus.USERS') {
# test column userid and password; find the data for user 'userid'
        if (defined($self->{coltype}->{userid}) && defined($self->{coltype}->{password})) {
# test input data
            if ($userid && $passwd) {
        # get data for user userid
                if (my $hash = $self->SUPER::associate('hashref',$userid,'userid')) {
                    my $encrypt = $hash->{password};
                    my $inverse = crypt($passwd,$encrypt);
# print "Verify: password=$passwd  encrypt=$encrypt  inverse=$inverse<br>";
                    if (!$inverse || $inverse ne $encrypt) {
                        $status = "Invalid password provided for user $userid";
                    }

                    elsif ($access && (my $priviledges = $hash->{priviledges})) {
                # test $access against $priviledges
                        $status = "User $userid has insufficient priviledge" if ($access > $priviledges);

                    } 
                    elsif ($access) {
                        $status = "User $userid has no priviledges set";
                    }

                }
                else {
                    $status = "Unknown user: $userid";
                }
	    }
	    else {
		$status = "Missing userid or password";
            }
        }
        else {
            $status = "ARCTURUS table $fullname is incorrectly initialised"; 
        }     
    }
    else {
        $status = "Invalid use of method 'authorize' on table $fullname";
    }

#    $status = "override successfull authorization" if (!$status);
    return $status; # 0 if all tests passed
}

#############################################################################
# Diagnostic tool(s)
#############################################################################

sub snapshot {
# generate a snapshot of currently open tables
    my $self     = shift;
    my $database = shift;

    my $instances = $self->findInstanceOf(0);
    return if (!$instances); # may not occur!

    my $table = '<TABLE BORDER=1 CELLPADDING=2>';
    $table .= '<TR><TH>Table</TH><TH>Database</TH><TH>Size</TH><TH>status</TH></TR>';
    foreach my $tablename (sort keys %$instances) {
        my $instance = $instances->{$tablename};
        my ($dbase, $tname) = split '\.',$tablename;
        my $count = $instance->count(-1);
        my $error = $instance->{errors} || "&nbsp";
        if (!$database || $dbase eq $database) {
            $table .= "<TR><TD>$tname</TD><TD>$dbase</TD>";
            $table .= "<TD>$count</TD><TD>$error</TD></TR>";
        }
    }
    $table .= "</TABLE>";

    return $table;
}

#############################################################################
# Some HTML formatted output
#############################################################################

sub htmlTable {
# list the table on STDOUT
    my $self   = shift;
    my $mask   = shift; # optional masking of table columns
    my $Column = shift; # optional (list only if column $Column has value $Cvalue 
    my $Cvalue = shift; # optional 

    undef my $list;

    my $tablename  = $self->{tablename};
    my $columntype = $self->{coltype};
    my $sublinks   = $self->{sublinks};

# set-up mask

    my $more = 0;
    undef my %mask;
    if (defined($mask)) {
        $more = 1 if ($mask =~ /2/);
        my @mask = split //,$mask;
        foreach my $column (@{$self->{columns}}) {
            $mask{$column} = 0 if (!@mask);
            $mask{$column} = shift(@mask) if (@mask);
        }
    }

    $list .= "<TABLE BORDER=1 CELLPADDING=2>";

# if a link to "more" for details is to be set up get primary key column & value

    my $keyColumn = $self->{prime_key};
    if (!$keyColumn) {
        foreach my $column (@{$self->{columns}}) {
            $keyColumn = $column if ($column =~ /id|name/);
            last if ($keyColumn);
        }
    }    

# get header

    my $header;
    my $nrcolumns = $more;
    foreach my $column (@{$self->{columns}}) {
        if (!defined($mask) || $mask{$column}) {
            my $field = $column;
            $field =~ s/\_/ /g; # allows for wrapped column headers
            if (defined($sublinks->{$column}) && $mask{$column} > 1) {
                my $linktable = $sublinks->{$column};
                my $linktablename = $linktable->[0];
            # put the name of the linked table in as anchor; replace outside with link
                $field = "<A href=\"TABLELINK$linktablename\" TABLETARGET>$field</A>";
            }
            $nrcolumns++;
            $header .= "<TH bgcolor='yellow'>$field</TH>";
        }
    }
    $header .= "<TH bgcolor='white'>&nbsp</TH>" if ($more);
    $list .= "<THEAD><TR><TH COLSPAN=$nrcolumns>Table $tablename</TH></TR></THEAD>";
    $list .= "<TR>$header</TR><TR><TD COLSPAN=$nrcolumns>&nbsp</TD></TR>";

# analyse column qualifiers

    my $columntest = 0;
    if (defined($Column)) {
        $Cvalue = '' if (!defined($Cvalue));
        if ($self->{coltype}->{$Column}) {
            $columntest = 1;
        }
    # the specified column does not exist! print a warning for diagnostic purposes
        else {
            $list .= "<TR><TD COLSPAN=$nrcolumns bgcolor='ORANGE' ALIGN=CENTER>";
            $list .= "WARNING: test column $Column does not exist</TD></TR>";
        }
    }

# print body (if it exists)

    my $lines = 0;
    if ($self->{hashrefs} && ref($self->{hashrefs}) eq "ARRAY") {
# print "print the table $self->{tablename}<br>";
        foreach my $hash (@{$self->{hashrefs}}) {
            my $include = 1;
            $include = 0 if ($columntest && defined($hash->{$Column}) && $hash->{$Column} ne $Cvalue);
	    if ($include) {
                $lines++;
                $list .= "<TR>";
                foreach my $column (@{$self->{columns}}) {
                    if (!defined($mask) || $mask{$column}) {
                        my $field = '&nbsp';
                        $field = $hash->{$column} if (defined($hash->{$column}) && $hash->{$column} =~ /\S/);
                        $field = 'non-ASCII characters' if (!&isASCII($field));
                        my $align = "left";
                        $align = "right" if ($columntype->{$column} =~ /int/i);
                        $field =~ s/([^\n\s]{40,}?)/$1<br>/g;
                        if (defined($mask) && $mask{$column} > 2) {
                            my $link = "href = \"ITEMLINK\?column=$keyColumn\&";
                            $link .= "value=$hash->{$keyColumn}\" ITEMTARGET";
                            $field = "<A $link>$field</A>";
                        }
                        $list .= "<TD ALIGN=$align BGCOLOR='lightblue' NOWRAP> $field </TD>";
                    }
                }
     # add a link field for details
                if ($more) {
                    my $link = "href = \"ITEMLINK\?column=$keyColumn\&";
                    $link .= "value=$hash->{$keyColumn}\" ITEMTARGET";
                    $list .= "<TD BGCOLOR='lightblue'><A $link>LINKTEXT</A></TD>";
                }
                $list .= "</TR>";
	    }
        }
    }
# add a message for an empty list
    if (!$lines) {
        $list .= "<TR><TD COLSPAN=$nrcolumns ALIGN=CENTER BGCOLOR='orange'>";
        $list .= "Sorry! No selection available</TD></TR>";
    }

    $list .= "</TABLE>";

    return $list;
}

#############################################################################

sub htmlMaskedTable {
# construct an HTML formatted masked table list with additional constraints
    my $self   = shift;
    my $mask   = shift; # the item for which select options list is made
    my $column = shift; # the column name to be tested for (or 'where')
    my $clause = shift; # this particular value or where clause

    undef my $list;
    if ($column ne 'where' && $column ne 'distinct where') {
# assume it's a column name and try htmlTable
        $list = htmlTable($self,$mask,$column,$clause);
    }
    else { # build a new temporary hash
        my $currentHash = $self->{hashrefs}; # memorize current hash
        my $query = "select * from <self> where ($clause)";
        $query =~ s/select/select distinct/ if ($column =~ /distinct/);
# print "masked table query: $query<br>";
        $self->{hashrefs} = $self->query($query,0); # use query trace if needed
        $list = htmlTable($self,$mask);      
        $self->{hashrefs} = $currentHash; # restore old hash
    }

    return $list;
}

#############################################################################

sub htmlOptions {
# construct an HTML SELECT OPTIONS list on item $item and return value $key
    my $self = shift;
    my $item = shift; # the item for which select options list is made
    my $key  = shift; # the name put in the SELECT tag 
    my $lgt  = shift; # optional length of widget and
    my $hgt  = shift; # optional width
    my $any  = shift; # set to '0' if --- field NOT requested

    undef my $list;

    my $tablename = $self->{tablename};
    my $nrcolumns = $#{$self->{columns}}+1;

# test if the item exists

    undef my $existItem;
    my $nrColumns = 0;
    foreach my $column (@{$self->{columns}}) {
        $existItem = 1 if ($item && $column eq $item);
        $nrColumns++;
    }
    if (!$existItem && $item) {
        $self->{errors} = "! Unknown column name $item in $tablename";
        return 0;
    } elsif (!$item && $nrColumns > 1) {
        $self->{errors} = "! Column name required for $tablename->htmlOptionTable";
        return 0;
    } elsif (!$item) {
        $item = $self->{columns}->[0];
    }

    $key = $item if (!$key);

# compose HTML select construct

    my $width = ''; # default no width specification
    $width = "width=$lgt" if ($lgt && $lgt > 0);
    my $height = ''; # default no height specification
    $height = "height=$hgt" if ($hgt && $hgt > 0);
    $list .= "<SELECT $width $height name = \"$key\">";
# $any undefined will add a '---' item with value 0 selected on top
# $any = 0 will not add or preselect any field
# $any = some value adds and selects that value in the choice list
    my $val = "0"; $val = $any if ($any);
    $any = "---" if (!defined($any));
    $list .= "<OPTION value = \"$val\" SELECTED> $any " if ($any);

# rebuild table to get ordered list

#    buildhash (0,$self,$item);

# print body (if it exists)

    my $count = 0;
    if ($self->{coltype}->{$item} =~ /enum\((.+)\)/i) {
# use the values in enumeration specification
        my $options = $1;
        $options =~ s/\'//g;
        my @options = split /,/,$options;
        foreach my $option (@options) {
            $list .= "<OPTION value = \'$option\'>$option" unless
	             ($any && ($val eq $any) && ($option eq $val));
            $count++;
        }
    }
    elsif ($self->{hashrefs} && ref($self->{hashrefs}) eq "ARRAY") {
# use the stored hash values
        foreach my $hash (@{$self->{hashrefs}}) {
            $list .= "<OPTION value = \'$hash->{$item}\'>$hash->{$item}" unless
	             ($any && ($val eq $any) && ($hash->{$item} eq $val));
            $count++;
        }
    }
    $list .= "</SELECT>";

    $list = "NO CHOICE AVAILABLE" if (!$count); # return empty list if no items found
    return $list;
}

#############################################################################

sub htmlMaskedOptions {
# construct an HTML SELECT OPTIONS (htmlOptions) list with additional constraints 
    my $self   = shift;
    my $item   = shift; # the item for which select options list is made
    my $column = shift; # the column name to be tested for (or 'where')
    my $value  = shift; # this particular value or where clause

    my $currentHash = $self->{hashrefs}; # memorize current hash
    if ($column ne 'where' && $column ne 'distinct where') {
        $self->{hashrefs} = $self->associate('hashrefs',$value,$column);
    }
    else {
        my $query = "select $item from <self> where ($value)";
        $query =~ s/select/select distinct/ if ($column =~ /distinct/);
# print "query $query<br>";
        $self->{hashrefs} = $self->query($query,0); # use query trace
    }
    my $list = htmlOptions ($self,$item,$item,@_); # select list new hash
    $self->{hashrefs} = $currentHash; # restore old hash

    return $list;
}

#############################################################################

sub htmlEditRecord {
# generate an HTML formatted table with input/value fields for one table record
    my $self = shift;
    my $skey = shift; # value, use 0 for form with all field empty
    my $ckey = shift; # item
    my $tick = shift; # yes/no for checkbox tickmarks
    my $mask = shift; # masking info
    my $null = shift; # add option "null" if an "options" field is present

    my $primeKey = $self->{prime_key};

# find the hash for the requested table entry ($item=$value)

    undef my $hash;
# the next statement tests if the hash for the requested entry already exists
    if ($skey && (!($hash=$self->{hashref}) || $self->{hashref}->{$ckey} ne $skey)) {
        $hash = $self->associate('hashref', $skey, $ckey); # get the hash
    }

    undef my $table;
    if (!$skey || defined($hash)) {

# check masking

        my $columns = $self->{columns};
        my $coltype = $self->{coltype};
        undef my %mask;
        my $noinput = 1;
        if (defined($mask)) {
            my $lastmask;
            my @mask = split //,$mask;
            foreach my $column (@$columns) {
                $mask{$column} = $lastmask   if (!@mask);
                $mask{$column} = shift(@mask) if (@mask);
                $noinput = 0 if ($mask{$column} > 1);
                $lastmask = $mask{$column};
            }
        }
        else {
            $noinput = 0;
        }

        if (defined($primeKey) && defined($mask{$primeKey}) && $mask{$primeKey}>1) {
            $mask{$primeKey} = 1; # disable new value field for primary key
        }

# compose table header

        $table .= "<TABLE BORDER=$noinput CELLPADDING=2 CELLSPACING=2>";
        foreach my $column (@$columns) {
        # get columns value, if hash exists; else set to empty string
            my $value = '';
            $value = $hash->{$column} if (defined($hash));
            $value = '' if (!defined($value) || $value !~ /\S/);
            my $isASCII = &isASCII($value); # test for non ASCII symbols
        # mask > 1: this column has item has an input field
            if (!defined($mask{$column}) || ($mask{$column} > 1 && $isASCII)) {

                my $fieldname = "$column"; 
                $fieldname = "$ckey\&$skey\&$fieldname" if ($skey); # re: cgiEditTable

                my $size = $coltype->{$column};
                if ($size =~ /^.*\((\d+)\).*$/) {
                    $size = $1;
                } else {
                    $size = 20; # default standard size
                }
                my $max = $size;
                $size = 20 if ($size > 20); # default maximum display size
                if ($tick) {
                    $table .= "<TR><TD><INPUT TYPE=checkbox NAME=$fieldname";
	            $table .= " VALUE=\"$value\"></TD><TD>&nbsp</TD>";
                }
                $table .= "<TH ALIGN=LEFT>$column</TH><TD>&nbsp</TD>";
                if ($coltype->{$column} =~ /enum\((.*)\)/i) {
                    my $options = $1;
                    $options =~ s/\'//g;
                    my @options = split /,/,$options;
                    my $list = "<SELECT NAME=\"$fieldname\">";
                    if ($null) {
                        $list .= "<OPTION value='0' SELECTED>$null";
                    }
                    foreach my $option (@options) {
                        $list .= "<OPTION value=\'$option\'>$option";
                    }
                    $list .= "</SELECT>";
                    $table .= "<TD>$list</TD></TR>";
# alternative:      &htmlOptions($self,$column,$fieldname,$size,0,0);
                } else {
                    $table .= "<TD><INPUT TYPE=text NAME=$fieldname SIZE=$size";
                    $table .= " MAXLENGTH=$max VALUE=\"$value\"></TD></TR>";
                }
            }
        # mask = 1: just list the column 
            elsif ($mask{$column} > 0) {
                $value = 'non-ASCII characters' if (!$isASCII);
                $value = "&nbsp" if ($value !~ /\S/);
                $table .= "<TR>";
                $table .= "<TD>&nbsp</TD><TD>&nbsp</TD>" if ($tick);
                $table .= "<TH ALIGN=LEFT> $column </TH>";
                $table .= "<TD>&nbsp</TD>" if (!$noinput);
                $value =~ s/([^\n\s]{40,}?)/$1<br>/g; # wrap long entries
                my $align = "CENTER"; $align = "LEFT" if ($noinput);
                $table .= "<TD ALIGN=$align><b> $value </b></TD></TR>"; 
            }
        }
        $table .= "</TABLE>";

    } else {

        $table = 0;

    }
    return $table;
}

#############################################################################

sub htmlListRecord {
# list an individual record using the htmlEditRecord method in non-input mode
    my $self = shift;

# this will setup the hashref if hashresf does not exist

    $self->htmlEditRecord(@_); # sets up {hashref} for one record
    $self->expandSequence();   # expands the sequence 
    return $self->htmlEditRecord(@_); # returns the list
}

#############################################################################

sub htmlEditTable {
# generate an HTML formatted table with selected (via masking) input fields
# this method applies only to tables which have been build as hash table
    my $self = shift;
    my $mask = shift; # masking info
    my $null = shift; # add option "null" if an "options" field is present

    my $primeKey = $self->{prime_key};

# find the hashrefs for the table 

    my $hashrefs = $self->{hashrefs};

    undef my $table;
    if (defined($hashrefs) && @$hashrefs > 0) {

# okay, the table exists as a list of hashes in memory; get columns and types

        my $columns = $self->{columns};
        my $coltype = $self->{coltype};

# get masking information for the various columns

        undef my %mask;
        if (defined($mask)) {
            my @mask = split //,$mask;
            foreach my $column (@$columns) {
                $mask{$column} = 0 if (!@mask);
                $mask{$column} = shift(@mask) if (@mask);
            }
        }

# note: mask=0: do not include in output; =1 for value only; =2 for input field with value

        if (defined($primeKey) && defined($mask{$primeKey}) && $mask{$primeKey} == 2) {
            $mask{$primeKey} = 1; # disable new value field for primary key
        }

# compose table header and find root column name (key used in the SQL where clause)

        my $rootcolname = $self->{prime_key};
        $table .= "<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=0><tr>";
        foreach my $column (@$columns) {
            if ($mask{$column} == 2) {
                $table .= "<TH>$column</TH>";
            } elsif ($mask{$column} > 0) {
                $table .= "<TH ALIGN=LEFT>$column</TH>";
            }
            $rootcolname = $column if ($mask{$column} == 3); # overrides primary key
        }
        $table .= "</TR>";

# and the body, line by line; to get the fieldname, take the prime key or the last field scanned previously

        my $linecount = 0;
        foreach my $hash (@$hashrefs) {

            $linecount++;
            my $rootname = $rootcolname;
            
            $table .= "<TR>";
            foreach my $column (@$columns) {

                my $value = $hash->{$column};
                $value = '' if (!defined($value) || $value !~ /\S/);

                if ($mask{$column} == 2) {
            # get the name of the column field using the previous rootname, its value and the current column
                    my $rootvalue = 0; # default undefined
                    $rootname = $linecount if (!$rootname);
                    $rootvalue = $hash->{$rootname} if ($rootname ne $linecount);                     
                    my $fieldname = "$rootname\&$rootvalue\&$column";
            # get size of field from coltype
                    my $size = $coltype->{$column};
                    if ($size =~ /^.*\((\d+)\).*$/) {
                        $size = $1;
                    } else {
                        $size = 20; # default standard size
                    }
                    my $max = $size;
                    $size = 20 if ($size > 20); # default maximum display size

                    if ($coltype->{$column} =~ /enum\((.*)\)/i) {
                        my $options = $1;
                        $options =~ s/\'//g;
                        my @options = split /,/,$options;
                        my $list = "<SELECT NAME=\"$fieldname\">";
                        if ($null) {
                            $list .= "<OPTION value='0' SELECTED>$null";
                        }
                        foreach my $option (@options) {
                            $list .= "<OPTION value=\'$option\'>$option";
                        }
                        $list .= "</SELECT>";
                        $table .= "<TD>$list</TD>";
                    }
                    else {
                        $table .= "<TD><INPUT TYPE=text NAME=$fieldname SIZE=$size";
                        $table .= " MAXLENGTH=$max VALUE=\"$value\"></TD></TR>";
                    }
                }
                elsif ($mask{$column} > 0) {
                    $value = "&nbsp" if (!$value);
                    $table .= "<TH ALIGN=LEFT>$value</TH>";
                    $rootname = $column if (!$self->{prime_key});
                }
            }
            $table .= "<tr>";
        }
        $table .= "</TABLE>";

    } else {

        $table = 0;

    }


    return $table;
}

#############################################################################

sub cgiEditTable {
# analyse the return values from an HTML form of the preceding htmlEditTable 
# this method applies only to tables which have been build as hash table
    my $self = shift;
    my $cgi  = shift; # the cgi input hash built with the MyCGI module
    my $exec = shift;

    my $report;
    my $change = 0;
    if (ref($cgi) eq 'HASH') {

        undef my $target;
        undef my %inventory;
        foreach my $key (keys (%$cgi)) {
            if ($key =~ /((\S+)\&(\S+))\&(\S+)/) {
                $inventory{$1}++;
                $target = $1;
            }
        }
        my $records = keys %inventory; # the number of records referenced
#print "number of records: $records<br>";
        if ($records == 1) {
            my @fields = split /\&/,$target;
            $report .= "<CENTER><H4>Changes defined for @fields</H4></CENTER>";
        }    

# the table references are characterized by the pattern nn&vv&cc

        $report .= "<TABLE BORDER=0 CELLSPACING=2 CELLPADDING=2>";
        $report .= "<TR> <TH><FONT color='blue'>item</FONT></TH>";
        $report .= "<TH><FONT color='blue'>old value</FONT></TH>";
        $report .= "<TH><FONT color='blue'>new value</FONT></TH>";
        $report .= "<TH><FONT color='orange'>constraint</FONT></TH>" if ($records > 1);
        $report .= "<TH>&nbsp</TH>" if ($exec);
        $report .= "</TR>"; 

        foreach my $key (sort keys (%$cgi)) {
            my $newvalue = $cgi->{$key};
            if ($key =~ /(\S+)\&(\S+)\&(\S+)/) {
            # test if the new value differs from the old one
                my $wkey = $1; my $wval = $2; my $item = $3;
                my $currentvalue = $self->associate($3, $2, $1);
		$currentvalue = '' if (!$currentvalue);
                $newvalue = 'NULL' if (!$newvalue && $currentvalue); 
                if ($currentvalue ne $newvalue) {

                    $currentvalue = "&nbsp" if ($currentvalue !~ /\S/);
                    $report .= "<TR><TH ALIGN=LEFT> $item </TH>";
                    $report .= "<TD>$currentvalue</TD>";
                    $report .= "<TD bgcolor='yellow'>$newvalue</TD>";
                    $report .= "<TD bgcolor='aquamarine'>$wkey = $wval</TD>" if ($records > 1);

                    if ($exec && $self->update($item, $newvalue, $wkey, $wval)) {
                        $report .= "<TD bgcolor='lightgreen'>DONE</TD>";
                    }
                    elsif ($exec) {
                        $report .= "<TD bgcolor='orange'>FAILED</TD>";
                    }
                    $report .= "</TR>";
                    $change++;
                }
                else {
                    $report .= "<TR><TH ALIGN=LEFT> $item </TH>";
                    $currentvalue = "&nbsp" if ($currentvalue !~ /\S/);
                    $report .= "<TD>$currentvalue</TD>";
                    $report .= "<TD>&nbsp</TD><TD>no change</TD></TR>";
                }    
            }
	}
        $report .= "</TABLE>";
    }
    else {
        $report = "Invalid input: variable \$cgi ($cgi) is not a hash<br>";
    }


    return ($change,$report);
}

#############################################################################

sub isASCII {
# test input string for presence of non-ASCII symbols
    my $string = shift;

    my @ascii = unpack('c*',$string);
    foreach my $ascii (@ascii) {
    # ASCII symbols are in range 32 - 126
        if ($ascii < 32 || $ascii > 127) {
            return 0;
        }
    }
    return 1;
# alternative: if (quotemeta($string) eq $string) {return 1;} else {return 0;}
}

#############################################################################

sub copy {
# copy a row or rows from <self> to another instance <target> of the database table 
    my $self   = shift;
    my $target = shift; # table handle of target database table
    my $column = shift; # column name or 'where' keyword
    my $cvalue = shift; # column value or selection condition for rows in this table
    my $cnames = shift; # optional, array with column names to be copied; else all

print "self $self  target $target $column $cvalue ";
print "cnames @$cnames" if $cnames;
print "auto inc: $self->{autoinc}<br>\n";
    my $unique =  $self->{unique};
# find the first unique key which is not numerical, if any, else take the first one 
    undef my $marker;
    foreach my $key (@$unique) {
        $marker = $key;
        last if ($key ne $self->{autoinc});
    }

    if ($target eq $self) {
        return;
    }
    elsif ($target->{tablename} ne $self->{tablename}) {
        print "! copy failed: table name mismatch\n";
        return;
    }
    elsif (!$unique || !$marker) {
        print "! copy failed: no unique key available\n";
        return;
    }

# get the rows to be copied

    my $hashes = $self->associate('hashrefs',$column,$cvalue,1);
print "hashes: $hashes  unique=$unique @$unique $marker\n";

    foreach my $hash (@$hashes) {
# test if the unique key exists in target; if so update, else newrow
        my $targethash;
        if (!($targethash = $target->associate('hashref',$hash->{$marker},$marker))) {
            print "creating new row for $hash->{$marker}\n";
#            $target->newrow($marker,$hash->{$marker});
        }
        foreach my $key (keys %$hash) {
   print "key $key  autoinc '$target->{autoinc}' marker $marker hashkey '$hash->{$key}'\n";
            if ($key ne $target->{autoinc} && $key ne $marker && $hash->{$key} && $hash->{$key} =~ /\S/) {
                if ($hash->{$key} ne $targethash->{$key}) {
                    print "updating $key = $hash->{$key} for $hash->{$marker}\n";
#                    $target->update($key,$hash->{$key},$marker,$hash->{$marker});
                }
                else {
		    print "key $key is identical in both tables\n";
                }
	    }
        }
print "\n\n";       
    }
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "30 Apr 2001",
        updated =>    "08 Apr 2002",
    };
}

1;
