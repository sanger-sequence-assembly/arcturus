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

DROP PROCEDURE IF EXISTS procFindContigHoles$

CREATE PROCEDURE procFindContigHoles(IN cid INT)
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intSequenceID INT DEFAULT -1;
  DECLARE intCstart INT DEFAULT -1;
  DECLARE intCfinish INT DEFAULT -1;

  DECLARE intRight INT DEFAULT -1;

  DECLARE done INT DEFAULT 0;

  DECLARE csrMapping CURSOR FOR SELECT seq_id,cstart,cfinish from MAPPING
	where contig_id=cid order by cstart asc;

  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN csrMapping;

  REPEAT
	FETCH csrMapping into intSequenceID,intCstart,intCfinish;

	IF (intRight > 0 AND intCstart > intRight) THEN
		SELECT cid as ContigID,intSequenceID,intCstart,intRight;
	END IF;

	IF (intCfinish > intRight) THEN
		set intRight = intCfinish;
	END IF;
  UNTIL done END REPEAT;

  CLOSE csrMapping;
END;$

DROP PROCEDURE IF EXISTS procFindAllContigHoles$

CREATE PROCEDURE procFindAllContigHoles()
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intContigID INT DEFAULT -1;

  DECLARE done INT DEFAULT 0;

  DECLARE csrContig CURSOR FOR SELECT contig_id from CONTIG;

  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN csrContig;

  REPEAT
	FETCH csrContig into intContigID;

	IF (done = 0) THEN
		call procFindContigHoles(intContigID);
	END IF;
  UNTIL done END REPEAT;

  CLOSE csrContig;
END;$

DELIMITER ;
