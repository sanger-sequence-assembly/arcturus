package CreateArcturus;

use strict;

# use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use vars qw(@ISA @EXPORT);

use Exporter ();

@ISA = qw(Exporter);

@EXPORT = qw(create_common create_organism diagnose);


# ARCTURUS database creation script for all or individual tables

#--------------------------- documentation --------------------------
#--------------------------------------------------------------------

sub create_common {
    my ($dbh, $target, $list) = @_;

    my $created = 0;

    $target = ' ' if (!defined($target));

    if ($target eq 'all' || $target eq 'inventory') {
        &create_INVENTORY($dbh, $list);
        $created++;
    }

    if ($target eq 'all' || $target eq 'organisms') {
        &create_ORGANISMS($dbh, $list);
        $created++;
    }

    if ($target eq 'all' || $target eq 'users') {
	&create_USERS($dbh, $list);
        $created++;
    }

    if ($target eq 'all' || $target eq 'sessions') {
        &create_SESSIONS($dbh, $list);
        $created++;
    }

    if ($target eq 'all' || $target eq 'readmodel') {
	&create_READMODEL($dbh, $list);
        $created++;
    }

    if ($target eq 'all' || $target eq 'datamodel') {
        &create_DATAMODEL($dbh, $list);
        $created++;
    }
       
    if ($target eq 'all' || $target eq 'vectors') {
        &create_VECTORS($dbh, $list);
        $created++;
    }
    
    if ($target eq 'all' || $target eq 'chemtypes') {
	&create_CHEMTYPES($dbh, $list);
        $created++;
    }

    return $created;
}

#*********************************************************************************************************

sub create_organism {
# create table $target or all in the current (organism) database
    my ($dbh, $database, $target, $userid, $level, $list) = @_;

    undef my @tables;

# check that we are in the right database by testing the "HISTORY" table
# if not found and level = 0, abort; if level=1: create 

    my $historyTable = 'HISTORY'.uc($database); # the required name
#print "SHOW TABLES FROM $database LIKE '$historyTable'<br>";
    my $result = $dbh->do("SHOW TABLES FROM $database LIKE '$historyTable'");
#print "SHOW TABLES FROM  $database LIKE '$historyTable' result:$result<br>";

    if ($level > 0 && (!defined($result) || $result <= 0)) {
    # the history table does not exist: create it
        &create_DBHISTORY ($dbh, $list, $userid);
    # after creation rename the table to its required name
        my $rename = $dbh->do("ALTER TABLE DBHISTORY RENAME AS $historyTable");
        push @tables, $historyTable if ($rename);
        undef $historyTable if (!$rename);
    }
    elsif (!defined($result) || $result <= 0) { # level<=0
        print "WARNING! Table $historyTable does not exist; create ABORTED<br>";
        $target = 'VOID'; # skips all subsequent create calls
        $result = $dbh->do("SHOW TABLES");
    }

# get the "history"  table into memory

    $historyTable = DbaseTable->new($dbh,$historyTable,$database,1);
    $historyTable->setTracer(0); # no query tracing


    if (!$target || $target eq 'HISTORY') {
	&create_HISTORY($dbh, $list, $userid);
        &record ($historyTable,$userid,'HISTORY');
        push @tables, 'HISTORY';
    }

    my $NEWREADS = 0;
    if (!$NEWREADS) {
# old structure for READS table: 
      if (!$target || $target eq 'READS') {    
        push @tables, 'READS';
        &create_READS ($dbh, $list);
        &record ($historyTable,$userid,'READS');
      }
    }
# new structure for READS table: 
    else {
      if (!$target || $target eq 'NEWREADS') {    
        push @tables, 'NEWREADS';
        &create_NEWREADS ($dbh, $list);
        &record ($historyTable,$userid,'READS');
      }

      if (!$target || $target eq 'DNA') {    
        push @tables, 'DNA';
        &create_DNA ($dbh, $list);
        &record ($historyTable,$userid,'DNA');
      }

      if (!$target || $target eq 'TEMPLATE') {    
        push @tables, 'TEMPLATE';
        &create_TEMPLATE ($dbh, $list);
        &record ($historyTable,$userid,'TEMPLATE');
      }

      if (!$target || $target eq 'COMMENT') {    
        push @tables, 'COMMENT';
        &create_COMMENT ($dbh, $list);
        &record ($historyTable,$userid,'COMMENT');
      }
    }

# end new structure

    if (!$target || $target eq 'READPAIRS') {    
        push @tables, 'READPAIRS';
        &create_READPAIRS ($dbh, $list);
        &record ($historyTable,$userid,'READPAIRS');
    }

    if (!$target || $target eq 'READEDITS') {    
        push @tables, 'READEDITS';
        &create_READEDITS ($dbh, $list);
        &record ($historyTable,$userid,'READEDITS');
    }

    if (!$target || $target eq 'READTAGS') {    
        push @tables, 'READTAGS';
        &create_READTAGS ($dbh, $list);
        &record ($historyTable,$userid,'READTAGS');
    }

    if (!$target || $target eq 'PENDING') {    
        push @tables, 'PENDING';
        &create_PENDING ($dbh, $list);
        &record ($historyTable,$userid,'PENDING');
    }

    if (!$target || $target eq 'READS2CONTIG') {    
        push @tables, 'READS2CONTIG';
        &create_READS2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'READS2CONTIG');
    }

    if (!$target || $target eq 'GAP4TAGS') {    
        push @tables, 'GAP4TAGS';
        &create_GAP4TAGS ($dbh, $list);
        &record ($historyTable,$userid,'GAP4TAGS');
    }

    if (!$target || $target eq 'STSTAGS') {    
        push @tables, 'STSTAGS';
        &create_STSTAGS ($dbh, $list);
        &record ($historyTable,$userid,'STSTAGS');
    }

    if (!$target || $target eq 'HAPPYMAP') {    
        push @tables, 'HAPPYMAP';
        &create_HAPPYMAP ($dbh, $list);
        &record ($historyTable,$userid,'HAPPYMAP');
    }

    if (!$target || $target eq 'HAPPYTAGS') {    
        push @tables, 'HAPPYTAGS';
        &create_HAPPYTAGS ($dbh, $list);
        &record ($historyTable,$userid,'HAPPYTAGS');
    }

    if (!$target || $target eq 'TAGS2CONTIG') {    
        push @tables, 'TAGS2CONTIG';
        &create_TAGS2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'TAGS2CONTIG');
    }

    if (!$target || $target eq 'GENE2CONTIG') {    
        push @tables, 'GENE2CONTIG';
        &create_GENE2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'GENE2CONTIG');
    }

    if (!$target || $target eq 'CLONEMAP') {    
        push @tables, 'CLONEMAP';
        &create_CLONEMAP ($dbh, $list);
        &record ($historyTable,$userid,'CLONEMAP');
    }

    if (!$target || $target eq 'CLONES2CONTIG') {    
        push @tables, 'CLONES2CONTIG';
        &create_CLONES2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'CLONES2CONTIG');
    }

    if (!$target || $target eq 'READS2ASSEMBLY') {    
        push @tables, 'READS2ASSEMBLY';
        &create_READS2ASSEMBLY ($dbh, $list);
        &record ($historyTable,$userid,'READS2ASSEMBLY');
    }

    if (!$target || $target eq 'CONTIGS') {    
        push @tables, 'CONTIGS';
        &create_CONTIGS ($dbh, $list);
        &record ($historyTable,$userid,'CONTIGS');
    }

    if (!$target || $target eq 'CONSENSUS') {    
        push @tables, 'CONSENSUS';
        &create_CONSENSUS ($dbh, $list);
        &record ($historyTable,$userid,'CONSENSUS');
    }

    if (!$target || $target eq 'CONTIGS2CONTIG') {    
        push @tables, 'CONTIGS2CONTIG';
        &create_CONTIGS2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'CONTIGS2CONTIG');
    }

    if (!$target || $target eq 'CONTIGS2SCAFFOLD') {    
        push @tables, 'CONTIGS2SCAFFOLD';
        &create_CONTIGS2SCAFFOLD ($dbh, $list);
        &record ($historyTable,$userid,'CONTIGS2SCAFFOLD');
    }

    if (!$target || $target eq 'CONTIGS2PROJECT') {    
        push @tables, 'CONTIGS2PROJECT';
        &create_CONTIGS2PROJECT ($dbh, $list);
        &record ($historyTable,$userid,'CONTIGS2PROJECT');
    }

    if (!$target || $target eq 'CHEMISTRY') {    
        push @tables, 'CHEMISTRY';
        &create_CHEMISTRY ($dbh, $list);
        &record ($historyTable,$userid,'CHEMISTRY');
    }

    if (!$target || $target eq 'STRANDS') {    
        push @tables, 'STRANDS';
        &create_STRANDS ($dbh, $list);
        &record ($historyTable,$userid,'STRANDS');
    }

    if (!$target || $target eq 'PRIMERTYPES') {    
        push @tables, 'PRIMERTYPES';
        &create_PRIMERTYPES ($dbh, $list);
        &record ($historyTable,$userid,'PRIMERTYPES');
    }

    if (!$target || $target eq 'BASECALLER') {    
        push @tables, 'BASECALLER';
        &create_BASECALLER ($dbh, $list);
        &record ($historyTable,$userid,'BASECALLER');
    }

    if (!$target || $target eq 'SEQUENCEVECTORS') {    
        push @tables, 'SEQUENCEVECTORS';
        &create_SEQUENCEVECTORS ($dbh, $list);
        &record ($historyTable,$userid,'SEQUENCEVECTORS');
    }

    if (!$target || $target eq 'CLONINGVECTORS') {    
        push @tables, 'CLONINGVECTORS';
        &create_CLONINGVECTORS ($dbh, $list);
        &record ($historyTable,$userid,'CLONINGVECTORS');
    }

    if (!$target || $target eq 'CLONES') {    
        push @tables, 'CLONES';
        &create_CLONES ($dbh, $list);
        &record ($historyTable,$userid,'CLONES');
    }

    if (!$target || $target eq 'CLONES2PROJECT') {    
        push @tables, 'CLONES2PROJECT';
        &create_CLONES2PROJECT ($dbh, $list);
        &record ($historyTable,$userid,'CLONES2PROJECT');
    }

    if (!$target || $target eq 'STATUS') {    
        push @tables, 'STATUS';
        &create_STATUS ($dbh, $list);
        &record ($historyTable,$userid,'STATUS');
    }

    if (!$target || $target eq 'LIGATIONS') {    
        push @tables, 'LIGATIONS';
        &create_LIGATIONS ($dbh, $list);
        &record ($historyTable,$userid,'LIGATIONS');
    }

    if (!$target || $target eq 'ASSEMBLY') {
        &create_ASSEMBLY($dbh, $list);
        &record ($historyTable,$userid,'ASSEMBLY');
        push @tables, 'ASSEMBLY';
    }

    if (!$target || $target eq 'PROJECTS') {
        &create_PROJECTS($dbh, $list);
        &record ($historyTable,$userid,'PROJECTS');
        push @tables, 'PROJECTS';
    }

    if (!$target || $target eq 'USERS2PROJECTS') {
	&create_USERS2PROJECTS($dbh, $list);
        &record ($historyTable,$userid,'USERS2PROJECTS');
        push @tables, 'USERS2PROJECTS';
    }

    return \@tables; # return a list of tables which have been created
}

#*********************************************************************************************************

sub record {
# enter a record into the history tables
    my $dbhistory = shift; # HISTORY<DB> table
    my $userid    = shift;
    my $dbtable   = shift; 

    my $timestamp = $dbhistory->timestamp(0);
    my ($date, $time) = split /\s/,$timestamp;

# add record to DBHISTORY table

# test if the entry exists; if not, create a new row

    if (!$dbhistory->associate('created',$dbtable,'tablename')) {
        $dbhistory->newrow('tablename',$dbtable);
    }
    $dbhistory->update('created'  ,$date      ,'tablename',$dbtable);
    $dbhistory->update('lastuser' ,$userid    ,'tablename',$dbtable);
    $dbhistory->update('lastouch' ,$timestamp ,'tablename',$dbtable);
    $dbhistory->update('action'   ,'created'  ,'tablename',$dbtable);

# now section add creation SQL instruction to the HISTORY table

    my $history = $dbhistory->spawn('HISTORY');

    my $success = 0;
# if history does not exist: error message
    if ($history->{errors}) {
        print "Failed to add timestamp to HISTORY table: $history->{errors}<br>\n";
    }
# if history is the table being created: scan the database for other tables
# possibly already created and add their creation status as initial record
    elsif ($dbtable eq 'HISTORY') {
        my $tables = $history->show('tables',0);
        foreach my $table (@$tables) {
            my $action = 'create';
            $action = 'CREATE' if ($table eq 'HISTORY');
            $action = 'CREATE' if ($table =~ /HISTORY/ && @$tables <= 2);
            $success = &updateHistory ($history, $table, $userid, $action);
            print "Failed to add timestamp for $table to HISTORY table: $history->{qerror}<br>\n" if !$success;
        }
    }
# for all other tables: add create record to history table
    else {
        $success = &updateHistory ($history, $dbtable, $userid);
        print "Failed to add timestamp for $dbtable to HISTORY table: $history->{qerror}<br>\n" if !$success;
    }

}

#*********************************************************************************************************

sub updateHistory {
# add a 'CREATE' record to the HISTORY table 
    my $history = shift; # handle to the HISTORY table
    my $dbtable = shift; # database table to be updated in HISTORY table
    my $userid  = shift;
    my $action  = shift || 'CREATE';

    my $sqlquery  = $history->show("create table $dbtable",1); # get create instruction for the table

    my $success = 0;
    if (ref($sqlquery) eq 'ARRAY') {
        my $timestamp = $history->timestamp(0);
        my @items  = ('tablename', 'date'    , 'user' , 'action', 'command');
        my @values = ($dbtable   , $timestamp, $userid,  $action, "$sqlquery->[0]");
        $success = $history->newrow(\@items,\@values);
    }

    return $success;
}

#*********************************************************************************************************
#*********************************************************************************************************
# tables for individual organism databases
#*********************************************************************************************************
#*********************************************************************************************************

sub create_READS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"READS", $list);
    print STDOUT "Creating table READS ..." if ($list);
    $dbh->do(qq[CREATE TABLE READS(
             read_id          MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY, 
             readname         VARCHAR(32) BINARY   NOT NULL, 
	     date             DATE                 NOT NULL,
             ligation         SMALLINT UNSIGNED    NOT NULL,
             clone            SMALLINT UNSIGNED        NULL,
             template         VARCHAR(24) BINARY   NOT NULL, 
             strand           CHAR(1)                  NULL, 
             primer           TINYINT  UNSIGNED   DEFAULT 0, 
             chemistry        TINYINT  UNSIGNED        NULL,
             basecaller       TINYINT  UNSIGNED        NULL,
             direction        ENUM ('?','+','-')  DEFAULT '?', 
             slength          SMALLINT UNSIGNED    NOT NULL,
             sequence         BLOB                 NOT NULL,
             scompress        TINYINT  UNSIGNED   DEFAULT 0,     
             quality          BLOB                 NOT NULL,
             qcompress        TINYINT  UNSIGNED   DEFAULT 0,     
             lqleft           SMALLINT UNSIGNED    NOT NULL,
             lqright          SMALLINT UNSIGNED    NOT NULL,
             svcsite          SMALLINT                 NULL,
             svpsite          SMALLINT                 NULL,
             svector          TINYINT  UNSIGNED   DEFAULT 0,               
             svleft           SMALLINT UNSIGNED        NULL,
             svright          SMALLINT UNSIGNED        NULL,
             cvector          TINYINT  UNSIGNED   DEFAULT 0,          
             cvleft           SMALLINT UNSIGNED        NULL,
             cvright          SMALLINT UNSIGNED        NULL,
             pstatus          TINYINT  UNSIGNED   DEFAULT 0,
             rstatus          MEDIUMINT UNSIGNED  DEFAULT 0,
             paired           ENUM ('N','F','R')  DEFAULT 'N',
             tstatus          ENUM ('N','I','T')  DEFAULT 'N',
             comment          VARCHAR(255)               NULL,
             CONSTRAINT READNAMEUNIQUE UNIQUE (READNAME)  
         )]);

    print STDOUT "... DONE!\n" if ($list);

# Make indices

    print STDOUT "Building indexes ...\n" if ($list);
    $dbh->do(qq[CREATE UNIQUE INDEX RECORD_INDEX ON READS (readname)]);
    $dbh->do(qq[CREATE INDEX TEMPLATE_INDEX ON READS (template)]);

    print STDOUT "Indexed READNAME ON READS ... DONE\n" if ($list);

}

#--------------------------- documentation --------------------------
=pod

=head1 Table READS

=head2 Synopsis

Primary Data table.

READS is a static data table: the only change made to data records after 
data insertion is the (possible) re-definition of the B<paired> column

=head2 Scripts & Modules

=over 4

=item rloader

(I<script>) entering read data from experiment files, (Oracle or caf files);

run from the Arcturus GUI under B<INPUT> --E<gt> B<READS>

=item find-complement

(I<script>) identifying read-pairs (see column B<paired>);

run from the Arcturus GUI under B<TEST> --E<gt> B<MENU> --E<gt> B<PAIRS>

=item ReadsReader.pm 

=item Compress.pm

=back 

=head2 Description of columns:

=over 4

=item read_id    

auto-incremented primary key (foreign key in many other tables)

=item readname 

unique readname (index)

=item date        

Asp date

=item ligation     

(integer) reference to table LIGATIONS, linked on foreign key 'ligation' 

=item clone        

(integer) reference to table CLONES, linked on foreign key 'clone'  

=item template     

read template name (indexed)

=item strand       

(character) reference to table STRANDS, linked on foreign key 'strand'  

=item primer       

(integer) reference to PRIMERS, linked on foreign key 'primer' 

=item chemistry    

(integer) reference to CHEMISTRY, linked on foreign key 'chemistry' 

=item basecaller   

(integer) reference to BASECALLER, linked on foreign key 'basecaller' 

=item direction    

direction of read ('+', '-' or '?')

=item slength      

length of stored DNA sequence

=item sequence     

DNA sequence data

=item scompress    

Sequence compression code: (obsolete in next release)

=over 8

=item 0 for no compression (stored as plain text string)

=item 1 for triplet encoding

=item 2 for Huffman compression

=item 99 for Z compression

=back

=item quality      

Basecaller Quality data

=item qcompress    

Quality data compression code: (obsolete in next release)

=over 8

=item 0 for no compression (stored as plain text string)

=item 1 for encoding with number substitution in range 0-100 (1 byte per value)

=item 2 for Huffman compression on text string

=item 3 for Huffman compression on difference data

=item 99 for Z compression

=back

=item lqleft       

low-quality left boundary

=item lqright      

low-quality right boundary

=item svcsite      

sequence vector cloning site

=item svpcite      

seqeunce vector primer site

=item svector      

(integer) reference to SEQUENCEVECTORS, linked on foreign key 'svector'

=item svleft       

sequence vector presence at left

=item svright      

sequence vector presence at right

=item cvector      

(integer) reference to CLONINGVECTORS, linked on foreign key 'cvector'

=item cvleft       

cloning vector position at left, if on left

=item cvright      

cloning vector position at right, if on right

=item pstatus      

(integer) reference to STATUS table, linked on foreign key 'status'

=item rstatus      

read processing status (when loaded from file) encoding (possible) load-time warnings 

=item tstatus      

trace archive status: N (not defined), I (ignore) for not entered, or T for entry confirmed  

=item paired      

label to mark as Forward or Reverse read of a pair or pairs; this column is the only
one which can be changed after initial data loading  

=item comment      

any (i.p. comment found in flat files)

=back

=head2 Linked Tables on key read_id

=over 4

=item READEDITS

=item READPAIRS

=item READS2ASSEMBLY

=item READS2CONTIG

=back

=head2 Dictionary Tables

=over 9

=item BASECALLER

=item CHEMISTRY

=item CLONES

=item CLONINGVECTORS

=item LIGATIONS

=item PRIMERS

=item SEQUENCEVECTORS

=item STATUS

=item STRANDS

=back

=cut
#=item COMMENT
#---------------------------------------------------------------------------------
# new readstable structure to be implemented

sub create_NEWREADS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"READS", $list);
    print STDOUT "Creating table READS ..." if ($list);
    $dbh->do(qq[CREATE TABLE READS(
             read_id          MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY, 
             readname         CHAR(32) BINARY      NOT NULL, 
	     date             DATE                 NOT NULL,
#             ligation         SMALLINT UNSIGNED    NOT NULL,
             clone            SMALLINT UNSIGNED        NULL,
#             template         CHAR(24) BINARY      NOT NULL, 
             template         MEDIUMINT UNSIGNED   NOT NULL, 
             strand           CHAR(1)                  NULL, 
             primer           TINYINT  UNSIGNED   DEFAULT 0, 
             chemistry        TINYINT  UNSIGNED        NULL,
             basecaller       TINYINT  UNSIGNED        NULL,
             direction        ENUM ('?','+','-')  DEFAULT '?', 
             slength          SMALLINT UNSIGNED    NOT NULL,
             lqleft           SMALLINT UNSIGNED    NOT NULL,
             lqright          SMALLINT UNSIGNED    NOT NULL,
             svcsite          SMALLINT                 NULL,
             svpsite          SMALLINT                 NULL,
             svector          TINYINT  UNSIGNED   DEFAULT 0,               
             svleft           SMALLINT UNSIGNED        NULL,
             svright          SMALLINT UNSIGNED        NULL,
             cvector          TINYINT  UNSIGNED   DEFAULT 0,          
             cvleft           SMALLINT UNSIGNED        NULL,
             cvright          SMALLINT UNSIGNED        NULL,
             pstatus          TINYINT  UNSIGNED   DEFAULT 0,
             rstatus          MEDIUMINT UNSIGNED  DEFAULT 0,
             paired           ENUM ('N','F','R')  DEFAULT 'N',
             tstatus          ENUM ('N','I','T')  DEFAULT 'N',
             comment          MEDIUMINT UNSIGNED   NOT NULL, 
             CONSTRAINT READNAMEUNIQUE UNIQUE (READNAME)  
         )]);

    print STDOUT "... DONE!\n" if ($list);

# Make indices

    print STDOUT "Building indexes ...\n" if ($list);
    $dbh->do(qq[CREATE UNIQUE INDEX READNAMES ON READS (readname)]);
    print STDOUT "Indexed READNAME ON READS ... DONE\n" if ($list);

}

#---
# scompress, qcompress redundent, laways Z compression used

sub create_DNA {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"DNA", $list);
    print STDOUT "Creating table DNA ..." if ($list);
    $dbh->do(qq[CREATE TABLE DNA(
             read_id          MEDIUMINT UNSIGNED   NOT NULL PRIMARY KEY,
             scompress        TINYINT  UNSIGNED   DEFAULT 0,     
             sequence         BLOB                 NOT NULL,
             qcompress        TINYINT  UNSIGNED   DEFAULT 0,     
             quality          BLOB                 NOT NULL
         )]);
			     
    print STDOUT "... DONE!\n" if ($list);
}

#---

sub create_TEMPLATE {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"TEMPLATE", $list);
    print STDOUT "Creating table TEMPLATE ..." if ($list);
    $dbh->do(qq[CREATE TABLE TEMPLATE(
             template        MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY, 
             templatename    CHAR(24) BINARY      NOT NULL, 
             ligation        SMALLINT UNSIGNED    NOT NULL,
             counted         INT UNSIGNED         DEFAULT 0
         )]);
    print STDOUT "Building indexes ...\n" if ($list);
    $dbh->do(qq[CREATE UNIQUE INDEX TEMPLATE_INDEX ON TEMPLATE (template)]);

    print STDOUT "... DONE!\n" if ($list);
}

#--- dictionary table

sub create_COMMENT {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"COMMENT", $list);
    print STDOUT "Creating table COMMENT ..." if ($list);
    $dbh->do(qq[CREATE TABLE COMMENT(
             comment         MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY, 
             commenttext     TEXT                 NOT NULL,
             counted         INT UNSIGNED         DEFAULT 0
        )]);
			     
    print STDOUT "... DONE!\n" if ($list);
}


#*********************************************************************************************************

sub create_READEDITS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"READEDITS", $list);
    print STDOUT "Creating table READEDITS ..." if ($list);
    $dbh->do(qq[CREATE TABLE READEDITS(
             read_id           MEDIUMINT UNSIGNED   NOT NULL,
             base              SMALLINT  UNSIGNED   NOT NULL,
             edit              CHAR(4)                  NULL,
             deprecated        ENUM ('N','Y','X') DEFAULT 'N'
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# Make index on read_id

    print STDOUT "Building index on read_id ...\n" if ($list);
    $dbh->do(qq[CREATE INDEX reads_index ON READEDITS (read_id)]);
    print STDOUT "Index READS_INDEX ON READEDITS ... DONE\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table READEDITS

=head2 Synopsis

=head2 Scripts & Modules

=over 4

=item cloader

(I<script>) entering read mapping data from CAF files;

=item ReadMapper.pm

=back

=head2 Description of columns:

=over 4

=item read_id

number of read

=item base

number of base affected 

=item edit

char(4) encoded edit: ....
# edits  : list of substitutions for individual bases in read, code: nnnGa nnnT etc.
#         (substitute "G" at position nnn by "a", delete "T" at position nnn)
# edit  : substitution value of blank for delete
# ? user  : integer refering to user table (implicit in contig info?)

=item deprecated

deprecation status: 'Y' for no longer valis, 'N' for current; transient 'X'

=back

=head2 Linked Tables on key read_id

=over 4

=item READS

=back

=cut

#*********************************************************************************************************

sub create_READPAIRS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"READPAIRS", $list);
    print STDOUT "Creating table READPAIRS ..." if ($list);
    $dbh->do(qq[CREATE TABLE READPAIRS(
             forward           MEDIUMINT UNSIGNED               NOT NULL,
             reverse           MEDIUMINT UNSIGNED               NOT NULL,
             score             ENUM('0','1','2','-1','-2','U')  NOT NULL DEFAULT 'U'
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# Make index on read_id

    print STDOUT "Building indexes on read_ids ...\n" if ($list);
    $dbh->do(qq[CREATE INDEX rfindex ON READPAIRS (forward)]);
    $dbh->do(qq[CREATE INDEX rrindex ON READPAIRS (reverse)]);
    print STDOUT "Index RFINDEX and RRINDEX ON READPAIRS ... DONE\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table READPAIRS

=head2 Synopsis

Read IDs of forward and reverse members of a read pair; a read can 
occur in more than one pair. This table has to be updated by running
the find-complement script after each new addition of reads. 

The table
facilitates easy location of read-pair bridges between contigs

=head2 Scripts & Modules

=over 4

=item find-complement

(I<script>) identifying read-pairs (see column B<paired>)

run from the Arcturus GUI under B<TEST> --E<gt> B<MENU> --E<gt> B<PAIRS>

=item test-complement

(I<script>) testing read-pair information (see column B<paired>);

run from the Arcturus GUI under B<TEST> --E<gt> B<MENU> --E<gt> B<PAIRS??>

=item find-bridges

(I<script>) identifying read-pair bridges between contigs

run from the Arcturus GUI under B<TEST> --E<gt> B<MENU> --E<gt> B<BRIDGES??>

=back

=head2 Description of columns:

=over 4

=item forward

read_id of forward read in pair (indexed)

=item reverse

read_id of reverse read in pair (indexed)

=item score

see http://www.sanger.ac.uk/Software/sequencing/docs/harper/asmReadpairs.shtml documentation; U for untested

=back

=head2 Linked Tables on keys forward & reverse

=over 4

=item READS

=back

=cut
#*********************************************************************************************************

sub create_READTAGS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"READTAGS", $list);
    print STDOUT "Creating table READTAGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE READTAGS(
             read_id           MEDIUMINT UNSIGNED    NOT NULL,
             readtag           CHAR(4) BINARY        NOT NULL,
             pstart            SMALLINT  UNSIGNED    NOT NULL,
             pfinal            SMALLINT  UNSIGNED    NOT NULL,
             strand            ENUM ('F','R','U') DEFAULT 'U',
             comment           VARCHAR(128)              NULL,
             deprecated        ENUM ('N','Y','X') DEFAULT 'N'
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# Make index on read_id

    print STDOUT "Building index on read_id ...\n" if ($list);
    $dbh->do(qq[CREATE INDEX reads_index ON READTAGS (read_id)]);
    print STDOUT "Index RTAGS_INDEX ON READTAGS ... DONE\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table READTAGS

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=over 4

=item read_id

number of read

=item readtag

name of tag 

=item pstart

begin of tag in read

=item pfinal

end of tag in read

=item strand

On forward (F) or reverse (R) strand, or unknown (U)

=item comment

Description of the tag, e.g. "Jumping library 50839"

=item deprecated

deprecation status: 'Y' for no longer valid, 'N' for current; transient 'X'

=back

=head2 Linked Tables on key read_id

=over 4

=item READS

=back

=cut

#*********************************************************************************************************

sub create_PENDING {
    my ($dbh, $list) = @_;

# list reads by readname refered to by contigs but not yet included in the data base

    &dropTable ($dbh,"PENDING", $list);
    print STDOUT "Creating table PENDING ..." if ($list);
    $dbh->do(qq[CREATE TABLE PENDING(
             record           INT                 NOT NULL AUTO_INCREMENT PRIMARY KEY,
             readname         VARCHAR(32)         NOT NULL,
             assembly         TINYINT UNSIGNED    NOT NULL
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table PENDING

=head2 Synopsis

Temporary storage of read(name)s to be loaded. This table is populated
by the r(eads)loader script with reads which failed to load, or by the
assembly loading script (cloader) in read-check mode.

The table is de-populated by the reads loader script once a read is 
successfully loaded, e.g. by using the forced-load option

=head2 Scripts & Modules

=over 4

=item rloader

=item cloader

=item cafloader

=item ReadsReader.pm

=back

=head2 Description of columns:

=over 4

=item record

Auto-incremented counter 

=item readname

Full read name 

=item assembly

Assembly number 

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_READS2CONTIG {
    my ($dbh, $list) = @_;

# readnr     : number of read in READS table
# contig     : number of contig in CONTIGS table 
#             (or should we use a combined number for index purposes)
# alignment    information in prstart, prfinal, pcstart, pcfinal
# label      : encodes mapping type (T) and alignment (A) as: 10T + A
#              T = 0 for one of several mapped read sections
#              T = 1 this mapped section is the only one
#              T = 2 the map is the overal map of all read sections
#              A = 0 for a read aligned with the contig,
#                = 1 for a read aligned against the contigs direction
#              e.g: cyclops searches label >= 10; others label < 20

# clone      : reference to CLONES table (duplicates info in READS, but 
#              is included for fast access by Cyclops in mapping context
# assembly   : assembly number reference to ASSEMBLY.assembly; duplicates
#              info in CONTIGS2PROJECT, PROJECT2ASSEMBLY but required for 
#              delete actions

# generation : incremented after each completed assembly with:
#              "update READS2CONTIG set generation=generation+1 where assembly=N"
# deprecated : on for mappings final (X) or no longer current (Y)
#              or marked for deletion (M) 
# //blocked    : re: full-proof upgrade generation counters//
#    $list = 1;
    &dropTable ($dbh,"READS2CONTIG", $list);
    print STDOUT "Creating table READS2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE READS2CONTIG(
             contig_id        MEDIUMINT UNSIGNED       NOT NULL,
             pcstart          INT UNSIGNED             NOT NULL,
             pcfinal          INT UNSIGNED             NOT NULL,
             read_id          MEDIUMINT UNSIGNED       NOT NULL,
             prstart          SMALLINT UNSIGNED        NOT NULL,
             prfinal          SMALLINT UNSIGNED        NOT NULL,
             label            TINYINT  UNSIGNED        NOT NULL,
             clone            SMALLINT UNSIGNED        NOT NULL,
             assembly         SMALLINT UNSIGNED        NOT NULL,
             generation       SMALLINT UNSIGNED        NOT NULL,
             deprecated       ENUM('N','M','Y','X')  DEFAULT 'X'
	 ) type = INNODB]);
    print STDOUT "... DONE!\n" if ($list);
#             blocked          ENUM('0','1')         DEFAULT '0' to be left out with INNODB tables
# NOTE item clone and assembly to be taken out

# Make (separate) indexes on read_id and contig_id

    print STDOUT "Building indexes on read_id, contig_id...\n" if ($list);
    $dbh->do(qq[CREATE INDEX reads_index ON READS2CONTIG (read_id)]);
    $dbh->do(qq[CREATE INDEX cntgs_index ON READS2CONTIG (contig_id)]);
    print STDOUT "Indexes READS_INDEX and CNTGS_INDEX  ON READS2CONTIG ... DONE\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table READS2CONTIG

=head2 Synopsis

Table for individual and overall reads-to-contig mappings in an assembly. 

This table is populated by the assembly loader script.

=head2 Scripts & Modules

=over 4

=item cloader (I<script>)

=item ReadMapper.pm

=item ContigBuilder.pm

=back

=head2 Description of columns:

=over 8

=item contig_id

number of contig in CONTIGS table 

=item read_id

number of read in READS table

=item pcstart

begin position of mapping on the contig

=item pcfinal

end position of mapping on the contig 

=item read_id

number of read in READS table

=item prstart

begin position of mapping on the read

=item prfinal

end position of mapping on the read 

=item label

encodes mapping type (T) and alignment (A) as: 10T + A

=over 16

=item  T = 0 for one of a series of mapped read sections

=item  T = 1 this mapped section is the only mapping for this read

=item  T = 2 the maping is the overal map of all read sections

=item  A = 0 for a read aligned with the contig,

=item  A = 1 for a counter-aligned read against the contigs direction

=back

Valid values are: 0, 1, 10, 11, 20, 21 

To access the individual mappings select on label < 20

To access the overall mapping of a read to the contig select on label >= 10

(Alignment information is also in the order of pcstart & pcfinal)

=item clone

number of clone in CLONES table

(duplicates info in READS table, but is included to facilitate
fast access by Cyclops to derive clone maps)

=item assembly

number of assembly in ASSEMBLY table

(duplicates info in CONTIGS2SCAFFOLD but required for generations update)

=item generation

generation counter, incremented after each completed assembly

=item deprecated

flag to mark the status of the mapping

=over 16

=item N for a new mapping

=item M for a mapping marked for deletion after a generation update

=item Y for a mapping no longer current, i.e. superseeded by a later mapping

=item X for a final mapping, i.e. the read disappears from the assembly

=back

=item blocked

flag used in full-proof upgrade generation counters

=back

=head2 Linked Tables

=over 4

=item CONTIGS on key contig_id

=item READS on key read_id

=item ASSEMBLY on key assembly

=item CLONES on key clones

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_READS2ASSEMBLY {
    my ($dbh, $list) = @_;

# reads to assembly (e.g. chromosome, blob)
# assembly REF to assembly id number
# astatus: assembly status: 0 for read in  bin of the assembly (not allocated) 
#                           1 for soft allocation e.g. temporarilly by finisher
#                           2 for firm allocation in a contig 
#          astatus > 0 for a locked read

    &dropTable ($dbh,"READS2ASSEMBLY", $list);
    print STDOUT "Creating table READS2ASSEMBLY ..." if ($list);
    $dbh->do(qq[CREATE TABLE READS2ASSEMBLY(
             read_id          MEDIUMINT      UNSIGNED NOT NULL PRIMARY KEY,
             assembly         TINYINT        UNSIGNED NOT NULL,
             astatus          ENUM ('0','1','2')    DEFAULT '0'
         )]);
    print STDOUT "... DONE!\n" if ($list);

    print STDOUT "Building index on assembly ...\n" if ($list);
    $dbh->do(qq[CREATE INDEX bin_index ON READS2ASSEMBLY (assembly)]);
    print STDOUT "Index BIN_INDEX ON READS2ASSEMBLY ... DONE\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table READS2ASSEMBLY 

=head2 Synopsis

Allocation of reads to an assembly (by number)

Table is populated/updated by both reads-loading and assembly-loading scripts

=head2 Scripts & Modules

=over 4

=item rloader (I<script>)

=item cloader (I<script>)

=back

=head2 Description of columns:

=over 8

=item read_id

number of read in READS table

=item assembly 

number of assembly in ASSEMBLY table

=item astatus 

flag for the status of a read in the assembly

=over 16

=item  0 for read in bin of the assembly (unallocated read) 

=item  1 for soft allocation,  e.g. temporarilly by finisher

=item  2 for firm (permanent) allocation in a contig 

=back

astatus > 0 for a locked read

=head2 Linked Tables

=over 4

=item READS on key read_id

=item ASSEMBLY on key assembly

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CONTIGS {
    my ($dbh, $list) = @_;


    &dropTable ($dbh,"CONTIGS", $list);
    print STDOUT "Creating table CONTIGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS(
             contig_id        MEDIUMINT UNSIGNED       NOT NULL AUTO_INCREMENT PRIMARY KEY,
             contigname       VARCHAR(32)              NOT NULL,
             aliasname        VARCHAR(32)              NOT NULL,
             length           INT                     DEFAULT 0,
             ncntgs           SMALLINT  UNSIGNED       NOT NULL,
             nreads           MEDIUMINT UNSIGNED       NOT NULL,
             newreads         MEDIUMINT                NOT NULL,
             cover            FLOAT(8,2)              DEFAULT '0.00',      
             origin           ENUM ('Arcturus CAF parser','Finishing Software','Other')  NULL,
             userid           VARCHAR(8)              DEFAULT 'arcturus',
             updated          DATETIME                 NOT NULL
         )]);
    print STDOUT "... DONE!\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table CONTIGS

=head2 Synopsis

Primary Data table, static

Populated by the assembly loading script

=head2 Scripts & Modules

=over 4

=item cloader

(I<script>) entering contig data from CAF files;

=item ContigBuilder.pm 

=back 

=head2 Description of columns:

=over 11

=item contig_id    

auto-incremented primary key (foreign key in many other tables)

=item contigname 

unique Arcturus contig name, built-up from first and last
readname, length and coverage; about 30 characters (usually) 

=item aliasname

other name to indicate the contig, for example the (non-unique) name used
in CAF files or a phrap name

=item length

number of bases

=item ncntgs

number of previous contigs merged into this contig (=0 for first generation)

=item nreads

number of assembled reads

=item newreads

number of reads appearing for the first time in the assembly (can be negative
for deallocated reads)

=item cover

average cover of contig by reads, equals (sumtotal readlength)/length

=item origin 

software used to build contig

=item userid

userid of contig creator to or the user last to access

=item updated

creation date

=back

=head2 Linked Tables on key contig_id

=over 4

=item READS2CONTIG

=item CONTIGS2CONTIG

=item CONTIG2SCAFFOLD

=item CLONES2CONTIG

=item TAGS2CONTIG

=item GENE2CONTIG

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CONSENSUS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CONSENSUS", $list);
    print STDOUT "Creating table CONSENSUS ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONSENSUS(
             contig_id       MEDIUMINT UNSIGNED        NOT NULL PRIMARY KEY,
             sequence        LONGBLOB                  NOT NULL,
             quality         LONGBLOB                  NOT NULL,
             length          INT                       DEFAULT 0
         ) type = MyISAM ]);
    print STDOUT "... DONE!\n" if ($list);
}
#?             reverse_id      MEDIUMINT UNSIGNED        DEFAULT 0
#--------------------------- documentation --------------------------
=pod

=head1 Table CONSENSUS

=head2 Synopsis

Dictionary table to CONTIGS with consensus sequence

Populated by the assembly loading software

=head2 Scripts & Modules

=over 4

=item cloader

(I<script>) entering contig data from CAF files;

=item (DH java script)

=item ContigBuilder.pm

=back

=head2 Description of columns:

=over 8

=item contig_id

number of contig in CONTIGS table

=item sequence

consensus sequence (Z-compressed)

=item quality

consensus quality (Z-compressed)

=back

=head2 Linked Tables

=over 4

=item CONTIGS on keys contig_id

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CONTIGS2CONTIG {
    my ($dbh, $list) = @_;

# contig to contig mapping implicitly contains the history

# generation : of the newly added contig / generation of first occurance gofo REPLACE by genofo
#       NOTE : duplicates READS2CONTIG info, but facilitates various shortcuts in generation upgrade No, not so
# newcontig  : contig id
# nranges    : starting point in new contig
# nrangef    : implicit in the above
# oldcontig  : contig id
# oranges    : starting point in old contig
# orangef    : end point in old contig

    &dropTable ($dbh,"CONTIGS2CONTIG", $list);
    print STDOUT "Creating table CONTIGS2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS2CONTIG(
             genofo           SMALLINT  UNSIGNED DEFAULT 0,
             newcontig        MEDIUMINT UNSIGNED  NOT NULL,
             nranges          INT                DEFAULT 0,
             nrangef          INT                DEFAULT 0,
             oldcontig        MEDIUMINT UNSIGNED  NOT NULL,
             oranges          INT                DEFAULT 0,
             orangef          INT                DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table CONTIGS2CONTIG

=head2 Synopsis

contig to contig mapping, which implicitly contains the history of the assembly

populated by assembly-loading scripts

=head2 Scripts & Modules

=over 4

=item cloader

=item ContigBuilder.pm

=back

=head2 Description of columns

=over 8

=item genofo

assembly generation of first occurrence, incremented after each new assembly

=item newcontig

contig ID of the new generation

=item nranges

begin position of the mapping on the new contig

=item nrangef

end position of the mapping on the new contig

=item oldcontig

contig ID of the old, i.e. previous generation

=item oranges

begin position of the mapping on the old contig

=item orangef

end position of the mapping on the old contig

=back

=head2 Linked Tables

=over 4

=item CONTIGS on keys oldcontig & newcontig

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CONTIGS2PROJECT {
    my ($dbh, $list) = @_;

# assign scaffolds (groups of one or more contigs) to projects and assemblies

# contig_id
# project   : reference to PROJECT.project number
# check flag for blocking

    &dropTable ($dbh,"CONTIGS2PROJECT", $list);
    print STDOUT "Creating table CONTIGS2PROJECT ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS2PROJECT(
             contig_id        MEDIUMINT          UNSIGNED NOT NULL PRIMARY KEY,
             checked          ENUM ('in','out')  DEFAULT 'in',
             project          SMALLINT           UNSIGNED NOT NULL
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------
#*********************************************************************************************************

sub create_CONTIGS2SCAFFOLD {
    my ($dbh, $list) = @_;

# assign contigs to scaffolds
# contig_id   : (unique) contig identifier
# scaffold    : scaffold id  number
# orientation : Forward, Reverse or Unknown
# ordering    : ordering sequence of contig in scaffold
# assembly    : reference to ASSEMBLY.assembly number (replicates info in project)
# astatus     : assembly status: 
#               N not allocated (should not occur except as transitory status)
#               C current generation (origin in CONTIGS.origin)
#               S contig is superseded by later one (i.e previous generation)
#               X locked status (includes transport status); locked by last
#                 user to access in CONTIGS.userid

    &dropTable ($dbh,"CONTIGS2SCAFFOLD", $list);
    print STDOUT "Creating table CONTIGS2SCAFFOLD ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS2SCAFFOLD(
             contig_id        MEDIUMINT          UNSIGNED NOT NULL PRIMARY KEY,
             scaffold         SMALLINT           UNSIGNED NOT NULL,
             orientation      ENUM ('F','R','U')       DEFAULT 'U',
             ordering         SMALLINT           UNSIGNED NOT NULL,
             zeropoint        INT                        DEFAULT 0,
             assembly         SMALLINT           UNSIGNED NOT NULL,
             astatus          ENUM ('N','C','S','X')   DEFAULT 'N'
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..


=item zeropoint

integer zeropoint of contig in assembly

=cut
#--------------------------------------------------------------------

sub create_ASSEMBLY {
    my ($dbh, $list) = @_;

# Assembly Number
# Assembly Name (possibly standardized, taken from Oracle?)
# Alias name (e.g. for projects from outside)
## to be removed # Organism: REFerence to organism table (refered to in amanager and create)
# chromosome: 0 for blob; 1-99 nr of a chromosome; 100 for other; > 100 e.g. plasmid
# Origin of DNA sequences (Sanger for in-house; any other name for outside sources)
# oracle project: the oracle project number of this assembly, if any
# size    : approxinmate length (kBase) of assembly, estimated e.g. from physical maps
# length  : actual length (base) measured from contigs
# Number of Reads stored
# Number of Reads assembled in latest assembly
# Number of Contigs stored  in latest assembly
# Number of all Contigs (in assembly history) 
# Number of Projects
# progress: status of data collection
# updated : date of last modification (time of last assembly)
# userid  : user (authorized or from USERS2PROJECT list last accessed/modified the project
# status  : status of assembly ('loading' if generation 0 in progress, 'completed' if generation
#           1 is the lowest generation; changes through each loading cycle)
# created : date of creation
# creator : reference to nr in USERS table
# attributes : any info (maybe used by ARCTURS scripts)

    &dropTable ($dbh,"ASSEMBLY", $list);
    print STDOUT "Creating table ASSEMBLY ..." if ($list);
    $dbh->do(qq[CREATE TABLE ASSEMBLY(
             assembly         SMALLINT UNSIGNED     NOT NULL AUTO_INCREMENT PRIMARY KEY,
             assemblyname     VARCHAR(16)           NOT NULL,
             organism         SMALLINT UNSIGNED     NOT NULL,
             chromosome       TINYINT  UNSIGNED  DEFAULT   0,
             origin           VARCHAR(32)           NOT NULL DEFAULT "The Sanger Institute",
             oracleproject    TINYINT  UNSIGNED  DEFAULT   0,
             size             MEDIUMINT UNSIGNED   DEFAULT 0,
             length           INT UNSIGNED         DEFAULT 0,
             l2000            INT UNSIGNED         DEFAULT 0,
             reads            INT UNSIGNED         DEFAULT 0,
             assembled        INT UNSIGNED         DEFAULT 0,
             contigs          INT UNSIGNED         DEFAULT 0,
             allcontigs       INT UNSIGNED         DEFAULT 0,
             projects         SMALLINT             DEFAULT 0,
             progress         ENUM ('in shotgun','in finishing','finished','other') DEFAULT 'other', 
             updated          DATETIME                  NULL,
             userid           CHAR(8)                   NULL,
             status           ENUM ('loading','complete','error','virgin','unknown') DEFAULT 'virgin', 
             created          DATETIME              NOT NULL,
	     creator          CHAR(8)               NOT NULL DEFAULT "oper",
             attributes       BLOB                      NULL,
             comment          VARCHAR(255)              NULL,             
             CONSTRAINT ASSEMBLYNAMEUNIQUE UNIQUE (ASSEMBLYNAME)  
	    )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------
#*********************************************************************************************************

sub create_PROJECTS {
    my ($dbh, $list) = @_;

# Project Number
# Project Name (possibly standardized, taken from Oracle?)
# Assembly: reference to assembly
# Number of Reads
# Number of Contigs 
# userid  user (authorized or from USERS2PROJECT list last accessed/modified the project
# creator or Principal Investigator: reference to nr in USERS table
# Date/Time of last modification
# status (last status or action on the project)
# attributes (e.g. GAP databases for contigs etc.)
# comment
# note : to be added ? 'access' 0,1 for read-only or read and write
# Note : privileges also dealt via 'assembly' and peopletoproject 

    &dropTable ($dbh,"PROJECTS", $list);
    print STDOUT "Creating table PROJECTS ..." if ($list);
    $dbh->do(qq[CREATE TABLE PROJECTS(
             project        SMALLINT UNSIGNED     NOT NULL AUTO_INCREMENT PRIMARY KEY,
             projectname    VARCHAR(24)           NOT NULL,
             projecttype    ENUM ("Finishing","Annotation","Comparative Sequencing","Bin","Other") DEFAULT "Bin",
             assembly       TINYINT  UNSIGNED    DEFAULT 0,
             reads          INT UNSIGNED         DEFAULT 0,
             contigs        INT UNSIGNED         DEFAULT 0,
             updated        DATETIME                  NULL,
             userid         CHAR(8)                   NULL,
             created        DATETIME                  NULL,
	     creator        CHAR(8)               NOT NULL DEFAULT "oper",
             attributes     BLOB                      NULL,
             comment        VARCHAR(255)              NULL,             
             status         ENUM ("Dormant","Active","Completed","Merged") DEFAULT "Dormant",
             CONSTRAINT PROJECTNAMEUNIQUE UNIQUE (PROJECTNAME)  
	    )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_USERS2PROJECTS {
    my ($dbh, $list) = @_;
 
#

    &dropTable ($dbh,"USERS2PROJECTS", $list);
    print STDOUT "Creating table USERS2PROJECTS ..." if ($list);
    $dbh->do(qq[CREATE TABLE USERS2PROJECTS(
             userid           CHAR(8)              NOT NULL,
             project          SMALLINT UNSIGNED    NOT NULL,
             date_from        DATE                     NULL,
             date_end         DATE                     NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------


#******************************************************************
# TAGS related tables STSTags, TAGS2CONTIG, GAP4TAGS, CLONEMAP
# > GAP4TAGS deals with GAP4 tags (user tags and automatically added)
# > STSTAGS & TAGS2CONTIG to be built with script on *.ststmap and *sts.fas
# > CLONEMAP to be built with script on *.physmap
#******************************************************************
# tagname    : 4 character string of name of TAG as used in 
#              /usr/local/badger/staden/tables/TAGDB 
# taglabel   : arbitrary label with comment by finisher (<= 255)
# deprecated : allow erasing but keep in database

sub create_GAP4TAGS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"GAP4TAGS", $list);
    print STDOUT "Creating table GAP4TAGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE GAP4TAGS(
             tag_id           MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             tagname          CHAR(4)              NOT NULL,
             taglabel         VARCHAR(255)         NOT NULL,
             deprecated       ENUM ('N','Y','X') DEFAULT 'N'
          ) AUTO_INCREMENT = 20000001 ]);
    print STDOUT "... DONE!\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------
#******************************************************************
# tag_id    : number 
# tagname   : sts file tag name
# sequence  : DNA sequence or encoded sequence
#             note: sequence can be either one continuous string
#             or two end sections separated by an unknown centre
# scompress : 0 for none, 1 for triplets, 2 for Huffman etc
# slength   : sequence length
# position  : (approximate) relative position of tag 
# linkage   : linkage group number
# assembly  : "chromosome" on which the tag is SUPPOSED to reside

# tap_start : (actual) position of tag in assembly
#             tap_start        INT UNSIGNED         NOT NULL,
#             tap_final        INT UNSIGNED         NOT NULL,

sub create_STSTAGS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"STSTAGS", $list);
    print STDOUT "Creating table STSTAGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE STSTAGS(
             tag_id           MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             tagname          CHAR(6)              NOT NULL,
             sequence         BLOB                 NOT NULL,
             scompress        TINYINT  UNSIGNED    NOT NULL,
             slength          SMALLINT UNSIGNED    NOT NULL,
             position         FLOAT                    NULL,
             linkage          SMALLINT UNSIGNED    NOT NULL,
             assembly         TINYINT  UNSIGNED    NOT NULL,
             CONSTRAINT TAGNAMEUNIQUE UNIQUE (TAGNAME)  
	  ) AUTO_INCREMENT = 10000001 ]);
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************
# tag_id     : number 
# tagname    : marker
# identifier : sequence name / source info
# sequence  : DNA sequence or encoded sequence
#             note: sequence can be either one continuous string
#             or two end sections separated by an unknown centre
# scompress : 0 for none, 1 for triplets, 2 for Huffman etc
# slength   : sequence length
# position  : (approximate, absolute) position of tag in its assembly
# assembly  : "chromosome" on which the tag resides (update with version)
# comment   : anything else

# changed   : (status) change of chromosome, change of linkage group, etc ...

# tap_start : (actual) position of tag in assembly
#             tap_start        INT UNSIGNED         NOT NULL,
#             tap_final        INT UNSIGNED         NOT NULL,

sub create_HAPPYTAGS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"HAPPYTAGS", $list);
    print STDOUT "Creating table HAPPYTAGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE HAPPYTAGS(
             tag_id           MEDIUMINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             tagname          VARCHAR(6)           NOT NULL,
             identifier       VARCHAR(32)          NOT NULL, 
             sequence         BLOB                 NOT NULL,
             scompress        TINYINT  UNSIGNED    NOT NULL,
             slength          SMALLINT UNSIGNED    NOT NULL,
             position         FLOAT                    NULL,
             assembly         TINYINT  UNSIGNED    NOT NULL,
             comment          TINYBLOB                 NULL  
	  ) AUTO_INCREMENT = 30000001 ]);
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************

# version   : 0 for latest version
# linkage   : (initial) linkage group number (preliminary?)
# position  : relative position of tag in its linkage group
# quality   : lod uniqueness of matches per marker ?
# assembly  : "chromosome" on which the tag is SUPPOSED to reside

sub create_HAPPYMAP {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"HAPPYMAP", $list);
    print STDOUT "Creating table HAPPYMAP ..." if ($list);
    $dbh->do(qq[CREATE TABLE HAPPYMAP(
             tag_id           MEDIUMINT UNSIGNED   NOT NULL,
             version          TINYINT  UNSIGNED    NOT NULL,
             position         FLOAT                    NULL,
             assembly         TINYINT  UNSIGNED    NOT NULL,
             linkage          SMALLINT UNSIGNED    NOT NULL,
             quality          FLOAT                    NULL
	  )]);
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************
# tag_id    : reference to a TAGS table;
#? tag_type  :
# contig_id : reference to CONTIGS table
# tcp_start : tag contig start position
# tcp_final : tag contig final position (could be < tcp_start)

sub create_TAGS2CONTIG {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"TAGS2CONTIG", $list);
    print STDOUT "Creating table TAGS2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE TAGS2CONTIG(
             tag_id           MEDIUMINT UNSIGNED   NOT NULL,
             contig_id        MEDIUMINT UNSIGNED   NOT NULL,
             tcp_start        INT UNSIGNED         NOT NULL,
             tcp_final        INT UNSIGNED         NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************
# tagname     : unique tag identifier 
# tagstatus   : Fluid (preliminary allocation) Permanent (set by annotators) 
# contig_id   : reference to CONTIGS table, contig of current generation (updated)
# tcp_start   : tag contig start position                                (updated)
# tcp_final   : tag contig final position                                (updated)
# orientation : Forward, Reverse or Unknown                              (updated)
# cid_first   : contig_id in which tag was first allocated
# updated     : flag set to signal change by non-GeneDB user (True,False) or deprecated (D)
# attributes  : allows e.g. comments or history info 
# 'updated' items are to be updated after each new assembly

sub create_GENE2CONTIG {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"GENE2CONTIG", $list);
    print STDOUT "Creating table GENE2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE GENE2CONTIG(
             tagname          VARCHAR(24) BINARY   NOT NULL PRIMARY KEY,
             tagstatus        ENUM('F','P','U')    DEFAULT 'U',
             contig_id        MEDIUMINT UNSIGNED   NOT NULL,
             tcp_start        INT UNSIGNED         NOT NULL,
             tcp_final        INT UNSIGNED         NOT NULL,
             orientation      ENUM('F','R','U')    DEFAULT 'U',
             cid_first        MEDIUMINT UNSIGNED   NOT NULL,
             updated          ENUM('T','F','D')    DEFAULT 'T',             
             attributes       BLOB                     NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************
# clonename  : (NOT ref to CLONES because clone may not yet be in it 
# assembly   : REF to ASSEMBLY
# cpkbstart  : approximate clone position start in kilobase
# cpkbfinal  : approximate clone position  end  in kilobase

# note: the clone name should also appear in the CLONES table
# should the loading script only process the clones in CLONES? YES

sub create_CLONEMAP {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONEMAP", $list);
    print STDOUT "Creating table CLONEMAP ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONEMAP(
             clonename         VARCHAR(20)          NOT NULL PRIMARY KEY,
             assembly          TINYINT UNSIGNED     NOT NULL,
             cpkbstart         MEDIUMINT UNSIGNED   NOT NULL,
             cpkbfinal         MEDIUMINT UNSIGNED   NOT NULL,
             CONSTRAINT CLONENAMEUNIQUE UNIQUE (CLONENAME)
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************
# ocp_start : observed clone position start in base (to updated during assembly process)
# ocp_final : observed clone position  end  in base
# The position of the clone in the assembly is given by: CONTIG.zeropoint + ocp_start
# reads     : the number of reads in the covered part of the contig
# cover     : average cover by clone (total read length devided by contig section)

sub create_CLONES2CONTIG {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONES2CONTIG", $list);
    print STDOUT "Creating table CLONES2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONES2CONTIG(
             clone_id         SMALLINT UNSIGNED    NOT NULL,
             contig_id        MEDIUMINT UNSIGNED   NOT NULL,
             ocp_start        INT UNSIGNED         NOT NULL,
             ocp_final        INT UNSIGNED         NOT NULL,
             reads            MEDIUMINT            NOT NULL,
             cover            FLOAT                NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut

##########################################################################################
##########################################################################################
#
# DICTIONARY TABLES
#
##########################################################################################
##########################################################################################

sub create_CHEMISTRY {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CHEMISTRY", $list);
    print STDOUT "Creating table CHEMISTRY ..." if ($list);
    $dbh->do(qq[CREATE TABLE CHEMISTRY(
             chemistry        SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             identifier       VARCHAR(32)        NOT NULL,
             chemtype         CHAR(1)                NULL,
             counted          INT UNSIGNED       DEFAULT 0  
     	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_STRANDS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"STRANDS", $list);
    print STDOUT "Creating table STRANDS ..." if ($list);
    $dbh->do(qq[CREATE TABLE STRANDS(
             strand           CHAR(1)                              NOT NULL PRIMARY KEY,
             strands          ENUM ('1','2')                           NULL,
             direction        ENUM ('forward','reverse','unknown') DEFAULT 'unknown',
             description      VARCHAR(48)                          NOT NULL, 
             counted          INT UNSIGNED                         DEFAULT 0
	    )]);
    print STDOUT "... loading ..." if ($list);
    my %strands = (
               'a','forward strand, assumed double',
               'b','reverse strand, assumed double',
               'p','Puc double strand forward',
               'q','Puc double strand reverse',
               's','strand of M13 forward',
               'f','strand of M13 PCR forward',
               'r','strand of M13 PCR reverse',
               'w','any walk off a custom PCR product',
               't','Puc template PCR forward',
               'u','Puc template PCR reverse',
               'x','unspecified single strand',
               'y','unspecified double strand',
               'z','unknown, assumed single strand');

    foreach my $key (keys (%strands)) {
        my $strands = 1; $strands++  if ($key =~ /[abpqy]/);
        my $sth = $dbh->prepare ("INSERT INTO STRANDS (strand,description,strands) "
                                  . "VALUES (\'$key\',\'$strands{$key}\', $strands)");
        $sth->execute();
        $sth->finish();
        $dbh->do("update STRANDS set direction='forward' where description like '%forward%'");
        $dbh->do("update STRANDS set direction='reverse' where description like '%reverse%'");
    }
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_PRIMERTYPES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"PRIMERTYPES", $list);
    print STDOUT "Creating table PRIMERTYPES ..." if ($list);
    $dbh->do(qq[CREATE TABLE PRIMERTYPES(
             primer      SMALLINT                    NOT NULL AUTO_INCREMENT PRIMARY KEY,
             type        ENUM ('universal','custom')     NULL,
             description VARCHAR(48)                 NOT NULL, 
             counted     INT UNSIGNED                DEFAULT 0
	 )]);
    print STDOUT "... loading ..." if ($list);
    my %primers = (
               '1' , 'Forward from beginning of insert',
               '2' , 'Reverse from end of insert',
               '3' , 'Forward custom primer (unspecified)',
               '4' , 'Reverse custom primer (unspecified)',
               '5' , 'Undefined');

    foreach my $key (sort keys (%primers)) {
        my $sth = $dbh->prepare ("INSERT INTO PRIMERTYPES (primer,description) "
                                . "VALUES ($key,\'$primers{$key}\')");
        $sth->execute();
        $sth->finish();
    }
    $dbh->do("update PRIMERTYPES set type='universal' where description like '% from %'");
    $dbh->do("update PRIMERTYPES set type='custom'  where description like '% custom %'");
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_BASECALLER {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"BASECALLER", $list);
    print STDOUT "Creating table BASECALLER ..." if ($list);
    $dbh->do(qq[CREATE TABLE BASECALLER(
             basecaller       SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             name             VARCHAR(32)        NOT NULL, 
             counted          INT UNSIGNED       DEFAULT 0
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_SEQUENCEVECTORS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"SEQUENCEVECTORS", $list);
    print STDOUT "Creating table SEQUENCEVECTORS ..." if ($list);
    $dbh->do(qq[CREATE TABLE SEQUENCEVECTORS(
             svector          TINYINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             name             VARCHAR(20)        NOT NULL,
             vector           TINYINT UNSIGNED  DEFAULT 0,
             counted          INT UNSIGNED      DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_CLONINGVECTORS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONINGVECTORS", $list);
    print STDOUT "Creating table CLONINGVECTORS ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONINGVECTORS(
             cvector          TINYINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             name             VARCHAR(16)        NOT NULL,
             vector           TINYINT UNSIGNED  DEFAULT 0,
             counted          INT UNSIGNED      DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CLONES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONES", $list);
    print STDOUT "Creating table CLONES ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONES(
             clone            SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             clonename        VARCHAR(20)        NOT NULL,
             clonetype        ENUM ('PUC finishing','PCR product' ,'unknown') DEFAULT 'unknown',
             library          ENUM ('transposition','small insert','unknown') DEFAULT 'unknown',
             origin           VARCHAR(20)        DEFAULT 'The Sanger Institute',
             counted          MEDIUMINT UNSIGNED DEFAULT 0
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_CLONES2PROJECT {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONES2PROJECT", $list);
    print STDOUT "Creating table CLONES2PROJECT ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONES2PROJECT(
             clone       SMALLINT UNSIGNED    NOT NULL,
             project     SMALLINT UNSIGNED    NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
 }
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_STATUS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"STATUS", $list);
    print STDOUT "Creating table STATUS ..." if ($list);
    $dbh->do(qq[CREATE TABLE STATUS(
             status           SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             identifier       VARCHAR(64)            NULL,
             comment          VARCHAR(8)             NULL,
             counted          INT UNSIGNED       DEFAULT 0
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut

#*********************************************************************************************************

sub create_LIGATIONS {
    my ($dbh, $list) = @_;

# silow, sihigh: SV insertion length
# origin: O for Oracle, R for reads, F for foreign; U for unidentified

    &dropTable ($dbh,"LIGATIONS", $list);
    print STDOUT "Creating table LIGATIONS ..." if ($list);
    $dbh->do(qq[CREATE TABLE LIGATIONS(
             ligation         SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             identifier       VARCHAR(20)        NOT NULL,
             clone            VARCHAR(20)        NOT NULL,
             origin           CHAR(1)                NULL,
             silow            MEDIUMINT UNSIGNED     NULL,
             sihigh           MEDIUMINT UNSIGNED     NULL,
             svector          SMALLINT           NOT NULL,
             counted          INT UNSIGNED       DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ..

=head2 Synopsis

=head2 Scripts & Modules

=head2 Description of columns:

=head2 Linked Tables on key ..

=cut

#################################################################################################
#################################################################################################
#
# TABLES OF THE COMMON DATABASE
#
#################################################################################################
#################################################################################################

sub create_READMODEL {
    my ($dbh, $list) = @_;

    &dropTable($dbh,"READMODEL", $list);
    print STDOUT "Creating table READMODEL ..." if ($list);
    $dbh->do(qq[CREATE TABLE READMODEL(
             item          CHAR(3)     NOT NULL PRIMARY KEY,
             column_name   CHAR(16)    NOT NULL,
             description   VARCHAR(64)     NULL,
             comment       VARCHAR(64)     NULL
	 )]);
    print STDOUT "... loading ..." if ($list);
    my @layoutsb = (
       'RN','ID','DT','CN','TN','ST','PR','CH','BC','DR','SLN','SQ','SCM','AV',
       'LG','QCM','QL','QR','SV','SC','SP','SL','SR','CV','CL','CR','PS','RPS','CC');

    my %layoutcn = (
       'RN'  ,   'read_id',  'ID' ,   'readname', 'DT' ,      'date',  'LG' ,  'ligation',
       'CN'  ,     'clone',  'TN' ,   'template', 'ST' ,    'strand',  'PR' ,    'primer',
       'CH'  , 'chemistry',  'BC' , 'basecaller', 'DR' , 'direction', 'SLN' ,   'slength',
       'SQ'  ,  'sequence', 'SCM' ,  'scompress', 'AV' ,   'quality', 'QCM' , 'qcompress',
       'QL'  ,    'lqleft',  'QR' ,    'lqright', 'SV' ,   'svector',  'SC' ,   'svcsite',
       'SP'  ,   'svpsite',  'SL' ,     'svleft', 'SR' ,   'svright',  'CV' ,   'cvector',
       'CL'  ,    'cvleft',  'CR' ,    'cvright', 'PS' ,   'pstatus', 'RPS' ,   'rstatus',
       'CC'  ,   'comment');

    my %layoutdc = (
                'RN' , '(unified) read_id number ',
                'ID' , 'Sanger standard file name',
                'DT' , 'Date',
                'LG' , 'REF to LIGATION table by number',
                'CN' , 'REF to CLONES table by number',
                'TN' , 'Template Name',
                'ST' , 'REF to STRANDS table by character id',
                'PR' , 'REF to PRIMERS table by number',
                'CH' , 'REF to CHEMISTRY table by number',
                'BC' , 'REF to BASECALLER table by number',
                'DR' , 'Direction of Read',
               'SLN' , 'Length of sequence stored',
                'SQ' , 'the DNA sequence (compressed)',
               'SCM' , 'compression method for DNA (0, 1, 2, 3)',
                'AV' , 'Accuracy values; Quality Data',
               'QCM' , 'compression method for AV data (0, 1, 2, 3)',
                'QL' , 'low quality left',
                'QR' , 'low quality right',
                'SV' , 'Sequence Vector; REF to VECTORS table by number',
                'SC' , 'Sequence Vector Cloning Site',
                'SP' , 'Sequence Vector Primer Site',
                'SL' , 'Sequence vector present at left',
                'SR' , 'Sequence vector present at right',
                'CV' , 'Cloning Vector;  REF to VECTORS table by number',
                'CL' , 'Cloning vector last base',
                'CR' , 'Cloning vector first base',
                'PS' , 'Processing Status; REF to STATUS table by number',
                'CC' , 'Comment, any text up to 255 characters',
               'RPS' , 'Read-parsing Status, 16 bit pattern');

    my %layoutcc = (
                'RN' , 'In order of entry',
                'BC' , '(only one in use now)',
                'PR' , 'current values in use: 1, 2',
                'DR' , 'either +, - or undefined',
               'SCM' , '1 for triads, 2 for Huffman, 3 for gzip',
               'QCM' , '1 for triads, 2 for Huffman, 3 for gzip',
                'QL' , '[ 1-QL] to be ignored',
                'QR' , '[QR-end] to be ignored',
                'SV' , 'Built on the fly from SV and SF',
                'CV' , 'Built on the fly from CV and CF',
                'SL' , 'position  1-SL', 
                'SR' , 'position SR-end',
                'CL' , 'currently from CS range',
                'CR' , 'currently from CS range',
                'CC' , 'sometimes contains SVEC range, if info in SL or SR, ignore',
               'RPS' , 'Encode load-time warnings');

    foreach my $key (@layoutsb) {
      if ($layoutcn{$key}) {
        my $sth = $dbh->prepare ("INSERT INTO READMODEL (item,column_name) "
                              . "VALUES (\'$key\',\'$layoutcn{$key}\')");
        $sth->execute();
        $sth->finish();
      }
      if ($layoutdc{$key}) {
        my $sth = $dbh->prepare ("UPDATE READMODEL set description = "
                                 . "\'$layoutdc{$key}\' WHERE item = \'$key\'");
        $sth->execute();
        $sth->finish();
      }
      if ($layoutcc{$key}) {
        my $sth = $dbh->prepare ("UPDATE READMODEL set comment = "
                                 . "\'$layoutcc{$key}\' WHERE item = \'$key\'");
        $sth->execute();
        $sth->finish();
      }
    }

    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table READMODEL

=head2 Synopsis

=head2 Scripts & Modules

=over 4

=item ReadsReader.pm

=back

=head2 Description of columns:

=cut

#*********************************************************************************************************

sub create_DATAMODEL {
    my ($dbh, $list) = @_;

# describes relations between tables in database
# column "tcolumn" in table "tablename" connects to "lcolumn" in "linktable"

    &dropTable ($dbh,"DATAMODEL", $list);
    print STDOUT "Creating table DATAMODEL ..." if ($list);
    $dbh->do(qq[CREATE TABLE DATAMODEL(
             tablename     VARCHAR(16)           NOT NULL,
             tcolumn       VARCHAR(16)           NOT NULL,
             linktable     VARCHAR(16)           NOT NULL, 
             lcolumn       VARCHAR(32)           NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);

    my @input = ('READEDITS          read_id             READS     read_id',
                 'READTAGS           read_id             READS     read_id',
                 'READS2CONTIG         clone            CLONES       clone',
                 'READS2CONTIG      assembly          ASSEMBLY    assembly',
                 'READS2CONTIG       read_id             READS     read_id',
                 'READS2CONTIG     contig_id           CONTIGS   contig_id', # ? /contigname/aliasname',
                 'READS2CONTIG     contig_id  CONTIGS2SCAFFOLD   contig_id',
                 'READS2ASSEMBLY     read_id             READS     read_id',
#                 'READS2ASSEMBLY    assembly          ASSEMBLY    assembly',
#                 'USERS               userid    USERS2PROJECTS      userid',
                 'USERS2PROJECTS      userid             USERS      userid',
                 'USERS2PROJECTS     project          PROJECTS     project',
                 'CONTIGS          contig_id      READS2CONTIG   contig_id',
                 'CONTIGS             userid             USERS      userid',
#                 'CONTIGS          contig_id       TAGS2CONTIG   contig_id',
                 'CONTIGS          contig_id       TAGS2CONTIG   contig_id',
                 'CONTIGS          contig_id         CONSENSUS   contig_id',
                 'TAGS2CONTIG      contig_id           CONTIGS   contig_id',
                 'GENE2CONTIG      contig_id           CONTIGS   contig_id',
                 'TAGS2CONTIG         tag_id           STSTAGS      tag_id',
                 'STSTAGS             tag_id       TAGS2CONTIG      tag_id',
                 'TAGS2CONTIG         tag_id         HAPPYTAGS      tag_id',
                 'HAPPYTAGS           tag_id       TAGS2CONTIG      tag_id',
                 'HAPPYMAP            tag_id         HAPPYTAGS      tag_id',
                 'TAGS2CONTIG         tag_id          GAP4TAGS      tag_id',
                 'GAP4TAGS            tag_id       TAGS2CONTIG      tag_id',
                 'ASSEMBLY          assembly          CLONEMAP    assembly',
                 'CLONES               clone      READS2CONTIG       clone',
                 'CLONEMAP          assembly          ASSEMBLY    assembly',
                 'CONTIGS2CONTIG   oldcontig           CONTIGS   contig_id',
                 'CONTIGS2CONTIG   newcontig           CONTIGS   contig_id',
#                 'CONTIGS2CONTIG   oldcontig  CONTIGS2SCAFFOLD   contig_id',
                 'CONTIGS2SCAFFOLD contig_id           CONTIGS   contig_id',
                 'CONTIGS2PROJECT  contig_id           CONTIGS   contig_id',
                 'CONTIGS          contig_id   CONTIGS2PROJECT   contig_id',
                 'CONTIGS          contig_id  CONTIGS2SCAFFOLD   contig_id',
                 'LIGATIONS          svector   SEQUENCEVECTORS     svector',
                 'CHEMISTRY         chemtype         CHEMTYPES    chemtype/description',
                 'SEQUENCEVECTORS     vector           VECTORS      vector',
                 'CLONINGVECTORS      vector           VECTORS      vector',
                 'CLONES2PROJECT       clone            CLONES       clone',
                 'CLONES2PROJECT     project          PROJECTS     project',
                 'PROJECTS           project    CLONES2PROJECT     project',
                 'PROJECTS           project    USERS2PROJECTS     project',
                 'PROJECTS          assembly          ASSEMBLY    assembly',
                 'PROJECTS            userid             USERS      userid',
                 'PROJECTS           creator             USERS      userid',
                 'ASSEMBLY          organism         ORGANISMS    organism',
                 'ASSEMBLY            userid             USERS      userid',
                 'ASSEMBLY           creator             USERS      userid',
                 'ASSEMBLY          assembly    READS2CONTIG      assembly',
#                 'SESSIONS            userid            USERS      userid',
                 'READS              read_id     READS2CONTIG      read_id',
                 'READS              read_id   READS2ASSEMBLY      read_id',
                 'READS              read_id        READEDITS      read_id',
#                 'READS              read_id              DNA      read_id',
                 'READS             ligation        LIGATIONS    ligation/identifier ',
                 'READS                clone           CLONES       clone/clonename  ',
                 'READS               strand          STRANDS      strand/description',
                 'READS               primer      PRIMERTYPES      primer/description',
                 'READS            chemistry        CHEMISTRY   chemistry/identifier/chemtype',
                 'READS           basecaller       BASECALLER  basecaller/name       ',
                 'READS              svector  SEQUENCEVECTORS     svector/name       ',
                 'READS              cvector   CLONINGVECTORS     cvector/name       ',
#                 'READS              comment          COMMENT      comment',
#                 'READS             template         TEMPLATE     template', # ?  template/ligation',
                 'READS              pstatus           STATUS      status/identifier');

    foreach my $line (@input) {
        my ($f1, $f2, $f3, $f4) = split /\s+/,$line;
        $dbh->do("insert into DATAMODEL (tablename,tcolumn,linktable,lcolumn) ".
                 "values (\"$f1\", \"$f2\", \"$f3\", \"$f4\")");
    }
}
#--------------------------- documentation --------------------------
=pod

=head1 Table DATAMODEL

=head2 Synopsis

representation of database schema I<in lieu> of foreign keys

used by ArcturusTable module to autoVivify linked tables and
dynamically generate SQL query joins over several tables

=head2 Scripts & Modules

=over 4

=item ArcturusTable

=back

=head2 Description of columns:

=over 8

=item tablename

the parent table

=item tcolumn

column of table I<tablename> acting as target key

=item linktable

table linked to table I<tablename> on foreign key I<lcolumn>                                                                                                             
=item lcolumn

the foreign key

more than one column can be specified as: lcolumn1/lcolumn2/lcolumn3;
in that case, the first column must be the foreign key proper, while the
other entries act as alternate column names for possible use in a join
(re: DbaseTable traceQuery method)

=back

=cut

#*********************************************************************************************************

sub create_INVENTORY {
    my ($dbh, $list) = @_;

# describes properties of tables in ARCTURUS database
# tablename   = ARCTURUS database table name
# domain      = 'c' for common table
#               'o' for table in organism database
# status      = 'a' for auxilliary table
#               'd' for dictionary table
#               'l' for linktable (organism database)
#               'm' for mapping table
#               'o' for 'other' table in organism database
#               'p' for principal/main/primary table
#               'r' for reference table
#               's' for status table (a kind of global tag)
#               't' for tag table
# rebuild     = '0' for prohibit if not empty;
#               '1' for rebuild from data in READS table using a special script
#               '2' always allowed to reinitialize the table
#               '3' for rebuild from a data file or files using a special script
#                   NOTE: "script only" means: by a purpose built script cross-checking
#                          with other tables for consistance and completeness
#                          Only level 2 allows recreation of the table (with loss of
#                          previous contents)
# onRead      = '1' for build the table as an object on opening in autoVivify mode (see module DbaseTable)

    &dropTable ($dbh,"INVENTORY", $list);
    print STDOUT "Creating table INVENTORY ..." if ($list);
    $dbh->do(qq[CREATE TABLE INVENTORY(
             tablename   VARCHAR(16)           NOT NULL,
             domain      ENUM ('c','o')                             DEFAULT 'o',
             status      ENUM ('a','d','l','m','o','p','r','s','t') DEFAULT 'o',
             rebuild     ENUM ('0','1','2','3')                     DEFAULT '0',         
             onRead      ENUM ('0','1')                             DEFAULT '0'
	 )]);
    print STDOUT "... DONE!\n" if ($list);

    my @input = ('INVENTORY         c  o  2  1',
                 'DATAMODEL         c  o  2  1',
                 'ORGANISMS         c  p  0  1',
                 'USERS             c  p  0  1',
                 'ASSEMBLY          o  o  0  1',
                 'PROJECTS          o  o  0  1',
                 'USERS2PROJECTS    o  l  0  1',
		 'READMODEL         c  o  2  1',
                 'VECTORS           c  r  0  1',
                 'CHEMTYPES         c  r  2  1',
                 'READS             o  p  0  0',

#                 'DNA               o  p  0  0',
#                 'COMMENT           o  d  1  0',
#                 'TEMPLATE          o  d  1  0',

                 'READEDITS         o  a  0  0',
                 'READTAGS          o  t  0  0',
                 'READPAIRS         o  l  3  0',
                 'PENDING           o  p  0  0',
                 'READS2CONTIG      o  m  0  0',
                 'GAP4TAGS          o  t  0  0',
                 'STSTAGS           o  t  3  1',
                 'HAPPYTAGS         o  t  3  1',
                 'HAPPYMAP          o  t  3  1',
                 'TAGS2CONTIG       o  m  3  0',
                 'GENE2CONTIG       o  m  3  0',
                 'CLONEMAP          o  t  3  1',
                 'CLONES2CONTIG     o  m  3  0',
                 'READS2ASSEMBLY    o  l  0  0',
                 'CONTIGS           o  p  0  0',
                 'CONTIGS2SCAFFOLD  o  l  3  0',
                 'CONTIGS2CONTIG    o  m  0  0',
                 'CONSENSUS         o  d  1  1',
                 'CONTIGS2PROJECT   o  l  3  0',
                 'CHEMISTRY         o  d  1  1',
                 'STRANDS           o  d  1  1',
                 'PRIMERTYPES       o  d  1  1',
                 'BASECALLER        o  d  1  1',
                 'SEQUENCEVECTORS   o  d  1  1',
                 'CLONINGVECTORS    o  d  1  1',
                 'CLONES            o  d  1  1',
                 'CLONES2PROJECT    o  l  0  1',
                 'LIGATIONS         o  d  1  1',
                 'SESSIONS          c  p  0  1',
                 'HISTORY           o  o  0  0',
                 'DBHISTORY         o  o  0  0',
                 'STATUS            o  s  1  1');

    foreach my $line (@input) {
        my ($f1, $f2, $f3, $f4, $f5) = split /\s+/,$line;
        $dbh->do("insert into INVENTORY (tablename,domain,status,rebuild,onRead) ".
                 "values (\"$f1\", \"$f2\", \"$f3\", \"$f4\", \"$f5\")");
    }
}
#--------------------------- documentation --------------------------
=pod

=head1 Table INVENTORY

=head2 Synopsis

maintenance aspects of tables in ARCTURUS database

control of building, rebuilding or modifying operations

=head2 Scripts & Modules

=over 4

=item create/update (I<script>)

=item ArcturusTable.pm

=back

=head2 Description of columns:

=over 8

=item tablename

=item domain

location of database table

=over 16

=item 'c' for common table

=item 'o' for table in organism database

=back

=item status

type of the data in the table

=over 16

=item  'a' for auxilliary table (unspecified)

=item  'd' for dictionary table (e.g. chemistry)

=item  'l' for linktable (e.g. contigs to projects)

=item  'm' for mapping table (e.g. reads to contig, tags to contig)

=item  'p' for principal/main/primary data table

=item  'r' for reference table (static dictionary table)

=item  's' for status table (a kind of global tag)

=item  't' for tag table

=item  'o' any type not mentioned above

=back

=item rebuild

protection flag controlling re-initialisation of a database table (by the
I<create> script)

=over 16

=item  '0' by default prohibited if not empty 

(rebuild can be forced by user with special privilege)

=item  '1' table can be rebuilt from data in READS table (using the I<create> script under CGI)

=item  '2' always allowed to re-initialise the table (with loss of contents)

=item  '3' allows rebuild from a I<data file> or files using a special script only (e.g. tags)

=back

=item onRead

set to '1' for caching the table on opening in autoVivify mode (see module ArcturusTable)

=back

=cut

#*********************************************************************************************************

sub create_USERS {
    my ($dbh, $list) = @_;

# authority: 0 for read only; 1 for finishing access; 2 for managing projects; 4 for supreme fascist
#            special case (-1): scientists and annotators who may add tags, but do nothing else 
#            users can transfer authority up to one level below their own
# seniority: 0 for retired; 1 for Trainee/research assistent; 2 for Finisher/ scientist;
#            3 for Project Manager, 4 for Team Leader, 5 for Database manager, 6 for SF oper
# projects : number of projects in which the user is currently involved (counted over all databases!)
# session  : transient session number for users logged in via, i.p. non-HTML, sessions: assign
#            session number after initial userId/password verification and transfer that one from
#            one login to another; session can be used to verify logged on users: on logout delete 

    &dropTable ($dbh,"USERS", $list);
    print STDOUT "Creating table USERS ..." if ($list);
    $dbh->do(qq[CREATE TABLE USERS(
             user             SMALLINT            NOT NULL AUTO_INCREMENT PRIMARY KEY,
             userid           CHAR(8) binary      NOT NULL,
             lastname         VARCHAR(24)         NOT NULL,
             givennames       VARCHAR(16)             NULL,
             affiliation      VARCHAR(32)         DEFAULT "Genomic Research Limited",
             division         VARCHAR(16)             NULL,
	     function         ENUM ("Database Owner","Database Manager","Team Leader","Project Manager","Finisher","Trainee","Scientist","Annotator", "Research Assistent","Visitor","Other") DEFAULT "Other",
             ustatus          ENUM ("new","active","retired","other") DEFAULT "new",
             email            VARCHAR(32)             NULL,
             password         VARCHAR(32)             NULL,
             seniority        TINYINT  UNSIGNED   NOT NULL,
             privilegea       SMALLINT UNSIGNED   NOT NULL,
             projects         TINYINT  UNSIGNED   NOT NULL,
             attributes       BLOB                    NULL,
             CONSTRAINT USERIDUNIQUE UNIQUE (USERID)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# privileges: 16 bits code for various access function (should be drawn from config file

    my $defaultusers = "INSERT INTO USERS ";
    $defaultusers .= "(userid, lastname, givennames, division, function, seniority)";
    $defaultusers .= " VALUES ";
    $defaultusers .= "('arcturus','the ARCTURUS project','Supreme Fascist','Pathogen Group','Database Owner',6),";
    $defaultusers .= "('oper','Zuiderwijk','Ed J.', 'Team 81', 'Database Manager',6),";
    $defaultusers .= "('ejz' ,'Zuiderwijk','Ed J.', 'Team 81', 'Database Manager',5) ";
    $dbh->do($defaultusers);
    $dbh->do("UPDATE USERS SET privilegea=255, password='arcturus', email='ejz\@sanger.ac.uk'");
}

#--------------------------- documentation --------------------------
=pod

=head1 Table USERS

=head2 Synopsis

arcturus user administration

each user has a userid and password defined by the user on registration

each user has a seniority and privileges set by an authorised other user.
both seniority and privileges determine which arcturus operations can be
executed

the superuser is called 'oper' and has seniority level 6

=head2 Scripts & Modules

=over 4

=item umanager (I<script>)

=item GateKeeper.pm

=item ArcturusTable.pm

=back

=head2 Description of columns:

=over 8

=item user

=item userid

user identifier (unique); up to 8 characters (but at least 3)

=item lastname

=item givennames

=item affiliation

=item division

Sanger Institute team number

=item function

whatever the user thinks of him or herself

=item ustatus

=item email

=item password

encrypted user password

=item seniority

=item privileges

=item projects

number of projects to which the user is assigned

=item attributes

a blob field for storage of any kind of fluid data as a hash image
but i.p. additional information about access privileges

the attributes field is accessed via purpose made methods of ArcturusTable.pm

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

sub create_SESSIONS {
    my ($dbh, $list) = @_;

# session 'username:encrypted number'
# ? organism id (0 for arcturus itself)
# timebegin
# timeclose
# access   count access under this session
# closed_by 

    &dropTable ($dbh,"SESSIONS", $list);
    print STDOUT "Creating table SESSIONS ..." if ($list);
    $dbh->do(qq[CREATE TABLE SESSIONS (
             session         CHAR(24)                        NULL,
             timebegin       DATETIME                    NOT NULL,
             timeclose       DATETIME                        NULL,
             access          SMALLINT UNSIGNED          DEFAULT 1,
             closed_by       ENUM('self','oper','other')     NULL,
             CONSTRAINT SESSIONUNIQUE UNIQUE (SESSION)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table SESSION

=head2 Synopsis

record of user sessions

a session number is issued on log-on via the GateKeeper.pm module

sessions are closed on log-off or when they have otherwise expired

curently sessions are kept for 30 days


=head2 Scripts & Modules

=over 4

=item GateKeeper.pm

=back

=head2 Description of columns:

=over 8

=item session

arcturus session ID consists of a string of form [userid]:[random-string]

=item timebegin

date and time of log-on

=item timeclose

date and time of either log-off or expiry

=item access

number of access to arcturus under this this session

=item closed_by

user ID effectuating log-off or expiry

=back

=head2 Linked Tables on key ..

=cut
#--------------------------------------------------------------------

#*****************************************************************************************

sub create_CHEMTYPES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CHEMTYPES", $list);
    print STDOUT "Creating table CHEMTYPES ..." if ($list);
    $dbh->do(qq[CREATE TABLE CHEMTYPES(
             number           SMALLINT UNSIGNED                     NOT NULL AUTO_INCREMENT PRIMARY KEY,
             chemtype         CHAR(1)                               NOT NULL,
             description      VARCHAR(32)                           NOT NULL,
             type             ENUM('primer','terminator','unknown') DEFAULT 'unknown',
             origin           VARCHAR(16)                               NULL
         )]);
    print STDOUT "... loading ..." if ($list);
    my %chemistry = ('b','Big Dye primer',
                     'c','Big Dye terminator',
                     'd','d-Rhodamine terminator',
                     'e','energy-transfer primer',
                     'f','energy-transfer terminator',
                     'k','Big dye V3 terminator', 
                     'l','Licor-chemistry',
                     'm','MegaBace primer',
                     'n','MegaBace terminator',
                     'p','standard Rhodamine primer',
                     't','standard Rhodamine terminator',
                     'o','other',
                     'u','unknown');
    my %manufacturer = ('f','Amersham','m','ET','n','ET','p','ABI','t','ABI');
    foreach my $key (sort keys (%chemistry)) {
        my $sth = $dbh->prepare ("INSERT INTO CHEMTYPES (chemtype,description) "
                                  . "VALUES (\'$key\',\'$chemistry{$key}\')");
        $sth->execute();
        if ($manufacturer{$key}) {
            $sth = $dbh->prepare ("UPDATE CHEMTYPES SET "
                                . "origin = \'$manufacturer{$key}\' "
                                . "WHERE chemtype = \'$key\'");
            $sth->execute();
            $sth->finish();
        }
    }
    $dbh->do("UPDATE CHEMTYPES SET type='primer'     where description like '%primer'");
    $dbh->do("UPDATE CHEMTYPES SET type='terminator' where description like '%terminator'");
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table CHEMTYPES

=head2 Synopsis

dictionary table of standard Sanger chemistry types

=head2 Description of columns:

=over 4

=item number

=item chemtype

Sanger chemistry type code

=item description

=item type

either 'primer', 'terminator' or 'unknown'

=item origin

=back

=cut
#--------------------------------------------------------------------

#******************************************************************************************

sub create_VECTORS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"VECTORS", $list);
    print STDOUT "Creating table VECTORS ..." if ($list);
    $dbh->do(qq[CREATE TABLE VECTORS(
             vector           TINYINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             template         VARCHAR(16)        NOT NULL,
             type             VARCHAR(16)            NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table VECTORS

=head2 Synopsis

master vector table of cloning and sequence vectors

=head2 Scripts & Modules

=over 4

=item create/update (I<script>)

=back

=head2 Description of columns:

=over 8

=item vector

autoincremented vector number

=item template

generic vector name

=item type

vector type, e.g. cosmid, plasmid

=back

=cut
#--------------------------------------------------------------------

#*********************************************************************************************************

# dbasename : name of the database (up to 8 characters, use IBM name convention)
# organism  :
# genus     : e.g. Plasmodium, Leishmania, Yersina, etc...
# species   : e.g. Falciporum, Pestis , etc...
# strain    : e.g. mssa
# isolate   : e.g. Clinical, Laboratory, environment
# schema    : Oracle Schema (projects to be put in assembly
# updated       : date time of last update of contents
# assemblies    : number of assemblies
# read_loaded   : total number of reads loaded
# reads_pending : overall number of pending reads
# contigs       : overall number of contigs
# date_created  : date of creation
# creator     : user ID of creator 
# last_backup : date of last backup
# residence   : url of arcturus incarnation or off line device
# available   : 'on-line', 'blocked', 'copied','off-line'
# attributes  : data last loaded from (e.g. directory or device name, see rloader script)

sub create_ORGANISMS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"ORGANISMS", $list);
    print STDOUT "Creating table ORGANISMS ..." if ($list);
    $dbh->do(qq[CREATE TABLE ORGANISMS(
             number          SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             dbasename       VARCHAR(16) binary  NOT NULL,
             genus           VARCHAR(24)         NOT NULL,
             species         VARCHAR(24)         NOT NULL,
             serovar         VARCHAR(24)         NOT NULL,
             strain          VARCHAR(24)         NOT NULL,
             isolate         VARCHAR(16)         NOT NULL,
             schema          VARCHAR(16)         NOT NULL,
             updated         DATETIME                NULL,
             assemblies      SMALLINT  UNSIGNED  NOT NULL,
             contigs         MEDIUMINT UNSIGNED  NOT NULL,
             reads_loaded    MEDIUMINT UNSIGNED  NOT NULL,
             reads_pending   MEDIUMINT UNSIGNED  NOT NULL,
             comment         VARCHAR(255)        NOT NULL,
             date_created    DATE                NOT NULL,
             creator         CHAR(8)             NOT NULL,
             last_backup     DATETIME                NULL,
             residence       VARCHAR(32)         NOT NULL,
             available       ENUM ('on-line','blocked','copied','off-line') DEFAULT 'on-line',
             attributes      BLOB                    NULL,
             CONSTRAINT DBASENAMEUNIQUE UNIQUE (DBASENAME)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table ORGANISMS

=head2 Synopsis

Meta data of all organism databases on all arcturus instances of the current server

Is populated by a variety of scripts

=head2 Scripts & Modules

=over 4

=item create (I<script>)

=item rloader (I<script>)

=item cloader (I<script>)

=item GateKeeper.pm

=back

=head2 Description of columns:

=over 8

=item dbasename

name (unique) of the database (up to 16 characters, use IBM name convention)

=item genus

=item species

=item strain 

=item isolate 

=item schema 

organism-related Oracle Schema

=item updated

date time of last update of contents

=item assemblies

number of assemblies

=item contigs

number of contigs (in all assemblies)

=item reads_loaded

total number of reads loaded (for all assemblies)

=item reads_pending

number of pending reads (known to be missing)

=item comment

any text, up to 255 caharacters

=item date_created

date of creation of the organism database

=item creator

user ID of creator of the database

=item last_backup

date and time of last backup

=item residence

server host, MySQL port and CGI port of the arcturus node, if on-line available, 
or off line storage information

=item available

flag for access status

=over 12

=item on-line  : database appears healthy

=item blocked  : e.g. when maintenance issues have to be resolved

=item copied   : after a successful copy to another arcturus node

=item off-line : e.g. when backed-up on CDROM and archived

=back

=item attributes

a blob field for storage of any kind of fluid data as a hash image, e.g.
most recently accessed data source (experiment file directory), last
accessed assembly, etc ..

the attributes field is accessed via purpose made methods of the ArcturusTable
module

=back

=cut

#*********************************************************************************************************

# database history table; to be renamed after creating in organism directory to: HISTORY<dbasename>
# contains: creation date, name of last last accessed user, date/time of that event, and
# the action which was done (e.g. rebuild, accumulate, edit, etc)

sub create_DBHISTORY {
    my ($dbh, $list, $user) = @_;

    &dropTable ($dbh,"DBHISTORY", $list) if ($user eq 'oper'); # only this user
    print STDOUT "Creating table DBHISTORY ..." if $list;
    $dbh->do(qq[CREATE TABLE DBHISTORY(
             tablename      VARCHAR(20)         NOT NULL,
             created        DATE                NOT NULL,
             lastuser       VARCHAR(8)          NOT NULL,
	     lastouch       DATETIME            NOT NULL,
             action         VARCHAR(8)          NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}
#--------------------------- documentation --------------------------
=pod

=head1 Table DBHISTORY

=head2 Synopsis

Record most recent type of change to the I<contents> of tables in the database

After creation of this table in the database, its name is changed to HISTORY[dbname];
this is done to create a unique table in each arcturus database, the presence of which
can be tested and used to protect against inadverted operations (see create script)  

Is populated by any script altering the database contents, by using a purpose made method
of the ArcturusTable module.

=head2 Scripts & Modules

=over 4

=item create (I<script>)

=item ArcturusTable.pm

=back

=head2 Description of columns:

=over 8

=item tablename

=item created

date of creation of the table

=item lastuser

most recent user to access the table for alteration of contents

=item lastouch

date and time of last alteration

=item action

the most recent operation (e.g. update, delete etc)

=back

=cut

#*********************************************************************************************************

# history table to record changes to the structure of tables in the database
# This table was added by DH to keep track of table structure updates 
# This table cannot be dropped (with this script), only changed

sub create_HISTORY {
    my ($dbh, $list, $user) = @_;

    &dropTable ($dbh,"HISTORY", $list) if ($user eq 'oper'); # only this user 'oper'
    print STDOUT "Creating table HISTORY ..." if $list;
    $dbh->do(qq[CREATE TABLE HISTORY(
             tablename      VARCHAR(20)         NOT NULL,
             date           DATETIME            NOT NULL,
             user           VARCHAR(20)         NOT NULL,
             action         VARCHAR(20)         NOT NULL,
             command        TEXT                NOT NULL
	 ) TYPE = MyISAM]);
    print STDOUT "... DONE!\n" if ($list);
}

#--------------------------- documentation --------------------------
=pod

=head1 Table HISTORY

=head2 Synopsis

Record changes to the I<structure> of tables in the database in order to 
keep track of table format updates

Is populated by create script only

=head2 Scripts & Modules

=over 4

=item create (I<script>)

=back

=head2 Description of columns:

=over 8

=item tablename

=item user

=item date

=item action

last operation on the table format (CREATE, ALTER, etc ..)

=item command

the full SQL command last executed

=back

=cut

#*********************************************************************************************************

sub dropTable {
    my ($dbh, $tbl, $list) = @_;

# test if table is present

        print STDOUT "Dropping table $dbh $tbl ... " if ($list);
        $dbh->do(qq[DROP TABLE IF EXISTS $tbl]);

}


#*********************************************************************************************************
# method diagnose scans this source file and compares the definition of tables with
# the definition returned by the MYSQL 'describe table' command. Possible differences will
# be translated and formatted as an ALTER TABLE instruction.
# In order to work correctly, it assumes that the table definition in this script follow
# a few rules: put one column on one line (starting of course with 'do .. create table')
# putthe closing parenthesis of the table definition on a separate line; possible 
# table_options are ignored in this version.
#*********************************************************************************************************

sub diagnose {
# compare an Arcturus table in the current database with its definition in this file
    my $table = shift; # ArcturusTable handle to be tested
    my $sroot = shift; # full filename of this source file 

    my $source = $sroot.'/CreateArcturus.pm';

    my $tablename = $table->{tablename} || 0;

# get the field definitions from this source file

    undef my %fields;
    my $collect = 0;
    open (SOURCE,"$source") || return -1; # can't open source file

    undef my $alterTable;

    undef my $record;
    undef my %columns;
    undef my $previous;
    my $testname = $tablename;
    $testname = 'DBHISTORY' if ($testname =~ /history\w+/i);
    my $tabletype = "MyISAM"; # default if not specified
    while (defined ($record = <SOURCE>)) {

        if (!$collect && $record !~ /\bdo\b/  || $record !~ /\S/) {
            next;
        }
        elsif (!$collect && $record =~ /\bcreate\s+table\b/i && $record =~ /\b$testname[\w+]?\b/) {
            $collect = 1; # tablename found start scanning on next line
	}
        elsif (!$collect) {
            next;
        }
        elsif ($collect && $record =~ /\bdo\b/) {
            $collect = 0; # should not occur but just in case
        }
        elsif ($collect && $record =~ /\S/ && $record !~ /\w/) {
            $collect = 0; # end of scanning
        }
        elsif ($collect && $record =~ /constraint/i) {
# here process table other column definition information (not required yet)
        } 
        elsif ($collect && $record =~ /\W(avg_row_length|checksum|auto_increment|type)\s*\=/i) {
# table options, for the moment only table type is being processed
            if ($record =~ /\Wtype\s*\=\s*(bdb|heap|innodb|isam|merge|myisam)/i) {
                $tabletype = $1; # the required table type
#print "table type test triggered by $record <br>";
                my $info = $table->getTableType(); # the current table type
                if ($info && uc($info) ne uc($tabletype)) {
#print "NEW tabletype read from source: $tabletype<br>\n";
                    if ($info !~ /heap|merge/i && $tabletype !~ /heap|merge/i) {
                        $alterTable = "ALTER table $tablename type=$tabletype" if !$alterTable;
                    }
                    else {
                        print "Conversion of $testname from $info to $tabletype is ignored <br>";
                    }
                }
            }
# ignore other_options information for the moment
            $collect = 0;
        }
        else {
# analyse column definitions
            $record =~ s/^\s+(\S)/$1/; # clip leading blanks
            $record =~ s/\s*\,?\s*$//; # chop trailing blanks/comma
            $record =~ s/\"/\'/g; # replace " by ' throughout
            $record =~ s/\benum\s*/enum/i; # close possible gap between enum key and '('
            $record =~ s/\s*\,\s*/,/g; # remove any blanks around commas (in enum list)
            my $original = $record; # keep the description (as is in source file)
# replace blanks inside quoted string value by a substitution symbol (allowing split on blanks)
            $record = &stringconnect($record,'%');
            my @description = split /\s+/,$record;
            my $column = $description[0]; 
            for (my $i = 1 ; $i < @description ; $i++) {
		$description[$i] =~ tr/A-Z/a-z/ if ($description[$i] !~ /\(.+\)|\'.+\'|NULL|NOT/i);
		$description[$i] =~ tr/A-Z/a-z/ if ($description[$i] =~ /CHAR/i);
                if ($description[$i] =~ /enum\(([^\)]+)/) {
                    my $choices = &enumorder($1);
                    $description[$i] = "enum($choices)";
                }
            }
            $fields{$column} = join ' ',@description;
            $fields{$column} =~ s/\%/ /g; # restore the blanks in quoted values
            $fields{$column} =~ s/\bFLOAT\b/float/; # to lower case

            if (my $info = $table->getColumnInfo($column,1)) {
# some massaging in order to align table info and script definitions
                $fields{$column} =~ s/\bchar/varchar/ if ($info =~ /\bvarchar\b/);
                $fields{$column} =~ s/\bNOT\sNULL/default 0/i if ($info =~ /default\s0/i);
                $info =~ s/default/NOT NULL default/i if ($fields{$column} =~ /\bNOT\sNULL\b/);
# keep the first encountered mismatch of a column definition
                if ($info ne $fields{$column}) {
#print "info: $info <br>fields: $fields{$column}<br>";
                    $alterTable = "ALTER table $tablename change column $column $original" if !$alterTable;
# print "sourcefile '$fields{$column}' <br>tabledata  '$info' <br>proposed ALTER: $alterTable <br><br>";
                }
	    }
# if the column is missing, generate an add column instruction
	    elsif (!$alterTable) {
                $previous = "after $previous" if $previous;
                $previous = "first" if !$previous;
                $alterTable = "ALTER table $tablename add column $original $previous";
            }
            $previous = $column;
        }
    }


# if all columns have been tested and passed for conformity, test for deleted columns 
# NOTE: this section will probably not handle multiple column changes correctly

    if (!$alterTable || $alterTable =~ /\badd\scolumn/) {
# compare $table->{columns} with keys %columns
        foreach my $column (@{$table->{columns}}) {
# there is a deleted column; if there is a missing column as well, perhaps it was renamed?
# if the table is empty, simply do the add and drop in two passes, else apply rename 
# if (!$fields{$column} && $alterTable && $table->count) {
            if (!$fields{$column} && $alterTable) {
print "there is an added column $alterTable and a column $column to be dropped <br>";
# to be completed (tricky)
# get the definition for the column to be dropped
                my $info = $table->getColumnInfo($column,1);
                $info =~ s/$column\s+//; # remove column name; left is specification
                $info =~ s/\s+//g; # remove all blanks
print "$info <br>";
# split the add column instruction into the add column ... specification 
                my $changeTable = $alterTable;
                $changeTable =~ s/first|after\s+\w+//; # remove position info 
                if ($changeTable =~ /(add\s+column\s+(\w+))\s+(\w.*)/) {
                    my $namepart = $1;
                    my $newname  = $2;
                    my $colspecs = $3;
                    $colspecs =~ s/first|after\s+\w+//; # remove position info
                    $colspecs =~ s/\s+//g; # remove all blanks
print "specs: '$colspecs'  '$info' <br>";
                    if (uc($colspecs) eq uc($info)) {
# specs are identical, hence the add / drop can be replaced by a change construct
                        $changeTable =~ s/$namepart/change column $column $newname/;
                        $alterTable = $changeTable; 
                    }
                }
            }
            elsif (!$fields{$column} && !$alterTable) {
                $alterTable = "ALTER table $tablename drop column $column";
            }
        }
    }
# print "diagnose $table->{tablename}: alterTable=$alterTable<br>\n" if ($alterTable && $tablename =~ /hist/i);

    return $alterTable || 0;
}

#*********************************************************************************************************

sub stringconnect {
# private function: replace blanks in a string by some other symbol
    my $string = shift;
    my $symbol = shift || '%';

    my @string = split //,$string;
    my $inString = 0;
    foreach my $s (@string) {
        $inString = 1 - $inString if ($s eq "'");
        $s = $symbol  if ($inString && $s eq ' '); 
    }

    return join '',@string;
}

#*********************************************************************************************************

sub enumorder {
# private function: sort a list of enumerated items
    my $choices = shift;

    my @choices = split /\s*\,\s*/,$choices;
    @choices = sort @choices;

    return join ',',@choices;
}

#*********************************************************************************************************

#--------------------------- documentation --------------------------
=pod

=head1 AUTHOR

Ed Zuiderwijk, E<lt>ejz@sanger.ac.ukE<gt>.

=cut
#--------------------------------------------------------------------

1;



