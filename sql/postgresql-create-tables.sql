create language 'plpgsql';

create or replace function auto_update_timestamp() returns trigger as '
  begin
  NEW.updated = now();
  return NEW;
  end
' language 'plpgsql'; 

--
-- Table structure for table ALIGN2SCF
--

CREATE TABLE ALIGN2SCF (
  seq_id integer NOT NULL,
  startinseq integer NOT NULL,
  startinscf integer NOT NULL,
  length integer NOT NULL
);

CREATE INDEX align2scf_seq_id_key ON ALIGN2SCF(seq_id);

--
-- Table structure for table ASSEMBLY
--

create sequence assembly_id_seq;

create type assembly_progress_enum as ENUM ('shotgun','finishing','finished','other');

CREATE TABLE ASSEMBLY (
  assembly_id smallint NOT NULL PRIMARY KEY default nextval('assembly_id_seq'),
  name varchar(16) NOT NULL default '',
  chromosome smallint default '0',
  origin varchar(32) NOT NULL default 'The Sanger Institute',
  size integer default '0',
  progress assembly_progress_enum default 'other',
  updated timestamp NOT NULL,
  created timestamp NOT NULL,
  creator varchar(8) NOT NULL default 'arcturus',
  comment text
);

CREATE INDEX assembly_name_key ON ASSEMBLY(assembly_id);

create trigger assembly_update_timestamp
    before insert or update on ASSEMBLY
    for each row execute procedure auto_update_timestamp();

--
-- Table structure for table BASECALLER
--

create sequence basecaller_id_seq;

CREATE TABLE BASECALLER (
  basecaller_id smallint NOT NULL PRIMARY KEY default nextval('basecaller_id_seq'),
  name varchar(32) NOT NULL default ''
);

--
-- Table structure for table C2CMAPPING
--

create sequence c2cmapping_id_seq;

create type c2cmapping_direction_enum AS ENUM('Forward','Reverse');

CREATE TABLE C2CMAPPING (
  mapping_id integer NOT NULL PRIMARY KEY default nextval('c2cmapping_id_seq'),
  age smallint default '0',
  contig_id integer NOT NULL default '0',
  parent_id integer NOT NULL default '0',
  cstart integer default NULL,
  cfinish integer default NULL,
  pstart integer default NULL,
  pfinish integer default NULL,
  direction c2cmapping_direction_enum default 'Forward'
);

CREATE INDEX assembly_contig_id_key ON C2CMAPPING(contig_id);
CREATE INDEX assembly_parent_id_key ON C2CMAPPING(parent_id);


--
-- Table structure for table C2CSEGMENT
--

CREATE TABLE C2CSEGMENT (
  mapping_id integer NOT NULL default '0',
  cstart integer NOT NULL default '0',
  pstart integer NOT NULL default '0',
  length integer default NULL
);

CREATE INDEX c2csegment_mapping_id_key ON C2CSEGMENT(mapping_id);

--
-- Table structure for table CLONE
--

create sequence clone_id_seq;

CREATE TABLE CLONE (
  clone_id smallint NOT NULL PRIMARY KEY default nextval('clone_id_seq'),
  name varchar(20) NOT NULL,
  origin varchar(20) default 'The Sanger Institute',
  assembly_id smallint default '0'
);

--
-- Table structure for table CLONEMAP
--

CREATE TABLE CLONEMAP (
  clonename varchar(20) NOT NULL PRIMARY KEY,
  assembly smallint NOT NULL default '0',
  cpkbstart integer NOT NULL default '0',
  cpkbfinal integer NOT NULL default '0'
);

CREATE INDEX clonemap_clonename_key ON CLONEMAP(clonename);

--
-- Table structure for table CLONEVEC
--

CREATE TABLE CLONEVEC (
  seq_id integer NOT NULL default '0',
  cvector_id smallint NOT NULL default '0',
  cvleft integer NOT NULL,
  cvright integer NOT NULL
);

CREATE INDEX clonevec_seq_id_key ON CLONEVEC(seq_id);

--
-- Table structure for table CLONINGVECTOR
--

create sequence cloningvector_seq;

CREATE TABLE CLONINGVECTOR (
  cvector_id smallint NOT NULL PRIMARY KEY default nextval('cloningvector_seq'),
  name varchar(16) NOT NULL default ''
);

CREATE INDEX cloningvector_name_key ON CLONINGVECTOR(name);

--
-- Table structure for table CONSENSUS
--

CREATE TABLE CONSENSUS (
  contig_id integer NOT NULL PRIMARY KEY,
  sequence bytea NOT NULL,
  quality bytea NOT NULL,
  length integer default '0'
);

--
-- Table structure for table CONTIG
--

create sequence contig_id_seq;

create type contig_origin_enum as ENUM('Arcturus CAF parser','Finishing Software','Other');

CREATE TABLE CONTIG (
  contig_id integer NOT NULL PRIMARY KEY default nextval('contig_id_seq'),
  gap4name char(32)default NULL,
  length integer default '0',
  ncntgs smallint NOT NULL default '0',
  nreads integer NOT NULL default '0',
  project_id integer NOT NULL default '0',
  newreads integer NOT NULL default '0',
  cover float default '0.00',
  origin contig_origin_enum default NULL,
  userid char(8) default 'arcturus',
  created timestamp default NULL,
  updated timestamp NOT NULL,
  readnamehash char(16) default NULL
);

CREATE INDEX contig_readnamehash_key ON CONTIG(readnamehash);

create trigger contig_update_timestamp
    before insert or update on CONTIG
    for each row execute procedure auto_update_timestamp();

--
-- Table structure for table CONTIGTAG
--

create sequence contigtag_tag_id_seq;

CREATE TABLE CONTIGTAG (
  tag_id integer NOT NULL PRIMARY KEY default nextval('contigtag_tag_id_seq'),
  tagtype varchar(4) NOT NULL,
  systematic_id varchar(32) default NULL,
  tag_seq_id integer NOT NULL,
  tagcomment text
);

--
-- Table structure for table CONTIGTRANSFERREQUEST
--

create sequence contigtransfer_request_id_seq;

create type contigtransfer_status_enum AS 
  ENUM('approved','cancelled','done','failed','pending','refused');

CREATE TABLE CONTIGTRANSFERREQUEST (
  request_id integer NOT NULL PRIMARY KEY
    default nextval('contigtransfer_request_id_seq'),
  contig_id integer NOT NULL default '0',
  old_project_id integer NOT NULL default '0',
  new_project_id integer NOT NULL default '0',
  requester varchar(8) NOT NULL default '',
  opened timestamp NOT NULL,
  requester_comment varchar(255) default NULL,
  reviewer varchar(8) default NULL,
  updated timestamp not null,
  reviewer_comment varchar(255) default NULL,
  status contigtransfer_status_enum NOT NULL default 'pending',
  closed timestamp default NULL
);

create trigger contigtransfer_update_timestamp
    before insert or update on CONTIGTRANSFERREQUEST
    for each row execute procedure auto_update_timestamp();

--
-- Table structure for table IMPORTEXPORT
--

create type importexport_action_enum AS ENUM('import','export');

CREATE TABLE IMPORTEXPORT (
  project_id integer NOT NULL,
  action importexport_action_enum NOT NULL,
  username char(8) NOT NULL,
  file char(100) NOT NULL,
  date timestamp NOT NULL
);

CREATE INDEX importexport_project_id_key ON IMPORTEXPORT(project_id);

--
-- Table structure for table LIGATION
--

create sequence ligation_id_seq;

CREATE TABLE LIGATION (
  ligation_id smallint NOT NULL PRIMARY KEY default nextval('ligation_id_seq'),
  name varchar(20) NOT NULL default '',
  clone_id smallint NOT NULL default 0,
  silow integer default NULL,
  sihigh integer default NULL,
  svector_id smallint NOT NULL default 0
);

CREATE INDEX ligation_name_key ON LIGATION(name);

--
-- Table structure for table MAPPING
--

create sequence mapping_id_seq;

create type mapping_direction_enum AS ENUM('Forward','Reverse');

CREATE TABLE MAPPING (
  mapping_id integer NOT NULL PRIMARY KEY default nextval('mapping_id_seq'),
  contig_id integer NOT NULL,
  seq_id integer NOT NULL,
  cstart integer default NULL,
  cfinish integer default NULL,
  direction mapping_direction_enum NOT NULL default 'Forward'
);

CREATE INDEX mapping_contig_id_key ON MAPPING(contig_id);
CREATE INDEX mapping_seq_id_key on MAPPING(seq_id);

--
-- Table structure for table PRIVILEGE
--

CREATE TABLE PRIVILEGE (
  username char(8) NOT NULL,
  privilege char(32) NOT NULL
);

CREATE UNIQUE INDEX privilege_username_privilege_key ON PRIVILEGE(username,privilege);

CREATE INDEX privilege_username ON PRIVILEGE(username);

--
-- Table structure for table PROJECT
--

create sequence project_id_seq;

create type project_status_enum AS ENUM('in shotgun','prefinishing','in finishing','finished','quality checked','retired');

CREATE TABLE PROJECT (
  project_id integer NOT NULL PRIMARY KEY default nextval('project_id_seq'),
  assembly_id smallint default '0',
  name varchar(16) NOT NULL default '',
  updated timestamp NOT NULL,
  owner varchar(8) default NULL,
  lockdate timestamp default NULL,
  lockowner varchar(8) default NULL,
  created timestamp default NULL,
  creator varchar(8) NOT NULL default 'arcturus',
  comment text,
  status project_status_enum NOT NULL default 'in shotgun',
  directory varchar(256) default NULL
);

CREATE UNIQUE INDEX project_assembly_id_name ON PROJECT(assembly_id,name);

create trigger project_update_timestamp
    before insert or update on PROJECT
    for each row execute procedure auto_update_timestamp();

--
-- Table structure for table QUALITYCLIP
--

CREATE TABLE QUALITYCLIP (
  seq_id integer NOT NULL PRIMARY KEY,
  qleft integer NOT NULL,
  qright integer NOT NULL
);

--
-- Table structure for table READCOMMENT
--

CREATE TABLE READCOMMENT (
  read_id integer NOT NULL,
  comment text
);

CREATE INDEX readcomment_read_id_key ON READCOMMENT(read_id);

--
-- Table structure for table READINFO
--

create sequence readinfo_read_id_seq;

create type readinfo_strand_enum AS ENUM('Forward','Reverse');

create type readinfo_primer_enum AS ENUM('Universal_primer','Custom','Unknown_primer');

create type readinfo_chemistry_enum AS ENUM('Dye_terminator','Dye_primer');

CREATE TABLE READINFO (
  read_id integer NOT NULL PRIMARY KEY default nextval('readinfo_read_id_seq'),
  readname char(32) NOT NULL,
  template_id integer default NULL,
  asped date default NULL,
  strand readinfo_strand_enum default NULL,
  primer readinfo_primer_enum default NULL,
  chemistry readinfo_chemistry_enum default NULL,
  basecaller smallint default NULL,
  status smallint default 0
);

CREATE UNIQUE INDEX readinfo_readname_key ON READINFO(readname);

CREATE INDEX readinfo_template_id ON READINFO(template_id);

--
-- Table structure for table READTAG
--

create type readtag_strand_enum AS ENUM('F','R','U');

create type readtag_deprecated_enum AS ENUM('N','Y','X');

CREATE TABLE READTAG (
  seq_id integer NOT NULL,
  tagtype varchar(4) NOT NULL,
  tag_seq_id integer NOT NULL default '0',
  pstart integer NOT NULL,
  pfinal integer NOT NULL,
  strand readtag_strand_enum default 'U',
  deprecated readtag_deprecated_enum default 'N',
  comment text
);

CREATE INDEX readtag_seq_id_key ON READTAG(seq_id);

--
-- Table structure for table SCAFFOLD
--

create type scaffold_orientation_enum AS ENUM('F','R','U');

create type scaffold_astatus_enum AS ENUM('N','C','S','X');

CREATE TABLE SCAFFOLD (
  contig_id integer NOT NULL PRIMARY KEY,
  scaffold smallint NOT NULL default '0',
  orientation scaffold_orientation_enum default 'U',
  ordering smallint NOT NULL default '0',
  zeropoint integer default '0',
  astatus scaffold_astatus_enum default 'N'
);

--
-- Table structure for table SEGMENT
--

CREATE TABLE SEGMENT (
  mapping_id integer NOT NULL,
  cstart integer NOT NULL default '0',
  rstart integer NOT NULL,
  length integer NOT NULL
);

CREATE INDEX segment_mapping_id_key ON SEGMENT(mapping_id);

--
-- Table structure for table SEQ2READ
--

create sequence seq2read_seq_id_seq;

CREATE TABLE SEQ2READ (
  seq_id integer NOT NULL PRIMARY KEY default nextval('seq2read_seq_id_seq'),
  read_id integer NOT NULL default '0',
  version integer NOT NULL default '0'
);

CREATE UNIQUE INDEX seq2read_read_id_version ON SEQ2READ(read_id,version);

CREATE INDEX seq2read_read_id ON SEQ2READ(read_id);

--
-- Table structure for table SEQUENCE
--

CREATE TABLE SEQUENCE (
  seq_id integer NOT NULL PRIMARY KEY,
  seqlen integer NOT NULL,
  seq_hash bytea default NULL,
  qual_hash bytea default NULL,
  sequence bytea NOT NULL,
  quality bytea NOT NULL
);

--
-- Table structure for table SEQUENCEVECTOR
--

create sequence svector_id_seq;

CREATE TABLE SEQUENCEVECTOR (
  svector_id smallint NOT NULL PRIMARY KEY default nextval('svector_id_seq'),
  name varchar(20) NOT NULL default ''
);

CREATE UNIQUE INDEX sequencevector_name_key ON SEQUENCEVECTOR(name);

--
-- Table structure for table SEQVEC
--

CREATE TABLE SEQVEC (
  seq_id integer NOT NULL,
  svector_id smallint NOT NULL default '0',
  svleft integer NOT NULL,
  svright integer NOT NULL
);

CREATE INDEX seqvec_seq_id_key ON SEQVEC(seq_id);

--
-- Table structure for table STATUS
--

create sequence status_id_seq;

CREATE TABLE STATUS (
  status_id smallint NOT NULL PRIMARY KEY default nextval('status_id_seq'),
  name varchar(64) default NULL
);

--
-- Table structure for table TAG2CONTIG
--

create type tag2contig_strand_enum AS ENUM('F','R','U');

CREATE TABLE TAG2CONTIG (
  contig_id integer NOT NULL default '0',
  tag_id integer NOT NULL default '0',
  cstart integer NOT NULL default '0',
  cfinal integer NOT NULL default '0',
  strand tag2contig_strand_enum default 'U',
  comment text
);

create index tag2contig_contig_id_key ON TAG2CONTIG(contig_id);

--
-- Table structure for table TAGSEQUENCE
--

create sequence tagsequence_id_seq;

CREATE TABLE TAGSEQUENCE (
  tag_seq_id integer NOT NULL PRIMARY KEY default nextval('tagsequence_id_seq'),
  tagseqname varchar(32) NOT NULL,
  sequence bytea
);

create unique index tagsequence_name_key on TAGSEQUENCE(tagseqname);

--
-- Table structure for table TEMPLATE
--

create sequence template_id_seq;

CREATE TABLE TEMPLATE (
  template_id integer NOT NULL PRIMARY KEY default nextval('template_id_seq'),
  name char(24) not null,
  ligation_id smallint NOT NULL default '0'
);

create unique index template_name_key on TEMPLATE(name);

--
-- Table structure for table TRACEARCHIVE
--

CREATE TABLE TRACEARCHIVE (
  read_id integer NOT NULL PRIMARY KEY,
  traceref bigint NOT NULL
);

--
-- Table structure for table USER
--

CREATE TABLE USERS (
  username char(8) NOT NULL PRIMARY KEY,
  role char(32) NOT NULL default 'finisher'
);

--
-- Final view structure for view CURRENTCONTIGS
--

CREATE VIEW CURRENTCONTIGS AS
select 	CONTIG.contig_id AS contig_id,
	CONTIG.gap4name AS gap4name,
	CONTIG.nreads AS nreads,
	CONTIG.ncntgs AS ncntgs,
	CONTIG.length AS length,
	CONTIG.created AS created,
	CONTIG.updated AS updated,
	CONTIG.project_id AS project_id
from CONTIG left join C2CMAPPING on (CONTIG.contig_id = C2CMAPPING.parent_id)
where (C2CMAPPING.parent_id is not null and CONTIG.nreads > 0);

--
-- Final view structure for view FREEREADS
--

CREATE VIEW FREEREADS AS
select	READINFO.read_id AS read_id,
	READINFO.readname AS readname
from 
(
  (
    (
      READINFO left join SEQ2READ on (READINFO.read_id = SEQ2READ.read_id)
    )
    left join MAPPING on (READINFO.read_id = SEQ2READ.read_id)
  )
  left join CURRENTCONTIGS on (MAPPING.contig_id = CURRENTCONTIGS.contig_id)
)
where CURRENTCONTIGS.contig_id is null;
