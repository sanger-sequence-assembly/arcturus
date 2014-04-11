-- Copyright (c) 2001-2014 Genome Research Ltd.
--
-- Authors: David Harper
--          Ed Zuiderwijk
--          Kate Taylor
--
-- This file is part of Arcturus.
--
-- Arcturus is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program. If not, see <http://www.gnu.org/licenses/>.

-- MySQL dump 10.11
--
-- Host: mcs4a    Database: TESTDB_ADH
-- ------------------------------------------------------
-- Server version	5.1.34-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `ALIGN2SCF`
--

DROP TABLE IF EXISTS `ALIGN2SCF`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `ALIGN2SCF` (
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `startinseq` int(11) NOT NULL,
  `startinscf` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`),
  CONSTRAINT `ALIGN2SCF_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `ASSEMBLY`
--

DROP TABLE IF EXISTS `ASSEMBLY`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `ASSEMBLY` (
  `assembly_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
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
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `BASECALLER`
--

DROP TABLE IF EXISTS `BASECALLER`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `BASECALLER` (
  `basecaller_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`basecaller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `C2CMAPPING`
--

DROP TABLE IF EXISTS `C2CMAPPING`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `C2CMAPPING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
  CONSTRAINT `C2CMAPPING_ibfk_2` FOREIGN KEY (`parent_id`) REFERENCES `CONTIG` (`contig_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `C2CSEGMENT`
--

DROP TABLE IF EXISTS `C2CSEGMENT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `C2CSEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cstart` int(10) unsigned NOT NULL DEFAULT '0',
  `pstart` int(10) unsigned NOT NULL DEFAULT '0',
  `length` int(10) unsigned DEFAULT NULL,
  KEY `mapping_id` (`mapping_id`),
  CONSTRAINT `C2CSEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `C2CMAPPING` (`mapping_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CANONICALMAPPING`
--

DROP TABLE IF EXISTS `CANONICALMAPPING`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CANONICALMAPPING` (
  `mapping_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cspan` int(11) NOT NULL,
  `rspan` int(11) NOT NULL,
  `checksum` binary(16) DEFAULT NULL,
  `cigar` text,
  PRIMARY KEY (`mapping_id`),
  UNIQUE KEY `checksum` (`checksum`(8)),
  KEY `cigar` (`cigar`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CANONICALSEGMENT`
--

DROP TABLE IF EXISTS `CANONICALSEGMENT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CANONICALSEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL,
  `cstart` int(11) NOT NULL,
  `rstart` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `mapping_id` (`mapping_id`),
  CONSTRAINT `CANONICALSEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `CANONICALMAPPING` (`mapping_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CLONE`
--

DROP TABLE IF EXISTS `CLONE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CLONE` (
  `clone_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  `origin` varchar(20) DEFAULT 'The Sanger Institute',
  `assembly_id` smallint(5) unsigned DEFAULT '0',
  PRIMARY KEY (`clone_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CLONEMAP`
--

DROP TABLE IF EXISTS `CLONEMAP`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CLONEMAP` (
  `clonename` varchar(20) NOT NULL DEFAULT '',
  `assembly` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cpkbstart` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cpkbfinal` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`clonename`),
  UNIQUE KEY `clonename` (`clonename`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CLONEVEC`
--

DROP TABLE IF EXISTS `CLONEVEC`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CLONEVEC` (
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `cvector_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cvleft` int(11) NOT NULL,
  `cvright` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`),
  KEY `cvector_id` (`cvector_id`),
  CONSTRAINT `CLONEVEC_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE,
  CONSTRAINT `CLONEVEC_ibfk_1` FOREIGN KEY (`cvector_id`) REFERENCES `CLONINGVECTOR` (`cvector_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CLONINGVECTOR`
--

DROP TABLE IF EXISTS `CLONINGVECTOR`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CLONINGVECTOR` (
  `cvector_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
  PRIMARY KEY (`cvector_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONSENSUS`
--

DROP TABLE IF EXISTS `CONSENSUS`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CONSENSUS` (
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `sequence` longblob NOT NULL,
  `quality` longblob NOT NULL,
  `length` int(10) unsigned DEFAULT '0',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`contig_id`),
  CONSTRAINT `CONSENSUS_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONTIG`
--

DROP TABLE IF EXISTS `CONTIG`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  KEY `project_id` (`project_id`),
  CONSTRAINT `CONTIG_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONTIGORDER`
--

DROP TABLE IF EXISTS `CONTIGORDER`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CONTIGORDER` (
  `scaffold_id` int(10) unsigned NOT NULL,
  `contig_id` mediumint(8) unsigned NOT NULL,
  `position` int(10) unsigned NOT NULL,
  `direction` enum('forward','reverse') NOT NULL DEFAULT 'forward',
  `following_gap_size` int(10) unsigned DEFAULT '0',
  UNIQUE KEY `scaffold_id` (`scaffold_id`,`contig_id`,`position`),
  KEY `contig_id` (`contig_id`),
  CONSTRAINT `CONTIGORDER_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
  CONSTRAINT `CONTIGORDER_ibfk_2` FOREIGN KEY (`scaffold_id`) REFERENCES `SCAFFOLD` (`scaffold_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONTIGPADDING`
--

DROP TABLE IF EXISTS `CONTIGPADDING`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CONTIGPADDING` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `pad_list_id` int(11) NOT NULL AUTO_INCREMENT,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `contig_id` (`contig_id`),
  UNIQUE KEY `pad_list_id` (`pad_list_id`),
  CONSTRAINT `CONTIGPADDING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONTIGTAG`
--

DROP TABLE IF EXISTS `CONTIGTAG`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `CONTIGTAG` (
  `tag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tagtype` varchar(4) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `systematic_id` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
  `tag_seq_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tagcomment` text,
  PRIMARY KEY (`tag_id`),
  KEY `systematic_id` (`systematic_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `CONTIGTRANSFERREQUEST`
--

DROP TABLE IF EXISTS `CONTIGTRANSFERREQUEST`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  KEY `new_project_id` (`new_project_id`),
  CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
  CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_2` FOREIGN KEY (`old_project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE,
  CONSTRAINT `CONTIGTRANSFERREQUEST_ibfk_3` FOREIGN KEY (`new_project_id`) REFERENCES `PROJECT` (`project_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `CURRENTCONTIGS`
--

DROP TABLE IF EXISTS `CURRENTCONTIGS`;
/*!50001 DROP VIEW IF EXISTS `CURRENTCONTIGS`*/;
/*!50001 CREATE TABLE `CURRENTCONTIGS` (
  `contig_id` mediumint(8) unsigned,
  `gap4name` char(48),
  `nreads` mediumint(8) unsigned,
  `ncntgs` smallint(5) unsigned,
  `length` int(10) unsigned,
  `created` datetime,
  `updated` timestamp,
  `project_id` mediumint(8) unsigned
) */;

--
-- Temporary table structure for view `DUPLICATEREADS`
--

DROP TABLE IF EXISTS `DUPLICATEREADS`;
/*!50001 DROP VIEW IF EXISTS `DUPLICATEREADS`*/;
/*!50001 CREATE TABLE `DUPLICATEREADS` (
  `read_id` int(10) unsigned,
  `hits` bigint(21)
) */;

--
-- Table structure for table `IMPORTEXPORT`
--

DROP TABLE IF EXISTS `IMPORTEXPORT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `IMPORTEXPORT` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `action` enum('import','export') NOT NULL,
  `username` char(8) NOT NULL,
  `file` char(100) NOT NULL,
  `date` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `LIGATION`
--

DROP TABLE IF EXISTS `LIGATION`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `MAPPING`
--

DROP TABLE IF EXISTS `MAPPING`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `MAPPING` (
  `contig_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `mapping_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cstart` int(10) unsigned DEFAULT NULL,
  `cfinish` int(10) unsigned DEFAULT NULL,
  `direction` enum('Forward','Reverse') NOT NULL DEFAULT 'Forward',
  PRIMARY KEY (`mapping_id`),
  KEY `contig_id` (`contig_id`),
  KEY `seq_id` (`seq_id`),
  CONSTRAINT `MAPPING_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`),
  CONSTRAINT `MAPPING_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `NOTE`
--

DROP TABLE IF EXISTS `NOTE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `PAD`
--

DROP TABLE IF EXISTS `PAD`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `PAD` (
  `pad_list_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  UNIQUE KEY `pad_list_id` (`pad_list_id`,`position`),
  CONSTRAINT `PAD_ibfk_1` FOREIGN KEY (`pad_list_id`) REFERENCES `CONTIGPADDING` (`pad_list_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `PROJECT`
--

DROP TABLE IF EXISTS `PROJECT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  UNIQUE KEY `assembly_id` (`assembly_id`,`name`),
  CONSTRAINT `PROJECT_ibfk_1` FOREIGN KEY (`assembly_id`) REFERENCES `ASSEMBLY` (`assembly_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `QUALITYCLIP`
--

DROP TABLE IF EXISTS `QUALITYCLIP`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `QUALITYCLIP` (
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `qleft` int(11) NOT NULL,
  `qright` int(11) NOT NULL,
  PRIMARY KEY (`seq_id`),
  CONSTRAINT `QUALITYCLIP_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `READCOMMENT`
--

DROP TABLE IF EXISTS `READCOMMENT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `READCOMMENT` (
  `read_id` int(10) unsigned NOT NULL DEFAULT '0',
  `comment` text,
  KEY `read_id` (`read_id`),
  CONSTRAINT `READCOMMENT_FK_READNAME` FOREIGN KEY (`read_id`) REFERENCES `READNAME` (`read_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `READINFO`
--

DROP TABLE IF EXISTS `READINFO`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `READINFO` (
  `read_id` int(10) unsigned NOT NULL,
  `template_id` mediumint(8) unsigned DEFAULT NULL,
  `asped` date DEFAULT NULL,
  `strand` enum('Forward','Reverse') DEFAULT NULL,
  `primer` enum('Universal_primer','Custom','Unknown_primer') DEFAULT NULL,
  `chemistry` enum('Dye_terminator','Dye_primer') DEFAULT NULL,
  `basecaller` tinyint(3) unsigned DEFAULT NULL,
  `status` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`read_id`),
  KEY `template_id` (`template_id`),
  CONSTRAINT `READINFO_FK_READNAME` FOREIGN KEY (`read_id`) REFERENCES `READNAME` (`read_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `READNAME`
--

DROP TABLE IF EXISTS `READNAME`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `READNAME` (
  `read_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `readname` varchar(48) NOT NULL,
  `flags` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`read_id`),
  UNIQUE KEY `readname` (`readname`,`flags`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `READTAG`
--

DROP TABLE IF EXISTS `READTAG`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SCAFFOLD`
--

DROP TABLE IF EXISTS `SCAFFOLD`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  KEY `type_id` (`type_id`),
  CONSTRAINT `SCAFFOLD_ibfk_1` FOREIGN KEY (`import_id`) REFERENCES `IMPORTEXPORT` (`id`),
  CONSTRAINT `SCAFFOLD_ibfk_2` FOREIGN KEY (`type_id`) REFERENCES `SCAFFOLDTYPE` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SCAFFOLDTYPE`
--

DROP TABLE IF EXISTS `SCAFFOLDTYPE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SCAFFOLDTYPE` (
  `type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(80) NOT NULL,
  PRIMARY KEY (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEGMENT`
--

DROP TABLE IF EXISTS `SEGMENT`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `cstart` int(10) unsigned NOT NULL DEFAULT '0',
  `rstart` int(11) NOT NULL,
  `length` int(11) NOT NULL,
  KEY `mapping_id` (`mapping_id`),
  CONSTRAINT `SEGMENT_ibfk_1` FOREIGN KEY (`mapping_id`) REFERENCES `MAPPING` (`mapping_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEQ2CONTIG`
--

DROP TABLE IF EXISTS `SEQ2CONTIG`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEQ2CONTIG` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `mapping_id` mediumint(8) unsigned NOT NULL,
  `coffset` int(11) NOT NULL,
  `roffset` int(11) NOT NULL,
  `direction` enum('Forward','Reverse') NOT NULL DEFAULT 'Forward',
  UNIQUE KEY `contig_id` (`contig_id`,`seq_id`),
  KEY `seq_id` (`seq_id`),
  KEY `mapping_id` (`mapping_id`),
  CONSTRAINT `SEQ2CONTIG_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`),
  CONSTRAINT `SEQ2CONTIG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
  CONSTRAINT `SEQ2CONTIG_ibfk_3` FOREIGN KEY (`mapping_id`) REFERENCES `CANONICALMAPPING` (`mapping_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEQ2READ`
--

DROP TABLE IF EXISTS `SEQ2READ`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEQ2READ` (
  `seq_id` int(10) unsigned NOT NULL,
  `read_id` int(10) unsigned NOT NULL,
  `version` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`seq_id`),
  UNIQUE KEY `read_id` (`read_id`,`version`),
  KEY `read_id_2` (`read_id`),
  CONSTRAINT `SEQ2READ_FK_READNAME` FOREIGN KEY (`read_id`) REFERENCES `READNAME` (`read_id`) ON DELETE CASCADE,
  CONSTRAINT `SEQ2READ_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEQUENCE`
--

DROP TABLE IF EXISTS `SEQUENCE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEQUENCE` (
  `seq_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seqlen` int(11) NOT NULL,
  `seq_hash` binary(16) DEFAULT NULL,
  `qual_hash` binary(16) DEFAULT NULL,
  `sequence` mediumblob NOT NULL,
  `quality` mediumblob NOT NULL,
  PRIMARY KEY (`seq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 MAX_ROWS=8000000 AVG_ROW_LENGTH=900;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEQUENCEVECTOR`
--

DROP TABLE IF EXISTS `SEQUENCEVECTOR`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEQUENCEVECTOR` (
  `svector_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`svector_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `SEQVEC`
--

DROP TABLE IF EXISTS `SEQVEC`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SEQVEC` (
  `seq_id` int(10) unsigned NOT NULL DEFAULT '0',
  `svector_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `svleft` int(11) NOT NULL,
  `svright` int(11) NOT NULL,
  KEY `seq_id` (`seq_id`),
  KEY `svector_id` (`svector_id`),
  CONSTRAINT `SEQVEC_FK_SEQUENCE` FOREIGN KEY (`seq_id`) REFERENCES `SEQUENCE` (`seq_id`) ON DELETE CASCADE,
  CONSTRAINT `SEQVEC_ibfk_1` FOREIGN KEY (`svector_id`) REFERENCES `SEQUENCEVECTOR` (`svector_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `STATUS`
--

DROP TABLE IF EXISTS `STATUS`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `STATUS` (
  `status_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`status_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `TAG2CONTIG`
--

DROP TABLE IF EXISTS `TAG2CONTIG`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
  CONSTRAINT `TAG2CONTIG_ibfk_1` FOREIGN KEY (`contig_id`) REFERENCES `CONTIG` (`contig_id`) ON DELETE CASCADE,
  CONSTRAINT `TAG2CONTIG_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `CONTIGTAG` (`tag_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `TAGSEQUENCE`
--

DROP TABLE IF EXISTS `TAGSEQUENCE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `TAGSEQUENCE` (
  `tag_seq_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `tagseqname` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `sequence` blob,
  PRIMARY KEY (`tag_seq_id`),
  UNIQUE KEY `tagseqname` (`tagseqname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `TEMPLATE`
--

DROP TABLE IF EXISTS `TEMPLATE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `TEMPLATE` (
  `template_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(48) NOT NULL,
  `ligation_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`template_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `THIS_IS_A_TEST_DATABASE`
--

DROP TABLE IF EXISTS `THIS_IS_A_TEST_DATABASE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `THIS_IS_A_TEST_DATABASE` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `TRACEARCHIVE`
--

DROP TABLE IF EXISTS `TRACEARCHIVE`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `TRACEARCHIVE` (
  `read_id` int(10) unsigned NOT NULL DEFAULT '0',
  `traceref` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`read_id`),
  CONSTRAINT `TRACEARCHIVE_FK_READNAME` FOREIGN KEY (`read_id`) REFERENCES `READNAME` (`read_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `USER`
--

DROP TABLE IF EXISTS `USER`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `USER` (
  `username` char(8) NOT NULL DEFAULT '',
  `role` char(32) DEFAULT NULL,
  PRIMARY KEY (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping routines for database 'TESTDB_ADH'
--
DELIMITER ;;
DELIMITER ;

--
-- Final view structure for view `CURRENTCONTIGS`
--

/*!50001 DROP TABLE `CURRENTCONTIGS`*/;
/*!50001 DROP VIEW IF EXISTS `CURRENTCONTIGS`*/;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`arcturus_dba`@`%` SQL SECURITY INVOKER */
/*!50001 VIEW `CURRENTCONTIGS` AS select `CONTIG`.`contig_id` AS `contig_id`,`CONTIG`.`gap4name` AS `gap4name`,`CONTIG`.`nreads` AS `nreads`,`CONTIG`.`ncntgs` AS `ncntgs`,`CONTIG`.`length` AS `length`,`CONTIG`.`created` AS `created`,`CONTIG`.`updated` AS `updated`,`CONTIG`.`project_id` AS `project_id` from (`CONTIG` left join `C2CMAPPING` on((`CONTIG`.`contig_id` = `C2CMAPPING`.`parent_id`))) where (isnull(`C2CMAPPING`.`parent_id`) and (`CONTIG`.`nreads` > 0)) */;

--
-- Final view structure for view `DUPLICATEREADS`
--

/*!50001 DROP TABLE `DUPLICATEREADS`*/;
/*!50001 DROP VIEW IF EXISTS `DUPLICATEREADS`*/;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`arcturus_dba`@`%` SQL SECURITY INVOKER */
/*!50001 VIEW `DUPLICATEREADS` AS select `SEQ2READ`.`read_id` AS `read_id`,count(0) AS `hits` from (`CURRENTCONTIGS` left join (`SEQ2CONTIG` left join `SEQ2READ` on((`SEQ2CONTIG`.`seq_id` = `SEQ2READ`.`seq_id`))) on((`CURRENTCONTIGS`.`contig_id` = `SEQ2CONTIG`.`contig_id`))) group by `SEQ2READ`.`read_id` having (`hits` > 1) */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2010-06-29  7:46:25
