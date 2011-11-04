-- create-tag-tables.sql
-- stores GAP Zc and Zs tags
-- keeps the Minerva1 and Minerva2 as close as possible so that transforming a GAP4 to GAP5 database is still possible
-- links tags to parent tags
-- parent_id to previously loaded tags is the possible source of non-deletable tags, but retain structure
-- in case policy of always importing all tags proves to be too space hungry

-- GAP4 support

DROP TABLE IF EXISTS `TAG2CONTIG`;
DROP TABLE IF EXISTS `CONTIGTAG`;

CREATE TABLE `CONTIGTAG` (
  `tag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT 'COMM',
  `systematic_id` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
  `tag_seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tagcomment` text,
  PRIMARY KEY (`tag_id`),
  KEY `systematic_id` (`systematic_id`)
	) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `TAG2CONTIG` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL DEFAULT '0',
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tag_id` int(10) unsigned NOT NULL DEFAULT '0',
  `cstart` int(11) unsigned NOT NULL DEFAULT '0',
  `cfinal` int(11) unsigned NOT NULL DEFAULT '0',
  `strand` enum('F','R','U') DEFAULT 'U',
  `comment` tinytext,
  PRIMARY KEY (`id`),
  KEY `tag2contig_index` (`contig_id`),
  KEY `tag_id` (`tag_id`),
  CONSTRAINT `TAG2CONTIG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- not clear what this is for

DROP TABLE IF EXISTS `TAGSEQUENCE`;
CREATE TABLE `TAGSEQUENCE` (
  `tag_seq_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
	`tagseqname` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
	`sequence` blob,
	 PRIMARY KEY (`tag_seq_id`),
	 UNIQUE KEY `tagseqname` (`tagseqname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- stores GAP Zs tags

DROP TABLE IF EXISTS `READTAG`;

CREATE TABLE `READTAG` (
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `tagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `tag_seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `pstart` int(11) NOT NULL,
  `pfinal` int(11) NOT NULL,
	`strand` enum('F','R','U') DEFAULT 'U',
  `deprecated` enum('N','Y','X') DEFAULT 'N',
  `comment` text,
  KEY `readtag_index` (`seq_id`),
  CONSTRAINT `READTAG_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- GAP5 support

DROP TABLE IF EXISTS `SAMTAG`;
CREATE TABLE `SAMTAG` (
  `tag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `SAMtagtype` enum('Zc','Zs','CT','PT', 'RT', 'FS') NOT NULL,
  `SAMtype` ENUM('A', 'i', 'f', 'Z', 'H', 'B') NOT NULL,
  `GAPtagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT 'COMM',
  `tagcomment` text,
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `start` int(11) unsigned NOT NULL DEFAULT '0',
  `length` int(11) unsigned NOT NULL DEFAULT '0',
  `tag_seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `strand` enum('+','-','?','.') NOT NULL DEFAULT 'U',
  `comment` tinytext,
  PRIMARY KEY (`tag_id`),
  KEY `GAPtagtype` (`GAPtagtype`),
  KEY `contig_id` (`contig_id`),
  KEY `tag_seq_id` (`tag_seq_id`),
  CONSTRAINT `SAMTAG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

