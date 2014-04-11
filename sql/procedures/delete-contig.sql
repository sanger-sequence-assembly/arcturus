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

DROP PROCEDURE IF EXISTS procDeleteContig$

CREATE PROCEDURE procDeleteContig(IN contigId INT)
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intContigExists INT DEFAULT 0;

  select count(*) into intContigExists from CURRENTCONTIGS where contig_id = contigId;

  IF (intContigExists = 1) THEN
    delete from TAG2CONTIG where contig_id = contigId;
    delete from CONTIGTRANSFERREQUEST where contig_id = contigId;
    delete from CONTIGORDER where contig_id = contigId;
    delete from CONSENSUS where contig_id = contigId;

    delete from MAPPING,SEGMENT using MAPPING left join SEGMENT using(mapping_id) where contig_id = contigId;
    delete from C2CMAPPING,C2CSEGMENT using C2CMAPPING left join C2CSEGMENT using(mapping_id) where contig_id = contigId;

    delete from CONTIG where contig_id = contigId;
  END IF;
END;$

DELIMITER ;
