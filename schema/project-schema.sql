--
-- Table structure for table `ALIGN2SCF`
--

CREATE TABLE `ALIGN2SCF` (
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `startinseq` int(11) NOT NULL,
  `startinscf` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `ASSEMBLY`
--

CREATE TABLE `ASSEMBLY` (
  `assembly_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `chromosome` tinyint(3) unsigned DEFAULT '0',
  `origin` varchar(32) NOT NULL DEFAULT 'The Sanger Institute',
  `size` mediumint(8) unsigned DEFAULT '0',
  `progress` enum('shotgun','finishing','finished','other') DEFAULT 'other',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `creator` varchar(8) NOT NULL DEFAULT 'arcturus',
  `comment` text,
  PRIMARY KEY (`assembly_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `BASECALLER`
--

CREATE TABLE `BASECALLER` (
  `basecaller_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`basecaller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `C2CMAPPING`
--

CREATE TABLE `C2CMAPPING` (
  `age` smallint(5) unsigned DEFAULT '0',
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `parent_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `mapping_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cstart` int(10) unsigned DEFAULT NULL,
  `cfinish` int(10) unsigned DEFAULT NULL,
  `pstart` int(10) unsigned DEFAULT NULL,
  `pfinish` int(10) unsigned DEFAULT NULL,
  `direction` enum('Forward','Reverse') DEFAULT 'Forward',
  PRIMARY KEY (`mapping_id`),
  KEY `contig_id` (`contig_id`),
  KEY `parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `C2CSEGMENT`
--

CREATE TABLE `C2CSEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cstart` int(10) unsigned NOT NULL DEFAULT '0',
  `pstart` int(10) unsigned NOT NULL DEFAULT '0',
  `length` int(10) unsigned DEFAULT NULL,
  KEY `mapping_id` (`mapping_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CANONICALMAPPING`
--

CREATE TABLE `CANONICALMAPPING` (
  `mapping_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cspan` int(11) NOT NULL,
  `rspan` int(11) NOT NULL,
  `checksum` binary(16) NOT NULL,
  PRIMARY KEY (`mapping_id`),
  UNIQUE KEY `checksum` (`checksum`(8))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CANONICALSEGMENT`
--

CREATE TABLE `CANONICALSEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL,
  `cstart` int(11) NOT NULL,
  `rstart` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `mapping_id` (`mapping_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CLONE`
--

CREATE TABLE `CLONE` (
  `clone_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  `origin` varchar(20) DEFAULT 'The Sanger Institute',
  `assembly_id` smallint(5) unsigned DEFAULT '0',
  PRIMARY KEY (`clone_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CLONEMAP`
--

CREATE TABLE `CLONEMAP` (
  `clonename` varchar(20) NOT NULL DEFAULT '',
  `assembly` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cpkbstart` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cpkbfinal` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`clonename`),
  UNIQUE KEY `clonename` (`clonename`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CLONEVEC`
--

CREATE TABLE `CLONEVEC` (
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cvector_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cvleft` int(11) NOT NULL,
  `cvright` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`),
  KEY `cvector_id` (`cvector_id`)) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CLONINGVECTOR`
--

CREATE TABLE `CLONINGVECTOR` (
  `cvector_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`cvector_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONSENSUS`
--

CREATE TABLE `CONSENSUS` (
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `sequence` longblob NOT NULL,
  `quality` longblob NOT NULL,
  `length` int(10) unsigned DEFAULT '0',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`contig_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONTIG`
--

CREATE TABLE `CONTIG` (
  `contig_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `gap4name` char(48) DEFAULT NULL,
  `length` int(10) unsigned DEFAULT '0',
  `ncntgs` smallint(5) unsigned NOT NULL DEFAULT '0',
  `nreads` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `project_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `newreads` mediumint(9) NOT NULL DEFAULT '0',
  `cover` float(8,2) DEFAULT '0.00',
  `origin` enum('Arcturus CAF parser','Finishing Software','Other') DEFAULT NULL,
  `creator` char(8) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `readnamehash` char(16) DEFAULT NULL,
  PRIMARY KEY (`contig_id`),
  KEY `rnhash` (`readnamehash`(8)),
  KEY `project_id` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONTIGORDER`
--

CREATE TABLE `CONTIGORDER` (
  `scaffold_id` int(10) unsigned NOT NULL,
  `contig_id` mediumint(8) unsigned NOT NULL,
  `position` int(10) unsigned NOT NULL,
  `direction` enum('forward','reverse') NOT NULL DEFAULT 'forward',
  `following_gap_size` int(10) unsigned DEFAULT '0',
  UNIQUE KEY `scaffold_id` (`scaffold_id`,`contig_id`,`position`),
  KEY `contig_id` (`contig_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONTIGPADDING`
--

CREATE TABLE `CONTIGPADDING` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `pad_list_id` int(11) NOT NULL AUTO_INCREMENT,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `contig_id` (`contig_id`),
  UNIQUE KEY `pad_list_id` (`pad_list_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONTIGTAG`
--

CREATE TABLE `CONTIGTAG` (
  `tag_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `tagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `systematic_id` varchar(255) DEFAULT NULL,
  `tag_seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tagcomment` text,
  PRIMARY KEY (`tag_id`),
  KEY `systematic_id` (`systematic_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `CONTIGTRANSFERREQUEST`
--

CREATE TABLE `CONTIGTRANSFERREQUEST` (
  `request_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `old_project_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `new_project_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `requester` varchar(8) NOT NULL DEFAULT '',
  `opened` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `requester_comment` varchar(255) DEFAULT NULL,
  `reviewer` varchar(8) DEFAULT NULL,
  `reviewed` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `reviewer_comment` varchar(255) DEFAULT NULL,
  `status` enum('approved','cancelled','done','failed','pending','refused') NOT NULL DEFAULT 'pending',
  `closed` datetime DEFAULT NULL,
  PRIMARY KEY (`request_id`),
  KEY `contig_id` (`contig_id`),
  KEY `old_project_id` (`old_project_id`),
  KEY `new_project_id` (`new_project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `IMPORTEXPORT`
--

CREATE TABLE `IMPORTEXPORT` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `action` enum('import','export') NOT NULL,
  `username` char(8) NOT NULL,
  `file` char(100) NOT NULL,
  `endtime` datetime DEFAULT NULL,
  `starttime` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `LIGATION`
--

CREATE TABLE `LIGATION` (
  `ligation_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  `clone_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `silow` mediumint(8) unsigned DEFAULT NULL,
  `sihigh` mediumint(8) unsigned DEFAULT NULL,
  `svector_id` smallint(5) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ligation_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `MAPPING`
--

CREATE TABLE `MAPPING` (
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `mapping_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cstart` int(10) unsigned DEFAULT NULL,
  `cfinish` int(10) unsigned DEFAULT NULL,
  `direction` enum('Forward','Reverse') NOT NULL DEFAULT 'Forward',
  PRIMARY KEY (`mapping_id`),
  KEY `contig_id` (`contig_id`),
  KEY `seq_id` (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `METADATA`
--

CREATE TABLE `METADATA` (
  `name` varchar(80) NOT NULL,
  `value` varchar(4096) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `NOTE`
--

CREATE TABLE `NOTE` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `creator` char(8) NOT NULL,
  `created` datetime NOT NULL,
  `type` varchar(50) NOT NULL,
  `format` varchar(50) NOT NULL,
  `content` longblob NOT NULL,
  PRIMARY KEY (`id`),
  KEY `creator` (`creator`),
  KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `OLD_PROJECT_DIRECTORY`
--

CREATE TABLE `OLD_PROJECT_DIRECTORY` (
  `project_id` mediumint(8) unsigned NOT NULL,
  `directory` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `PAD`
--

CREATE TABLE `PAD` (
  `pad_list_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  UNIQUE KEY `pad_list_id` (`pad_list_id`,`position`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `PROJECT`
--

CREATE TABLE `PROJECT` (
  `project_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `assembly_id` smallint(5) unsigned DEFAULT '0',
  `name` varchar(40) NOT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `owner` varchar(8) DEFAULT NULL,
  `lockdate` datetime DEFAULT NULL,
  `lockowner` varchar(8) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `creator` varchar(8) NOT NULL DEFAULT 'arcturus',
  `comment` text,
  `status` enum('in shotgun','prefinishing','in finishing','finished','quality checked','retired') NOT NULL DEFAULT 'in shotgun',
  `directory` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`project_id`),
  UNIQUE KEY `assembly_id` (`assembly_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `QUALITYCLIP`
--

CREATE TABLE `QUALITYCLIP` (
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `qleft` int(11) NOT NULL,
  `qright` int(11) NOT NULL,
  PRIMARY KEY (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `READCOMMENT`
--

CREATE TABLE `READCOMMENT` (
  `read_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `comment` text,
  KEY `read_id` (`read_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `READINFO`
--

CREATE TABLE `READINFO` (
  `read_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `readname` char(48) NOT NULL,
  `template_id` mediumint(8) unsigned DEFAULT NULL,
  `asped` date DEFAULT NULL,
  `strand` enum('Forward','Reverse') DEFAULT NULL,
  `primer` enum('Universal_primer','Custom','Unknown_primer') DEFAULT NULL,
  `chemistry` enum('Dye_terminator','Dye_primer') DEFAULT NULL,
  `basecaller` tinyint(3) unsigned DEFAULT NULL,
  `status` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`read_id`),
  UNIQUE KEY `readname` (`readname`),
  UNIQUE KEY `RECORD_INDEX` (`readname`),
  UNIQUE KEY `READNAMES` (`readname`),
  KEY `template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `READTAG`
--


CREATE TABLE `READTAG` (
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `tag_seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `pstart` int(11) NOT NULL,
  `pfinal` int(11) NOT NULL,
  `strand` enum('F','R','U') DEFAULT 'U',
  `deprecated` enum('N','Y','X') DEFAULT 'N',
  `comment` text,
  KEY `readtag_index` (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SCAFFOLD`
--

CREATE TABLE `SCAFFOLD` (
  `scaffold_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `creator` char(8) NOT NULL,
  `created` datetime NOT NULL,
  `import_id` int(10) unsigned DEFAULT NULL,
  `type_id` smallint(5) unsigned NOT NULL,
  `source` varchar(80) DEFAULT NULL,
  `comment` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`scaffold_id`),
  KEY `import_id` (`import_id`),
  KEY `type_id` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SCAFFOLDTYPE`
--

CREATE TABLE `SCAFFOLDTYPE` (
  `type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(80) NOT NULL,
  PRIMARY KEY (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SEGMENT`
--

CREATE TABLE `SEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cstart` int(10) unsigned NOT NULL DEFAULT '0',
  `rstart` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `mapping_id` (`mapping_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SEQ2CONTIG`
--

CREATE TABLE `SEQ2CONTIG` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `seq_id` mediumint(8) unsigned NOT NULL,
  `mapping_id` mediumint(8) unsigned NOT NULL,
  `coffset` int(11) NOT NULL,
  `roffset` int(11) NOT NULL,
  `direction` enum('Forward','Reverse') NOT NULL DEFAULT 'Forward',
  UNIQUE KEY `contig_id` (`contig_id`,`seq_id`),
  KEY `seq_id` (`seq_id`),
  KEY `mapping_id` (`mapping_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SEQ2READ`
--

CREATE TABLE `SEQ2READ` (
  `seq_id` mediumint(8) unsigned NOT NULL,
  `read_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `version` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`seq_id`),
  UNIQUE KEY `read_id` (`read_id`,`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SEQUENCE`
--

CREATE TABLE `SEQUENCE` (
  `seq_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `seqlen` int(11) NOT NULL,
  `seq_hash` binary(16) DEFAULT NULL,
  `qual_hash` binary(16) DEFAULT NULL,
  `sequence` mediumblob NOT NULL,
  `quality` mediumblob NOT NULL,
  PRIMARY KEY (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 MAX_ROWS=8000000 AVG_ROW_LENGTH=900;

--
-- Table structure for table `SEQUENCEVECTOR`
--

CREATE TABLE `SEQUENCEVECTOR` (
  `svector_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`svector_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SEQVEC`
--

CREATE TABLE `SEQVEC` (
  `seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `svector_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `svleft` int(11) NOT NULL,
  `svright` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`),
  KEY `svector_id` (`svector_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `STATUS`
--

CREATE TABLE `STATUS` (
  `status_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`status_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `TAG2CONTIG`
--

CREATE TABLE `TAG2CONTIG` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL DEFAULT '0',
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tag_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cstart` int(11) unsigned NOT NULL DEFAULT '0',
  `cfinal` int(11) unsigned NOT NULL DEFAULT '0',
  `strand` enum('F','R','U') DEFAULT 'U',
  `comment` tinytext,
  PRIMARY KEY (`id`),
  KEY `tag2contig_index` (`contig_id`),
  KEY `tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `TAGSEQUENCE`
--

CREATE TABLE `TAGSEQUENCE` (
  `tag_seq_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `tagseqname` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `sequence` blob,
  PRIMARY KEY (`tag_seq_id`),
  UNIQUE KEY `tagseqname` (`tagseqname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `TEMPLATE`
--

CREATE TABLE `TEMPLATE` (
  `template_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(48) NOT NULL,
  `ligation_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`template_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `TRACEARCHIVE`
--

CREATE TABLE `TRACEARCHIVE` (
  `read_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `traceref` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`read_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `USER`
--

CREATE TABLE `USER` (
  `username` char(8) NOT NULL DEFAULT '',
  `role` char(32) NOT NULL DEFAULT 'finisher',
  PRIMARY KEY (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Final view structure for view `CURRENTCONTIGS`
--

CREATE ALGORITHM=UNDEFINED
DEFINER=`arcturus_dba`@`%` SQL SECURITY INVOKER
VIEW `CURRENTCONTIGS` AS select `CONTIG`.`contig_id` AS `contig_id`,`CONTIG`.`gap4name` AS `gap4name`,`CONTIG`.`nreads` AS `nreads`,`CONTIG`.`ncntgs` AS `ncntgs`,`CONTIG`.`length` AS `length`,`CONTIG`.`created` AS `created`,`CONTIG`.`updated` AS `updated`,`CONTIG`.`project_id` AS `project_id` from (`CONTIG` left join `C2CMAPPING` on((`CONTIG`.`contig_id` = `C2CMAPPING`.`parent_id`))) where (isnull(`C2CMAPPING`.`parent_id`) and (`CONTIG`.`nreads` > 0));

--
-- Final view structure for view `DUPLICATEREADS`
--

CREATE ALGORITHM=UNDEFINED
DEFINER=`arcturus_dba`@`%` SQL SECURITY INVOKER
VIEW `DUPLICATEREADS` AS select `SEQ2READ`.`read_id` AS `read_id`,count(0) AS `hits` from (`CURRENTCONTIGS` left join (`MAPPING` left join `SEQ2READ` on((`MAPPING`.`seq_id` = `SEQ2READ`.`seq_id`))) on((`CURRENTCONTIGS`.`contig_id` = `MAPPING`.`contig_id`))) group by `SEQ2READ`.`read_id` having (`hits` > 1);

--
-- Final view structure for view `FREEREADS`
--

CREATE ALGORITHM=UNDEFINED
DEFINER=`arcturus_dba`@`%` SQL SECURITY INVOKER
VIEW `FREEREADS` AS select `READINFO`.`read_id` AS `read_id`,`READINFO`.`readname` AS `readname`,`READINFO`.`status` AS `status` from (`READINFO` left join ((`SEQ2READ` join `MAPPING`) join `CURRENTCONTIGS`) on(((`READINFO`.`read_id` = `SEQ2READ`.`read_id`) and (`SEQ2READ`.`seq_id` = `MAPPING`.`seq_id`) and (`MAPPING`.`contig_id` = `CURRENTCONTIGS`.`contig_id`)))) where isnull(`CURRENTCONTIGS`.`contig_id`);

--
-- Add foreign key constraints
--

ALTER TABLE `ALIGN2SCF`
ADD CONSTRAINT `ALIGN2SCF_ibfk_1` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `C2CMAPPING`
ADD CONSTRAINT `C2CMAPPING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD CONSTRAINT `C2CMAPPING_ibfk_2` FOREIGN KEY (`parent_id`) REFERENCES `CONTIG` (`contig_id`);

ALTER TABLE `C2CSEGMENT`
ADD CONSTRAINT `C2CSEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `C2CMAPPING` (`mapping_id`) ON DELETE CASCADE;

ALTER TABLE `CANONICALSEGMENT`
ADD CONSTRAINT `CANONICALSEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `CANONICALMAPPING` (`mapping_id`) ON DELETE CASCADE;

ALTER TABLE `CLONEVEC`
ADD CONSTRAINT `CLONEVEC_ibfk_1` FOREIGN KEY (`cvector_id`) REFERENCES `CLONINGVECTOR` (`cvector_id`),
ADD  CONSTRAINT `CLONEVEC_ibfk_2` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `CONSENSUS`
ADD CONSTRAINT `CONSENSUS_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE;

ALTER TABLE `CONTIG`
ADD CONSTRAINT `CONTIG_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE;

ALTER TABLE `CONTIGORDER`
ADD CONSTRAINT `CONTIGORDER_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD  CONSTRAINT `CONTIGORDER_ibfk_2` FOREIGN KEY (`scaffold_id`) REFERENCES `SCAFFOLD` (`scaffold_id`) ON DELETE CASCADE;

ALTER TABLE `CONTIGPADDING`
ADD CONSTRAINT `CONTIGPADDING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE;

ALTER TABLE `CONTIGTRANSFERREQUEST`
ADD CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_2` FOREIGN KEY (`old_project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE,
ADD CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_3` FOREIGN KEY (`new_project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE;

ALTER TABLE `MAPPING`
ADD CONSTRAINT `MAPPING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD CONSTRAINT `MAPPING_ibfk_2` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`);

ALTER TABLE `OLD_PROJECT_DIRECTORY`
ADD CONSTRAINT `OLD_PROJECT_DIRECTORY_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `PROJECT` (`project_id`) ON DELETE CASCADE;

ALTER TABLE `PAD`
ADD CONSTRAINT `PAD_ibfk_1` FOREIGN KEY (`pad_list_id`) REFERENCES `CONTIGPADDING` (`pad_list_id`) ON DELETE CASCADE;

ALTER TABLE `PROJECT`
ADD CONSTRAINT `PROJECT_ibfk_1` FOREIGN KEY (`assembly_id`) REFERENCES `ASSEMBLY` (`assembly_id`);

ALTER TABLE `QUALITYCLIP`
ADD CONSTRAINT `QUALITYCLIP_ibfk_1` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `READCOMMENT`
ADD CONSTRAINT `READCOMMENT_ibfk_1` FOREIGN KEY (`read_id`) REFERENCES `READINFO` (`read_id`) ON DELETE CASCADE;

ALTER TABLE `READTAG`
ADD CONSTRAINT `READTAG_ibfk_1` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `SCAFFOLD`
ADD CONSTRAINT `SCAFFOLD_ibfk_1` FOREIGN KEY (`import_id`) REFERENCES `IMPORTEXPORT` (`id`),
ADD CONSTRAINT `SCAFFOLD_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `SCAFFOLDTYPE` (`type_id`);

ALTER TABLE `SEGMENT`
ADD CONSTRAINT `SEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `MAPPING` (`mapping_id`) ON DELETE CASCADE;

ALTER TABLE `SEQ2CONTIG`
ADD CONSTRAINT `SEQ2CONTIG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD CONSTRAINT `SEQ2CONTIG_ibfk_2` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`),
ADD CONSTRAINT `SEQ2CONTIG_ibfk_3` FOREIGN KEY (`mapping_id`) REFERENCES `CANONICALMAPPING` (`mapping_id`);

ALTER TABLE `SEQ2READ`
ADD CONSTRAINT `SEQ2READ_ibfk_1` FOREIGN KEY (`read_id`) REFERENCES `READINFO` (`read_id`) ON DELETE CASCADE,
ADD CONSTRAINT `SEQ2READ_ibfk_2` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `SEQVEC`
ADD CONSTRAINT `SEQVEC_ibfk_1` FOREIGN KEY (`svector_id`) REFERENCES `SEQUENCEVECTOR` (`svector_id`),
ADD CONSTRAINT `SEQVEC_ibfk_2` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE;

ALTER TABLE `TAG2CONTIG`
ADD CONSTRAINT `TAG2CONTIG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
ADD CONSTRAINT `TAG2CONTIG_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `CONTIGTAG` (`tag_id`) ON DELETE CASCADE;

ALTER TABLE `TRACEARCHIVE`
ADD CONSTRAINT `TRACEARCHIVE_ibfk_1` FOREIGN KEY (`read_id`) REFERENCES `READINFO` (`read_id`) ON DELETE CASCADE;