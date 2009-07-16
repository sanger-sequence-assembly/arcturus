# MySQL dump 8.16
#
# Host: pcs3    Database: EIMER
#--------------------------------------------------------
# Server version	4.1.13a-standard-log

#
# Table structure for table 'ALIGN2SCF'
#

CREATE TABLE ALIGN2SCF (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  startinseq smallint(5) unsigned NOT NULL default '0',
  startinscf smallint(5) unsigned NOT NULL default '0',
  length smallint(5) unsigned NOT NULL default '0',
  KEY seq_id (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'ASSEMBLY'
#

CREATE TABLE ASSEMBLY (
  assembly_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(16) NOT NULL default '',
  chromosome tinyint(3) unsigned default '0',
  origin varchar(32) NOT NULL default 'The Sanger Institute',
  size mediumint(8) unsigned default '0',
  progress enum('shotgun','finishing','finished','other') default 'other',
  updated timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  created datetime NOT NULL default '0000-00-00 00:00:00',
  creator varchar(8) NOT NULL default 'arcturus',
  `comment` text,
  PRIMARY KEY  (assembly_id),
  UNIQUE KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'BASECALLER'
#

CREATE TABLE BASECALLER (
  basecaller_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(32) NOT NULL default '',
  PRIMARY KEY  (basecaller_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'C2CMAPPING'
#

CREATE TABLE C2CMAPPING (
  age smallint(5) unsigned default '0',
  contig_id mediumint(8) unsigned NOT NULL default '0',
  parent_id mediumint(8) unsigned NOT NULL default '0',
  mapping_id mediumint(8) unsigned NOT NULL auto_increment,
  cstart int(10) unsigned default NULL,
  cfinish int(10) unsigned default NULL,
  pstart int(10) unsigned default NULL,
  pfinish int(10) unsigned default NULL,
  direction enum('Forward','Reverse') default 'Forward',
  PRIMARY KEY  (mapping_id),
  KEY contig_id (contig_id),
  KEY parent_id (parent_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'C2CSEGMENT'
#

CREATE TABLE C2CSEGMENT (
  mapping_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(10) unsigned NOT NULL default '0',
  pstart int(10) unsigned NOT NULL default '0',
  length int(10) unsigned default NULL,
  KEY mapping_id (mapping_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CHECHOUTLOG'
#

CREATE TABLE CHECKOUTSTATUS (
  project_id smallint(5) unsigned NOT NULL,
  lastcheckout datetime NOT NULL,
  lastcheckin datetime NOT NULL,
  directory varchar(64),
  user char(8) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CLONE'
#

CREATE TABLE CLONE (
  clone_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  origin varchar(20) default 'The Sanger Institute',
  assembly_id smallint(5) unsigned default '0',
  PRIMARY KEY  (clone_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CLONEMAP'
#

CREATE TABLE CLONEMAP (
  clonename varchar(20) NOT NULL default '',
  assembly tinyint(3) unsigned NOT NULL default '0',
  cpkbstart mediumint(8) unsigned NOT NULL default '0',
  cpkbfinal mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (clonename),
  UNIQUE KEY clonename (clonename)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CLONEVEC'
#

CREATE TABLE CLONEVEC (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  cvector_id tinyint(3) unsigned NOT NULL default '0',
  cvleft smallint(5) unsigned NOT NULL default '0',
  cvright smallint(5) unsigned NOT NULL default '0',
  KEY seq_id (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CLONINGVECTOR'
#

CREATE TABLE CLONINGVECTOR (
  cvector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(16) NOT NULL default '',
  PRIMARY KEY  (cvector_id),
  UNIQUE KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CONSENSUS'
#

CREATE TABLE CONSENSUS (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  sequence longblob NOT NULL,
  quality longblob NOT NULL,
  length int(10) unsigned default '0',
  PRIMARY KEY  (contig_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CONTIG'
#

CREATE TABLE CONTIG (
  contig_id mediumint(8) unsigned NOT NULL auto_increment,
  gap4name char(32) character set latin1 collate latin1_bin default NULL,
  length int(10) unsigned default '0',
  ncntgs smallint(5) unsigned NOT NULL default '0',
  nreads mediumint(8) unsigned NOT NULL default '0',
  project_id mediumint(8) unsigned NOT NULL default '0',
  newreads mediumint(9) NOT NULL default '0',
  cover float(8,2) default '0.00',
  origin enum('Arcturus CAF parser','Finishing Software','Other') default NULL,
  userid char(8) default 'arcturus',
  created datetime default NULL,
  updated timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  readnamehash char(16) default NULL,
  PRIMARY KEY  (contig_id),
  KEY rnhash (readnamehash(8))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CONTIGTAG'
#

CREATE TABLE CONTIGTAG (
  tag_id mediumint(8) unsigned NOT NULL auto_increment,
  tagtype varchar(4) character set latin1 collate latin1_bin NOT NULL default '',
  systematic_id varchar(32) character set latin1 collate latin1_bin default NULL,
  tag_seq_id mediumint(8) unsigned NOT NULL default '0',
  tagcomment tinytext,
  KEY contigtag_index (tag_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'CONTIGTRANSFERREQUEST'
#

CREATE TABLE CONTIGTRANSFERREQUEST (
  request_id mediumint(8) unsigned NOT NULL auto_increment,
  contig_id mediumint(8) unsigned NOT NULL default '0',
  old_project_id mediumint(8) unsigned NOT NULL default '0',
  new_project_id mediumint(8) unsigned NOT NULL default '0',
  `requester` varchar(8) NOT NULL default '',
  opened datetime NOT NULL,
  requester_comment varchar(255) NULL,
  `reviewer` varchar(8) NULL,
  reviewed timestamp NULL on update CURRENT_TIMESTAMP,
  reviewer_comment varchar(255) NULL,
  `status` enum ('approved','cancelled','done','failed','pending','refused') NOT NULL default 'pending',
  closed datetime NULL,
  PRIMARY KEY  (request_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#  reviewed timestamp NULL,  # old version requires active update


#
# Table structure for table 'LIGATION'
#

CREATE TABLE LIGATION (
  ligation_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  clone_id smallint(5) unsigned NOT NULL default '0',
  silow mediumint(8) unsigned default NULL,
  sihigh mediumint(8) unsigned default NULL,
  svector_id smallint(5) NOT NULL default '0',
  PRIMARY KEY  (ligation_id),
  UNIQUE KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'MAPPING'
#

CREATE TABLE MAPPING (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  seq_id mediumint(8) unsigned NOT NULL default '0',
  mapping_id mediumint(8) unsigned NOT NULL auto_increment,
  cstart int(10) unsigned default NULL,
  cfinish int(10) unsigned default NULL,
  direction enum('Forward','Reverse') NOT NULL default 'Forward',
  PRIMARY KEY  (mapping_id),
  KEY contig_id (contig_id),
  KEY seq_id (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'PROJECT'
#

CREATE TABLE PROJECT (
  project_id mediumint(8) unsigned NOT NULL auto_increment,
  assembly_id smallint(5) unsigned default '0',
  name varchar(16) binary NOT NULL default '',
  updated timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  owner varchar(8) default NULL,
  status enum ('in shotgun','prefinishing','in finishing','finished','quality checked') default 'in shotgun',
  lockdate datetime default NULL,
  lockowner varchar(8) default NULL,
  created datetime default NULL,
  creator varchar(8) NOT NULL default 'arcturus',
  `comment` text,
  PRIMARY KEY  (project_id),
  UNIQUE KEY assembly_id (assembly_id,name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'QUALITYCLIP'
#

CREATE TABLE QUALITYCLIP (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  qleft smallint(5) unsigned NOT NULL default '0',
  qright smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'READCOMMENT'
#

CREATE TABLE READCOMMENT (
  read_id mediumint(8) unsigned NOT NULL default '0',
  `comment` varchar(255) default NULL,
  KEY read_id (read_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'READS'
#

CREATE TABLE READS (
  read_id mediumint(8) unsigned NOT NULL auto_increment,
  readname char(32) character set latin1 collate latin1_bin default NULL,
  template_id mediumint(8) unsigned default NULL,
  asped date default NULL,
  strand enum('Forward','Reverse') default NULL,
  primer enum('Universal_primer','Custom','Unknown_primer') default NULL,
  chemistry enum('Dye_terminator','Dye_primer') default NULL,
  basecaller tinyint(3) unsigned default NULL,
  `status` tinyint(3) unsigned default '0',
  PRIMARY KEY  (read_id),
  UNIQUE KEY readname (readname),
  UNIQUE KEY RECORD_INDEX (readname),
  UNIQUE KEY READNAMES (readname),
  KEY template_id (template_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'READTAG'
#

CREATE TABLE READTAG (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  tagtype varchar(4) character set latin1 collate latin1_bin NOT NULL default '',
  tag_seq_id mediumint(8) unsigned NOT NULL default '0',
  pstart smallint(5) unsigned NOT NULL default '0',
  pfinal smallint(5) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  deprecated enum('N','Y','X') default 'N',
  `comment` tinytext,
  KEY readtag_index (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


#
# Table structure for table 'SCAFFOLD'
#

CREATE TABLE SCAFFOLD (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  scaffold smallint(5) unsigned NOT NULL default '0',
  orientation enum('F','R','U') default 'U',
  ordering smallint(5) unsigned NOT NULL default '0',
  zeropoint int(11) default '0',
  astatus enum('N','C','S','X') default 'N',
  PRIMARY KEY  (contig_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'SEGMENT'
#

CREATE TABLE SEGMENT (
  mapping_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(10) unsigned NOT NULL default '0',
  rstart smallint(5) unsigned NOT NULL default '0',
  length smallint(5) unsigned NOT NULL default '1',
  KEY mapping_id (mapping_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'SEQ2READ'
#

CREATE TABLE SEQ2READ (
  seq_id mediumint(8) unsigned NOT NULL auto_increment,
  read_id mediumint(8) unsigned NOT NULL default '0',
  version mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (seq_id),
  UNIQUE KEY read_id (read_id,version)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'SEQUENCE'
#

CREATE TABLE SEQUENCE (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  sequence blob NOT NULL,
  quality blob NOT NULL,
  seqlen smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 MAX_ROWS=8000000 AVG_ROW_LENGTH=900;

#
# Table structure for table 'SEQUENCEVECTOR'
#

CREATE TABLE SEQUENCEVECTOR (
  svector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  PRIMARY KEY  (svector_id),
  UNIQUE KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'SEQVEC'
#

CREATE TABLE SEQVEC (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  svector_id tinyint(3) unsigned NOT NULL default '0',
  svleft smallint(5) unsigned NOT NULL default '0',
  svright smallint(5) unsigned NOT NULL default '0',
  KEY seq_id (seq_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'STATUS'
#

CREATE TABLE `STATUS` (
  status_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(64) default NULL,
  PRIMARY KEY  (status_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'TAG2CONTIG'
#

CREATE TABLE TAG2CONTIG (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  tag_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(11) unsigned NOT NULL default '0',
  cfinal int(11) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  `comment` tinytext,
  KEY tag2contig_index (contig_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


#
# Table structure for table 'ANNOTATIONTAG2CONTIG'
#

#***
CREATE TABLE ANNOTATIONTAG2CONTIG (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  tag_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(11) unsigned NOT NULL default '0',
  cfinal int(11) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  `comment` tinytext,
  KEY annotationtag2contig_index (contig_id,tag_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'FINISHINGTAG2CONTIG'
#

CREATE TABLE FINISHINGTAG2CONTIG (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  tag_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(11) unsigned NOT NULL default '0',
  cfinal int(11) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  `comment` tinytext,
  KEY finishingtag2contig_index (contig_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#***

#
# Table structure for table 'TAGSEQUENCE'
#

CREATE TABLE TAGSEQUENCE (
  tag_seq_id mediumint(8) unsigned NOT NULL auto_increment,
  tagseqname varchar(32) character set latin1 collate latin1_bin NOT NULL default '',
  sequence blob,
  PRIMARY KEY  (tag_seq_id),
  UNIQUE KEY tagseqname (tagseqname)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'TEMPLATE'
#

CREATE TABLE TEMPLATE (
  template_id mediumint(8) unsigned NOT NULL auto_increment,
  name char(24) character set latin1 collate latin1_bin default NULL,
  ligation_id smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (template_id),
  UNIQUE KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'TESTCONSENSUS'
#

CREATE TABLE TESTCONSENSUS (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  sequence longblob NOT NULL,
  quality longblob NOT NULL,
  length int(10) unsigned default '0',
  PRIMARY KEY  (contig_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#
# Table structure for table 'TRACEARCHIVE'
#

CREATE TABLE TRACEARCHIVE (
  read_id mediumint(8) unsigned NOT NULL default '0',
  traceref varchar(255) NOT NULL default '',
  PRIMARY KEY  (read_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


#
# Table structure for table 'USER'
#

CREATE TABLE `USER` (
  username char(8) NOT NULL default '',
  role char(32) NOT NULL default 'finisher',
  can_create_new_project enum('N','Y') NOT NULL default 'N',
  can_assign_project enum('N','Y') NOT NULL default 'N',
  can_move_any_contig enum('N','Y') NOT NULL default 'N',
  can_grant_privileges enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (username)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT into USER values ('arcturus','superuser','Y','Y','Y','Y');
INSERT into USER values ('adh','administrator','Y','Y','Y','Y');
INSERT into USER values ('ejz','administrator','Y','Y','Y','Y');
