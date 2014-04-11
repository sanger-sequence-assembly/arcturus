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

DROP PROCEDURE IF EXISTS procDeleteSingletonContigs$

CREATE PROCEDURE procDeleteSingletonContigs(IN projectName VARCHAR(30))
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intProjectID INT DEFAULT -1;
  DECLARE intContigID INT DEFAULT -1;
  DECLARE strUsername INT DEFAULT substring_index(user(), '@', 1);
  DECLARE done INT DEFAULT 0;
  DECLARE contigsDeleted INT DEFAULT 0;
  DECLARE csrContigs CURSOR FOR SELECT contig_id from CURRENTCONTIGS
	where project_id=intProjectID and nreads = 1;
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  select project_id into intProjectID from PROJECT where name = projectName;

  IF (intProjectID > 0) THEN
	update PROJECT set lockowner=strUsername, lockdate=NOW()
	  where project_id=intProjectID and lockowner is null and lockdate is null;

	IF (row_count() > 0) THEN
		OPEN csrContigs;

		REPEAT
			FETCH csrContigs into intContigID;
			IF (done = 0) THEN
				call procDeleteContig(intContigID);
				set contigsDeleted = contigsDeleted + 1;
			END IF;
		UNTIL done END REPEAT;

		CLOSE csrContigs;

		update PROJECT set lockowner=null, lockdate=null where project_id=intProjectID;

		select contigsDeleted;
	END IF;
  END IF;
END;$

DELIMITER ;
