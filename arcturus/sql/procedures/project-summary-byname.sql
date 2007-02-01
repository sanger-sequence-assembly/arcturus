DELIMITER $

DROP PROCEDURE IF EXISTS procProjectSummaryByName$

CREATE PROCEDURE procProjectSummaryByName(IN minContigSize INT, IN projectName VARCHAR(30))
  READS SQL DATA
  SQL SECURITY INVOKER
BEGIN
  DECLARE intProjectId INT;
  DECLARE intProjectNotFound INT DEFAULT 0;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET intProjectNotFound = 1;

  select project_id into intProjectId from PROJECT where name=projectName;

  IF (intProjectNotFound = 0) THEN
    select projectName as name, count(*) as contigs,
      sum(nreads) as nreads, sum(length) as length,
      round(avg(length)) as avglen, round(std(length)) as stdlen,
      max(length) as maxlen, max(CURRENTCONTIGS.created) as newestcontig,
      max(PROJECT.updated) as projectupdated
    from CURRENTCONTIGS
    where project_id = intProjectId AND length >= minContigSize;
  END IF;
END;$

DELIMITER ;
