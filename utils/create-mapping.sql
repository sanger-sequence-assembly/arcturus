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

DROP TABLE IF EXISTS `MAPPING`;

CREATE TABLE `MAPPING` (
  `contig_id` mediumint(8) unsigned NOT NULL default '0',
  `read_id` mediumint(8) unsigned NOT NULL default '0',
  `mapping_id` mediumint(8) unsigned NOT NULL auto_increment,
  `revision` mediumint(8) unsigned NOT NULL default '0',
  INDEX (`contig_id`),
  INDEX (`read_id`),
  PRIMARY KEY `mapping_id` (`mapping_id`)
);

DROP TABLE IF EXISTS `SEGMENT`;

CREATE TABLE `SEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL default '0',
  `pcstart` int(10) unsigned NOT NULL default '0',
  `pcfinal` int(10) unsigned NOT NULL default '0',
  `prstart` smallint(5) unsigned NOT NULL default '0',
  `prfinal` smallint(5) unsigned NOT NULL default '0',
  `label` tinyint(3) unsigned NOT NULL default '0',
  INDEX (`mapping_id`)
);
