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
  basecaller smallint(5) unsigned NOT NULL auto_increment,
  name varchar(32) NOT NULL default '',
  counted int(10) unsigned default '0',
  PRIMARY KEY  (basecaller)
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
# Table structure for table 'CLONES'
#

CREATE TABLE CLONES (
  clone smallint(5) unsigned NOT NULL auto_increment,
  clonename varchar(20) NOT NULL default '',
  clonetype enum('PUC finishing','PCR product','unknown') default 'unknown',
  library enum('transposition','small insert','unknown') default 'unknown',
  origin varchar(20) default 'The Sanger Institute',
  counted mediumint(8) unsigned default '0',
  PRIMARY KEY  (clone)
) TYPE=MyISAM;

#
# Table structure for table 'CLONES2CONTIG'
#

CREATE TABLE CLONES2CONTIG (
  clone_id smallint(5) unsigned NOT NULL default '0',
  contig_id mediumint(8) unsigned NOT NULL default '0',
  ocp_start int(10) unsigned NOT NULL default '0',
  ocp_final int(10) unsigned NOT NULL default '0',
  reads mediumint(9) NOT NULL default '0',
  cover float NOT NULL default '0'
) TYPE=MyISAM;

#
# Table structure for table 'CLONES2PROJECT'
#

CREATE TABLE CLONES2PROJECT (
  clone smallint(5) unsigned NOT NULL default '0',
  project smallint(5) unsigned NOT NULL default '0'
) TYPE=MyISAM;

#
# Table structure for table 'CLONEVEC'
#

CREATE TABLE CLONEVEC (
  read_id mediumint(8) unsigned NOT NULL,
  cvector_id tinyint(3) unsigned NOT NULL,
  begin smallint unsigned NOT NULL,
  end smallint unsigned NOT NULL,
  KEY read_id (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'CLONINGVECTORS'
#

CREATE TABLE CLONINGVECTORS (
  cvector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(16) NOT NULL default '',
  vector tinyint(3) unsigned default '0',
  counted int(10) unsigned default '0',
  PRIMARY KEY  (cvector_id)
) TYPE=MyISAM;

#
# Table structure for table 'CONSENSUS'
#

CREATE TABLE CONSENSUS (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  sequence longblob NOT NULL,
  quality longblob NOT NULL,
  length int(11) default '0',
  PRIMARY KEY  (contig_id)
) TYPE=MyISAM;

#
# Table structure for table 'CONTIGS'
#

CREATE TABLE CONTIGS (
  contig_id mediumint(8) unsigned NOT NULL auto_increment,
  contigname varchar(32) NOT NULL default '',
  aliasname varchar(32) NOT NULL default '',
  length int(11) default '0',
  ncntgs smallint(5) unsigned NOT NULL default '0',
  nreads mediumint(8) unsigned NOT NULL default '0',
  newreads mediumint(9) NOT NULL default '0',
  cover float(8,2) default '0.00',
  origin enum('Arcturus CAF parser','Finishing Software','Other') default NULL,
  userid varchar(8) default 'arcturus',
  updated datetime NOT NULL default '0000-00-00 00:00:00',
  readnamehash varchar(16) default NULL,
  PRIMARY KEY  (contig_id),
  KEY rnhash (readnamehash(8))
) TYPE=MyISAM;

#
# Table structure for table 'CONTIGS2CONTIG'
#

CREATE TABLE CONTIGS2CONTIG (
  genofo smallint(5) unsigned default '0',
  newcontig mediumint(8) unsigned NOT NULL default '0',
  nranges int(11) default '0',
  nrangef int(11) default '0',
  oldcontig mediumint(8) unsigned NOT NULL default '0',
  oranges int(11) default '0',
  orangef int(11) default '0'
) TYPE=MyISAM;

#
# Table structure for table 'CONTIGS2PROJECT'
#

CREATE TABLE CONTIGS2PROJECT (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  checked enum('in','out') default 'in',
  project smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (contig_id)
) TYPE=MyISAM;

#
# Table structure for table 'GAP4TAGS'
#

CREATE TABLE GAP4TAGS (
  tag_id mediumint(8) unsigned NOT NULL auto_increment,
  tagname varchar(4) NOT NULL default '',
  taglabel varchar(255) NOT NULL default '',
  deprecated enum('N','Y','X') default 'N',
  PRIMARY KEY  (tag_id)
) TYPE=MyISAM;

#
# Table structure for table 'LIGATIONS'
#

CREATE TABLE LIGATIONS (
  ligation_id smallint(5) unsigned NOT NULL auto_increment,
  identifier varchar(20) NOT NULL default '',
  clone varchar(20) NOT NULL default '',
  origin char(1) default NULL,
  silow mediumint(8) unsigned default NULL,
  sihigh mediumint(8) unsigned default NULL,
  svector smallint(6) NOT NULL default '0',
  counted int(10) unsigned default '0',
  PRIMARY KEY  (ligation_id)
) TYPE=MyISAM;

#
# Table structure for table 'MAPPING'
#

CREATE TABLE MAPPING (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  read_id mediumint(8) unsigned NOT NULL default '0',
  mapping_id mediumint(8) unsigned NOT NULL auto_increment,
  revision mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (mapping_id),
  KEY contig_id (contig_id),
  KEY read_id (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'PROJECTS'
#

CREATE TABLE PROJECTS (
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
  PRIMARY KEY  (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'READEDITS'
#

CREATE TABLE READEDITS (
  read_id mediumint(8) unsigned NOT NULL default '0',
  base smallint(5) unsigned NOT NULL default '0',
  edit char(4) default NULL,
  deprecated enum('N','Y','X') default 'N',
  KEY reads_index (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'READPAIRS'
#

CREATE TABLE READPAIRS (
  forward mediumint(8) unsigned NOT NULL default '0',
  reverse mediumint(8) unsigned NOT NULL default '0',
  score enum('0','1','2','-1','-2','U') NOT NULL default 'U',
  KEY rfindex (forward),
  KEY rrindex (reverse)
) TYPE=MyISAM;

#
# Table structure for table 'READS'
#

CREATE TABLE READS (
  read_id mediumint(8) unsigned NOT NULL auto_increment,
  readname char(32) binary default NULL,
  asped date NOT NULL default '0000-00-00',
  clone smallint(5) unsigned default NULL,
  strand enum('Forward', 'Reverse') default NULL,
  primer enum('Universal_primer', 'Custom', 'Unknown_primer') default NULL,
  chemistry enum('Dye_terminator', 'Dye_primer') default NULL,
  basecaller tinyint(3) unsigned default NULL,
  slength smallint(5) unsigned NOT NULL default '0',
  lqleft smallint(5) unsigned NOT NULL default '0',
  lqright smallint(5) unsigned NOT NULL default '0',
  svcsite smallint(6) default NULL,
  svpsite smallint(6) default NULL,
  pstatus tinyint(3) unsigned default '0',
  tstatus enum('N','I','T') default 'N',
  template_id mediumint(8) unsigned default NULL,
  PRIMARY KEY  (read_id),
  UNIQUE KEY readname (readname),
  UNIQUE KEY RECORD_INDEX (readname),
  UNIQUE KEY READNAMES (readname),
  KEY template_id (template_id)
) TYPE=MyISAM;

#
# Table structure for table 'READS2ASSEMBLY'
#

CREATE TABLE READS2ASSEMBLY (
  read_id mediumint(8) unsigned NOT NULL default '0',
  assembly tinyint(3) unsigned NOT NULL default '0',
  astatus enum('0','1','2') default '0',
  PRIMARY KEY  (read_id),
  KEY bin_index (assembly)
) TYPE=MyISAM;

#
# Table structure for table 'READS2CONTIG'
#

CREATE TABLE READS2CONTIG (
  contig_id mediumint(8) unsigned NOT NULL default '0',
  pcstart int(10) unsigned NOT NULL default '0',
  pcfinal int(10) unsigned NOT NULL default '0',
  read_id mediumint(8) unsigned NOT NULL default '0',
  prstart smallint(5) unsigned NOT NULL default '0',
  prfinal smallint(5) unsigned NOT NULL default '0',
  label tinyint(3) unsigned NOT NULL default '0',
  clone smallint(5) unsigned NOT NULL default '0',
  assembly smallint(5) unsigned NOT NULL default '0',
  generation smallint(5) unsigned NOT NULL default '0',
  deprecated enum('N','M','Y','X') default 'X',
  blocked enum('0','1') default '0',
  KEY reads_index (read_id),
  KEY cntgs_index (contig_id)
) TYPE=MyISAM;

#
# Table structure for table 'READTAGS'
#

CREATE TABLE READTAGS (
  read_id mediumint(8) unsigned NOT NULL default '0',
  readtag varchar(4) binary NOT NULL default '',
  pstart smallint(5) unsigned NOT NULL default '0',
  pfinal smallint(5) unsigned NOT NULL default '0',
  strand enum('F','R','U') default 'U',
  comment varchar(128) default NULL,
  deprecated enum('N','Y','X') default 'N',
  KEY reads_index (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'SCAFFOLDS'
#

CREATE TABLE SCAFFOLDS (
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
  pcstart int(10) unsigned NOT NULL default '0',
  pcfinal int(10) unsigned NOT NULL default '0',
  prstart smallint(5) unsigned NOT NULL default '0',
  prfinal smallint(5) unsigned NOT NULL default '0',
  label tinyint(3) unsigned NOT NULL default '0',
  KEY mapping_id (mapping_id)
) TYPE=MyISAM;

#
# Table structure for table 'SEQUENCE'
#

CREATE TABLE SEQUENCE (
  read_id mediumint(8) unsigned NOT NULL default '0',
  sequence blob NOT NULL,
  quality blob NOT NULL,
  PRIMARY KEY  (read_id)
) TYPE=MyISAM MAX_ROWS=8000000 AVG_ROW_LENGTH=900;

#
# Table structure for table 'SEQVEC'
#

CREATE TABLE SEQVEC (
  read_id mediumint(8) unsigned NOT NULL,
  svector_id tinyint(3) unsigned NOT NULL,
  begin smallint unsigned NOT NULL,
  end smallint unsigned NOT NULL,
  KEY read_id (read_id)
) TYPE=MyISAM;

#
# Table structure for table 'SEQUENCEVECTORS'
#

CREATE TABLE SEQUENCEVECTORS (
  svector_id tinyint(3) unsigned NOT NULL auto_increment,
  name varchar(20) NOT NULL default '',
  vector tinyint(3) unsigned default '0',
  counted int(10) unsigned default '0',
  PRIMARY KEY  (svector_id)
) TYPE=MyISAM;

#
# Table structure for table 'STATUS'
#

CREATE TABLE STATUS (
  status smallint(5) unsigned NOT NULL auto_increment,
  identifier varchar(64) default NULL,
  comment varchar(8) default NULL,
  counted int(10) unsigned default '0',
  PRIMARY KEY  (status)
) TYPE=MyISAM;

#
# Table structure for table 'STSTAGS'
#

CREATE TABLE STSTAGS (
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
# Table structure for table 'TAGS2CONTIG'
#

CREATE TABLE TAGS2CONTIG (
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
  PRIMARY KEY  (template_id)
) TYPE=MyISAM;

#
# Table structure for table 'USERS2PROJECTS'
#

CREATE TABLE USERS2PROJECTS (
  userid char(8) NOT NULL default '',
  project smallint(5) unsigned NOT NULL default '0',
  date_from date default NULL,
  date_end date default NULL
) TYPE=MyISAM;

