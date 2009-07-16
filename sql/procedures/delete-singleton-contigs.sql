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
