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

DROP TABLE IF EXISTS `PROJECT_CONTIG_HISTORY`;
CREATE TABLE IF NOT EXISTS `PROJECT_CONTIG_HISTORY` (
  `project_id` mediumint(8) unsigned NOT NULL default '0',
	`statsdate` date not null , 
	`name` varchar(40) not null,
	`total_contigs` int(12) unsigned NOT NULL default 0,
	`total_reads` int(12) unsigned NOT NULL default 0,
	`total_contig_length` int(12) unsigned NOT NULL default 0,
	`mean_contig_length` int(12) unsigned NOT NULL default 0,
	`stddev_contig_length` int(12) unsigned NOT NULL default 0,
	`max_contig_length` int(12) unsigned NOT NULL default 0,
	`n50_contig_length` int(12) unsigned NOT NULL default 0,
  PRIMARY KEY (`project_id`,`statsdate`),
  KEY `statsdate` (`statsdate`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
