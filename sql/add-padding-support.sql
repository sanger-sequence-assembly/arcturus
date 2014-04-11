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

alter table CONSENSUS
  add column `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

update CONSENSUS CS,CONTIG C
  set CS.updated=C.updated where CS.contig_id=C.contig_id;

CREATE TABLE `CONTIGPADDING` (
  `contig_id` mediumint(8) unsigned NOT NULL,
  `pad_list_id` int(11) NOT NULL AUTO_INCREMENT,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `contig_id` (`contig_id`),
  UNIQUE KEY `pad_list_id` (`pad_list_id`),
  constraint foreign key (contig_id)
    references CONTIG(contig_id) on delete cascade
) ENGINE=InnoDB;

CREATE TABLE `PAD` (
  `pad_list_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  UNIQUE KEY `pad_list_id` (`pad_list_id`,`position`),
  constraint foreign key (pad_list_id)
    references CONTIGPADDING(pad_list_id) on delete cascade
) ENGINE=InnoDB;
