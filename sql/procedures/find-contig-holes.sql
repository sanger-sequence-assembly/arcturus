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
