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

DROP TABLE IF EXISTS `SAMREADGROUPRECORD`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SAMREADGROUPRECORD` (
   `read_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
   `read_group_line_id` int(10) NOT NULL,
	 `import_id` int(10) unsigned NOT NULL, 
   `IDvalue` char(100) NOT NULL,
	 `SMvalue` char(100) NOT NULL,
	 `LBvalue` char(100) NULL,
	 `DSvalue` char(100) NULL,
	 `PUvalue` char(100) NULL,
	 `PIvalue` int(10) unsigned NULL,
	 `CNvalue` char(100) NULL,
	 `DTvalue` date NULL,
	 `PLvalue` char(100) NULL,
   PRIMARY KEY (`read_group_id`),
   KEY `read_group_id` (`read_group_id`),
	 CONSTRAINT `SAMREADGROUPRECORD_ibfk_1` FOREIGN KEY (`import_id`) REFERENCES `IMPORTEXPORT` (`id`) ON DELETE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

