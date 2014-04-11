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

DELIMITER $

DROP PROCEDURE IF EXISTS procFreeReads$

CREATE PROCEDURE procFreeReads()
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  create temporary table CURREAD
    (read_id integer not null,
     seq_id integer not null,
     key (read_id))
  as select READINFO.read_id,SEQ2READ.seq_id
  from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS
  where READINFO.read_id = SEQ2READ.read_id
    and SEQ2READ.seq_id = MAPPING.seq_id
    and MAPPING.contig_id = CURRENTCONTIGS.contig_id;

  select READINFO.read_id,readname from READINFO left join CURREAD using(read_id) where seq_id is null;

  drop temporary table CURREAD;
END;$

DELIMITER ;
