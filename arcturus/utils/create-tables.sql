# Table creation script for an Arcturus database

#
# Table structure for table 'ASSEMBLY'
#

CREATE TABLE ASSEMBLY (
  assembly smallint(5) unsigned NOT NULL auto_increment,
  assemblyname varchar(16) NOT NULL default '',
  organism smallint(5) unsigned NOT NULL default '0',
  chromosome tinyint(3) unsigned default '0',
  origin varchar(32) NOT NULL default 'The Sanger Institute',
  oracleproject tinyint(3) unsigned default '0',
  size mediumint(8) unsigned default '0',
  length int(10) unsigned default '0',
  l2000 int(10) unsigned default '0',
  reads int(10) unsigned default '0',
  assembled int(10) unsigned default '0',
  contigs int(10) unsigned default '0',
  allcontigs int(10) unsigned default '0',
  projects smallint(6) default '0',
  progress enum('in shotgun','in finishing','finished','other') default 'other',
  updated datetime default NULL,
  userid varchar(8) default NULL,
  status enum('loading','complete','error','virgin','unknown') default 'virgin',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  creator varchar(8) NOT NULL default 'arcturus',
  attributes blob,
  comment varchar(255) default NULL,
  PRIMARY KEY  (assembly),
  UNIQUE KEY assemblyname (assemblyname)
) TYPE=MyISAM;

#
# Table structure for table 'BASECALLER'
#

CREATE TABLE BASECALLER (
  basecaller_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(32) NOT NULL default '',
  PRIMARY KEY  (basecaller_id)
) TYPE=MyISAM;

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
) TYPE=MyISAM;

#
# Table structure for table 'CLONE'
#

CREATE TABLE CLONE (
  clone_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  origin varchar(20) default 'The Sanger Institute',
  PRIMARY KEY  (clone_id)
) TYPE=MyISAM;

#
# Table structure for table 'CLONE2CONTIG'
#

CREATE TABLE CLONE2CONTIG (
  clone_id smallint(5) unsigned NOT NULL default '0',
  contig_id mediumint(8) unsigned NOT NULL default '0',
  ocp_start int(10) unsigned NOT NULL default '0',
  ocp_final int(10) unsigned NOT NULL default '0',
  reads mediumint(9) NOT NULL default '0',
  cover float NOT NULL default '0'
) TYPE=MyISAM;

#
# Table structure for table 'CLONE2PROJECT'
#

CREATE TABLE CLONE2PROJECT (
  clone smallint(5) unsigned NOT NULL default '0',
  project smallint(5) unsigned NOT NULL default '0'
) TYPE=MyISAM;

#
# Table structure for table 'CLONEVEC'
#

CREATE TABLE CLONEVEC (
  seq_id mediumint(8) unsigned NOT NULL,
  cvector_id tinyint(3) unsigned NOT NULL,
  cvleft smallint unsigned NOT NULL,
  cvright smallint unsigned NOT NULL,
  KEY seq_id (seq_id)
) TYPE=MyISAM;

#
# Table structure for table 'CLONINGVECTOR'
#

CREATE TABLE CLONINGVECTOR (
  cvector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(16) NOT NULL default '',
  PRIMARY KEY  (cvector_id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

#
# Table structure for table 'CONSENSUS'
#

CREATE TABLE CONSENSUS (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  sequence longblob NOT NULL,
  quality longblob NOT NULL,
  length int(10) unsigned default '0',
  PRIMARY KEY  (contig_id)
) TYPE=MyISAM;

#
# Table structure for table 'CONTIG'
#

CREATE TABLE CONTIG (
  contig_id mediumint(8) unsigned NOT NULL auto_increment,
  length int(10) unsigned default '0',
  ncntgs smallint(5) unsigned NOT NULL default '0',
  nreads mediumint(8) unsigned NOT NULL default '0',
  newreads mediumint(9) NOT NULL default '0',
  cover float(8,2) default '0.00',
  origin enum('Arcturus CAF parser','Finishing Software','Other') default NULL,
  userid char(8) default 'arcturus',
  updated datetime NOT NULL default '0000-00-00 00:00:00',
  readnamehash char(16) default NULL,
  PRIMARY KEY  (contig_id),
  KEY rnhash (readnamehash(8))
) TYPE=MyISAM;

#
# Table structure for table 'CONTIG2PROJECT'
#

CREATE TABLE CONTIG2PROJECT (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  checked enum('in','out') default 'in',
  project smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (contig_id)
) TYPE=MyISAM;

#
# Table structure for table 'GAP4TAG'
#

CREATE TABLE GAP4TAG (
  tag_id mediumint(8) unsigned NOT NULL auto_increment,
  tagname varchar(4) NOT NULL default '',
  taglabel varchar(255) NOT NULL default '',
  deprecated enum('N','Y','X') default 'N',
  PRIMARY KEY  (tag_id)
) TYPE=MyISAM;

#
# Table structure for table 'LIGATION'
#

CREATE TABLE LIGATION (
  ligation_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  clone_id smallint(5) unsigned NOT NULL,
  silow mediumint(8) unsigned default NULL,
  sihigh mediumint(8) unsigned default NULL,
  svector_id smallint(5) NOT NULL,
  PRIMARY KEY  (ligation_id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

#
# Table structure for table 'MAPPING'
#

CREATE TABLE MAPPING (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  seq_id mediumint(8) unsigned NOT NULL default '0',
  mapping_id mediumint(8) unsigned NOT NULL auto_increment,
  cstart int(10) unsigned NULL,
  cfinish int(10) unsigned NULL,
  direction enum('Forward','Reverse') NOT NULL default 'Forward',
  PRIMARY KEY  (mapping_id),
  KEY contig_id (contig_id),
  KEY seq_id (seq_id)
) TYPE=MyISAM;

#
# Table structure for table 'PROJECT'
#

CREATE TABLE PROJECT (
  project smallint(5) unsigned NOT NULL auto_increment,
  projectname varchar(24) NOT NULL default '',
  projecttype enum('Finishing','Annotation','Comparative Sequencing','Bin','Other') default 'Bin',
  assembly tinyint(3) unsigned default '0',
  reads int(10) unsigned default '0',
  contigs int(10) unsigned default '0',
  updated datetime default NULL,
  userid varchar(8) default NULL,
  created datetime default NULL,
  creator varchar(8) NOT NULL default 'arcturus',
  attributes blob,
  comment varchar(255) default NULL,
  status enum('Dormant','Active','Completed','Merged') default 'Dormant',
  PRIMARY KEY  (project),
  UNIQUE KEY projectname (projectname)
) TYPE=MyISAM;

#
# Table structure for table 'READCOMMENT'
#

CREATE TABLE READCOMMENT (
  read_id mediumint(8) unsigned NOT NULL default '0',
  comment varchar(255) default NULL,
  KEY read_id (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'READ'
#

CREATE TABLE READS (
  read_id mediumint(8) unsigned NOT NULL auto_increment,
  readname char(32) binary default NULL,
  template_id mediumint(8) unsigned default NULL,
  asped date default NULL,
  strand enum('Forward', 'Reverse') default NULL,
  primer enum('Universal_primer', 'Custom', 'Unknown_primer') default NULL,
  chemistry enum('Dye_terminator', 'Dye_primer') default NULL,
  basecaller tinyint(3) unsigned default NULL,
  status tinyint(3) unsigned default '0',
  PRIMARY KEY  (read_id),
  UNIQUE KEY readname (readname),
  UNIQUE KEY RECORD_INDEX (readname),
  UNIQUE KEY READNAMES (readname),
  KEY template_id (template_id)
) TYPE=MyISAM;

#
# Table structure for table 'READ2ASSEMBLY'
#

CREATE TABLE READ2ASSEMBLY (
  read_id mediumint(8) unsigned NOT NULL default '0',
  assembly tinyint(3) unsigned NOT NULL default '0',
  astatus enum('0','1','2') default '0',
  PRIMARY KEY  (read_id),
  KEY bin_index (assembly)
) TYPE=MyISAM;

#
# Table structure for table 'READTAG'
#

CREATE TABLE READTAG (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  readtag varchar(4) binary NOT NULL default '',
  pstart smallint(5) unsigned NOT NULL default '0',
  pfinal smallint(5) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  comment varchar(128) default NULL,
  deprecated enum('N','Y','X') default 'N',
  KEY reads_index (seq_id)
) TYPE=MyISAM;

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
) TYPE=MyISAM;

#
# Table structure for table 'SEGMENT'
#

CREATE TABLE SEGMENT (
  mapping_id mediumint(8) unsigned NOT NULL default '0',
  cstart int(10) unsigned NOT NULL default '0',
  rstart smallint(5) unsigned NOT NULL default '0',
  length smallint(5) unsigned NOT NULL default '1',
  KEY mapping_id (mapping_id)
) TYPE=MyISAM;

#
# Table structure for table 'SEQUENCE'
#

CREATE TABLE SEQUENCE (
  seq_id mediumint(8) unsigned NOT NULL default '0',
  sequence blob NOT NULL,
  quality blob NOT NULL,
  seqlen smallint unsigned NOT NULL,
  PRIMARY KEY  (seq_id)
) TYPE=MyISAM MAX_ROWS=8000000 AVG_ROW_LENGTH=900;

#
# Table structure for table 'SEQVEC'
#

CREATE TABLE SEQVEC (
  seq_id mediumint(8) unsigned NOT NULL,
  svector_id tinyint(3) unsigned NOT NULL,
  svleft smallint unsigned NOT NULL,
  svright smallint unsigned NOT NULL,
  KEY seq_id (seq_id)
) TYPE=MyISAM;

#
# Table structure for table 'SEQUENCEVECTOR'
#

CREATE TABLE SEQUENCEVECTOR (
  svector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  PRIMARY KEY  (svector_id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

#
# Table structure for table 'STATUS'
#

CREATE TABLE STATUS (
  status_id smallint(5) unsigned NOT NULL auto_increment,
  name varchar(64) default NULL,
  PRIMARY KEY (status_id)
) TYPE=MyISAM;

#
# Table structure for table 'STSTAG'
#

CREATE TABLE STSTAG (
  tag_id mediumint(8) unsigned NOT NULL auto_increment,
  tagname varchar(6) NOT NULL default '',
  sequence blob NOT NULL,
  scompress tinyint(3) unsigned NOT NULL default '0',
  slength smallint(5) unsigned NOT NULL default '0',
  position float default NULL,
  linkage smallint(5) unsigned NOT NULL default '0',
  assembly tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (tag_id),
  UNIQUE KEY tagname (tagname)
) TYPE=MyISAM;

#
# Table structure for table 'TAG2CONTIG'
#

CREATE TABLE TAG2CONTIG (
  tag_id mediumint(8) unsigned NOT NULL default '0',
  contig_id mediumint(8) unsigned NOT NULL default '0',
  tcp_start int(10) unsigned NOT NULL default '0',
  tcp_final int(10) unsigned NOT NULL default '0'
) TYPE=MyISAM;

#
# Table structure for table 'TEMPLATE'
#

CREATE TABLE TEMPLATE (
  template_id mediumint(8) unsigned NOT NULL auto_increment,
  name char(24) binary default NULL,
  ligation_id smallint unsigned NOT NULL,
  PRIMARY KEY (template_id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

#
# Table structure for table 'TRACEARCHIVE'
#

CREATE TABLE TRACEARCHIVE (
  read_id MEDIUMINT UNSIGNED NOT NULL, 
  traceref VARCHAR(255) NOT NULL,
  PRIMARY KEY (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'USER2PROJECT'
#

CREATE TABLE USER2PROJECT (
  userid char(8) NOT NULL default '',
  project smallint(5) unsigned NOT NULL default '0',
  date_from date default NULL,
  date_end date default NULL
) TYPE=MyISAM;

#
# Table structure for table 'SEQ2READ'
#

CREATE TABLE SEQ2READ (
  seq_id mediumint unsigned NOT NULL auto_increment,
  read_id mediumint unsigned NOT NULL,
  version mediumint unsigned NOT NULL default '0',
  primary key (seq_id),
  unique key (read_id, version)
) TYPE=MyISAM;

#
# Table structure for table 'QUALITYCLIP'
#

CREATE TABLE QUALITYCLIP (
  seq_id mediumint unsigned NOT NULL,
  qleft smallint unsigned NOT NULL,
  qright smallint unsigned NOT NULL,
  primary key (seq_id)
) TYPE=MyISAM;

#
# Table structure for table 'ALIGN2SCF'
#

CREATE TABLE ALIGN2SCF (
  seq_id mediumint unsigned NOT NULL,
  startinseq smallint unsigned NOT NULL,
  startinscf smallint unsigned NOT NULL,
  length smallint unsigned NOT NULL,
  KEY (seq_id)
) TYPE=MyISAM;

#
# Table structure for table 'C2CMAPPING'
#

CREATE TABLE C2CMAPPING (
  age smallint(5) unsigned default '0',
  contig_id mediumint(8) unsigned NOT NULL default '0',
  parent_id mediumint(8) unsigned NOT NULL default '0',
  mapping_id mediumint(8) unsigned NOT NULL auto_increment,
  cstart int(10) unsigned NULL,
  cfinish int(10) unsigned NULL,
  direction enum('Forward','Reverse') default 'Forward',
  PRIMARY KEY  (mapping_id),
  KEY contig_id (contig_id),
  KEY parent_id (parent_id)
) TYPE=MyISAM;

#
# Table structure for table 'C2CSEGMENT'
#

CREATE TABLE C2CSEGMENT (
  mapping_id mediumint(8) unsigned NOT NULL,
  cstart int(10) unsigned NOT NULL default '0',
  pstart int(10) unsigned NOT NULL default '0',
  length int(10) unsigned NOT NULL default '1',
  KEY mapping_id (mapping_id)
) TYPE=MyISAM;






