DELIMITER $

DROP PROCEDURE IF EXISTS procDeleteContigsAfterDate$

CREATE PROCEDURE procDeleteContigsAfterDate(IN cutoff DATETIME)
  MODIFIES SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intContigID INT DEFAULT -1;
  DECLARE done INT DEFAULT 0;
  DECLARE contigsDeleted INT DEFAULT 0;
  DECLARE csrContigs CURSOR FOR SELECT contig_id from CONTIG
	where created > cutoff order by contig_id desc;
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN csrContigs;

  REPEAT
	FETCH csrContigs into intContigID;
	IF (done = 0) THEN
		call procDeleteContig(intContigID);
		set contigsDeleted = contigsDeleted + 1;
	END IF;
  UNTIL done END REPEAT;

  CLOSE csrContigs;

  select contigsDeleted;
END;$

DELIMITER ;
