
# use strict;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

#require Exporter;

#@ISA = qw(Exporter);
#@EXPORT = qw();
#@EXPORT_OK = qw();

# ARCTURUS database creation script for all or individual tables

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

    if ($target eq 'all' || $target eq 'people') {
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
        &create_HISTORY ($dbh, $list);
    # after creation rename the table to its required name
        my $rename = $dbh->do("ALTER TABLE HISTORY RENAME AS $historyTable");
        push @tables, $historyTable if ($rename);
        undef $historyTable if (!$rename);
    } elsif (!defined($result) || $result <= 0) { # level<=0
        print "WARNING! Table $historyTable does not exist; create ABORTED<br>";
        $target = 'VOID'; # skips all subsequent create calls
        $result = $dbh->do("SHOW TABLES");
    }

# get the "history"  table into memory

    $historyTable = DbaseTable->new($dbh,$historyTable,$database);
    $historyTable->build(1) if ($historyTable);

    if (!$target || $target eq 'READS') {    
        push @tables, 'READS';
        &create_READS ($dbh, $list);
        &record ($historyTable,$userid,'READS');
    }

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

    if (!$target || $target eq 'TAGS2CONTIG') {    
        push @tables, 'TAGS2CONTIG';
        &create_TAGS2CONTIG ($dbh, $list);
        &record ($historyTable,$userid,'TAGS2CONTIG');
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
        $created++;
    }

    if (!$target || $target eq 'PROJECTS') {
        &create_PROJECTS($dbh, $list);
        &record ($historyTable,$userid,'PROJECTS');
        push @tables, 'PROJECTS';
        $created++;
    }

    if (!$target || $target eq 'USERS2PROJECTS') {
	&create_USERS2PROJECTS($dbh, $list);
        &record ($historyTable,$userid,'USERS2PROJECTS');
        push @tables, 'USERS2PROJECTS';
        $created++;
    }

    return \@tables; # return a list of tables to be created
}
#*********************************************************************************************************

sub record {
# enter a record into the history table
    my $history = shift;
    my $userid  = shift;
    my $dbtable = shift; 
  
    my $timestamp = $history->timestamp(0);
    my ($date, $time) = split /\s/,$timestamp;

# test if the entry exists

    if (!($history->associate('tablename',$dbtable))) {
        $history->newrow('tablename',$dbtable);
    }
    $history->update('created'  ,$date      ,'tablename',$dbtable);
    $history->update('lastuser' ,$userid    ,'tablename',$dbtable);
    $history->update('lastouch' ,$timestamp ,'tablename',$dbtable);
    $history->update('action'   ,'created'  ,'tablename',$dbtable);
}

#*********************************************************************************************************
#*********************************************************************************************************
# tables for individual organism databases
#*********************************************************************************************************
#*********************************************************************************************************

# paired : label to mark as Forward or Reverse read of a pair or pairs

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
             direction        ENUM ('?','+','-')   NOT NULL, 
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
             paired           ENUM ('N','F','R')   NOT NULL,
             comment          VARCHAR(255)             NULL,
             CONSTRAINT READNAMEUNIQUE UNIQUE (READNAME)  
         )]);

    print STDOUT "... DONE!\n" if ($list);

# Make indices

    print STDOUT "Building indexes ...\n" if ($list);
    $dbh->do(qq[CREATE UNIQUE INDEX RECORD_INDEX ON READS (readname)]);
    $dbh->do(qq[CREATE INDEX TEMPLATE_INDEX ON READS (template)]);

    print STDOUT "Indexed READNAME ON READS ... DONE\n" if ($list);

}

#*********************************************************************************************************

sub create_READEDITS {
    my ($dbh, $list) = @_;

# edits  : list of substitutions for individual bases in read, code: nnnGa nnnT etc.
#         (substitute "G" at position nnn by "a", delete "T" at position nnn)
# read  : number of read
# base  : number of base to be changed
# edit  : substitution value of blank for delete
# ? user  : integer refering to user table (implicit in contig info?)
# depre : deprecation status

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

#*********************************************************************************************************

sub create_READPAIRS {
    my ($dbh, $list) = @_;

# forward   : read_id of read with forward strand
# reverse   : ibid
# score     : see asmReadpairs.shtml documentation; U for untested added

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
#              info in CONTIGS2SCAFFOLD but required for delete actions
# generation : incremented after each completed assembly
# deprecated : on for mappings transient (X) or no longer current (Y)
#              or marked for deletion (M) 
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
             generation       TINYINT  UNSIGNED        NOT NULL,
             deprecated       ENUM ('N','M','Y','X') DEFAULT 'X'
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# Make (separate) indexes on read_id and contig_id

    print STDOUT "Building indexes on read_id, contig_id...\n" if ($list);
    $dbh->do(qq[CREATE INDEX reads_index ON READS2CONTIG (read_id)]);
    $dbh->do(qq[CREATE INDEX cntgs_index ON READS2CONTIG (contig_id)]);
    print STDOUT "Indexes READS_INDEX and CNTGS_INDEX  ON READS2CONTIG ... DONE\n" if ($list);
}

#*********************************************************************************************************

sub create_READS2ASSEMBLY {
    my ($dbh, $list) = @_;

# reads to assembly (e.g. chromosome, blob)
# assembly REF to assembly id number
# locked : reference to USER table; 0 if not locked by anyone
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

#*********************************************************************************************************

sub create_CONTIGS {
    my ($dbh, $list) = @_;

# contig_id   : unique contig identification number
# contigname  : compound ARCTURUS contigname
#  note: determine name from farthest lefthand/righthand reads
#  note: find a parity test on nr of reads and total length
# ? read_left   : read_id of read on  lefthand side
# ? read_right  : read_id of read on righthand side
# alias       : e.g. caf or phrap contigname
# zeropoint   : (regularly updated) position with respect to assembly
# length      : number of bases
# ncntgs      : (parity check) number of previous contigs merged into it; 
#               (=0 for first generation) re: CONTIGS2CONTIG table
# nreads      : (parity check) number of reads referenced; re: READS2CONTIG table
# cover       : average cover of contig by reads (=(sumtotal readlength)/length)
# origin      : e.g. software used to build contig
# userid      : userid  of contig creator/last user to access
# updated     : creation date (or last modification)

# pstatus     : allocation to project status: 'N' for not
#               'D' default allocation (usually default project),
#               'H' for alloaction by inheritance
#               'Y' for allocation by any other means
#               project/assembly specified in CONTIGS2SCAFFOLD

    &dropTable ($dbh,"CONTIGS", $list);
    print STDOUT "Creating table CONTIGS ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS(
             contig_id        MEDIUMINT UNSIGNED       NOT NULL AUTO_INCREMENT PRIMARY KEY,
             contigname       VARCHAR(48)              NOT NULL,
             aliasname        VARCHAR(32)              NOT NULL,
             zeropoint        INT                     DEFAULT 0,
             length           INT                     DEFAULT 0,
             ncntgs           SMALLINT  UNSIGNED       NOT NULL,
             nreads           MEDIUMINT UNSIGNED       NOT NULL,
             newreads         MEDIUMINT                NOT NULL,
             cover            FLOAT                    NOT NULL,      
             origin           ENUM ('Arcturus CAF parser','Other')  NULL,
             userid           VARCHAR(8)              DEFAULT 'arcturus',
             updated          DATETIME                 NOT NULL,
             CONSTRAINT CONTIGNAMEUNIQUE UNIQUE (CONTIGNAME)  
         )]);
#             pstatus          ENUM ('N','D','H','Y') DEFAULT 'N'
    print STDOUT "... DONE!\n" if ($list);
# index on contig_id implicit in PRIMARY key declaration 
}

#*********************************************************************************************************

sub create_CONTIGS2CONTIG {
    my ($dbh, $list) = @_;

# contig to contig mapping implicitly contains the history

# oldcontig : contig id
# oranges   : starting point in old contig
# orangef   : end point in old contig
# newcontig : contig id
# nranges   : starting point in new contig
# nrangef   : implicit in the above

    &dropTable ($dbh,"CONTIGS2CONTIG", $list);
    print STDOUT "Creating table CONTIGS2CONTIG ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS2CONTIG(
             oldcontig        MEDIUMINT UNSIGNED  NOT NULL,
             oranges          INT                DEFAULT 0,
             orangef          INT                DEFAULT 0,
             newcontig        MEDIUMINT UNSIGNED  NOT NULL,
             nranges          INT                DEFAULT 0,
             nrangef          INT                DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}


#*********************************************************************************************************

sub create_CONTIGS2SCAFFOLD {
    my ($dbh, $list) = @_;

# assign contigs to projects and assemblies
# contig_id 
# project   : reference to PROJECT.project number
# assembly  : reference to ASSEMBLY.assembly number
# astatus   : assembly status: 
#             N not allocated (should not occur except as transitory status)
#             C current generation (origin in CONTIGS.origin)
#             S contig is superseded by later one (i.e previous generation)
#             X locked status (includes transport status); locked by last
#               user to access in CONTIGS.userid

    &dropTable ($dbh,"CONTIGS2SCAFFOLD", $list);
    print STDOUT "Creating table CONTIGS2SCAFFOLD ..." if ($list);
    $dbh->do(qq[CREATE TABLE CONTIGS2SCAFFOLD(
             contig_id        MEDIUMINT          UNSIGNED NOT NULL PRIMARY KEY,
             project          SMALLINT           UNSIGNED NOT NULL,
             assembly         SMALLINT           UNSIGNED NOT NULL,
             astatus          ENUM ('N','C','S','X')    DEFAULT 'N'
         )]);
    print STDOUT "... DONE!\n" if ($list);
}

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
	 )]);
    print STDOUT "... DONE!\n" if ($list);
    $dbh->do("INSERT INTO GAP4TAGS (tag_id, tagname) VALUES (2000000, \"DUMMY\")");
}

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
             position         FLOAT(4)                 NULL,
             linkage          SMALLINT UNSIGNED    NOT NULL,
             assembly         TINYINT  UNSIGNED    NOT NULL,
             CONSTRAINT TAGNAMEUNIQUE UNIQUE (TAGNAME)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);
    $dbh->do("INSERT INTO STSTAGS (tag_id, tagname) VALUES (1000000, \"DUMMY\")");
}

#******************************************************************
# tag_id    : reference to a TAGS table; tag type implicit in tag_id
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
             clonename         VARCHAR(16)          NOT NULL,
             assembly          TINYINT UNSIGNED     NOT NULL,
             cpkbstart         MEDIUMINT UNSIGNED   NOT NULL,
             cpkbfinal         MEDIUMINT UNSIGNED   NOT NULL,
             CONSTRAINT CLONENAMEUNIQUE UNIQUE (CLONENAME)
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}

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
#*****************************************************************************************

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

#******************************************************************************************

sub create_STRANDS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"STRANDS", $list);
    print STDOUT "Creating table STRANDS ..." if ($list);
    $dbh->do(qq[CREATE TABLE STRANDS(
             strand           CHAR(1)            NOT NULL PRIMARY KEY,
             strands          ENUM ('1','2'),
             description      VARCHAR(48)        NOT NULL, 
             counted          INT UNSIGNED       DEFAULT 0
	    )]);
    print STDOUT "... loading ..." if ($list);
    my %strands = (
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
        my $strands = 1; $strands++ if ($key eq 'p' || $key eq 'q' || $key eq 'y');
        my $sth = $dbh->prepare ("INSERT INTO STRANDS (strand,description,strands) "
                                  . "VALUES (\'$key\',\'$strands{$key}\', $strands)");
        $sth->execute();
        $sth->finish();
    }
    print STDOUT "... DONE!\n" if ($list);
}

#******************************************************************************************

sub create_PRIMERTYPES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"PRIMERTYPES", $list);
    print STDOUT "Creating table PRIMERTYPES ..." if ($list);
    $dbh->do(qq[CREATE TABLE PRIMERTYPES(
             primer           SMALLINT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
             description      VARCHAR(48)        NOT NULL, 
             counted          INT UNSIGNED       DEFAULT 0
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
    print STDOUT "... DONE!\n" if ($list);
}

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

#******************************************************************************************

sub create_SEQUENCEVECTORS {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"SEQUENCEVECTORS", $list);
    print STDOUT "Creating table SEQUENCEVECTORS ..." if ($list);
    $dbh->do(qq[CREATE TABLE SEQUENCEVECTORS(
             svector          TINYINT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
             name             VARCHAR(16)        NOT NULL,
             vector           TINYINT UNSIGNED  DEFAULT 0,
             counted          INT UNSIGNED      DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}

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

#*********************************************************************************************************

sub create_CLONES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CLONES", $list);
    print STDOUT "Creating table CLONES ..." if ($list);
    $dbh->do(qq[CREATE TABLE CLONES(
             clone            SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             clonename        VARCHAR(16)        NOT NULL,
             clonetype        ENUM ('PUC finishing','PCR product' ,'unknown') DEFAULT 'unknown',
             library          ENUM ('transposition','small insert','unknown') DEFAULT 'unknown',
             origin           VARCHAR(16)        DEFAULT 'The Sanger Institute',
             counted          MEDIUMINT UNSIGNED DEFAULT 0
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}

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

#*********************************************************************************************************

sub create_LIGATIONS {
    my ($dbh, $list) = @_;

# silow, sihigh: SV insertion length ; origin: O for Oracle, R for reads, U for unidentified

    &dropTable ($dbh,"LIGATIONS", $list);
    print STDOUT "Creating table LIGATIONS ..." if ($list);
    $dbh->do(qq[CREATE TABLE LIGATIONS(
             ligation         SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             identifier       VARCHAR(8)         NOT NULL,
             clone            VARCHAR(16)        NOT NULL,
             origin           CHAR(1)                NULL,
             silow            MEDIUMINT UNSIGNED     NULL,
             sihigh           MEDIUMINT UNSIGNED     NULL,
             svector          SMALLINT           NOT NULL,
             counted          INT UNSIGNED       DEFAULT 0
         )]);
    print STDOUT "... DONE!\n" if ($list);
}

#*********************************************************************************************************
#*********************************************************************************************************
# in common by all databases
#*********************************************************************************************************
#*********************************************************************************************************

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

    $action++;
}

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
             lcolumn       VARCHAR(16)           NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);

    my @input = ('READEDITS          read_id            READS     read_id',
                 'READS2CONTIG       read_id            READS     read_id',
                 'READS2CONTIG     contig_id          CONTIGS   contig_id',
                 'READS2CONTIG     contig_id CONTIGS2SCAFFOLD   contig_id',
                 'READS2CONTIG         clone           CLONES       clone',
                 'READS2ASSEMBLY     read_id            READS     read_id',
                 'READS2ASSEMBLY    assembly         ASSEMBLY    assembly',
                 'USERS               userid   USERS2PROJECTS      userid',
                 'USERS2PROJECTS      userid            USERS      userid',
                 'USERS2PROJECTS     project         PROJECTS     project',
                 'CONTIGS          contig_id     READS2CONTIG   contig_id', # ?
                 'CONTIGS             userid            USERS      userid',
                 'CONTIGS          contig_id      TAGS2CONTIG   contig_id',
                 'CONTIGS          contig_id      TAGS2CONTIG   contig_id',
                 'TAGS2CONTIG      contig_id          CONTIGS   contig_id',
                 'TAGS2CONTIG         tag_id          STSTAGS      tag_id',
                 'STSTAGS             tag_id      TAGS2CONTIG      tag_id',
                 'TAGS2CONTIG         tag_id         GAP4TAGS      tag_id',
                 'GAP4TAGS            tag_id      TAGS2CONTIG      tag_id',
                 'ASSEMBLY          assembly         CLONEMAP    assembly',
                 'CLONEMAP          assembly         ASSEMBLY    assembly',
                 'CONTIGS          oldcontig   CONTIGS2CONTIG   contig_id',
                 'CONTIGS2CONTIG   oldcontig          CONTIGS   contig_id',
                 'CONTIGS2CONTIG   newcontig          CONTIGS   contig_id',
                 'CONTIGS2CONTIG   oldcontig CONTIGS2SCAFFOLD   contig_id',
                 'CONTIGS2SCAFFOLD contig_id   CONTIGS2CONTIG   oldcontig',
                 'CONTIGS2SCAFFOLD contig_id          CONTIGS   contig_id',
                 'CONTIGS          contig_id CONTIGS2SCAFFOLD   contig_id',
                 'CONTIGS2SCAFFOLD   project         PROJECTS     project',
                 'LIGATIONS          svector  SEQUENCEVECTORS     svector',
                 'CHEMISTRY         chemtype        CHEMTYPES    chemtype',
                 'SEQUENCEVECTORS     vector          VECTORS      vector',
                 'CLONINGVECTORS      vector          VECTORS      vector',
                 'CLONES2PROJECT       clone           CLONES       clone',
                 'CLONES2PROJECT     project         PROJECTS     project',
                 'PROJECTS           project   CLONES2PROJECT     project',
                 'PROJECTS           project   USERS2PROJECTS     project',
                 'PROJECTS          assembly         ASSEMBLY    assembly',
                 'PROJECTS            userid            USERS      userid',
                 'PROJECTS           creator            USERS      userid',
                 'ASSEMBLY          organism        ORGANISMS    organism',
                 'ASSEMBLY            userid            USERS      userid',
                 'ASSEMBLY           creator            USERS      userid',
#                 'SESSIONS            userid            USERS      userid',
                 'READS              read_id     READS2CONTIG     read_id',
                 'READS              read_id   READS2ASSEMBLY     read_id',
                 'READS              read_id        READEDITS     read_id',
                 'READS             ligation        LIGATIONS    ligation',
                 'READS                clone           CLONES       clone',
                 'READS               strand          STRANDS      strand',
                 'READS               primer      PRIMERTYPES      primer',
                 'READS            chemistry        CHEMISTRY   chemistry',
                 'READS           basecaller       BASECALLER  basecaller',
                 'READS              svector  SEQUENCEVECTORS     svector',
                 'READS              cvector   CLONINGVECTORS     cvector',
                 'READS              pstatus           STATUS      status');

    foreach my $line (@input) {
        my ($f1, $f2, $f3, $f4) = split /\s+/,$line;
        $dbh->do("insert into DATAMODEL (tablename,tcolumn,linktable,lcolumn) ".
                 "values (\"$f1\", \"$f2\", \"$f3\", \"$f4\")");
    }
}

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
# onRead      = '1' for build the table as an object on opening (see module DbaseTable)

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
                 'READEDITS         o  a  0  0',
                 'READPAIRS         o  l  3  0',
                 'PENDING           o  p  0  0',
                 'READS2CONTIG      o  m  0  0',
                 'GAP4TAGS          o  t  0  0',
                 'STSTAGS           o  t  3  1',
                 'TAGS2CONTIG       o  m  3  0',
                 'CLONEMAP          o  t  3  1',
                 'CLONES2CONTIG     o  m  3  0',
                 'READS2ASSEMBLY    o  l  0  0',
                 'CONTIGS           o  p  0  0',
                 'CONTIGS2SCAFFOLD  o  l  3  0',
                 'CONTIGS2CONTIG    o  m  0  0',
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
                 'STATUS            o  s  1  1');

    foreach my $line (@input) {
        my ($f1, $f2, $f3, $f4, $f5) = split /\s+/,$line;
        $dbh->do("insert into INVENTORY (tablename,domain,status,rebuild,onRead) ".
                 "values (\"$f1\", \"$f2\", \"$f3\", \"$f4\", \"$f5\")");
    }
}
#*********************************************************************************************************

sub create_ASSEMBLY {
    my ($dbh, $list) = @_;

# Assembly Number
# Assembly Name (possibly standardized, taken from Oracle?)
# Alias name (e.g. for projects from outside)
# Organism: REFerence to organism table
# chromosome: 0 for blob; 1-99 nr of a chromosome; 100 for other; > 100 e.g. plasmid
# Origin of DNA sequences (Sanger for in-house; any other name for outside sources)
# size    : approxinmate length (kBase) of assembly, estimated e.g. from physical maps
# length  : actual length (base) measured from contigs
# Number of Reads stored
# Number of Contigs stored
# Number of Projects
# progress: status of data collection
# updated : date of last modification (time of last assembly)
# userid  : user (authorized or from USERS2PROJECT list last accessed/modified the project
# status  : status of assembly
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
             size             MEDIUMINT UNSIGNED   DEFAULT 0,
             length           INT UNSIGNED         DEFAULT 0,
             l2000            INT UNSIGNED         DEFAULT 0,
             reads            INT UNSIGNED         DEFAULT 0,
             contigs          INT UNSIGNED         DEFAULT 0,
             projects         SMALLINT             DEFAULT 0,
             progress         ENUM ('shotgun','in finishing','finished','other') DEFAULT 'other', 
             updated          DATETIME                  NULL,
             userid           CHAR(8)                   NULL,
             status           ENUM ('in progress','completed','error','unknown') DEFAULT 'unknown', 
             created          DATETIME              NOT NULL,
	     creator          CHAR(8)               NOT NULL DEFAULT "oper",
             attributes       BLOB                      NULL,
             comment          VARCHAR(255)              NULL,             
             CONSTRAINT ASSEMBLYNAMEUNIQUE UNIQUE (ASSEMBLYNAME)  
	    )]);
    print STDOUT "... DONE!\n" if ($list);
}

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
# Note : priviledges also dealt via 'assembly' and peopletoproject 

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
             userid           CHAR(8)             NOT NULL,
             lastname         VARCHAR(24)         NOT NULL,
             givennames       VARCHAR(16)             NULL,
             affiliation      VARCHAR(32)         DEFAULT "Genomic Research Limited",
             division         VARCHAR(16)             NULL,
	     function         ENUM ("Finisher","Project Manager","Team Leader",
                                    "Database Manager","Visitor","Scientist",
                                    "Research Assistent","Annotator","Trainee","Other"),
             ustatus          ENUM ("new","active","retired") DEFAULT "new",
             email            VARCHAR(32)             NULL,
             password         VARCHAR(32)             NULL,
             seniority        TINYINT  UNSIGNED   NOT NULL,
             priviledges      SMALLINT UNSIGNED   NOT NULL,
             projects         TINYINT  UNSIGNED   NOT NULL,
             attributes       BLOB                    NULL,
             CONSTRAINT USERIDUNIQUE UNIQUE (USERID)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);

# priviledges: 16 bits code for various access function

    $dbh->do("INSERT INTO USERS (userid, lastname, givennames, division, function)".
            " VALUES (\"arcturus\",\"Anonymous\",\"User\", \"Pathogen Group\", \"Other\")");
    $dbh->do("UPDATE USERS SET priviledges=255, password=\"update\" WHERE userid = \"arcturus\"");
    $dbh->do("UPDATE USERS SET email=\"ejz\@sanger.ac.uk\" WHERE userid = \"arcturus\"");
    $dbh->do("INSERT INTO USERS (userid, lastname, givennames, division, function)".
            " VALUES (\"oper\",\"Zuiderwijk\",\"Ed J.\", \"Team 81\", \"Database Manager\")");
    $dbh->do("UPDATE USERS SET priviledges=255, password=\"update\" WHERE userid = \"oper\"");
    $dbh->do("UPDATE USERS SET email=\"ejz\@sanger.ac.uk\" WHERE userid = \"oper\"");
    $dbh->do("INSERT INTO USERS (userid, lastname, givennames, division, function)".
            " VALUES (\"ejz\",\"Zuiderwijk\",\"Ed J.\", \"Team 81\", \"Database Manager\")");
    $dbh->do("UPDATE USERS SET priviledges=255, password=\"update\" WHERE userid = \"ejz\"");
    $dbh->do("UPDATE USERS SET email=\"ejz\@sanger.ac.uk\" WHERE userid = \"ejz\"");
}

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

#*****************************************************************************************

sub create_CHEMTYPES {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"CHEMTYPES", $list);
    print STDOUT "Creating table CHEMTYPES ..." if ($list);
    $dbh->do(qq[CREATE TABLE CHEMTYPES(
             number           SMALLINT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
             chemtype         CHAR(1)            NOT NULL,
             description      VARCHAR(32)        NOT NULL,
             origin           VARCHAR(16)            NULL
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
    print STDOUT "... DONE!\n" if ($list);
}

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

#*********************************************************************************************************

# dbasename : name of the database (up to 8 characters, use IBM name convention)
# organism  :
# genus     : e.g. Plasmodium, Leishmania, Yersina, etc...
# species   : e.g. Falciporum, Pestis , etc...
# strain    : e.g. mssa
# isolate   : e.g. Clinical, Laboratory, environment
# updated       : date time of last update of contents
# assemblies    : number of assemblies
# read_loaded   : total number of reads loaded
# reads_pending : overall number of pending reads
# contigs       : overall number of contigs
# date_created  : date of creation
# creator     : user ID of creator 
# last_backup : date of last backup
# residence   : url of arcturus incarnation or off line device
# available   : 0 for blocked, 1 for on line and available, 2 for off line  (what about on-line and in use)
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
             available       ENUM ('on-line','blocked','remote','off-line') DEFAULT 'on-line',
             attributes      BLOB                    NULL,
             CONSTRAINT DBASENAMEUNIQUE UNIQUE (DBASENAME)  
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}


#*********************************************************************************************************

# history table; to be renamed after creating in organism directory to: HISTORY<dbasename>
# contains: creation date, name of last last accessed user, date/time of that event, and
# the action which was done (e.g. rebuild, accumulate, edit, etc)

sub create_HISTORY {
    my ($dbh, $list) = @_;

    &dropTable ($dbh,"HISTORY", $list);
    print STDOUT "Creating table HISTORY ..." if ($list);
    $dbh->do(qq[CREATE TABLE HISTORY(
             tablename      VARCHAR(16)         NOT NULL,
             created        DATE                NOT NULL,
             lastuser       VARCHAR(8)          NOT NULL,
	     lastouch       DATETIME            NOT NULL,
             action         VARCHAR(8)          NOT NULL
	 )]);
    print STDOUT "... DONE!\n" if ($list);
}

#*********************************************************************************************************

sub dropTable {
    my ($dbh, $tbl, $list) = @_;

# test if table is present

        print STDOUT "Dropping table $dbh $tbl ... " if ($list);
        $dbh->do(qq[DROP TABLE IF EXISTS $tbl]);

}


#*********************************************************************************************************

1;
